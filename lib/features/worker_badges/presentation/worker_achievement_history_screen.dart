import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:workable/core/theme/workable_design.dart';
import 'package:workable/widgets/workable_ui.dart';

import '../domain/worker_achievement.dart';
import 'worker_badge_criteria_screen.dart';
import 'worker_badge_providers.dart';
import 'worker_badge_summary_card.dart';

class WorkerAchievementHistoryScreen extends ConsumerWidget {
  static const routeName = '/worker/achievements';

  const WorkerAchievementHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workerId = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (workerId.isEmpty) {
      return const Scaffold(
        body: WorkableEmptyState(
          icon: LucideIcons.userX,
          title: 'Sign in required',
          message: 'Please sign in as a worker to view your achievements.',
        ),
      );
    }

    final achievements = ref.watch(workerAchievementHistoryProvider(workerId));
    final profile = ref.watch(workerCertificateProfileProvider(workerId));

    return Scaffold(
      backgroundColor: WorkableDesign.canvas,
      appBar: AppBar(title: const Text('Achievements & Badges')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(workerAchievementHistoryProvider(workerId));
          ref.invalidate(workerBadgeSummaryProvider(workerId));
          ref.invalidate(workerCertificateProfileProvider(workerId));
        },
        child: ListView(
          padding: const EdgeInsets.all(WorkableDesign.pagePadding),
          children: [
            const WorkablePageHeader(
              title: 'Professional Growth',
              subtitle:
                  'Your badge, verified hours, completed work, and customer trust history.',
              icon: LucideIcons.award,
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => Navigator.pushNamed(
                context,
                WorkerBadgeCriteriaScreen.routeName,
              ),
              icon: const Icon(LucideIcons.badgeCheck, size: 18),
              label: const Text('View Badge Criteria'),
            ),
            const SizedBox(height: 16),
            WorkerBadgeSummaryCard(workerId: workerId),
            const SizedBox(height: 16),
            achievements.when(
              loading: () => const WorkableSectionCard(
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, _) => WorkableSectionCard(
                child: Text(
                  'Unable to load achievements: $error',
                  style: const TextStyle(color: WorkableDesign.danger),
                ),
              ),
              data: (items) {
                if (items.isEmpty) {
                  return const WorkableEmptyState(
                    icon: LucideIcons.badgeCheck,
                    title: 'Achievements will appear after paid jobs',
                    message:
                        'Complete jobs through Workable and your verified hours, badges, and certificate history will sync here.',
                  );
                }
                final workerName = profile.maybeWhen(
                  data: (data) => data.name,
                  orElse: () => '',
                );
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ShareAchievementCard(
                      achievement: items.first,
                      workerName: workerName,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Monthly History',
                      style: TextStyle(
                        color: WorkableDesign.ink,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ...items.map(_AchievementTile.new),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ShareAchievementCard extends StatelessWidget {
  const _ShareAchievementCard({
    required this.achievement,
    required this.workerName,
  });

  final WorkerAchievement achievement;
  final String workerName;

  @override
  Widget build(BuildContext context) {
    return WorkableSectionCard(
      color: achievement.badgeLevel.color.withValues(alpha: 0.07),
      borderColor: achievement.badgeLevel.color.withValues(alpha: 0.2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: achievement.badgeLevel.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(WorkableDesign.radius),
                ),
                child: Icon(
                  LucideIcons.share2,
                  color: achievement.badgeLevel.color,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      achievement.shareTitle,
                      style: const TextStyle(
                        color: WorkableDesign.ink,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      'Share your verified Workable milestone.',
                      style: TextStyle(
                        color: WorkableDesign.ink.withValues(alpha: 0.64),
                      ),
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
              if (achievement.achievementLabels.isNotEmpty)
                ...achievement.achievementLabels.map(
                  (label) => WorkableStatusPill(
                    label: label,
                    color: WorkableDesign.warning,
                    icon: LucideIcons.sparkles,
                  ),
                ),
              WorkableStatusPill(
                label: '${achievement.completedJobs} jobs',
                color: WorkableDesign.primary,
                icon: LucideIcons.briefcase,
              ),
              WorkableStatusPill(
                label:
                    '${achievement.verifiedHours.toStringAsFixed(0)} verified hours',
                color: WorkableDesign.accent,
                icon: LucideIcons.clock,
              ),
              WorkableStatusPill(
                label: achievement.averageRating > 0
                    ? '${achievement.averageRating.toStringAsFixed(1)} rating'
                    : 'New rating',
                color: WorkableDesign.success,
                icon: LucideIcons.star,
              ),
              if (achievement.punctualityTrackedJobs > 0)
                WorkableStatusPill(
                  label: '${achievement.onTimePercent}% on-time',
                  color: WorkableDesign.warning,
                  icon: LucideIcons.timer,
                ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () async {
                await Clipboard.setData(
                  ClipboardData(text: achievement.shareText(workerName)),
                );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Achievement card copied')),
                  );
                }
              },
              icon: const Icon(LucideIcons.copy, size: 18),
              label: const Text('Copy Share Card'),
            ),
          ),
        ],
      ),
    );
  }
}

class _AchievementTile extends StatelessWidget {
  const _AchievementTile(this.achievement);

  final WorkerAchievement achievement;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: WorkableSectionCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  LucideIcons.badgeCheck,
                  color: achievement.badgeLevel.color,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    achievement.monthLabel,
                    style: const TextStyle(
                      color: WorkableDesign.ink,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                WorkableStatusPill(
                  label: achievement.badgeLevel.label,
                  color: achievement.badgeLevel.color,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                WorkableStatusPill(
                  label: '+${achievement.monthlyCompletedJobs} jobs',
                  color: WorkableDesign.primary,
                  icon: LucideIcons.briefcase,
                ),
                WorkableStatusPill(
                  label:
                      '+${achievement.monthlyVerifiedHours.toStringAsFixed(0)} hours',
                  color: WorkableDesign.accent,
                  icon: LucideIcons.clock,
                ),
                WorkableStatusPill(
                  label: achievement.certificateNumber,
                  color: WorkableDesign.muted,
                  icon: LucideIcons.fileCheck,
                ),
                if (achievement.achievementLabels.isNotEmpty)
                  ...achievement.achievementLabels.map(
                    (label) => WorkableStatusPill(
                      label: label,
                      color: WorkableDesign.warning,
                      icon: LucideIcons.sparkles,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
