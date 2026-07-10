import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../core/theme/workable_design.dart';
import '../widgets/workable_ui.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  static const routeName = '/privacy-policy';

  const PrivacyPolicyScreen({super.key});

  static const _sections = [
    _PolicySection('Information we collect', [
      'Account details such as name, phone number, email, role, and profile information.',
      'Booking details such as service type, address, schedule, issue description, payment state, and support history.',
      'Worker trust details such as verification status, skills, pricing, service area, payout readiness, portfolio, ratings, and job history.',
      'Device and preference information needed for notifications, accessibility, language, and app settings.',
    ]),
    _PolicySection('How we use information', [
      'To connect customers with suitable workers and manage booking lifecycle updates.',
      'To process payment status, payout requests, disputes, verification review, and support requests.',
      'To improve safety, prevent fraud, and protect customers, workers, and the marketplace.',
      'To personalize app settings, notifications, saved addresses, favorites, and future AI-assisted help flows.',
    ]),
    _PolicySection('Sharing and visibility', [
      'Customer details are shared with assigned workers only where needed to complete a booking.',
      'Worker marketplace profiles become visible only when readiness and verification rules allow it.',
      'We do not sell personal data. Limited data may be shared with service providers or authorities where legally required.',
    ]),
    _PolicySection('Security and choices', [
      'Use strong passwords and keep your phone secure.',
      'You can change app settings, notification preferences, language, addresses, and profile details from your account.',
      'Data export and account deletion workflows are planned before full public launch.',
    ]),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WorkableDesign.canvas,
      appBar: AppBar(title: const Text('Privacy Policy')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(WorkableDesign.pagePadding),
          children: [
            const WorkablePageHeader(
              title: 'Workable Privacy Policy',
              subtitle:
                  'Effective July 10, 2025. Built for a trusted customer-worker marketplace.',
              icon: LucideIcons.shield,
            ),
            const SizedBox(height: 16),
            ..._sections.map(_PolicyCard.new),
            const SizedBox(height: 8),
            const WorkableSectionCard(
              child: WorkableInfoRow(
                icon: LucideIcons.mail,
                text: 'Questions or privacy requests: support@workableapp.com',
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PolicyCard extends StatelessWidget {
  const _PolicyCard(this.section);

  final _PolicySection section;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: WorkableSectionCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              section.title,
              style: const TextStyle(
                color: WorkableDesign.ink,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 10),
            ...section.points.map(
              (point) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: WorkableInfoRow(icon: LucideIcons.check, text: point),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PolicySection {
  const _PolicySection(this.title, this.points);

  final String title;
  final List<String> points;
}
