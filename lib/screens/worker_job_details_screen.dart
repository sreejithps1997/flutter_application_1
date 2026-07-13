import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../core/theme/workable_design.dart';
import '../features/bookings/data/booking_action_repository.dart';
import '../services/payment_reconciliation_service.dart';
import '../services/verification_tier_manager.dart';
import '../widgets/workable_ui.dart';

class WorkerJobDetailsScreen extends StatefulWidget {
  static const routeName = '/worker-job-details';

  final String bookingId;

  const WorkerJobDetailsScreen({super.key, required this.bookingId});

  @override
  State<WorkerJobDetailsScreen> createState() => _WorkerJobDetailsScreenState();
}

class _WorkerJobDetailsScreenState extends State<WorkerJobDetailsScreen> {
  bool hasVerified = true;
  bool _isActing = false;

  @override
  void initState() {
    super.initState();
    _checkVerificationStatus();
  }

  Future<void> _checkVerificationStatus() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final verified = await VerificationTierManager().hasUploadedPanAndAadhaar(
      uid,
    );

    if (!mounted) return;
    setState(() => hasVerified = verified);
  }

  Future<void> _runBookingAction(
    Future<void> Function(BookingActionRepository actions) action, {
    required String successMessage,
    String? failureMessage,
  }) async {
    if (_isActing) return;
    setState(() => _isActing = true);

    try {
      await action(BookingActionRepository());

      if (!mounted) return;
      _showSnack(successMessage);
    } catch (error) {
      if (!mounted) return;
      _showSnack(
        _friendlyActionError(error, failureMessage ?? 'Unable to update job.'),
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _isActing = false);
    }
  }

  Future<void> _acceptJob() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final verified = await VerificationTierManager().hasUploadedPanAndAadhaar(
      uid,
    );
    if (!verified) {
      if (!mounted) return;
      _showUploadPanAadhaarDialog(context);
      return;
    }

    await _runBookingAction(
      (actions) => actions.acceptBooking(widget.bookingId),
      successMessage: 'Job accepted.',
      failureMessage: 'Unable to accept job.',
    );
  }

  Future<void> _declineJob() async {
    await _runBookingAction(
      (actions) => actions.declineBooking(widget.bookingId),
      successMessage: 'Job declined.',
      failureMessage: 'Unable to decline job.',
    );
  }

  Future<void> _requestCompletion() async {
    await _runBookingAction(
      (actions) => actions.requestCompletion(widget.bookingId),
      successMessage: 'Completion request sent to the customer.',
      failureMessage: 'Unable to request completion.',
    );
  }

  Future<void> _startWork() async {
    await _runBookingAction(
      (actions) => actions.startWork(widget.bookingId),
      successMessage: 'Work started. Verified hours are now being tracked.',
      failureMessage: 'Unable to start work.',
    );
  }

  Future<void> _confirmCashReceived() async {
    if (_isActing) return;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    setState(() => _isActing = true);
    try {
      await PaymentReconciliationService().approvePayment(
        bookingId: widget.bookingId,
        reviewedBy: uid,
        reviewerRole: 'worker',
        note: 'Worker confirmed cash received.',
      );

      if (!mounted) return;
      _showSnack('Cash payment confirmed.');
    } catch (_) {
      if (!mounted) return;
      _showSnack('Unable to confirm cash payment.', isError: true);
    } finally {
      if (mounted) setState(() => _isActing = false);
    }
  }

  void _showSnack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: isError
            ? WorkableDesign.danger
            : WorkableDesign.success,
      ),
    );
  }

  String _friendlyActionError(Object error, String fallback) {
    final text = error.toString().replaceFirst('Bad state: ', '').trim();
    if (text.isEmpty || text == 'Exception') return fallback;
    return text;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WorkableDesign.canvas,
      appBar: AppBar(title: const Text('Job Details')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('bookings')
            .doc(widget.bookingId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return WorkableEmptyState(
              icon: LucideIcons.alertTriangle,
              title: 'Unable to load job',
              message: snapshot.error.toString(),
            );
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const WorkableEmptyState(
              icon: LucideIcons.briefcase,
              title: 'Job not found',
              message: 'This booking may have been removed or reassigned.',
            );
          }

          final job = snapshot.data!.data() ?? {};
          return _buildDetails(job);
        },
      ),
    );
  }

  Widget _buildDetails(Map<String, dynamic> job) {
    final status = _value(job, ['status']) ?? 'pending';
    final paymentStatus = _value(job, ['paymentStatus']) ?? 'not_started';
    final paymentMethod = _value(job, ['paymentMethod', 'payment']) ?? '-';
    final isCashPending =
        paymentStatus == 'cash_pending_confirmation' ||
        (paymentMethod.toLowerCase().contains('cash') &&
            status == 'payment_under_review');

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(WorkableDesign.pagePadding),
        children: [
          WorkablePageHeader(
            title: _value(job, ['service', 'serviceType']) ?? 'Assigned job',
            subtitle:
                'Review customer details, job status, payment state, and next action.',
            icon: LucideIcons.briefcase,
            trailing: WorkableStatusPill(
              label: _statusLabel(status),
              color: _statusColor(status),
            ),
          ),
          const SizedBox(height: 16),
          _buildStatusCard(status, paymentStatus, paymentMethod),
          const SizedBox(height: 16),
          _buildCustomerCard(job),
          const SizedBox(height: 16),
          _buildJobCard(job),
          const SizedBox(height: 16),
          if (!hasVerified) _buildRestrictedCard(),
          if (!hasVerified) const SizedBox(height: 16),
          _buildWorkHoursCard(job),
          const SizedBox(height: 16),
          _buildActionCard(status, isCashPending),
        ],
      ),
    );
  }

  Widget _buildStatusCard(
    String status,
    String paymentStatus,
    String paymentMethod,
  ) {
    return WorkableSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle('Current status'),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              WorkableStatusPill(
                label: _statusLabel(status),
                color: _statusColor(status),
                icon: LucideIcons.activity,
              ),
              WorkableStatusPill(
                label: _paymentLabel(paymentStatus),
                color: _paymentColor(paymentStatus),
                icon: LucideIcons.wallet,
              ),
            ],
          ),
          const SizedBox(height: 14),
          WorkableInfoRow(
            icon: LucideIcons.creditCard,
            text: 'Payment method: $paymentMethod',
          ),
          const SizedBox(height: 8),
          WorkableInfoRow(
            icon: LucideIcons.hash,
            text: 'Job ID: ${widget.bookingId}',
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerCard(Map<String, dynamic> job) {
    return WorkableSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle('Customer'),
          const SizedBox(height: 12),
          _DetailRow(
            icon: LucideIcons.user,
            label: 'Name',
            value: hasVerified
                ? _value(job, ['customerName', 'name']) ?? '-'
                : 'Restricted until verification',
          ),
          _DetailRow(
            icon: LucideIcons.phone,
            label: 'Phone',
            value: hasVerified
                ? _value(job, ['customerPhone', 'phone', 'phoneNumber']) ?? '-'
                : 'Restricted until verification',
          ),
          _DetailRow(
            icon: LucideIcons.mapPin,
            label: 'Address',
            value: hasVerified
                ? _value(job, ['address']) ?? '-'
                : 'Restricted until verification',
          ),
        ],
      ),
    );
  }

  Widget _buildJobCard(Map<String, dynamic> job) {
    return WorkableSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle('Job information'),
          const SizedBox(height: 12),
          _DetailRow(
            icon: LucideIcons.wrench,
            label: 'Service',
            value: _value(job, ['service', 'serviceType']) ?? '-',
          ),
          _DetailRow(
            icon: LucideIcons.fileText,
            label: 'Issue',
            value: _value(job, ['issueDescription', 'issue']) ?? '-',
          ),
          _DetailRow(
            icon: LucideIcons.calendar,
            label: 'Date',
            value: _value(job, ['preferredDate']) ?? '-',
          ),
          _DetailRow(
            icon: LucideIcons.clock,
            label: 'Time',
            value: _value(job, ['preferredTime']) ?? '-',
          ),
        ],
      ),
    );
  }

  Widget _buildWorkHoursCard(Map<String, dynamic> job) {
    final start = _date(
      job['workStartedAt'] ?? job['timeline']?['in_progress'],
    );
    final end = _date(
      job['workCompletedAt'] ??
          job['completionRequestedAt'] ??
          job['completedAt'] ??
          job['paidAt'] ??
          job['customerConfirmedCompletionAt'] ??
          job['timeline']?['work_completed'] ??
          job['timeline']?['completion_requested'] ??
          job['timeline']?['completed'] ??
          job['timeline']?['paid'],
    );
    final verifiedMinutes = _verifiedMinutes(start, end);
    final distance = _asDouble(job['startWorkDistanceMeters']);

    return WorkableSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle('Verified work hours'),
          const SizedBox(height: 12),
          _DetailRow(
            icon: LucideIcons.playCircle,
            label: 'Started',
            value: _formatDateTime(start),
          ),
          _DetailRow(
            icon: LucideIcons.checkCircle,
            label: 'Work completed',
            value: _formatDateTime(end),
          ),
          _DetailRow(
            icon: LucideIcons.timer,
            label: 'Tracked time',
            value: verifiedMinutes == null
                ? 'Will calculate after completion'
                : _formatDuration(verifiedMinutes),
          ),
          _DetailRow(
            icon: LucideIcons.mapPin,
            label: 'Start location',
            value: job['startLocationVerified'] == true
                ? 'Verified${distance == null ? '' : ' within ${distance.toStringAsFixed(0)} m'}'
                : 'Not verified yet',
          ),
          const SizedBox(height: 6),
          const WorkableInfoRow(
            icon: LucideIcons.shieldCheck,
            text:
                'Workable counts verified hours only between Start Work and Work Completed, and ignores impossible long sessions.',
          ),
        ],
      ),
    );
  }

  Widget _buildRestrictedCard() {
    return WorkableSectionCard(
      color: WorkableDesign.warning.withValues(alpha: 0.08),
      borderColor: WorkableDesign.warning.withValues(alpha: 0.24),
      child: const WorkableInfoRow(
        icon: LucideIcons.shieldAlert,
        text:
            'Customer contact details stay restricted until PAN and Aadhaar upload requirements are completed.',
      ),
    );
  }

  Widget _buildActionCard(String status, bool isCashPending) {
    return WorkableSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle('Next action'),
          const SizedBox(height: 12),
          if (isCashPending) ...[
            const WorkableInfoRow(
              icon: LucideIcons.banknote,
              text:
                  'Confirm cash only after the customer has paid you directly.',
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _isActing ? null : _confirmCashReceived,
                icon: const Icon(LucideIcons.checkCircle),
                label: Text(
                  _isActing ? 'Updating...' : 'Confirm Cash Received',
                ),
              ),
            ),
          ] else if (status == 'confirmed' || status == 'accepted') ...[
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _isActing ? null : _startWork,
                icon: const Icon(LucideIcons.playCircle),
                label: Text(_isActing ? 'Starting...' : 'Start Work'),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _isActing ? null : _declineJob,
                icon: const Icon(LucideIcons.xCircle),
                label: const Text('Cancel Job'),
              ),
            ),
          ] else if (status == 'in_progress') ...[
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _isActing ? null : _requestCompletion,
                icon: const Icon(LucideIcons.checkCircle),
                label: Text(_isActing ? 'Sending...' : 'Request Completion'),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _isActing ? null : _declineJob,
                icon: const Icon(LucideIcons.xCircle),
                label: const Text('Cancel Job'),
              ),
            ),
          ] else if (status == 'pending') ...[
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _isActing ? null : _acceptJob,
                icon: const Icon(LucideIcons.checkCircle),
                label: Text(_isActing ? 'Accepting...' : 'Accept Job'),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _isActing ? null : _declineJob,
                icon: const Icon(LucideIcons.xCircle),
                label: const Text('Decline Job'),
              ),
            ),
          ] else if (status == 'completion_requested') ...[
            const WorkableInfoRow(
              icon: LucideIcons.hourglass,
              text:
                  'Waiting for the customer to confirm the completed work. Payment starts after confirmation.',
            ),
          ] else if (status == 'completed' || status == 'paid') ...[
            const WorkableInfoRow(
              icon: LucideIcons.checkCircle,
              text: 'This job is completed. It will remain visible in history.',
            ),
          ] else ...[
            WorkableInfoRow(
              icon: LucideIcons.info,
              text:
                  'No worker action is available for ${_statusLabel(status)}.',
            ),
          ],
        ],
      ),
    );
  }

  String? _value(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = data[key]?.toString().trim();
      if (value != null && value.isNotEmpty && value.toLowerCase() != 'null') {
        return value;
      }
    }
    return null;
  }

  DateTime? _date(dynamic value) {
    if (value is Timestamp) return value.toDate();
    return null;
  }

  int? _verifiedMinutes(DateTime? start, DateTime? end) {
    if (start == null || end == null || !end.isAfter(start)) return null;
    final minutes = end.difference(start).inMinutes;
    if (minutes <= 0 || minutes > 16 * 60) return null;
    return minutes;
  }

  double? _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  String _formatDateTime(DateTime? value) {
    if (value == null) return 'Not recorded yet';
    final hour = value.hour > 12
        ? value.hour - 12
        : value.hour == 0
        ? 12
        : value.hour;
    final minute = value.minute.toString().padLeft(2, '0');
    final period = value.hour >= 12 ? 'PM' : 'AM';
    return '${value.day}/${value.month}/${value.year} $hour:$minute $period';
  }

  String _formatDuration(int minutes) {
    final hours = minutes ~/ 60;
    final rest = minutes % 60;
    if (hours == 0) return '$rest min';
    if (rest == 0) return '$hours hr';
    return '$hours hr $rest min';
  }

  String _statusLabel(String status) {
    return status
        .split('_')
        .where((part) => part.isNotEmpty)
        .map((part) => part[0].toUpperCase() + part.substring(1))
        .join(' ');
  }

  String _paymentLabel(String status) {
    if (status.trim().isEmpty) return 'Payment Not Started';
    return _statusLabel(status);
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'confirmed':
      case 'accepted':
        return WorkableDesign.accent;
      case 'pending':
        return WorkableDesign.warning;
      case 'completion_requested':
        return WorkableDesign.warning;
      case 'payment_due':
      case 'payment_initiated':
      case 'payment_under_review':
        return WorkableDesign.primary;
      case 'cancelled':
      case 'rejected':
        return WorkableDesign.danger;
      case 'completed':
      case 'paid':
        return WorkableDesign.success;
      default:
        return WorkableDesign.muted;
    }
  }

  Color _paymentColor(String status) {
    switch (status.toLowerCase()) {
      case 'paid':
      case 'completed':
        return WorkableDesign.success;
      case 'cash_pending_confirmation':
      case 'payment_under_review':
      case 'customer_reported_paid':
        return WorkableDesign.warning;
      case 'rejected':
        return WorkableDesign.danger;
      case 'not_started':
      default:
        return WorkableDesign.primary;
    }
  }

  void _showUploadPanAadhaarDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Verification Required'),
        content: const Text(
          'To accept a job, upload your PAN card and Aadhaar card first.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/identity-verification');
            },
            child: const Text('Go to Verification'),
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

class _DetailRow extends StatelessWidget {
  const _DetailRow({
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
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: WorkableDesign.primary),
          const SizedBox(width: 10),
          SizedBox(
            width: 82,
            child: Text(
              label,
              style: const TextStyle(
                color: WorkableDesign.muted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: WorkableDesign.ink,
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
