import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:workable/core/theme/workable_design.dart';
import 'package:workable/widgets/workable_ui.dart';

import 'worker_badge_providers.dart';

class WorkerBadgeSummaryCard extends ConsumerWidget {
  const WorkerBadgeSummaryCard({super.key, required this.workerId});

  final String workerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (workerId.trim().isEmpty) return const SizedBox.shrink();

    final summary = ref.watch(workerBadgeSummaryProvider(workerId));
    return summary.when(
      loading: () => const WorkableSectionCard(
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => const SizedBox.shrink(),
      data: (badge) {
        return WorkableSectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: badge.color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(
                        WorkableDesign.radius,
                      ),
                    ),
                    child: Icon(LucideIcons.award, color: badge.color),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${badge.label} Professional',
                          style: const TextStyle(
                            color: WorkableDesign.ink,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const Text(
                          'Badge is based on real Workable activity.',
                          style: TextStyle(color: WorkableDesign.muted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  WorkableStatusPill(
                    label: '${badge.completedJobs} jobs',
                    color: WorkableDesign.primary,
                    icon: LucideIcons.briefcase,
                  ),
                  WorkableStatusPill(
                    label:
                        '${badge.verifiedHours.toStringAsFixed(0)} verified hours',
                    color: WorkableDesign.accent,
                    icon: LucideIcons.clock,
                  ),
                  WorkableStatusPill(
                    label: badge.averageRating > 0
                        ? '${badge.averageRating.toStringAsFixed(1)} rating'
                        : 'New rating',
                    color: WorkableDesign.success,
                    icon: LucideIcons.star,
                  ),
                  if (badge.repeatCustomers > 0)
                    WorkableStatusPill(
                      label: '${badge.repeatCustomers} repeat customers',
                      color: WorkableDesign.warning,
                      icon: LucideIcons.repeat,
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
