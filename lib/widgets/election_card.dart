import 'package:flutter/material.dart';

import '../core/models.dart';
import '../core/theme.dart';
import '../core/time.dart';
import 'common.dart';

/// Summary card for one election, used on Home / News / Elections lists.
class ElectionCard extends StatelessWidget {
  final ElectionSummary election;
  final Duration skew;
  final VoidCallback? onTap;

  const ElectionCard(this.election, {super.key, this.skew = Duration.zero, this.onTap});

  @override
  Widget build(BuildContext context) {
    final e = election;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final window = e.startLabel.isNotEmpty || e.endLabel.isNotEmpty
        ? '${e.startLabel} – ${e.endLabel}'
        : (e.startAt != null && e.endAt != null
            ? '${formatAccra(e.startAt!)} – ${formatAccra(e.endAt!)}'
            : '');

    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
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
              const SizedBox(width: 8),
              StatusPill(e.status),
            ],
          ),
          if (e.description.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              e.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: muted),
            ),
          ],
          if (window.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.schedule, size: 16, color: muted),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(window, style: TextStyle(color: muted, fontSize: 13)),
                ),
              ],
            ),
          ],
          if (e.status == ElectionStatus.scheduled && e.startAt != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.hourglass_top, size: 16, color: AppColors.amber),
                const SizedBox(width: 6),
                const Text('Starts in ', style: TextStyle(fontSize: 13)),
                CountdownText(e.startAt!, skew: skew, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              ],
            ),
          ],
          if (e.status == ElectionStatus.active && e.endAt != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.timer_outlined, size: 16, color: AppColors.green2),
                const SizedBox(width: 6),
                const Text('Closes in ', style: TextStyle(fontSize: 13)),
                CountdownText(e.endAt!, skew: skew, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              ],
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              if (e.hasVoted)
                const Chip(
                  label: Text('Voted'),
                  avatar: Icon(Icons.check_circle, size: 16),
                  visualDensity: VisualDensity.compact,
                ),
              if (e.hasVoted) const SizedBox(width: 8),
              const Spacer(),
              Text(
                e.canVote ? 'Vote now' : (e.hasVoted ? 'View results' : 'Details'),
                style: const TextStyle(
                  color: AppColors.green2,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.green2),
            ],
          ),
        ],
      ),
    );
  }
}
