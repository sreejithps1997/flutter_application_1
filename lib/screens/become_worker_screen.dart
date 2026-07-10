import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../core/theme/workable_design.dart';
import '../widgets/workable_ui.dart';
import 'worker_signup_screen.dart';

class BecomeWorkerScreen extends StatelessWidget {
  static const routeName = '/become-worker';

  const BecomeWorkerScreen({super.key});

  static const _benefits = [
    ('Flexible work', 'Accept jobs that match your skills and schedule.'),
    (
      'Trust profile',
      'Verification, ratings and portfolio help customers choose you.',
    ),
    (
      'Clear earnings',
      'Completed jobs connect to earnings and payout requests.',
    ),
    (
      'Growth opportunities',
      'Future demand signals can suggest new services to add.',
    ),
  ];

  static const _requirements = [
    'Profile photo and contact details',
    'Service area and travel radius',
    'Skills, pricing and availability',
    'Identity/selfie verification for customer trust',
    'UPI or bank payout details',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WorkableDesign.canvas,
      appBar: AppBar(title: const Text('Become a Worker')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(WorkableDesign.pagePadding),
          children: [
            const WorkablePageHeader(
              title: 'Earn with Workable',
              subtitle:
                  'Create a trusted worker profile, receive jobs, complete work, and request payouts from eligible earnings.',
              icon: LucideIcons.briefcase,
            ),
            const SizedBox(height: 16),
            _buildBenefits(),
            const SizedBox(height: 16),
            _buildRequirements(),
            const SizedBox(height: 16),
            _buildProcess(),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: () =>
                  Navigator.pushNamed(context, WorkerSignupScreen.routeName),
              icon: const Icon(LucideIcons.arrowRight),
              label: const Text('Start Worker Signup'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBenefits() {
    return WorkableSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle('Why join'),
          const SizedBox(height: 12),
          ..._benefits.map(
            (benefit) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: WorkableInfoRow(
                icon: LucideIcons.checkCircle,
                text: '${benefit.$1}: ${benefit.$2}',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequirements() {
    return WorkableSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle('What you need'),
          const SizedBox(height: 12),
          ..._requirements.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: WorkableInfoRow(icon: LucideIcons.fileCheck, text: item),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProcess() {
    return const WorkableSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle('Approval flow'),
          SizedBox(height: 12),
          WorkableInfoRow(
            icon: LucideIcons.user,
            text: '1. Add profile and service area',
          ),
          SizedBox(height: 10),
          WorkableInfoRow(
            icon: LucideIcons.wrench,
            text: '2. Add services, pricing and availability',
          ),
          SizedBox(height: 10),
          WorkableInfoRow(
            icon: LucideIcons.shieldCheck,
            text:
                '3. Submit verification. Your profile stays hidden until readiness and review rules allow visibility.',
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: WorkableDesign.ink,
        fontSize: 16,
        fontWeight: FontWeight.w900,
      ),
    );
  }
}
