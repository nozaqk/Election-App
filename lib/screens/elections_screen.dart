import 'dart:async';

import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/config.dart';
import '../core/models.dart';
import '../widgets/common.dart';
import '../widgets/election_card.dart';

/// Elections tab: every election, most actionable first.
class ElectionsScreen extends StatefulWidget {
  final ApiClient api;
  final void Function(ElectionSummary election) onOpenElection;

  const ElectionsScreen({super.key, required this.api, required this.onOpenElection});

  @override
  State<ElectionsScreen> createState() => _ElectionsScreenState();
}

class _ElectionsScreenState extends State<ElectionsScreen> {
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
      final res = await widget.api.getJson('/student/overview');
      if (!mounted) return;
      setState(() {
        _overview = Overview.fromJson(res);
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
      return CenteredColumn(child: ErrorBanner(_error!, onRetry: () => _load()));
    }

    final elections =
        _overview == null ? <ElectionSummary>[] : byImportance(_overview!.elections);

    if (elections.isEmpty) {
      return EmptyState(
        icon: Icons.how_to_vote_outlined,
        headline: _overview?.empty?.headline ?? 'No elections',
        body: _overview?.empty?.body ??
            'There are no elections to show right now.',
        onAction: () => _load(),
        actionLabel: 'Refresh',
      );
    }

    return RefreshIndicator(
      onRefresh: () => _load(),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        itemCount: elections.length,
        itemBuilder: (context, i) {
          final e = elections[i];
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: kMaxContentWidth),
              child: ElectionCard(
                e,
                skew: _skew,
                onTap: () => widget.onOpenElection(e),
              ),
            ),
          );
        },
      ),
    );
  }
}
