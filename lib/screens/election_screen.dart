import 'dart:async';

import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/config.dart';
import '../core/models.dart';
import '../core/native_bridge.dart';
import '../core/theme.dart';
import '../core/time.dart';
import '../widgets/common.dart';

enum _Step { verify, ballot, review, done }

/// Election detail + voting flow.
///
/// Steps: verify presence (Bluetooth polling node when required) → choose
/// candidates → review → done. The presence authorisation is time-boxed;
/// if it expires mid-flow the student returns to Verify with their ballot
/// selections intact.
class ElectionScreen extends StatefulWidget {
  final ApiClient api;
  final ElectionSummary election;

  const ElectionScreen({super.key, required this.api, required this.election});

  @override
  State<ElectionScreen> createState() => _ElectionScreenState();
}

class _ElectionScreenState extends State<ElectionScreen> {
  final NativeBridge _bridge = NativeBridge();

  ElectionDetail? _detail;
  String? _error;
  bool _loading = true;
  Timer? _pollTimer;
  Timer? _tickTimer;
  DateTime _now = DateTime.now();

  _Step _step = _Step.verify;
  String? _authorization;
  DateTime? _authExpiresAt;
  final Map<String, Set<String>> _selections = <String, Set<String>>{};
  final Set<String> _abstains = <String>{};
  String? _receiptId;
  bool _busy = false;
  String? _verifyError;
  String? _verifyErrorCode;

  Results? _results;
  bool _resultsLoading = false;
  String? _resultsError;

  @override
  void initState() {
    super.initState();
    _loadDetail();
    _pollTimer = Timer.periodic(AppConfig.pollInterval, (_) => _loadDetail(silent: true));
    _tickTimer = Timer.periodic(const Duration(seconds: 1), _tick);
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _tickTimer?.cancel();
    super.dispose();
  }

  Duration get _skew {
    final serverTime = _detail?.serverTime;
    if (serverTime == null) return Duration.zero;
    return serverTime.difference(DateTime.now());
  }

  DateTime get _effectiveNow => DateTime.now().add(_skew);

  void _tick(Timer timer) {
    if (!mounted) return;
    setState(() => _now = _effectiveNow);
    // Expired authorisation sends the student back to Verify (selections kept).
    if (_authExpiresAt != null &&
        _effectiveNow.isAfter(_authExpiresAt!) &&
        (_step == _Step.ballot || _step == _Step.review)) {
      setState(() {
        _step = _Step.verify;
        _authorization = null;
        _authExpiresAt = null;
        _verifyError = 'Your authorisation expired. Please verify again — your selections are kept.';
        _verifyErrorCode = 'AUTH_EXPIRED';
      });
    }
  }

  Future<void> _loadDetail({bool silent = false}) async {
    try {
      final res = await widget.api.getJson('/student/elections/${widget.election.id}');
      if (!mounted) return;
      final detail = ElectionDetail.fromJson(res);
      setState(() {
        _detail = detail;
        _error = null;
        _loading = false;
      });
      if (detail.hasVoted || detail.status == ElectionStatus.published) {
        _loadResults();
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Something went wrong. Please try again.';
        _loading = false;
      });
    }
  }

  Future<void> _loadResults() async {
    if (_resultsLoading) return;
    setState(() {
      _resultsLoading = true;
      _resultsError = null;
    });
    try {
      final res = await widget.api.getJson('/student/elections/${widget.election.id}/results');
      if (!mounted) return;
      setState(() {
        _results = Results.fromJson(res);
        _resultsLoading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _resultsError = e.message;
        _resultsLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _resultsError = 'Results could not be loaded.';
        _resultsLoading = false;
      });
    }
  }

  // ---------------------------------------------------------------- verify

  Future<void> _verify() async {
    final detail = _detail;
    if (detail == null || _busy) return;
    setState(() {
      _busy = true;
      _verifyError = null;
      _verifyErrorCode = null;
    });
    try {
      if (detail.requirePresence) {
        final claims = await _bridge.scan();
        if (claims.isEmpty) {
          throw const NativeException(
              'TIMEOUT', 'No polling device found. Move closer to the polling device and try again.');
        }
        // Try each nearby beacon (strongest first) until the server accepts
        // one; look-alikes from other devices are rejected with NODE_REJECTED.
        ApiException? last;
        for (final claim in claims.take(3)) {
          try {
            final res = await widget.api.postJson(
                '/student/elections/${detail.id}/presence', {'claim': claim.toJson()});
            _applyGrant(PresenceGrant.fromJson(res));
            return;
          } on ApiException catch (e) {
            last = e;
            if (e.code != 'NODE_REJECTED') rethrow;
          }
        }
        throw last ??
            const ApiException(0, 'NODE_REJECTED', 'The polling device rejected this phone.');
      }
      final res = await widget.api.postJson(
          '/student/elections/${detail.id}/presence', <String, dynamic>{});
      _applyGrant(PresenceGrant.fromJson(res));
    } on NativeException catch (e) {
      if (mounted) {
        setState(() {
          _verifyError = e.message;
          _verifyErrorCode = e.code;
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _verifyError = e.message;
          _verifyErrorCode = e.code;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _verifyError = 'Verification failed. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _applyGrant(PresenceGrant grant) {
    setState(() {
      _authorization = grant.authorization;
      _authExpiresAt = grant.expiresAt;
      _step = _Step.ballot;
      _verifyError = null;
    });
  }

  // ---------------------------------------------------------------- ballot

  void _toggleCandidate(Position position, String candidateId) {
    setState(() {
      final selected = _selections.putIfAbsent(position.id, () => <String>{});
      if (selected.contains(candidateId)) {
        selected.remove(candidateId);
      } else {
        if (position.maxSelections == 1) {
          selected.clear();
        } else if (selected.length >= position.maxSelections) {
          return;
        }
        selected.add(candidateId);
      }
      _abstains.remove(position.id);
    });
  }

  void _toggleAbstain(Position position) {
    setState(() {
      if (_abstains.contains(position.id)) {
        _abstains.remove(position.id);
      } else {
        _abstains.add(position.id);
        _selections[position.id]?.clear();
      }
    });
  }

  bool _positionAnswered(Position position) =>
      (_selections[position.id]?.isNotEmpty ?? false) ||
      _abstains.contains(position.id);

  bool get _ballotComplete =>
      _detail != null && _detail!.positions.every(_positionAnswered);

  // ---------------------------------------------------------------- review

  Future<void> _castVote() async {
    final detail = _detail;
    if (detail == null || _busy || _authorization == null) return;
    setState(() {
      _busy = true;
      _verifyError = null;
    });
    try {
      final choices = detail.positions.map((p) {
        return <String, dynamic>{
          'positionId': p.id,
          'candidateIds': (_selections[p.id] ?? <String>{}).toList(),
          'abstain': _abstains.contains(p.id),
        };
      }).toList();
      final res = await widget.api.postJson(
        '/student/elections/${detail.id}/vote',
        {'authorization': _authorization, 'choices': choices},
      );
      if (!mounted) return;
      setState(() {
        _receiptId = res['receiptId']?.toString();
        _step = _Step.done;
      });
      _loadResults();
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.code == 'ALREADY_VOTED') {
        setState(() {
          _step = _Step.done;
          _receiptId = null;
        });
        _loadResults();
      } else if (e.code == 'AUTH_EXPIRED' || e.code == 'AUTH_USED') {
        setState(() {
          _step = _Step.verify;
          _authorization = null;
          _authExpiresAt = null;
          _verifyError = 'Your authorisation is no longer valid. Please verify again.';
          _verifyErrorCode = e.code;
        });
      } else {
        setState(() => _verifyError = e.message);
      }
    } catch (_) {
      if (mounted) setState(() => _verifyError = 'Could not cast your vote. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ---------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.election.title)),
      body: _loading
          ? const LoadingView()
          : (_error != null && _detail == null)
              ? CenteredColumn(child: ErrorBanner(_error!, onRetry: () => _loadDetail()))
              : RefreshIndicator(
                  onRefresh: () => _loadDetail(),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                    children: [
                      Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: kMaxContentWidth),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _header(_detail!),
                              const SizedBox(height: 16),
                              _body(_detail!),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _header(ElectionDetail d) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final window = d.startLabel.isNotEmpty || d.endLabel.isNotEmpty
        ? '${d.startLabel} – ${d.endLabel}'
        : (d.startAt != null && d.endAt != null
            ? '${formatAccra(d.startAt!)} – ${formatAccra(d.endAt!)}'
            : '');
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  d.title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              StatusPill(d.status),
            ],
          ),
          if (d.description.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(d.description, style: TextStyle(color: muted)),
          ],
          if (window.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.schedule, size: 16, color: muted),
                const SizedBox(width: 6),
                Expanded(child: Text(window, style: TextStyle(color: muted, fontSize: 13))),
              ],
            ),
          ],
          if (d.status == ElectionStatus.scheduled && d.startAt != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.hourglass_top, size: 16, color: AppColors.amber),
                const SizedBox(width: 6),
                const Text('Starts in ', style: TextStyle(fontSize: 13)),
                CountdownText(d.startAt!, skew: _skew, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              ],
            ),
          ],
          if (d.status == ElectionStatus.active && d.endAt != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.timer_outlined, size: 16, color: AppColors.green2),
                const SizedBox(width: 6),
                const Text('Closes in ', style: TextStyle(fontSize: 13)),
                CountdownText(d.endAt!, skew: _skew, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              ],
            ),
          ],
          if (d.ui.headline.isNotEmpty || d.ui.body.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(kRadius),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (d.ui.headline.isNotEmpty)
                    Text(d.ui.headline, style: const TextStyle(fontWeight: FontWeight.w700)),
                  if (d.ui.body.isNotEmpty)
                    Text(d.ui.body, style: TextStyle(color: muted)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _body(ElectionDetail d) {
    if (_step == _Step.done) return _doneView();
    if (d.hasVoted) return _votedView();
    if (d.canVote) return _voteFlowView(d);
    return _infoView(d);
  }

  // ---------------------------------------------------------------- views

  Widget _infoView(ElectionDetail d) {
    return EmptyState(
      icon: Icons.how_to_vote_outlined,
      headline: d.ui.headline.isNotEmpty ? d.ui.headline : 'Voting is not open yet',
      body: d.ui.body.isNotEmpty
          ? d.ui.body
          : 'You will be able to vote here once this election opens.',
      onAction: () => _loadDetail(),
      actionLabel: 'Refresh',
    );
  }

  Widget _votedView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AppCard(
          child: Row(
            children: [
              Icon(Icons.check_circle, color: AppColors.green2, size: 28),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'You have already voted in this election.',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        _resultsSection(),
      ],
    );
  }

  Widget _doneView() {
    final receipt = _receiptId;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppCard(
          child: Column(
            children: [
              const Icon(Icons.check_circle, color: AppColors.green2, size: 56),
              const SizedBox(height: 12),
              Text(
                'Vote recorded',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(
                receipt != null && receipt.isNotEmpty
                    ? 'Receipt ${receipt.length > 8 ? receipt.substring(0, 8) : receipt}'
                    : 'Your ballot has been cast successfully.',
                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        _resultsSection(),
      ],
    );
  }

  Widget _voteFlowView(ElectionDetail d) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _stepper(),
        const SizedBox(height: 12),
        if (_authExpiresAt != null && _step != _Step.verify) _authBanner(),
        if (_authExpiresAt != null && _step != _Step.verify) const SizedBox(height: 12),
        switch (_step) {
          _Step.verify => _verifyView(d),
          _Step.ballot => _ballotView(d),
          _Step.review => _reviewView(d),
          _Step.done => const SizedBox.shrink(),
        },
      ],
    );
  }

  Widget _stepper() {
    const steps = ['Verify', 'Ballot', 'Review'];
    final current = switch (_step) {
      _Step.verify => 0,
      _Step.ballot => 1,
      _Step.review => 2,
      _Step.done => 3,
    };
    return Row(
      children: [
        for (var i = 0; i < steps.length; i++) ...[
          if (i > 0) const Expanded(child: Divider(height: 1)),
          Column(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: i <= current ? AppColors.green : Theme.of(context).colorScheme.surfaceContainerHighest,
                child: Icon(
                  i < current ? Icons.check : Icons.circle,
                  size: 14,
                  color: i <= current ? Colors.white : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                steps[i],
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: i == current ? FontWeight.w700 : FontWeight.w400,
                  color: i == current ? AppColors.green : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _authBanner() {
    final remaining = _authExpiresAt!.difference(_now);
    final urgent = remaining.inSeconds <= 60;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: urgent ? const Color(0xFFFDF0C7) : const Color(0xFFD8F3E4),
        borderRadius: BorderRadius.circular(kRadius),
      ),
      child: Row(
        children: [
          Icon(Icons.verified_user_outlined, color: urgent ? AppColors.amber : AppColors.green2, size: 20),
          const SizedBox(width: 10),
          const Text('Authorisation expires in ', style: TextStyle(fontWeight: FontWeight.w600)),
          Text(
            formatCountdown(remaining),
            style: const TextStyle(fontWeight: FontWeight.w800, fontFeatures: [FontFeature.tabularFigures()]),
          ),
        ],
      ),
    );
  }

  Widget _verifyView(ElectionDetail d) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Verify your presence',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            d.requirePresence
                ? 'This election is presence-gated. Keep Bluetooth on and scan for the polling node at your polling station, then cast your ballot before the authorisation expires.'
                : 'Confirm you are ready to vote. You will receive a short-lived authorisation to cast your ballot.',
            style: TextStyle(color: muted),
          ),
          if (_verifyError != null) ...[
            const SizedBox(height: 12),
            ErrorBanner(_verifyError!),
          ],
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _busy ? null : _verify,
            icon: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : Icon(d.requirePresence ? Icons.bluetooth_searching : Icons.verified_user_outlined),
            label: Text(_busy
                ? 'Verifying…'
                : d.requirePresence
                    ? 'Scan for polling node'
                    : 'Verify and continue'),
          ),
          if (_verifyErrorCode == 'BLUETOOTH_OFF') ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => _bridge.enableBluetooth(),
              icon: const Icon(Icons.bluetooth),
              label: const Text('Turn on Bluetooth'),
            ),
          ],
          if (_verifyErrorCode == 'PERMISSION_DENIED' || _verifyErrorCode == 'NO_APP') ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => _bridge.openSettings(),
              icon: const Icon(Icons.settings_outlined),
              label: const Text('Open app settings'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _ballotView(ElectionDetail d) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ...d.positions.map((position) => _positionCard(position, muted)),
        const SizedBox(height: 8),
        if (!_ballotComplete)
          Text(
            'Answer every position to continue.',
            style: TextStyle(color: muted, fontSize: 13),
          ),
        const SizedBox(height: 8),
        ElevatedButton(
          onPressed: _ballotComplete ? () => setState(() => _step = _Step.review) : null,
          child: const Text('Review ballot'),
        ),
        TextButton(
          onPressed: () => setState(() => _step = _Step.verify),
          child: const Text('Back to verify'),
        ),
      ],
    );
  }

  Widget _positionCard(Position position, Color muted) {
    final selected = _selections[position.id] ?? <String>{};
    final abstained = _abstains.contains(position.id);
    final single = position.maxSelections == 1;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            position.title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 2),
          Text(
            single ? 'Choose one' : 'Choose up to ${position.maxSelections}',
            style: TextStyle(color: muted, fontSize: 13),
          ),
          const SizedBox(height: 8),
          ...position.candidates.map((candidate) {
            final checked = selected.contains(candidate.id);
            final disabled = !single && !checked && selected.length >= position.maxSelections;
            final tile = single
                ? RadioListTile<String>(
                    value: candidate.id,
                    groupValue: abstained ? null : (checked ? candidate.id : null),
                    onChanged: (_) => _toggleCandidate(position, candidate.id),
                    title: Text(candidate.name),
                    subtitle: candidate.number.isNotEmpty ? Text('Ballot № ${candidate.number}') : null,
                    contentPadding: EdgeInsets.zero,
                  )
                : CheckboxListTile(
                    value: checked,
                    onChanged: disabled ? null : (_) => _toggleCandidate(position, candidate.id),
                    title: Text(candidate.name),
                    subtitle: candidate.number.isNotEmpty ? Text('Ballot № ${candidate.number}') : null,
                    contentPadding: EdgeInsets.zero,
                  );
            return Column(
              children: [
                tile,
                if (candidate.manifesto.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
                    child: Text(candidate.manifesto, style: TextStyle(color: muted, fontSize: 13)),
                  ),
              ],
            );
          }),
          if (position.allowAbstain)
            (single
                ? RadioListTile<String>(
                    value: '__abstain__',
                    groupValue: abstained ? '__abstain__' : null,
                    onChanged: (_) => _toggleAbstain(position),
                    title: const Text('Abstain'),
                    contentPadding: EdgeInsets.zero,
                  )
                : CheckboxListTile(
                    value: abstained,
                    onChanged: (_) => _toggleAbstain(position),
                    title: const Text('Abstain'),
                    contentPadding: EdgeInsets.zero,
                  )),
        ],
      ),
    );
  }

  Widget _reviewView(ElectionDetail d) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Review your ballot',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              ...d.positions.map((position) {
                final selected = _selections[position.id] ?? <String>{};
                final abstained = _abstains.contains(position.id);
                final names = abstained
                    ? 'Abstain'
                    : position.candidates
                        .where((c) => selected.contains(c.id))
                        .map((c) => c.name)
                        .join(', ');
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: Text(position.title, style: const TextStyle(fontWeight: FontWeight.w600))),
                      Flexible(
                        child: Text(
                          names.isEmpty ? '—' : names,
                          textAlign: TextAlign.end,
                          style: TextStyle(color: muted),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
        const SizedBox(height: 8),
        if (_verifyError != null) ...[
          ErrorBanner(_verifyError!),
          const SizedBox(height: 8),
        ],
        ElevatedButton(
          onPressed: _busy ? null : _castVote,
          child: _busy
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Cast vote'),
        ),
        TextButton(
          onPressed: _busy ? null : () => setState(() => _step = _Step.ballot),
          child: const Text('Back to ballot'),
        ),
      ],
    );
  }

  // -------------------------------------------------------------- results

  Widget _resultsSection() {
    if (_resultsLoading && _results == null) {
      return const AppCard(child: Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator())));
    }
    if (_resultsError != null && _results == null) {
      return AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Results are not published yet.',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            OutlinedButton(onPressed: _loadResults, child: const Text('Check again')),
          ],
        ),
      );
    }
    final results = _results;
    if (results == null) return const SizedBox.shrink();
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionTitle('Results'),
        if (results.publishedLabel.isNotEmpty)
          Text(results.publishedLabel, style: TextStyle(color: muted)),
        if (results.turnoutLabel.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(results.turnoutLabel, style: TextStyle(color: muted, fontWeight: FontWeight.w600)),
        ],
        ...results.results.map((position) => _positionResultCard(position, muted)),
      ],
    );
  }

  Widget _positionResultCard(PositionResult position, Color muted) {
    final sorted = position.candidates.toList()
      ..sort((a, b) => b.votes.compareTo(a.votes));
    final total = position.totalVotes > 0 ? position.totalVotes : 1;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  position.title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              if (position.seats > 0)
                Text('${position.seats} seat${position.seats == 1 ? '' : 's'}',
                    style: TextStyle(color: muted, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '$total votes cast${position.abstained > 0 ? ' · ${position.abstained} abstentions' : ''}',
            style: TextStyle(color: muted, fontSize: 13),
          ),
          if (position.tie || position.runoffRequired) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFDF0C7),
                borderRadius: BorderRadius.circular(kRadius),
              ),
              child: Text(
                position.runoffRequired
                    ? 'A runoff is required for this position.'
                    : 'This position is tied and will go to a runoff.',
                style: const TextStyle(color: AppColors.amber, fontWeight: FontWeight.w600),
              ),
            ),
          ],
          const SizedBox(height: 10),
          ...sorted.map((candidate) {
            final fraction = (candidate.votes / total).clamp(0.0, 1.0);
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Avatar(name: candidate.name, photoUrl: candidate.photoUrl, radius: 16),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(candidate.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                            ),
                            if (candidate.winner) ...[
                              const SizedBox(width: 6),
                              const Icon(Icons.emoji_events, size: 16, color: AppColors.gold),
                            ],
                            if (candidate.tied) ...[
                              const SizedBox(width: 6),
                              const Chip(
                                label: Text('Tied'),
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: fraction,
                            minHeight: 8,
                            backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              candidate.winner ? AppColors.gold : AppColors.green2,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '${candidate.votes}',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
