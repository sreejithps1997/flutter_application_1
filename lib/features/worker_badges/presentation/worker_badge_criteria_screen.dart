import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:workable/core/theme/workable_design.dart';
import 'package:workable/widgets/workable_ui.dart';

import '../domain/worker_badge_summary.dart';

class WorkerBadgeCriteriaScreen extends StatelessWidget {
  static const routeName = '/worker/badge-criteria';

  const WorkerBadgeCriteriaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WorkableDesign.canvas,
      appBar: AppBar(title: const Text('Badge Criteria')),
      body: ListView(
        padding: const EdgeInsets.all(WorkableDesign.pagePadding),
        children: [
          const WorkablePageHeader(
            title: 'Worker Trust Badges',
            subtitle:
                'Badges are calculated from completed paid jobs, verified work hours, ratings, and punctuality.',
            icon: LucideIcons.badgeCheck,
          ),
          const SizedBox(height: 16),
          ..._criteria.map(_CriteriaCard.new),
          const SizedBox(height: 12),
          const WorkableSectionCard(
            child: WorkableInfoRow(
              icon: LucideIcons.shieldCheck,
              text:
                  'Verified hours count only from Start Work to Work Completed. Sessions longer than 16 hours are ignored until reviewed.',
            ),
          ),
        ],
      ),
    );
  }
}

class _BadgeCriteria {
  const _BadgeCriteria({
    required this.level,
    required this.description,
    required this.requirements,
  });

  final WorkerBadgeLevel level;
  final String description;
  final List<String> requirements;
}

const _criteria = [
  _BadgeCriteria(
    level: WorkerBadgeLevel.verified,
    description: 'Basic trusted worker profile with platform activity.',
    requirements: [
      'Worker profile is active',
      'Identity/verification status can be shown separately',
      'First completed paid jobs start building badge history',
    ],
  ),
  _BadgeCriteria(
    level: WorkerBadgeLevel.silver,
    description: 'Reliable worker with early consistency.',
    requirements: [
      '15+ completed paid jobs',
      '40+ verified work hours',
      '4.2+ average customer rating',
    ],
  ),
  _BadgeCriteria(
    level: WorkerBadgeLevel.gold,
    description: 'Strong professional with proven customer trust.',
    requirements: [
      '50+ completed paid jobs',
      '150+ verified work hours',
      '4.5+ average customer rating',
    ],
  ),
  _BadgeCriteria(
    level: WorkerBadgeLevel.diamond,
    description: 'High-performing expert for important services.',
    requirements: [
      '120+ completed paid jobs',
      '500+ verified work hours',
      '4.7+ average customer rating',
    ],
  ),
  _BadgeCriteria(
    level: WorkerBadgeLevel.platinum,
    description: 'Elite Workable professional with excellent punctuality.',
    requirements: [
      '250+ completed paid jobs',
      '1,200+ verified work hours',
      '4.8+ average customer rating',
      '95%+ on-time arrival when schedule data is available',
    ],
  ),
];

class _CriteriaCard extends StatelessWidget {
  const _CriteriaCard(this.criteria);

  final _BadgeCriteria criteria;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: WorkableSectionCard(
        borderColor: criteria.level.color.withValues(alpha: 0.22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: criteria.level.color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(WorkableDesign.radius),
                  ),
                  child: Icon(LucideIcons.award, color: criteria.level.color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${criteria.level.label} Professional',
                        style: const TextStyle(
                          color: WorkableDesign.ink,
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        criteria.description,
                        style: const TextStyle(
                          color: WorkableDesign.muted,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...criteria.requirements.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: WorkableInfoRow(
                  icon: LucideIcons.checkCircle,
                  text: item,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
