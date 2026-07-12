import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:workable/core/theme/workable_design.dart';
import 'package:workable/widgets/workable_ui.dart';

import '../domain/admin_referral_reward.dart';
import 'admin_referral_providers.dart';

class AdminReferralRewardScreen extends ConsumerStatefulWidget {
  static const routeName = '/admin-referral-rewards';

  const AdminReferralRewardScreen({super.key});

  @override
  ConsumerState<AdminReferralRewardScreen> createState() =>
      _AdminReferralRewardScreenState();
}

class _AdminReferralRewardScreenState
    extends ConsumerState<AdminReferralRewardScreen> {
  final _currency = NumberFormat.currency(locale: 'en_IN', symbol: 'Rs ');
  final _dateFormat = DateFormat('dd MMM yyyy, hh:mm a');
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final asyncRewards = ref.watch(filteredAdminReferralRewardsProvider);
    final allRewards =
        ref.watch(adminReferralRewardsProvider).value ?? const [];
    final filter = ref.watch(adminReferralFilterProvider);

    return Scaffold(
      backgroundColor: WorkableDesign.canvas,
      appBar: AppBar(title: const Text('Referral Rewards')),
      body: asyncRewards.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => WorkableEmptyState(
          icon: LucideIcons.alertTriangle,
          title: 'Unable to load referrals',
          message: error.toString(),
        ),
        data: (rewards) {
          return ListView(
            padding: const EdgeInsets.all(WorkableDesign.pagePadding),
            children: [
              WorkablePageHeader(
                title: 'Referral reward control',
                subtitle:
                    'Review referral conversions, approve valid incentives, and mark credited rewards after business checks.',
                icon: LucideIcons.badgePercent,
              ),
              const SizedBox(height: 14),
              _buildStats(allRewards),
              const SizedBox(height: 14),
              _buildFilters(filter),
              const SizedBox(height: 14),
              if (rewards.isEmpty)
                const WorkableEmptyState(
                  icon: LucideIcons.inbox,
                  title: 'No referral records here',
                  message:
                      'Referral activity will appear when users join through invite codes and rewards become eligible.',
                )
              else
                ...rewards.map(_buildRewardCard),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStats(List<AdminReferralReward> rewards) {
    final ready = rewards.where((item) => item.isRewardReady).length;
    final worker = rewards.where((item) => item.isWorkerOnboarding).length;
    final creditedAmount = rewards
        .where((item) => item.isCredited)
        .fold<num>(0, (total, item) => total + item.rewardAmount);

    return Row(
      children: [
        Expanded(child: _stat('Ready', ready.toString(), LucideIcons.clock)),
        const SizedBox(width: 10),
        Expanded(child: _stat('Workers', worker.toString(), LucideIcons.users)),
        const SizedBox(width: 10),
        Expanded(
          child: _stat(
            'Credited',
            _currency.format(creditedAmount),
            LucideIcons.wallet,
          ),
        ),
      ],
    );
  }

  Widget _stat(String label, String value, IconData icon) {
    return WorkableSectionCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: WorkableDesign.primary, size: 18),
          const SizedBox(height: 10),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: WorkableDesign.ink,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              color: WorkableDesign.muted,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters(String filter) {
    final filters = const [
      ('action', 'Action'),
      ('ready', 'Ready'),
      ('worker', 'Workers'),
      ('credited', 'Credited'),
      ('rejected', 'Rejected'),
      ('all', 'All'),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.map((item) {
          final selected = filter == item.$1;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              selected: selected,
              label: Text(item.$2),
              onSelected: (_) {
                ref.read(adminReferralFilterProvider.notifier).state = item.$1;
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildRewardCard(AdminReferralReward referral) {
    final color = _statusColor(referral);
    final canApprove = !referral.isCredited && !referral.isRejected;
    final canCredit =
        referral.rewardStatus == 'ready_for_credit' ||
        referral.rewardStatus == 'approved';
    final amount = referral.rewardAmount > 0 ? referral.rewardAmount : 50;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: WorkableSectionCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: color.withValues(alpha: 0.12),
                  child: Icon(_roleIcon(referral), color: color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        referral.referredUserName,
                        style: const TextStyle(
                          color: WorkableDesign.ink,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Referred by ${referral.referrerName}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: WorkableDesign.muted),
                      ),
                    ],
                  ),
                ),
                WorkableStatusPill(
                  label: _statusLabel(referral),
                  color: color,
                  icon: _statusIcon(referral),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                WorkableStatusPill(
                  label: referral.referredUserRole.toUpperCase(),
                  color: WorkableDesign.primary,
                  icon: _roleIcon(referral),
                ),
                WorkableStatusPill(
                  label: referral.referralCode.isEmpty
                      ? 'NO CODE'
                      : referral.referralCode,
                  color: WorkableDesign.accent,
                  icon: LucideIcons.ticket,
                ),
                WorkableStatusPill(
                  label: _currency.format(amount),
                  color: WorkableDesign.success,
                  icon: LucideIcons.badgePercent,
                ),
              ],
            ),
            const SizedBox(height: 12),
            WorkableInfoRow(
              icon: LucideIcons.user,
              text: 'Referrer ID: ${referral.referrerId}',
            ),
            const SizedBox(height: 8),
            WorkableInfoRow(
              icon: LucideIcons.userPlus,
              text: 'Joined user ID: ${referral.referredUserId}',
            ),
            if ((referral.referredUserPhone ?? '').isNotEmpty) ...[
              const SizedBox(height: 8),
              WorkableInfoRow(
                icon: LucideIcons.phone,
                text: 'Phone: ${referral.referredUserPhone}',
              ),
            ],
            if ((referral.firstPaidBookingId ?? '').isNotEmpty) ...[
              const SizedBox(height: 8),
              WorkableInfoRow(
                icon: LucideIcons.receipt,
                text: 'First paid booking: ${referral.firstPaidBookingId}',
              ),
            ],
            const SizedBox(height: 8),
            WorkableInfoRow(
              icon: LucideIcons.calendarClock,
              text:
                  'Updated: ${_date(referral.updatedAt ?? referral.createdAt)}',
            ),
            if ((referral.adminNote ?? '').isNotEmpty) ...[
              const SizedBox(height: 8),
              WorkableInfoRow(
                icon: LucideIcons.messageSquare,
                text: 'Admin note: ${referral.adminNote}',
              ),
            ],
            if (canApprove || canCredit) ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  if (canApprove) ...[
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _busy
                            ? null
                            : () => _review(referral, 'rejected', amount),
                        icon: const Icon(LucideIcons.xCircle, size: 18),
                        label: const Text('Reject'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _busy
                            ? null
                            : () => _review(referral, 'approved', amount),
                        icon: const Icon(LucideIcons.checkCircle2, size: 18),
                        label: const Text('Approve'),
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  if (canCredit)
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _busy
                            ? null
                            : () => _review(referral, 'credited', amount),
                        icon: const Icon(LucideIcons.walletCards, size: 18),
                        label: const Text('Mark Credited'),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _review(
    AdminReferralReward referral,
    String decision,
    num defaultAmount,
  ) async {
    final result = await _showReviewDialog(referral, decision, defaultAmount);
    if (result == null) return;

    setState(() => _busy = true);
    try {
      await ref
          .read(adminReferralRepositoryProvider)
          .reviewReward(
            referral: referral,
            decision: decision,
            rewardAmount: result.amount,
            note: result.note,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Referral reward $decision.')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to update referral reward: $error'),
          backgroundColor: WorkableDesign.danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<_ReviewInput?> _showReviewDialog(
    AdminReferralReward referral,
    String decision,
    num defaultAmount,
  ) async {
    final amountController = TextEditingController(
      text: defaultAmount.toString(),
    );
    final noteController = TextEditingController();
    final result = await showDialog<_ReviewInput>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${_dialogTitle(decision)}?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${referral.referredUserName} joined through ${referral.referrerName}.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Reward amount',
                border: OutlineInputBorder(),
              ),
              enabled: decision != 'rejected',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: noteController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: decision == 'rejected'
                    ? 'Reason shown in audit'
                    : 'Admin note',
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final amount = num.tryParse(amountController.text.trim()) ?? 0;
              Navigator.pop(
                context,
                _ReviewInput(amount: amount, note: noteController.text.trim()),
              );
            },
            child: Text(_dialogTitle(decision)),
          ),
        ],
      ),
    );
    amountController.dispose();
    noteController.dispose();
    return result;
  }

  String _dialogTitle(String decision) {
    switch (decision) {
      case 'credited':
        return 'Mark credited';
      case 'approved':
        return 'Approve reward';
      case 'rejected':
        return 'Reject reward';
      default:
        return 'Review reward';
    }
  }

  String _date(DateTime? date) {
    if (date == null) return 'Not recorded';
    return _dateFormat.format(date);
  }

  String _statusLabel(AdminReferralReward referral) {
    if (referral.isWorkerOnboarding) return 'Worker policy';
    switch (referral.rewardStatus) {
      case 'ready_for_credit':
        return 'Ready';
      case 'approved':
        return 'Approved';
      case 'credited':
        return 'Credited';
      case 'rejected':
        return 'Rejected';
      case 'locked':
        return 'Locked';
      default:
        return referral.rewardStatus;
    }
  }

  IconData _statusIcon(AdminReferralReward referral) {
    if (referral.isCredited) return LucideIcons.walletCards;
    if (referral.isRejected) return LucideIcons.xCircle;
    if (referral.isRewardReady) return LucideIcons.badgeCheck;
    if (referral.isWorkerOnboarding) return LucideIcons.userCog;
    return LucideIcons.lock;
  }

  Color _statusColor(AdminReferralReward referral) {
    if (referral.isCredited) return WorkableDesign.success;
    if (referral.isRejected) return WorkableDesign.danger;
    if (referral.isRewardReady) return WorkableDesign.primary;
    if (referral.isWorkerOnboarding) return WorkableDesign.warning;
    return WorkableDesign.muted;
  }

  IconData _roleIcon(AdminReferralReward referral) {
    return referral.referredUserRole == 'worker'
        ? LucideIcons.hardHat
        : LucideIcons.user;
  }
}

class _ReviewInput {
  const _ReviewInput({required this.amount, required this.note});

  final num amount;
  final String note;
}
