import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:workable/core/theme/workable_design.dart';

import 'worker_badge_providers.dart';

class WorkerBadgeChip extends ConsumerWidget {
  const WorkerBadgeChip({
    super.key,
    required this.workerId,
    this.compact = true,
  });

  final String workerId;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (workerId.trim().isEmpty) return const SizedBox.shrink();

    final summary = ref.watch(workerBadgeSummaryProvider(workerId));
    return summary.when(
      loading: () => _chip(
        label: 'Checking',
        color: WorkableDesign.muted,
        icon: LucideIcons.loader2,
      ),
      error: (_, __) => _chip(
        label: 'Verified',
        color: WorkableDesign.primary,
        icon: LucideIcons.badgeCheck,
      ),
      data: (badge) => Tooltip(
        message:
            '${badge.label} Professional\n'
            '${badge.completedJobs} completed jobs\n'
            '${badge.verifiedHours.toStringAsFixed(0)} verified hours\n'
            '${badge.averageRating.toStringAsFixed(1)} rating\n'
            '${badge.onTimePercent > 0 ? '${badge.onTimePercent}% on-time' : 'Punctuality tracking starting'}',
        child: _chip(
          label: compact ? badge.label : '${badge.label} Professional',
          color: badge.color,
          icon: LucideIcons.award,
        ),
      ),
    );
  }

  Widget _chip({
    required String label,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 5 : 7,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: compact ? 13 : 15, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: compact ? 11 : 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}
