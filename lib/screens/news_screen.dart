import 'dart:async';

import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/config.dart';
import '../core/models.dart';
import '../core/theme.dart';
import '../core/time.dart';
import '../widgets/common.dart';

/// News tab: election announcements (headline + body) from the overview feed.
class NewsScreen extends StatefulWidget {
  final ApiClient api;
  final void Function(ElectionSummary election) onOpenElection;

  const NewsScreen({super.key, required this.api, required this.onOpenElection});

  @override
  State<NewsScreen> createState() => _NewsScreenState();
}

class _NewsScreenState extends State<NewsScreen> {
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

  @override
  Widget build(BuildContext context) {
    if (_loading) return const LoadingView();
    if (_error != null && _overview == null) {
      return CenteredColumn(child: ErrorBanner(_error!, onRetry: () => _load()));
    }

    final elections = _overview == null
        ? <ElectionSummary>[]
        : byImportance(_overview!.elections)
            .where((e) => e.ui.headline.isNotEmpty || e.ui.body.isNotEmpty)
            .toList();

    if (elections.isEmpty) {
      return EmptyState(
        icon: Icons.newspaper_outlined,
        headline: _overview?.empty?.headline ?? 'No news yet',
        body: _overview?.empty?.body ??
            'Election announcements will appear here as soon as they are published.',
        onAction: () => _load(),
        actionLabel: 'Refresh',
      );
    }

    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
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
              child: AppCard(
                onTap: () => widget.onOpenElection(e),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            e.title,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                        StatusPill(e.status),
                      ],
                    ),
                    if (e.ui.headline.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        e.ui.headline,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                    if (e.ui.body.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(e.ui.body, style: TextStyle(color: muted)),
                    ],
                    if (e.startAt != null || e.endAt != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.schedule, size: 16, color: muted),
                          const SizedBox(width: 6),
                          Text(
                            [
                              if (e.startAt != null) 'From ${formatAccra(e.startAt!)}',
                              if (e.endAt != null) 'To ${formatAccra(e.endAt!)}',
                            ].join('  ·  '),
                            style: TextStyle(color: muted, fontSize: 13),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
