import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:workable/core/theme/workable_design.dart';
import 'package:workable/widgets/workable_ui.dart';

import '../domain/worker_achievement.dart';
import 'worker_badge_providers.dart';

class WorkerExperienceCertificateScreen extends ConsumerWidget {
  static const routeName = '/worker/experience-certificate';

  const WorkerExperienceCertificateScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workerId = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (workerId.isEmpty) {
      return const Scaffold(
        body: WorkableEmptyState(
          icon: LucideIcons.userX,
          title: 'Sign in required',
          message: 'Please sign in as a worker to view your certificate.',
        ),
      );
    }

    final achievements = ref.watch(workerAchievementHistoryProvider(workerId));
    final profile = ref.watch(workerCertificateProfileProvider(workerId));

    return Scaffold(
      backgroundColor: WorkableDesign.canvas,
      appBar: AppBar(title: const Text('Experience Certificate')),
      body: ListView(
        padding: const EdgeInsets.all(WorkableDesign.pagePadding),
        children: [
          const WorkablePageHeader(
            title: 'Verified Work Record',
            subtitle:
                'A professional Workable record based on jobs completed through the platform.',
            icon: LucideIcons.fileCheck,
          ),
          const SizedBox(height: 16),
          achievements.when(
            loading: () => const WorkableSectionCard(
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, _) => WorkableSectionCard(
              child: Text(
                'Unable to load certificate: $error',
                style: const TextStyle(color: WorkableDesign.danger),
              ),
            ),
            data: (items) {
              if (items.isEmpty) {
                return const WorkableEmptyState(
                  icon: LucideIcons.fileCheck,
                  title: 'Certificate unlocks after paid work',
                  message:
                      'Complete paid jobs through Workable to generate your verified work record.',
                );
              }
              return profile.when(
                loading: () => const WorkableSectionCard(
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (error, _) => WorkableSectionCard(
                  child: Text(
                    'Unable to load worker profile: $error',
                    style: const TextStyle(color: WorkableDesign.danger),
                  ),
                ),
                data: (worker) =>
                    _CertificateCard(worker: worker, achievement: items.first),
              );
            },
          ),
          const SizedBox(height: 12),
          const WorkableInfoRow(
            icon: LucideIcons.info,
            text:
                'This is not a government or academic certificate. It is a Workable platform record based on verified service activity.',
          ),
        ],
      ),
    );
  }
}

class _CertificateCard extends StatelessWidget {
  const _CertificateCard({required this.worker, required this.achievement});

  final WorkerCertificateProfile worker;
  final WorkerAchievement achievement;

  @override
  Widget build(BuildContext context) {
    final certificateText = _certificateText;
    return WorkableSectionCard(
      padding: const EdgeInsets.all(18),
      borderColor: achievement.badgeLevel.color.withValues(alpha: 0.28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 34,
                backgroundColor: achievement.badgeLevel.color.withValues(
                  alpha: 0.12,
                ),
                backgroundImage: worker.photoUrl.isNotEmpty
                    ? NetworkImage(worker.photoUrl)
                    : null,
                child: worker.photoUrl.isEmpty
                    ? Icon(
                        LucideIcons.user,
                        color: achievement.badgeLevel.color,
                        size: 30,
                      )
                    : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Workable Professional Experience Certificate',
                      style: TextStyle(
                        color: WorkableDesign.ink,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      worker.name.isEmpty
                          ? 'Verified Workable Worker'
                          : worker.name,
                      style: const TextStyle(
                        color: WorkableDesign.muted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              WorkableStatusPill(
                label: achievement.badgeLevel.label,
                color: achievement.badgeLevel.color,
                icon: LucideIcons.award,
              ),
              if (worker.isVerified)
                const WorkableStatusPill(
                  label: 'Identity verified',
                  color: WorkableDesign.success,
                  icon: LucideIcons.badgeCheck,
                ),
              WorkableStatusPill(
                label: achievement.certificateNumber,
                color: WorkableDesign.primary,
                icon: LucideIcons.fileCheck,
              ),
            ],
          ),
          const SizedBox(height: 18),
          _CertificateMetricGrid(achievement: achievement),
          const SizedBox(height: 18),
          _CertificateField(
            icon: LucideIcons.briefcase,
            label: 'Skills',
            value: worker.skills.isEmpty
                ? 'Not listed yet'
                : worker.skills.join(', '),
          ),
          _CertificateField(
            icon: LucideIcons.mapPin,
            label: 'Service area',
            value: worker.serviceArea.isEmpty
                ? 'Not listed yet'
                : worker.serviceArea,
          ),
          _CertificateField(
            icon: LucideIcons.qrCode,
            label: 'Verification link',
            value: 'workable.app/certificate/${worker.workerId}',
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await Clipboard.setData(
                      ClipboardData(text: certificateText),
                    );
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Certificate copied')),
                      );
                    }
                  },
                  icon: const Icon(LucideIcons.copy, size: 18),
                  label: const Text('Copy'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () async {
                    await Clipboard.setData(
                      ClipboardData(text: certificateText),
                    );
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Certificate text ready to share'),
                        ),
                      );
                    }
                  },
                  icon: const Icon(LucideIcons.share2, size: 18),
                  label: const Text('Share'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String get _certificateText {
    final name = worker.name.isEmpty ? 'Verified Workable Worker' : worker.name;
    final skills = worker.skills.isEmpty
        ? 'listed Workable services'
        : worker.skills.join(', ');
    return 'Workable Professional Experience Certificate\n'
        'Name: $name\n'
        'Worker ID: ${worker.workerId}\n'
        'Skills: $skills\n'
        'Badge: ${achievement.badgeLevel.label}\n'
        'Completed jobs: ${achievement.completedJobs}\n'
        'Verified hours: ${achievement.verifiedHours.toStringAsFixed(1)}\n'
        'Average rating: ${achievement.averageRating.toStringAsFixed(1)}\n'
        'Certificate number: ${achievement.certificateNumber}\n'
        'Verify: workable.app/certificate/${worker.workerId}';
  }
}

class _CertificateMetricGrid extends StatelessWidget {
  const _CertificateMetricGrid({required this.achievement});

  final WorkerAchievement achievement;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 2.2,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      children: [
        _MetricTile(
          label: 'Completed jobs',
          value: achievement.completedJobs.toString(),
          icon: LucideIcons.briefcase,
        ),
        _MetricTile(
          label: 'Verified hours',
          value: achievement.verifiedHours.toStringAsFixed(0),
          icon: LucideIcons.clock,
        ),
        _MetricTile(
          label: 'Average rating',
          value: achievement.averageRating > 0
              ? achievement.averageRating.toStringAsFixed(1)
              : 'New',
          icon: LucideIcons.star,
        ),
        _MetricTile(
          label: 'Repeat customers',
          value: achievement.repeatCustomers.toString(),
          icon: LucideIcons.repeat,
        ),
      ],
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: WorkableDesign.cardDecoration(
        color: WorkableDesign.canvas,
        borderColor: WorkableDesign.border,
      ),
      child: Row(
        children: [
          Icon(icon, color: WorkableDesign.primary, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    color: WorkableDesign.ink,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: WorkableDesign.muted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CertificateField extends StatelessWidget {
  const _CertificateField({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: WorkableDesign.muted),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: WorkableDesign.muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    color: WorkableDesign.ink,
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
