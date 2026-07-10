import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/theme/workable_design.dart';
import '../services/payout_request_service.dart';

class WorkerEarningsScreen extends StatelessWidget {
  const WorkerEarningsScreen({super.key});

  static const routeName = '/worker/earnings';

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: WorkableDesign.canvas,
      appBar: AppBar(title: const Text('Earnings & Payouts')),
      body: uid == null
          ? const Center(child: Text('Please log in again.'))
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('bookings')
                  .where('workerId', isEqualTo: uid)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Text('Unable to load earnings: ${snapshot.error}'),
                  );
                }

                final jobs =
                    snapshot.data?.docs
                        .map((doc) => _EarningJob(id: doc.id, data: doc.data()))
                        .toList() ??
                    [];
                final summary = _EarningsSummary.fromJobs(jobs);

                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _HeroSummary(summary: summary),
                    const SizedBox(height: 14),
                    _HelpEarningsCard(summary: summary),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: _MetricCard(
                            title: 'Pending',
                            value: summary.format(summary.pendingAmount),
                            subtitle: '${summary.pendingJobs} jobs in review',
                            icon: Icons.hourglass_top_outlined,
                            color: WorkableDesign.warning,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _MetricCard(
                            title: 'Paid Out',
                            value: summary.format(summary.paidOutAmount),
                            subtitle: '${summary.paidOutJobs} jobs paid',
                            icon: Icons.verified_outlined,
                            color: WorkableDesign.success,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _PayoutRequestCard(workerId: uid),
                    const SizedBox(height: 14),
                    const _ActionLinks(),
                    const SizedBox(height: 18),
                    _PayoutHistory(workerId: uid),
                    const SizedBox(height: 18),
                    const Text(
                      'Recent Earnings',
                      style: TextStyle(
                        color: WorkableDesign.ink,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (summary.earnedJobs.isEmpty)
                      const _EmptyEarnings()
                    else
                      ...summary.earnedJobs
                          .take(20)
                          .map((job) => _EarningCard(job: job)),
                    const SizedBox(height: 28),
                  ],
                );
              },
            ),
    );
  }
}

class _PayoutRequestCard extends StatefulWidget {
  const _PayoutRequestCard({required this.workerId});

  final String workerId;

  @override
  State<_PayoutRequestCard> createState() => _PayoutRequestCardState();
}

class _PayoutRequestCardState extends State<_PayoutRequestCard> {
  final _service = PayoutRequestService();
  late Future<PayoutSummary> _summaryFuture;
  bool _requesting = false;

  @override
  void initState() {
    super.initState();
    _summaryFuture = _service.loadSummary(widget.workerId);
  }

  void _refresh() {
    setState(() => _summaryFuture = _service.loadSummary(widget.workerId));
  }

  Future<void> _requestPayout(PayoutSummary summary) async {
    setState(() => _requesting = true);
    try {
      await _service.createRequest(workerId: widget.workerId, summary: summary);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payout request submitted for approval')),
      );
      _refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _requesting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(locale: 'en_IN', symbol: 'Rs ');

    return FutureBuilder<PayoutSummary>(
      future: _summaryFuture,
      builder: (context, snapshot) {
        final loading = snapshot.connectionState == ConnectionState.waiting;
        final summary = snapshot.data;
        final available = summary?.availableAmount ?? 0;
        final hasMethod = summary?.hasPayoutMethod ?? false;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: WorkableDesign.cardDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: WorkableDesign.accent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.account_balance_wallet_outlined,
                      color: WorkableDesign.accent,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Available for payout',
                          style: TextStyle(
                            color: WorkableDesign.ink,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          loading
                              ? 'Checking completed paid jobs...'
                              : '${summary?.availableBookingIds.length ?? 0} jobs ready',
                          style: const TextStyle(
                            color: WorkableDesign.muted,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    currency.format(available),
                    style: const TextStyle(
                      color: WorkableDesign.ink,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              if (!loading && !hasMethod) ...[
                const SizedBox(height: 12),
                _WarningNote(
                  text:
                      'Add a valid UPI or bank payout method before requesting payout.',
                  actionLabel: 'Payout Methods',
                  onTap: () =>
                      Navigator.pushNamed(context, '/worker/payout-methods'),
                ),
              ],
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed:
                      loading ||
                          _requesting ||
                          summary == null ||
                          available <= 0 ||
                          !hasMethod
                      ? null
                      : () => _requestPayout(summary),
                  icon: _requesting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.payments_outlined),
                  label: Text(_requesting ? 'Requesting...' : 'Request Payout'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PayoutHistory extends StatelessWidget {
  const _PayoutHistory({required this.workerId});

  final String workerId;

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(locale: 'en_IN', symbol: 'Rs ');

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('payoutRequests')
          .where('workerId', isEqualTo: workerId)
          .snapshots(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];
        docs.sort((a, b) => _date(b.data()).compareTo(_date(a.data())));

        if (docs.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Payout Requests',
              style: TextStyle(
                color: WorkableDesign.ink,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 10),
            ...docs.take(5).map((doc) {
              final data = doc.data();
              final amount = data['amount'] is num ? data['amount'] as num : 0;
              final status = data['status']?.toString() ?? 'pending';
              final bookingIds = data['bookingIds'];
              final count = bookingIds is List ? bookingIds.length : 0;

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: WorkableDesign.cardDecoration(),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            currency.format(amount),
                            style: const TextStyle(
                              color: WorkableDesign.ink,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Text(
                            '$count jobs | ${data['payoutMethod'] ?? 'payout'}',
                            style: const TextStyle(
                              color: WorkableDesign.muted,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _StatusPill(status: status),
                  ],
                ),
              );
            }),
          ],
        );
      },
    );
  }

  DateTime _date(Map<String, dynamic> data) {
    final timestamp = data['requestedAt'] ?? data['updatedAt'];
    if (timestamp is Timestamp) return timestamp.toDate();
    return DateTime.fromMillisecondsSinceEpoch(0);
  }
}

class _HeroSummary extends StatelessWidget {
  const _HeroSummary({required this.summary});

  final _EarningsSummary summary;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: WorkableDesign.ink,
        borderRadius: BorderRadius.circular(WorkableDesign.radius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Total earned',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.72)),
          ),
          const SizedBox(height: 6),
          Text(
            summary.format(summary.totalEarned),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 34,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _DarkMetric(
                  label: 'Earned jobs',
                  value: '${summary.earnedJobs.length}',
                ),
              ),
              Expanded(
                child: _DarkMetric(
                  label: 'Help earned',
                  value: summary.format(summary.helpEarnedAmount),
                ),
              ),
              Expanded(
                child: _DarkMetric(
                  label: 'Available',
                  value: summary.format(summary.availableAmount),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HelpEarningsCard extends StatelessWidget {
  const _HelpEarningsCard({required this.summary});

  final _EarningsSummary summary;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: WorkableDesign.cardDecoration(),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: WorkableDesign.accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.volunteer_activism_outlined,
              color: WorkableDesign.accent,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Help request earnings',
                  style: TextStyle(
                    color: WorkableDesign.ink,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${summary.helpEarnedJobs} completed help jobs | ${summary.helpPendingJobs} pending payment',
                  style: const TextStyle(
                    color: WorkableDesign.muted,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Text(
            summary.format(summary.helpEarnedAmount),
            style: const TextStyle(
              color: WorkableDesign.accent,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _DarkMetric extends StatelessWidget {
  const _DarkMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(color: Colors.white.withValues(alpha: 0.66)),
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: WorkableDesign.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(
              color: WorkableDesign.muted,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              color: WorkableDesign.ink,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            subtitle,
            style: const TextStyle(
              color: WorkableDesign.muted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionLinks extends StatelessWidget {
  const _ActionLinks();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () =>
                Navigator.pushNamed(context, '/worker/payout-methods'),
            icon: const Icon(Icons.account_balance_outlined),
            label: const Text('Payout Methods'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () =>
                Navigator.pushNamed(context, '/worker/transaction-history'),
            icon: const Icon(Icons.receipt_long),
            label: const Text('Transactions'),
          ),
        ),
      ],
    );
  }
}

class _EarningCard extends StatelessWidget {
  const _EarningCard({required this.job});

  final _EarningJob job;

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(locale: 'en_IN', symbol: 'Rs ');
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: WorkableDesign.cardDecoration(),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: WorkableDesign.success.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.payments_outlined,
              color: WorkableDesign.success,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  job.displayService,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: WorkableDesign.ink,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  '${job.customerName} | ${job.date}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: WorkableDesign.muted,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Text(
            currency.format(job.amount),
            style: const TextStyle(
              color: WorkableDesign.success,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'approved' || 'paid' => WorkableDesign.success,
      'rejected' => WorkableDesign.danger,
      'processing' => WorkableDesign.primary,
      _ => WorkableDesign.warning,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        status.replaceAll('_', ' '),
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _WarningNote extends StatelessWidget {
  const _WarningNote({
    required this.text,
    required this.actionLabel,
    required this.onTap,
  });

  final String text;
  final String actionLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: WorkableDesign.warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(WorkableDesign.radius),
        border: Border.all(
          color: WorkableDesign.warning.withValues(alpha: 0.18),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: WorkableDesign.warning),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: WorkableDesign.ink,
                fontSize: 12.5,
                height: 1.35,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          TextButton(onPressed: onTap, child: Text(actionLabel)),
        ],
      ),
    );
  }
}

class _EarningsSummary {
  final List<_EarningJob> earnedJobs;
  final num totalEarned;
  final num availableAmount;
  final num pendingAmount;
  final num paidOutAmount;
  final num helpEarnedAmount;
  final int pendingJobs;
  final int paidOutJobs;
  final int helpEarnedJobs;
  final int helpPendingJobs;

  _EarningsSummary({
    required this.earnedJobs,
    required this.totalEarned,
    required this.availableAmount,
    required this.pendingAmount,
    required this.paidOutAmount,
    required this.helpEarnedAmount,
    required this.pendingJobs,
    required this.paidOutJobs,
    required this.helpEarnedJobs,
    required this.helpPendingJobs,
  });

  factory _EarningsSummary.fromJobs(List<_EarningJob> jobs) {
    final earned = jobs.where((job) => job.isEarned).toList()
      ..sort((a, b) => b.sortDate.compareTo(a.sortDate));
    final available = earned.where((job) => job.isAvailableForPayout).toList();
    final pending = jobs.where((job) => job.isPendingMoney).toList();
    final paidOut = earned.where((job) => job.payoutStatus == 'paid').toList();
    final helpEarned = earned.where((job) => job.isHelpRequest).toList();
    final helpPending = pending.where((job) => job.isHelpRequest).toList();

    return _EarningsSummary(
      earnedJobs: earned,
      totalEarned: earned.fold<num>(0, (total, job) => total + job.amount),
      availableAmount: available.fold<num>(
        0,
        (total, job) => total + job.amount,
      ),
      pendingAmount: pending.fold<num>(0, (total, job) => total + job.amount),
      paidOutAmount: paidOut.fold<num>(0, (total, job) => total + job.amount),
      helpEarnedAmount: helpEarned.fold<num>(
        0,
        (total, job) => total + job.amount,
      ),
      pendingJobs: pending.length,
      paidOutJobs: paidOut.length,
      helpEarnedJobs: helpEarned.length,
      helpPendingJobs: helpPending.length,
    );
  }

  String format(num amount) {
    return NumberFormat.currency(locale: 'en_IN', symbol: 'Rs ').format(amount);
  }
}

class _EarningJob {
  const _EarningJob({required this.id, required this.data});

  final String id;
  final Map<String, dynamic> data;

  String get status => (data['status'] ?? '').toString().toLowerCase();
  String get paymentStatus =>
      (data['paymentStatus'] ?? '').toString().toLowerCase();
  String get payoutStatus =>
      (data['payoutStatus'] ?? '').toString().toLowerCase();
  String get customerName => _text(['customerName', 'name'], 'Customer');
  String get service => _text(['service', 'serviceType'], 'Service');
  String get displayService => isHelpRequest ? 'Help: $service' : service;
  String get date => _text(['preferredDate'], 'Date not set');
  bool get isHelpRequest =>
      data['source'] == 'help_request' ||
      data['sourceHelpRequestId']?.toString().trim().isNotEmpty == true ||
      data['requestKind'] == 'generic_help';
  num get amount => _asNum(
    data['price'] ??
        data['estimatedPrice'] ??
        data['amount'] ??
        data['totalAmount'],
  );

  bool get isEarned {
    return status == 'completed' || status == 'paid' || paymentStatus == 'paid';
  }

  bool get isAvailableForPayout {
    return isEarned &&
        !{'requested', 'processing', 'paid', 'rejected'}.contains(payoutStatus);
  }

  bool get isPendingMoney {
    return status == 'payment_due' ||
        status == 'payment_initiated' ||
        status == 'payment_under_review' ||
        paymentStatus == 'cash_pending_confirmation' ||
        paymentStatus == 'customer_reported_paid';
  }

  DateTime get sortDate {
    final timestamp =
        data['paidAt'] ?? data['completedAt'] ?? data['updatedAt'];
    if (timestamp is Timestamp) return timestamp.toDate();
    final scheduledAt = data['scheduledAt'];
    if (scheduledAt is Timestamp) return scheduledAt.toDate();
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  String _text(List<String> keys, String fallback) {
    for (final key in keys) {
      final value = data[key]?.toString().trim();
      if (value != null && value.isNotEmpty && value.toLowerCase() != 'null') {
        return value;
      }
    }
    return fallback;
  }

  num _asNum(dynamic value) {
    if (value is num) return value;
    final match = RegExp(r'\d+(\.\d+)?').firstMatch(value?.toString() ?? '');
    return num.tryParse(match?.group(0) ?? '') ?? 0;
  }
}

class _EmptyEarnings extends StatelessWidget {
  const _EmptyEarnings();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: WorkableDesign.cardDecoration(),
      child: const Column(
        children: [
          Icon(Icons.savings_outlined, size: 38, color: WorkableDesign.muted),
          SizedBox(height: 8),
          Text(
            'No earnings yet',
            style: TextStyle(
              color: WorkableDesign.ink,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Completed and paid jobs will appear here.',
            style: TextStyle(color: WorkableDesign.muted),
          ),
        ],
      ),
    );
  }
}
