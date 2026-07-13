import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:workable/core/theme/workable_design.dart';
import 'package:workable/features/admin_demand/presentation/admin_demand_review_screen.dart';
import 'package:workable/features/admin_referrals/presentation/admin_referral_reward_screen.dart';
import 'package:workable/features/community_campaigns/presentation/admin_campaign_calendar_screen.dart';
import 'package:workable/screens/admin/admin_payout_review_screen.dart';
import 'package:workable/screens/admin/admin_payment_review_screen.dart';
import 'package:workable/screens/admin/admin_verification_dashboard.dart';
import 'package:workable/screens/admin/admin_work_start_override_screen.dart';
import 'package:workable/widgets/workable_ui.dart';

import '../domain/admin_control_summary.dart';
import 'admin_control_providers.dart';

class AdminControlCenterScreen extends ConsumerWidget {
  static const routeName = '/admin-control-center';

  const AdminControlCenterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(adminControlSummaryProvider);
    return Scaffold(
      backgroundColor: WorkableDesign.canvas,
      appBar: AppBar(
        title: const Text('Admin Control Center'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: () => ref.invalidate(adminControlSummaryProvider),
            icon: const Icon(LucideIcons.refreshCw),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(adminControlSummaryProvider),
        child: summary.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => ListView(
            padding: const EdgeInsets.all(WorkableDesign.pagePadding),
            children: [
              WorkableEmptyState(
                icon: LucideIcons.alertTriangle,
                title: 'Unable to load control center',
                message: error.toString(),
              ),
            ],
          ),
          data: (data) => _AdminControlContent(summary: data),
        ),
      ),
    );
  }
}

class _AdminControlContent extends StatelessWidget {
  const _AdminControlContent({required this.summary});

  final AdminControlSummary summary;

  @override
  Widget build(BuildContext context) {
    final items = [
      _ControlItem(
        title: 'Payment Review',
        subtitle: 'UPI/cash reports waiting for approval',
        count: summary.paymentReviews,
        icon: LucideIcons.receipt,
        color: WorkableDesign.warning,
        routeName: AdminPaymentReviewScreen.routeName,
      ),
      _ControlItem(
        title: 'Payout Review',
        subtitle: 'Worker payout requests and paid marking',
        count: summary.payoutReviews,
        icon: LucideIcons.wallet,
        color: WorkableDesign.primary,
        routeName: AdminPayoutReviewScreen.routeName,
      ),
      _ControlItem(
        title: 'Verification Queue',
        subtitle: 'Identity and document submissions',
        count: summary.verificationReviews,
        icon: LucideIcons.shieldCheck,
        color: WorkableDesign.accent,
        routeName: AdminVerificationDashboard.routeName,
      ),
      _ControlItem(
        title: 'Work Start Override',
        subtitle: 'Arrival fallback and manual-start audit',
        count: summary.workStartOverrides,
        icon: LucideIcons.playCircle,
        color: WorkableDesign.success,
        routeName: AdminWorkStartOverrideScreen.routeName,
      ),
      _ControlItem(
        title: 'Disputed Bookings',
        subtitle: 'Completion/payment disputes needing review',
        count: summary.disputedBookings,
        icon: LucideIcons.alertTriangle,
        color: WorkableDesign.danger,
        routeName: AdminPaymentReviewScreen.routeName,
      ),
      _ControlItem(
        title: 'Help Issues',
        subtitle: 'Help requests in dispute or review states',
        count: summary.helpIssues,
        icon: Icons.volunteer_activism_outlined,
        color: WorkableDesign.warning,
        routeName: AdminPaymentReviewScreen.routeName,
      ),
      _ControlItem(
        title: 'Demand Review',
        subtitle: 'New categories and customer demand signals',
        count: summary.openDemandSignals,
        icon: LucideIcons.radar,
        color: WorkableDesign.primary,
        routeName: AdminDemandReviewScreen.routeName,
      ),
      _ControlItem(
        title: 'Referral Rewards',
        subtitle: 'Approve, reject, or credit incentives',
        count: summary.referralRewards,
        icon: LucideIcons.badgePercent,
        color: WorkableDesign.accent,
        routeName: AdminReferralRewardScreen.routeName,
      ),
      _ControlItem(
        title: 'Campaign Calendar',
        subtitle: 'Seasonal/community campaigns',
        count: summary.activeCampaigns,
        icon: LucideIcons.calendarDays,
        color: WorkableDesign.success,
        routeName: AdminCampaignCalendarScreen.routeName,
      ),
    ];

    return ListView(
      padding: const EdgeInsets.all(WorkableDesign.pagePadding),
      children: [
        WorkablePageHeader(
          title: '${summary.totalActionItems} action items',
          subtitle:
              'One command center for marketplace trust, payments, verification, demand, referrals, and campaigns.',
          icon: LucideIcons.layoutDashboard,
        ),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 430,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 2.2,
          ),
          itemBuilder: (context, index) => _ControlCard(item: items[index]),
        ),
      ],
    );
  }
}

class _ControlItem {
  const _ControlItem({
    required this.title,
    required this.subtitle,
    required this.count,
    required this.icon,
    required this.color,
    required this.routeName,
  });

  final String title;
  final String subtitle;
  final int count;
  final IconData icon;
  final Color color;
  final String routeName;
}

class _ControlCard extends StatelessWidget {
  const _ControlCard({required this.item});

  final _ControlItem item;

  @override
  Widget build(BuildContext context) {
    return WorkableSectionCard(
      child: InkWell(
        borderRadius: BorderRadius.circular(WorkableDesign.radius),
        onTap: () => Navigator.pushNamed(context, item.routeName),
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: item.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(WorkableDesign.radius),
                ),
                child: Icon(item.icon, color: item.color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: WorkableDesign.ink,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        WorkableStatusPill(
                          label: item.count.toString(),
                          color: item.count > 0
                              ? item.color
                              : WorkableDesign.muted,
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      item.subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: WorkableDesign.muted,
                        height: 1.25,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
