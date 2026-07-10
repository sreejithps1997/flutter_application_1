import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../core/theme/workable_design.dart';
import '../widgets/workable_ui.dart';

class SubscriptionScreen extends StatelessWidget {
  static const routeName = '/subscription';

  const SubscriptionScreen({super.key});

  static const _plans = [
    _Plan(
      title: 'Starter',
      price: 'Free',
      status: 'Active',
      features: [
        'Standard marketplace access',
        'Booking and profile tools',
        'Basic support',
      ],
    ),
    _Plan(
      title: 'Growth',
      price: 'Planned',
      status: 'Coming later',
      features: [
        'Profile boost after trust checks',
        'Advanced opportunity insights',
        'Priority support queue',
      ],
    ),
    _Plan(
      title: 'Premium Verified',
      price: 'Planned',
      status: 'Coming later',
      features: [
        'Premium trust badge',
        'Advanced portfolio placement',
        'Business growth analytics',
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WorkableDesign.canvas,
      appBar: AppBar(title: const Text('Membership Plans')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(WorkableDesign.pagePadding),
          children: [
            const WorkablePageHeader(
              title: 'Membership is planned',
              subtitle:
                  'Paid plans will be enabled only after pricing, payment, tax, refund, and trust rules are production-ready.',
              icon: LucideIcons.badgeCheck,
            ),
            const SizedBox(height: 16),
            ..._plans.map(_PlanCard.new),
            const SizedBox(height: 8),
            const WorkableSectionCard(
              child: WorkableInfoRow(
                icon: LucideIcons.info,
                text:
                    'For now, workers can keep improving visibility through profile completeness, verification, ratings, portfolio, and response quality.',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard(this.plan);

  final _Plan plan;

  @override
  Widget build(BuildContext context) {
    final active = plan.status == 'Active';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: WorkableSectionCard(
        borderColor: active
            ? WorkableDesign.success.withValues(alpha: 0.28)
            : WorkableDesign.border,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    plan.title,
                    style: const TextStyle(
                      color: WorkableDesign.ink,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                WorkableStatusPill(
                  label: plan.status,
                  color: active ? WorkableDesign.success : WorkableDesign.muted,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              plan.price,
              style: const TextStyle(
                color: WorkableDesign.primary,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 12),
            ...plan.features.map(
              (feature) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: WorkableInfoRow(icon: LucideIcons.check, text: feature),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Plan {
  const _Plan({
    required this.title,
    required this.price,
    required this.status,
    required this.features,
  });

  final String title;
  final String price;
  final String status;
  final List<String> features;
}
