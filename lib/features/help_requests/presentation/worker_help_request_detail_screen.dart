import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/workable_design.dart';
import '../../../screens/worker_job_details_screen.dart';
import '../../../widgets/workable_ui.dart';
import '../domain/help_request.dart';
import 'help_request_providers.dart';

class WorkerHelpRequestDetailScreen extends ConsumerStatefulWidget {
  const WorkerHelpRequestDetailScreen({super.key, this.requestId});

  static const routeName = '/worker/help-request-detail';

  final String? requestId;

  @override
  ConsumerState<WorkerHelpRequestDetailScreen> createState() =>
      _WorkerHelpRequestDetailScreenState();
}

class _WorkerHelpRequestDetailScreenState
    extends ConsumerState<WorkerHelpRequestDetailScreen> {
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
        title: const Text('Help Job Details'),
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
          subtitle: 'Manage this accepted help job from start to payment.',
          icon: Icons.volunteer_activism_outlined,
          trailing: WorkableStatusPill(
            label: _label(request.status),
            color: _statusColor(request.status),
          ),
        ),
        const SizedBox(height: 16),
        _InfoCard(
          title: 'Customer',
          rows: [
            _InfoRow(Icons.person_outline, request.customerName),
            _InfoRow(
              Icons.phone_outlined,
              request.customerPhone.isEmpty
                  ? 'Phone not shared'
                  : request.customerPhone,
            ),
          ],
        ),
        const SizedBox(height: 14),
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
    final cashPending = request.paymentStatus == 'cash_pending_confirmation';

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
                  'This help request is linked to a booking. Use the booking job screen for work status, completion, cash, and UPI payment flow.',
            ),
            const SizedBox(height: 12),
            _button(
              label: 'Open Job Details',
              icon: Icons.open_in_new,
              onPressed: () => Navigator.pushNamed(
                context,
                WorkerJobDetailsScreen.routeName,
                arguments: request.linkedBookingId,
              ),
            ),
          ] else if (cashPending) ...[
            const WorkableInfoRow(
              icon: Icons.payments_outlined,
              text: 'Confirm only after you receive cash from the customer.',
            ),
            const SizedBox(height: 12),
            _button(
              label: 'Confirm Cash Received',
              icon: Icons.check_circle_outline,
              onPressed: () => _run(
                () => ref
                    .read(helpRequestRepositoryProvider)
                    .confirmCashReceived(request.id),
                'Cash payment confirmed.',
              ),
            ),
          ] else if (status == 'accepted') ...[
            _button(
              label: 'Start Work',
              icon: Icons.play_arrow_rounded,
              onPressed: () => _run(
                () => ref
                    .read(helpRequestRepositoryProvider)
                    .startHelpRequest(request.id),
                'Help job started.',
              ),
            ),
          ] else if (status == 'in_progress') ...[
            _button(
              label: 'Request Completion',
              icon: Icons.task_alt_outlined,
              onPressed: () => _run(
                () => ref
                    .read(helpRequestRepositoryProvider)
                    .requestCompletion(request.id),
                'Completion request sent.',
              ),
            ),
          ] else ...[
            WorkableInfoRow(
              icon: Icons.info_outline,
              text: 'No worker action is available for ${_label(status)}.',
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
  }) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
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
