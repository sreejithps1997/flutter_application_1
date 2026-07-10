import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../core/theme/workable_design.dart';
import '../features/bookings/data/booking_action_repository.dart';
import '../services/chat_service.dart';
import 'chat_screen.dart';
import 'worker_job_details_screen.dart';

class WorkerActiveJobsScreen extends StatelessWidget {
  const WorkerActiveJobsScreen({super.key});

  static const routeName = '/worker/active-jobs';

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: WorkableDesign.canvas,
      appBar: AppBar(
        title: const Text('Active Jobs'),
        backgroundColor: WorkableDesign.surface,
        foregroundColor: WorkableDesign.ink,
      ),
      body: uid == null
          ? const Center(child: Text('Please log in again.'))
          : StreamBuilder<QuerySnapshot>(
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
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text('Unable to load jobs: ${snapshot.error}'),
                    ),
                  );
                }

                final jobs =
                    snapshot.data?.docs
                        .map((doc) {
                          return _ActiveJob(
                            id: doc.id,
                            data: doc.data() as Map<String, dynamic>,
                          );
                        })
                        .where((job) => !job.isClosed)
                        .toList() ??
                    [];

                jobs.sort((a, b) => a.sortDate.compareTo(b.sortDate));

                final requests = jobs.where((job) => job.isNewRequest).toList();
                final accepted = jobs.where((job) => job.isAccepted).toList();
                final inProgress = jobs
                    .where((job) => job.isInProgress)
                    .toList();
                final completion = jobs
                    .where((job) => job.isCompletionRequested)
                    .toList();
                final payment = jobs
                    .where((job) => job.isPaymentStage)
                    .toList();

                return ListView(
                  padding: const EdgeInsets.all(WorkableDesign.pagePadding),
                  children: [
                    _HeaderSummary(
                      total: jobs.length,
                      requests: requests.length,
                      actionNeeded: requests.length + payment.length,
                    ),
                    const SizedBox(height: 16),
                    _JobSection(
                      title: 'New Requests',
                      subtitle:
                          'Accept or decline quickly to keep your score healthy.',
                      emptyText: 'No new requests waiting for your response.',
                      jobs: requests,
                    ),
                    _JobSection(
                      title: 'Accepted',
                      subtitle: 'Jobs accepted but not started yet.',
                      emptyText: 'No accepted jobs waiting to start.',
                      jobs: accepted,
                    ),
                    _JobSection(
                      title: 'In Progress',
                      subtitle: 'Work currently underway.',
                      emptyText: 'No jobs are currently in progress.',
                      jobs: inProgress,
                    ),
                    _JobSection(
                      title: 'Completion Requested',
                      subtitle: 'Waiting for customer confirmation.',
                      emptyText:
                          'No jobs are waiting for completion confirmation.',
                      jobs: completion,
                    ),
                    _JobSection(
                      title: 'Payment Due / Review',
                      subtitle: 'Follow up on unpaid or payment-review jobs.',
                      emptyText: 'No active jobs are waiting on payment.',
                      jobs: payment,
                    ),
                  ],
                );
              },
            ),
    );
  }
}

class _HeaderSummary extends StatelessWidget {
  const _HeaderSummary({
    required this.total,
    required this.requests,
    required this.actionNeeded,
  });

  final int total;
  final int requests;
  final int actionNeeded;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: WorkableDesign.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Today\'s work board',
            style: TextStyle(
              color: WorkableDesign.ink,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Track requests, ongoing work, completion checks and payments from one place.',
            style: TextStyle(color: WorkableDesign.muted, height: 1.35),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _MetricTile(
                  label: 'Active',
                  value: '$total',
                  color: WorkableDesign.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MetricTile(
                  label: 'Requests',
                  value: '$requests',
                  color: WorkableDesign.warning,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MetricTile(
                  label: 'Action',
                  value: '$actionNeeded',
                  color: actionNeeded > 0
                      ? WorkableDesign.danger
                      : WorkableDesign.success,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(WorkableDesign.radius),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
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
}

class _JobSection extends StatelessWidget {
  const _JobSection({
    required this.title,
    required this.subtitle,
    required this.emptyText,
    required this.jobs,
  });

  final String title;
  final String subtitle;
  final String emptyText;
  final List<_ActiveJob> jobs;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: WorkableDesign.ink,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: WorkableDesign.muted,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              _CountPill(count: jobs.length),
            ],
          ),
          const SizedBox(height: 12),
          if (jobs.isEmpty)
            _EmptyCard(text: emptyText)
          else
            ...jobs.map((job) => _ActiveJobCard(job: job)),
        ],
      ),
    );
  }
}

class _ActiveJobCard extends StatelessWidget {
  const _ActiveJobCard({required this.job});

  final _ActiveJob job;

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(job.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: WorkableDesign.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      job.service,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: WorkableDesign.ink,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      job.customerName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: WorkableDesign.muted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _StatusPill(label: job.statusLabel, color: statusColor),
            ],
          ),
          const SizedBox(height: 12),
          _IconLine(
            icon: Icons.schedule_outlined,
            text: '${job.date} • ${job.time}',
          ),
          _IconLine(icon: Icons.location_on_outlined, text: job.address),
          if (job.amount > 0)
            _IconLine(
              icon: Icons.currency_rupee,
              text: 'Rs ${job.amount.toStringAsFixed(0)}',
            ),
          if (job.issue.isNotEmpty)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(top: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: WorkableDesign.canvas,
                borderRadius: BorderRadius.circular(WorkableDesign.radius),
              ),
              child: Text(
                job.issue,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: WorkableDesign.ink, height: 1.35),
              ),
            ),
          const SizedBox(height: 12),
          _NextStepBanner(job: job),
          const SizedBox(height: 12),
          _PrimaryActions(job: job),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            WorkerJobDetailsScreen(bookingId: job.id),
                      ),
                    );
                  },
                  icon: const Icon(Icons.open_in_new, size: 18),
                  label: const Text('Details'),
                ),
              ),
              const SizedBox(width: 10),
              IconButton.outlined(
                tooltip: 'Message customer',
                onPressed: () => _openChat(context),
                icon: const Icon(Icons.chat_bubble_outline),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _openChat(BuildContext context) async {
    if (job.customerId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Customer details not found')),
      );
      return;
    }

    await ChatService().ensureChatForBooking(
      otherUserId: job.customerId,
      otherUserName: job.customerName,
      userRole: 'worker',
      bookingId: job.id,
      service: job.service,
    );
    if (!context.mounted) return;

    Navigator.pushNamed(
      context,
      ChatScreen.routeName,
      arguments: {
        'chatWithId': job.customerId,
        'chatWithName': job.customerName,
        'userRole': 'worker',
        'bookingId': job.id,
        'workerService': job.service,
      },
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'confirmed':
      case 'in_progress':
        return WorkableDesign.success;
      case 'pending':
        return WorkableDesign.warning;
      case 'completion_requested':
      case 'payment_due':
      case 'payment_initiated':
      case 'customer_reported_paid':
      case 'cash_pending_confirmation':
      case 'payment_under_review':
        return WorkableDesign.primary;
      case 'cancelled':
      case 'rejected':
      case 'payment_rejected':
        return WorkableDesign.danger;
      default:
        return WorkableDesign.muted;
    }
  }
}

class _PrimaryActions extends StatelessWidget {
  const _PrimaryActions({required this.job});

  final _ActiveJob job;

  @override
  Widget build(BuildContext context) {
    if (job.isNewRequest) {
      return Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => _updateStatus(context, 'cancelled'),
              child: const Text('Decline'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: FilledButton(
              onPressed: () => _updateStatus(context, 'confirmed'),
              child: const Text('Accept'),
            ),
          ),
        ],
      );
    }

    if (job.isAccepted) {
      return FilledButton.icon(
        onPressed: () => _updateStatus(context, 'in_progress'),
        icon: const Icon(Icons.play_arrow_rounded),
        label: const Text('Start Work'),
      );
    }

    if (job.isInProgress) {
      return FilledButton.icon(
        onPressed: () => _requestCompletion(context),
        icon: const Icon(Icons.task_alt_rounded),
        label: const Text('Request Completion'),
      );
    }

    if (job.isCashPending) {
      return FilledButton.icon(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => WorkerJobDetailsScreen(bookingId: job.id),
            ),
          );
        },
        icon: const Icon(Icons.payments_outlined),
        label: const Text('Confirm Cash In Details'),
      );
    }

    return const SizedBox.shrink();
  }

  Future<void> _updateStatus(BuildContext context, String nextStatus) async {
    final actions = BookingActionRepository();
    if (nextStatus == 'confirmed') {
      await actions.acceptBooking(job.id);
    } else if (nextStatus == 'in_progress') {
      await actions.startWork(job.id);
    } else if (nextStatus == 'cancelled') {
      await actions.declineBooking(job.id);
    }
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(_statusMessage(nextStatus))));
  }

  Future<void> _requestCompletion(BuildContext context) async {
    await BookingActionRepository().requestCompletion(job.id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Completion request sent to customer')),
    );
  }

  String _statusMessage(String status) {
    switch (status) {
      case 'confirmed':
        return 'Job accepted';
      case 'in_progress':
        return 'Job marked as in progress';
      case 'cancelled':
        return 'Job declined';
      default:
        return 'Job updated';
    }
  }
}

class _NextStepBanner extends StatelessWidget {
  const _NextStepBanner({required this.job});

  final _ActiveJob job;

  @override
  Widget build(BuildContext context) {
    final color = job.nextStepColor;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(WorkableDesign.radius),
        border: Border.all(color: color.withValues(alpha: 0.16)),
      ),
      child: Row(
        children: [
          Icon(job.nextStepIcon, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              job.nextStep,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w700,
                height: 1.25,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActiveJob {
  const _ActiveJob({required this.id, required this.data});

  final String id;
  final Map<String, dynamic> data;

  String get status => (data['status'] ?? 'pending').toString().toLowerCase();
  String get paymentStatus =>
      (data['paymentStatus'] ?? '').toString().toLowerCase();
  String get statusLabel => status.replaceAll('_', ' ');
  String get customerId => data['customerId']?.toString() ?? '';
  String get customerName => _text(['customerName', 'name'], 'Customer');
  String get service => _text(['service', 'serviceType'], 'Service');
  String get issue => _text(['issueDescription', 'issue'], '');
  String get address => _text(['address'], 'Address not available');
  String get date => _text(['preferredDate'], 'Date not set');
  String get time => _text(['preferredTime'], 'Time not set');

  bool get isNewRequest => status == 'pending';
  bool get isAccepted => status == 'confirmed' || status == 'accepted';
  bool get isInProgress => status == 'in_progress';
  bool get isCompletionRequested => status == 'completion_requested';
  bool get isCashPending =>
      paymentStatus == 'cash_pending_confirmation' ||
      status == 'cash_pending_confirmation';
  bool get isPaymentStage {
    return {
          'payment_due',
          'payment_initiated',
          'customer_reported_paid',
          'payment_under_review',
          'cash_pending_confirmation',
        }.contains(status) ||
        {
          'payment_due',
          'payment_initiated',
          'customer_reported_paid',
          'payment_under_review',
          'cash_pending_confirmation',
        }.contains(paymentStatus);
  }

  bool get isClosed {
    return {
      'completed',
      'paid',
      'cancelled',
      'rejected',
      'declined',
      'payment_rejected',
    }.contains(status);
  }

  double get amount {
    for (final key in ['totalAmount', 'amount', 'price', 'servicePrice']) {
      final value = data[key];
      if (value is num) return value.toDouble();
      final parsed = double.tryParse(value?.toString() ?? '');
      if (parsed != null) return parsed;
    }
    return 0;
  }

  DateTime get sortDate {
    for (final key in [
      'scheduledAt',
      'preferredAt',
      'createdAt',
      'updatedAt',
    ]) {
      final value = data[key];
      if (value is Timestamp) return value.toDate();
    }
    return DateTime.tryParse('$date ${_normalizeTime(time)}') ??
        DateTime.tryParse(date) ??
        DateTime.fromMillisecondsSinceEpoch(0);
  }

  String get nextStep {
    if (isNewRequest) {
      return 'Respond to this request before the customer waits too long.';
    }
    if (isAccepted) return 'Start work when you reach the customer location.';
    if (isInProgress) {
      return 'When the work is done, request completion confirmation.';
    }
    if (isCompletionRequested) {
      return 'Customer must confirm the completed work before payment.';
    }
    if (isCashPending) {
      return 'Confirm only after you have received cash from the customer.';
    }
    if (isPaymentStage) {
      return 'Payment is pending or under review. Keep customer communication clear.';
    }
    return 'Open details to review the latest job status.';
  }

  IconData get nextStepIcon {
    if (isNewRequest) return Icons.notifications_active_outlined;
    if (isAccepted) return Icons.play_circle_outline;
    if (isInProgress) return Icons.handyman_outlined;
    if (isCompletionRequested) return Icons.fact_check_outlined;
    if (isPaymentStage) return Icons.payments_outlined;
    return Icons.info_outline;
  }

  Color get nextStepColor {
    if (isNewRequest) return WorkableDesign.warning;
    if (isPaymentStage) return WorkableDesign.primary;
    if (isAccepted || isInProgress) return WorkableDesign.success;
    return WorkableDesign.accent;
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

  String _normalizeTime(String value) {
    final match = RegExp(
      r'^(\d{1,2})(?::(\d{2}))?\s*(AM|PM)?$',
      caseSensitive: false,
    ).firstMatch(value.trim());
    if (match == null) return '00:00';
    var hour = int.tryParse(match.group(1) ?? '0') ?? 0;
    final minute = int.tryParse(match.group(2) ?? '0') ?? 0;
    final period = match.group(3)?.toUpperCase();
    if (period == 'PM' && hour < 12) hour += 12;
    if (period == 'AM' && hour == 12) hour = 0;
    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 132),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _CountPill extends StatelessWidget {
  const _CountPill({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: WorkableDesign.primary.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$count',
        style: const TextStyle(
          color: WorkableDesign.primary,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: WorkableDesign.cardDecoration(),
      child: Row(
        children: [
          const Icon(Icons.work_outline, color: WorkableDesign.muted),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: WorkableDesign.muted),
            ),
          ),
        ],
      ),
    );
  }
}

class _IconLine extends StatelessWidget {
  const _IconLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          Icon(icon, size: 16, color: WorkableDesign.muted),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: WorkableDesign.muted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
