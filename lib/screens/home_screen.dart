import 'dart:async';

import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/config.dart';
import '../core/models.dart';
import '../core/theme.dart';
import '../core/time.dart';
import '../widgets/common.dart';
import '../widgets/election_card.dart';

/// Home tab: greeting plus the elections that need attention.
class HomeScreen extends StatefulWidget {
  final ApiClient api;
  final void Function(ElectionSummary election) onOpenElection;

  const HomeScreen({super.key, required this.api, required this.onOpenElection});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Me? _me;
  Overview? _overview;
  String? _error;
  bool _loading = true;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(AppConfig.pollInterval, (_) => _load(silent: true));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    try {
      final results = await Future.wait([
        widget.api.getJson('/auth/student/me'),
        widget.api.getJson('/student/overview'),
      ]);
      if (!mounted) return;
      setState(() {
        _me = Me.fromJson(results[0]);
        _overview = Overview.fromJson(results[1]);
        _error = null;
        _loading = false;
      });
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

  Duration get _skew {
    final serverTime = _overview?.serverTime;
    if (serverTime == null) return Duration.zero;
    return serverTime.difference(DateTime.now());
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const LoadingView();
    if (_error != null && _overview == null) {
      return CenteredColumn(
        child: ErrorBanner(_error!, onRetry: () => _load()),
      );
    }

    final overview = _overview;
    final elections = overview == null ? <ElectionSummary>[] : byImportance(overview.elections);
    final name = _me?.fullName.trim() ?? '';
    final firstName = name.isEmpty ? '' : name.split(RegExp(r'\s+')).first;

    return RefreshIndicator(
      onRefresh: () => _load(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: kMaxContentWidth),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '${greetingFor(DateTime.now())}${firstName.isEmpty ? '' : ', $firstName'}',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  if (_me != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      '${_me!.department} · ${_me!.programme} · Level ${_me!.level}',
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                  ],
                  const SectionTitle('Elections'),
                  if (elections.isEmpty)
                    AppCard(
                      child: Text(
                        overview?.empty?.body ??
                            'There are no elections right now. Check back soon.',
                        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                      ),
                    )
                  else
                    ...elections.map(
                      (e) => ElectionCard(
                        e,
                        skew: _skew,
                        onTap: () => widget.onOpenElection(e),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
