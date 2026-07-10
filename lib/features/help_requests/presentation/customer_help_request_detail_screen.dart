import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/workable_design.dart';
import '../../../screens/customer_booking_detail_screen.dart';
import '../../../widgets/workable_ui.dart';
import '../domain/help_request.dart';
import 'help_request_providers.dart';

class CustomerHelpRequestDetailScreen extends ConsumerStatefulWidget {
  const CustomerHelpRequestDetailScreen({super.key, this.requestId});

  static const routeName = '/customer/help-request-detail';

  final String? requestId;

  @override
  ConsumerState<CustomerHelpRequestDetailScreen> createState() =>
      _CustomerHelpRequestDetailScreenState();
}

class _CustomerHelpRequestDetailScreenState
    extends ConsumerState<CustomerHelpRequestDetailScreen> {
  bool _isActing = false;

  @override
  Widget build(BuildContext context) {
    final requestId = _requestId(context);
    if (requestId.isEmpty) {
      return const Scaffold(
        body: WorkableEmptyState(
          icon: Icons.help_outline,
          title: 'Request not found',
          message: 'This help request could not be opened.',
        ),
      );
    }

    final request = ref.watch(helpRequestProvider(requestId));

    return Scaffold(
      backgroundColor: WorkableDesign.canvas,
      appBar: AppBar(
        title: const Text('Help Request'),
        backgroundColor: WorkableDesign.surface,
        foregroundColor: WorkableDesign.ink,
      ),
      body: request.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => WorkableEmptyState(
          icon: Icons.warning_amber_outlined,
          title: 'Unable to load request',
          message: error.toString(),
        ),
        data: (item) {
          if (item == null) {
            return const WorkableEmptyState(
              icon: Icons.help_outline,
              title: 'Request not found',
              message: 'This help request may have been removed.',
            );
          }
          return _buildDetails(item);
        },
      ),
    );
  }

  Widget _buildDetails(HelpRequest request) {
    return ListView(
      padding: const EdgeInsets.all(WorkableDesign.pagePadding),
      children: [
        WorkablePageHeader(
          title: request.title,
          subtitle: 'Track worker response, completion, and payment status.',
          icon: Icons.handshake_outlined,
          trailing: WorkableStatusPill(
            label: _label(request.status),
            color: _statusColor(request.status),
          ),
        ),
        const SizedBox(height: 16),
        _InfoCard(
          title: 'Request',
          rows: [
            _InfoRow(Icons.category_outlined, request.requestType),
            _InfoRow(Icons.description_outlined, request.description),
            _InfoRow(Icons.schedule_outlined, request.timeLabel),
            _InfoRow(Icons.location_on_outlined, request.pickupAddress),
            if (request.destinationAddress.isNotEmpty)
              _InfoRow(Icons.flag_outlined, request.destinationAddress),
            if (request.budget != null)
              _InfoRow(
                Icons.currency_rupee,
                'Budget: Rs ${request.budget!.toStringAsFixed(0)}',
              ),
          ],
        ),
        const SizedBox(height: 14),
        _InfoCard(
          title: 'Worker',
          rows: [
            _InfoRow(Icons.person_outline, request.workerName),
            _InfoRow(
              Icons.phone_outlined,
              request.workerPhone.isEmpty
                  ? 'Worker phone not shared yet'
                  : request.workerPhone,
            ),
          ],
        ),
        const SizedBox(height: 14),
        _InfoCard(
          title: 'Payment',
          rows: [
            _InfoRow(Icons.payments_outlined, _label(request.paymentStatus)),
            if (request.linkedBookingId.isNotEmpty)
              _InfoRow(Icons.receipt_long_outlined, 'Booking linked'),
          ],
        ),
        const SizedBox(height: 14),
        _actionCard(request),
      ],
    );
  }

  Widget _actionCard(HelpRequest request) {
    final status = request.status;
    final paymentStatus = request.paymentStatus;

    return WorkableSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Next action',
            style: TextStyle(
              color: WorkableDesign.ink,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          if (request.linkedBookingId.isNotEmpty) ...[
            const WorkableInfoRow(
              icon: Icons.open_in_new,
              text:
                  'This help request is linked to a booking. Use booking details for completion confirmation, UPI, cash, review, and support.',
            ),
            const SizedBox(height: 12),
            _button(
              label: 'Open Booking Details',
              icon: Icons.open_in_new,
              onPressed: () => _openLinkedBooking(request.linkedBookingId),
            ),
          ] else if (status == 'completion_requested') ...[
            const WorkableInfoRow(
              icon: Icons.fact_check_outlined,
              text:
                  'Confirm only after the worker has completed the requested help.',
            ),
            const SizedBox(height: 12),
            _button(
              label: 'Confirm Work Completed',
              icon: Icons.check_circle_outline,
              onPressed: () => _run(
                () => ref
                    .read(helpRequestRepositoryProvider)
                    .confirmCompletion(request.id),
                'Work completion confirmed.',
              ),
            ),
          ] else if (status == 'payment_due') ...[
            const WorkableInfoRow(
              icon: Icons.payments_outlined,
              text:
                  'Cash payment is available now. UPI for help requests will reuse the booking payment engine in the next pass.',
            ),
            const SizedBox(height: 12),
            _button(
              label: 'I Will Pay Cash',
              icon: Icons.payments_outlined,
              onPressed: () => _run(
                () => ref
                    .read(helpRequestRepositoryProvider)
                    .markCashPending(request.id),
                'Cash payment marked for worker confirmation.',
              ),
            ),
          ] else if (paymentStatus == 'cash_pending_confirmation') ...[
            const WorkableInfoRow(
              icon: Icons.hourglass_top_outlined,
              text:
                  'Waiting for the worker to confirm cash received. The request completes after confirmation.',
            ),
          ] else if (status == 'open' || status == 'accepted') ...[
            _button(
              label: 'Cancel Request',
              icon: Icons.cancel_outlined,
              onPressed: () => _run(
                () => ref
                    .read(helpRequestRepositoryProvider)
                    .cancelHelpRequest(request.id),
                'Help request cancelled.',
              ),
              danger: true,
            ),
          ] else ...[
            WorkableInfoRow(
              icon: Icons.info_outline,
              text: 'No customer action is available for ${_label(status)}.',
            ),
          ],
        ],
      ),
    );
  }

  Widget _button({
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
    bool danger = false,
  }) {
    return SizedBox(
      width: double.infinity,
      child: danger
          ? OutlinedButton.icon(
              onPressed: _isActing ? null : onPressed,
              icon: Icon(icon),
              label: Text(_isActing ? 'Updating...' : label),
            )
          : FilledButton.icon(
              onPressed: _isActing ? null : onPressed,
              icon: Icon(icon),
              label: Text(_isActing ? 'Updating...' : label),
            ),
    );
  }

  Future<void> _run(Future<void> Function() action, String message) async {
    if (_isActing) return;
    setState(() => _isActing = true);
    try {
      await action();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _isActing = false);
    }
  }

  Future<void> _openLinkedBooking(String bookingId) async {
    if (_isActing) return;
    setState(() => _isActing = true);
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('bookings')
          .doc(bookingId)
          .get();
      final booking = snapshot.data();
      if (booking == null) {
        throw StateError('Linked booking was not found.');
      }
      if (!mounted) return;
      Navigator.pushNamed(
        context,
        CustomerBookingDetailScreen.routeName,
        arguments: {'id': snapshot.id, ...booking},
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _isActing = false);
    }
  }

  String _requestId(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments;
    if (widget.requestId != null) return widget.requestId!.trim();
    if (args is String) return args.trim();
    if (args is Map && args['requestId'] != null) {
      return args['requestId'].toString().trim();
    }
    return '';
  }

  String _label(String value) {
    if (value.trim().isEmpty) return 'Not Started';
    return value
        .split('_')
        .where((part) => part.isNotEmpty)
        .map((part) => part[0].toUpperCase() + part.substring(1))
        .join(' ');
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'accepted':
      case 'in_progress':
        return WorkableDesign.success;
      case 'completion_requested':
      case 'payment_due':
      case 'payment_under_review':
        return WorkableDesign.primary;
      case 'cancelled':
      case 'rejected':
        return WorkableDesign.danger;
      case 'completed':
      case 'paid':
        return WorkableDesign.success;
      default:
        return WorkableDesign.warning;
    }
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.title, required this.rows});

  final String title;
  final List<_InfoRow> rows;

  @override
  Widget build(BuildContext context) {
    return WorkableSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: WorkableDesign.ink,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          ...rows.where((row) => row.text.trim().isNotEmpty).map((row) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: WorkableInfoRow(icon: row.icon, text: row.text),
            );
          }),
        ],
      ),
    );
  }
}

class _InfoRow {
  const _InfoRow(this.icon, this.text);

  final IconData icon;
  final String text;
}
