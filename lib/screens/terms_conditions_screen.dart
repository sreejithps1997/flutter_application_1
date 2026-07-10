import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../core/theme/workable_design.dart';
import '../widgets/workable_ui.dart';

class TermsConditionsScreen extends StatelessWidget {
  static const routeName = '/terms-conditions';

  const TermsConditionsScreen({super.key});

  static const _sections = [
    _TermsSection('Using Workable', [
      'Customers may request local services, repairs, delivery, pickup, urgent help, and related assistance through the app.',
      'Workers must provide accurate profile, service, pricing, availability, payout, and verification information.',
      'Users must not create fake bookings, fake payment reports, abusive messages, or misleading profiles.',
    ]),
    _TermsSection('Bookings and completion', [
      'A booking moves through requested, accepted, in progress, completion requested, payment, and completed states.',
      'Workers should request completion only after the agreed work is finished.',
      'Customers should confirm completion only after checking the service result.',
    ]),
    _TermsSection('Payments and payouts', [
      'UPI or cash payment status may be reviewed before a booking is treated as paid.',
      'Cash should be confirmed by the worker only after receiving the amount.',
      'Worker payouts depend on eligible completed/paid bookings and valid payout details.',
    ]),
    _TermsSection('Safety, disputes, and account action', [
      'Safety reports, fraud signals, repeated cancellations, and payment disputes may be reviewed by Workable/admin users.',
      'Accounts may be limited, hidden, suspended, or removed for abuse, unsafe behavior, fraud, or policy violation.',
      'Workable is a marketplace platform. Workers are responsible for service quality and customers are responsible for truthful requests and payment behavior.',
    ]),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WorkableDesign.canvas,
      appBar: AppBar(title: const Text('Terms & Conditions')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(WorkableDesign.pagePadding),
          children: [
            const WorkablePageHeader(
              title: 'Workable Terms',
              subtitle:
                  'Effective July 10, 2025. Marketplace rules for customers, workers, payments, and safety.',
              icon: LucideIcons.scrollText,
            ),
            const SizedBox(height: 16),
            ..._sections.map(_TermsCard.new),
            const SizedBox(height: 8),
            const WorkableSectionCard(
              color: WorkableDesign.surface,
              child: WorkableInfoRow(
                icon: LucideIcons.info,
                text:
                    'For policy questions or support, contact support@workableapp.com.',
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('I Understand'),
            ),
          ],
        ),
      ),
    );
  }
}

class _TermsCard extends StatelessWidget {
  const _TermsCard(this.section);

  final _TermsSection section;

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

class _TermsSection {
  const _TermsSection(this.title, this.points);

  final String title;
  final List<String> points;
}
