import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../core/theme/workable_design.dart';
import 'worker_job_details_screen.dart';

class WorkerJobHistoryScreen extends StatefulWidget {
  const WorkerJobHistoryScreen({super.key});

  static const routeName = '/worker/job-history';

  @override
  State<WorkerJobHistoryScreen> createState() => _WorkerJobHistoryScreenState();
}

class _WorkerJobHistoryScreenState extends State<WorkerJobHistoryScreen> {
  String _filter = 'all';

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: WorkableDesign.canvas,
      appBar: AppBar(
        title: const Text('Job History'),
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
                      child: Text('Unable to load history: ${snapshot.error}'),
                    ),
                  );
                }

                final allClosed =
                    snapshot.data?.docs
                        .map(
                          (doc) => _HistoryJob(
                            id: doc.id,
                            data: doc.data() as Map<String, dynamic>,
                          ),
                        )
                        .where((job) => job.isHistory)
                        .toList() ??
                    [];

                allClosed.sort((a, b) => b.sortDate.compareTo(a.sortDate));

                final filtered = allClosed.where(_matchesFilter).toList();

                return ListView(
                  padding: const EdgeInsets.all(WorkableDesign.pagePadding),
                  children: [
                    _HistorySummary(jobs: allClosed),
                    const SizedBox(height: 14),
                    _buildFilters(allClosed),
                    const SizedBox(height: 14),
                    if (filtered.isEmpty)
                      _EmptyHistory(filter: _filter)
                    else
                      ...filtered.map((job) => _HistoryCard(job: job)),
                  ],
                );
              },
            ),
    );
  }

  bool _matchesFilter(_HistoryJob job) {
    switch (_filter) {
      case 'completed':
        return job.isCompleted;
      case 'cancelled':
        return job.isCancelled;
      case 'rejected':
        return job.isRejected;
      case 'disputed':
        return job.isDisputed;
      case 'help':
        return job.isHelpRequest;
      default:
        return true;
    }
  }

  Widget _buildFilters(List<_HistoryJob> jobs) {
    final filters = [
      _FilterOption('all', 'All', jobs.length),
      _FilterOption(
        'completed',
        'Completed',
        jobs.where((j) => j.isCompleted).length,
      ),
      _FilterOption(
        'cancelled',
        'Cancelled',
        jobs.where((j) => j.isCancelled).length,
      ),
      _FilterOption(
        'rejected',
        'Rejected',
        jobs.where((j) => j.isRejected).length,
      ),
      _FilterOption(
        'disputed',
        'Disputed',
        jobs.where((j) => j.isDisputed).length,
      ),
      _FilterOption('help', 'Help', jobs.where((j) => j.isHelpRequest).length),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.map((filter) {
          final selected = _filter == filter.key;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text('${filter.label} ${filter.count}'),
              selected: selected,
              onSelected: (_) => setState(() => _filter = filter.key),
              selectedColor: WorkableDesign.primary.withValues(alpha: 0.12),
              labelStyle: TextStyle(
                color: selected ? WorkableDesign.primary : WorkableDesign.ink,
                fontWeight: FontWeight.w700,
              ),
              side: BorderSide(
                color: selected
                    ? WorkableDesign.primary
                    : WorkableDesign.border,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _HistorySummary extends StatelessWidget {
  const _HistorySummary({required this.jobs});

  final List<_HistoryJob> jobs;

  @override
  Widget build(BuildContext context) {
    final completed = jobs.where((job) => job.isCompleted).length;
    final cancelled = jobs.where((job) => job.isCancelled).length;
    final disputes = jobs
        .where((job) => job.isDisputed || job.isRejected)
        .length;
    final helpJobs = jobs.where((job) => job.isHelpRequest).length;
    final helpEarnings = jobs
        .where((job) => job.isCompleted && job.isHelpRequest)
        .fold<double>(0, (total, job) => total + job.amount);
    final totalEarnings = jobs
        .where((job) => job.isCompleted)
        .fold<double>(0, (total, job) => total + job.amount);
    final ratedJobs = jobs.where((job) => job.rating > 0).toList();
    final averageRating = ratedJobs.isEmpty
        ? 0.0
        : ratedJobs.fold<double>(0, (total, job) => total + job.rating) /
              ratedJobs.length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: WorkableDesign.cardDecoration(color: WorkableDesign.ink),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Closed job record',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Completed work, cancellations, rejected payments and disputes stay here for review.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.72),
              height: 1.35,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _SummaryMetric(
                  label: 'Earned',
                  value: 'Rs ${totalEarnings.toStringAsFixed(0)}',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _SummaryMetric(label: 'Completed', value: '$completed'),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _SummaryMetric(
                  label: 'Rating',
                  value: averageRating <= 0
                      ? '--'
                      : averageRating.toStringAsFixed(1),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _MiniPill(label: 'Cancelled $cancelled'),
              const SizedBox(width: 8),
              _MiniPill(label: 'Issues $disputes'),
              const SizedBox(width: 8),
              _MiniPill(
                label: helpJobs == 0
                    ? 'Help 0'
                    : 'Help $helpJobs | Rs ${helpEarnings.toStringAsFixed(0)}',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.job});

  final _HistoryJob job;

  @override
  Widget build(BuildContext context) {
    final statusColor = job.statusColor;

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
                    if (job.isHelpRequest) ...[
                      const _StatusPill(
                        label: 'help request',
                        color: WorkableDesign.accent,
                      ),
                      const SizedBox(width: 8),
                    ],
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
              _StatusPill(label: job.displayStatus, color: statusColor),
            ],
          ),
          const SizedBox(height: 12),
          _IconLine(
            icon: Icons.schedule_outlined,
            text: '${job.date} - ${job.time}',
          ),
          _IconLine(icon: Icons.location_on_outlined, text: job.address),
          _IconLine(icon: Icons.payments_outlined, text: job.paymentLabel),
          _IconLine(icon: Icons.timer_outlined, text: job.verifiedHoursLabel),
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
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: WorkableDesign.ink, height: 1.35),
              ),
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _OutcomeTile(
                  label: job.isCompleted ? 'Worker earning' : 'Recorded amount',
                  value: job.amount > 0
                      ? 'Rs ${job.amount.toStringAsFixed(0)}'
                      : 'Not saved',
                  color: job.isCompleted
                      ? WorkableDesign.success
                      : WorkableDesign.muted,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _OutcomeTile(
                  label: 'Customer rating',
                  value: job.rating > 0
                      ? job.rating.toStringAsFixed(1)
                      : 'None',
                  color: job.rating > 0
                      ? WorkableDesign.warning
                      : WorkableDesign.muted,
                  icon: job.rating > 0 ? Icons.star_rounded : Icons.star_border,
                ),
              ),
            ],
          ),
          if (job.reviewText.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              job.reviewText,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: WorkableDesign.muted, height: 1.35),
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => WorkerJobDetailsScreen(bookingId: job.id),
                  ),
                );
              },
              icon: const Icon(Icons.open_in_new, size: 18),
              label: const Text('Open Details'),
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryJob {
  const _HistoryJob({required this.id, required this.data});

  final String id;
  final Map<String, dynamic> data;

  String get status => (data['status'] ?? '').toString().toLowerCase();
  String get paymentStatus =>
      (data['paymentStatus'] ?? '').toString().toLowerCase();
  String get customerName => _text(['customerName', 'name'], 'Customer');
  String get service => _text(['service', 'serviceType'], 'Service');
  String get issue => _text(['issueDescription', 'issue'], '');
  String get address => _text(['address'], 'Address not available');
  String get date => _text(['preferredDate'], 'Date not set');
  String get time => _text(['preferredTime'], 'Time not set');
  String get reviewText => _text(['review', 'customerReview', 'feedback'], '');
  bool get isHelpRequest =>
      data['source'] == 'help_request' ||
      data['sourceHelpRequestId']?.toString().trim().isNotEmpty == true ||
      data['requestKind'] == 'generic_help';

  bool get isCompleted =>
      status == 'completed' || status == 'paid' || paymentStatus == 'paid';
  bool get isCancelled => status == 'cancelled' || status == 'declined';
  bool get isRejected =>
      status == 'rejected' ||
      status == 'payment_rejected' ||
      paymentStatus == 'payment_rejected';
  bool get isDisputed =>
      status == 'completion_disputed' ||
      status == 'disputed' ||
      paymentStatus == 'disputed';
  bool get isHistory => isCompleted || isCancelled || isRejected || isDisputed;

  String get displayStatus {
    if (isCompleted) return 'completed';
    if (isRejected) return 'rejected';
    if (isDisputed) return 'disputed';
    if (isCancelled) return 'cancelled';
    return status.replaceAll('_', ' ');
  }

  String get paymentLabel {
    final method = _text([
      'paymentMethod',
      'payment',
    ], 'Payment method not set');
    final statusLabel = paymentStatus.isEmpty
        ? 'payment status not saved'
        : paymentStatus.replaceAll('_', ' ');
    return '$method - $statusLabel';
  }

  double get amount {
    for (final key in [
      'workerEarning',
      'workerAmount',
      'totalAmount',
      'amount',
      'price',
      'estimatedPrice',
      'servicePrice',
    ]) {
      final parsed = _asDouble(data[key]);
      if (parsed > 0) return parsed;
    }
    return 0;
  }

  double get rating {
    for (final key in ['workerRating', 'rating', 'customerRating']) {
      final parsed = _asDouble(data[key]);
      if (parsed > 0) return parsed;
    }
    return 0;
  }

  String get verifiedHoursLabel {
    final minutes = verifiedMinutes;
    if (minutes == null) return 'Verified hours not recorded';
    final hours = minutes ~/ 60;
    final rest = minutes % 60;
    if (hours == 0) return 'Verified work: $rest min';
    if (rest == 0) return 'Verified work: $hours hr';
    return 'Verified work: $hours hr $rest min';
  }

  int? get verifiedMinutes {
    final stored = _asDouble(data['verifiedWorkMinutes']);
    if (stored > 0) return stored.round();
    final start = _date(
      data['workStartedAt'] ??
          (data['timeline'] is Map ? data['timeline']['in_progress'] : null),
    );
    final end = _date(
      data['workCompletedAt'] ??
          data['completionRequestedAt'] ??
          data['completedAt'] ??
          data['paidAt'] ??
          data['customerConfirmedCompletionAt'] ??
          (data['timeline'] is Map
              ? data['timeline']['work_completed']
              : null) ??
          (data['timeline'] is Map
              ? data['timeline']['completion_requested']
              : null) ??
          (data['timeline'] is Map ? data['timeline']['completed'] : null) ??
          (data['timeline'] is Map ? data['timeline']['paid'] : null),
    );
    if (start == null || end == null || !end.isAfter(start)) return null;
    final minutes = end.difference(start).inMinutes;
    if (minutes <= 0 || minutes > 16 * 60) return null;
    return minutes;
  }

  DateTime get sortDate {
    for (final key in [
      'paidAt',
      'completedAt',
      'cancelledAt',
      'declinedAt',
      'updatedAt',
      'scheduledAt',
      'createdAt',
    ]) {
      final value = data[key];
      if (value is Timestamp) return value.toDate();
    }
    return DateTime.tryParse('$date ${_normalizeTime(time)}') ??
        DateTime.tryParse(date) ??
        DateTime.fromMillisecondsSinceEpoch(0);
  }

  Color get statusColor {
    if (isCompleted) return WorkableDesign.success;
    if (isCancelled || isRejected) return WorkableDesign.danger;
    if (isDisputed) return WorkableDesign.warning;
    return WorkableDesign.muted;
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

  double _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    final match = RegExp(r'\d+(\.\d+)?').firstMatch(value?.toString() ?? '');
    return double.tryParse(match?.group(0) ?? '') ?? 0;
  }

  DateTime? _date(dynamic value) {
    if (value is Timestamp) return value.toDate();
    return null;
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

class _FilterOption {
  const _FilterOption(this.key, this.label, this.count);

  final String key;
  final String label;
  final int count;
}

class _SummaryMetric extends StatelessWidget {
  const _SummaryMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(WorkableDesign.radius),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.72)),
          ),
        ],
      ),
    );
  }
}

class _MiniPill extends StatelessWidget {
  const _MiniPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.8),
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 118),
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

class _OutcomeTile extends StatelessWidget {
  const _OutcomeTile({
    required this.label,
    required this.value,
    required this.color,
    this.icon,
  });

  final String label;
  final String value;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(WorkableDesign.radius),
        border: Border.all(color: color.withValues(alpha: 0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
          const SizedBox(height: 5),
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, color: color, size: 17),
                const SizedBox(width: 4),
              ],
              Expanded(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory({required this.filter});

  final String filter;

  @override
  Widget build(BuildContext context) {
    final message = filter == 'all'
        ? 'Completed, cancelled, rejected and disputed jobs will appear here.'
        : 'No jobs found for this filter.';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: WorkableDesign.cardDecoration(),
      child: Column(
        children: [
          const Icon(Icons.history, size: 36, color: WorkableDesign.muted),
          const SizedBox(height: 8),
          const Text(
            'No history found',
            style: TextStyle(
              color: WorkableDesign.ink,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: WorkableDesign.muted),
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
