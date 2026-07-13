import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:workable/core/theme/workable_design.dart';
import 'package:workable/features/bookings/data/booking_action_repository.dart';
import 'package:workable/widgets/workable_ui.dart';

class AdminWorkStartOverrideScreen extends StatefulWidget {
  static const routeName = '/admin-work-start-override';

  const AdminWorkStartOverrideScreen({super.key});

  @override
  State<AdminWorkStartOverrideScreen> createState() =>
      _AdminWorkStartOverrideScreenState();
}

class _AdminWorkStartOverrideScreenState
    extends State<AdminWorkStartOverrideScreen> {
  final _dateFormat = DateFormat('dd MMM yyyy, h:mm a');
  bool _busy = false;

  Stream<QuerySnapshot<Map<String, dynamic>>> _waitingToStart() {
    return FirebaseFirestore.instance
        .collection('bookings')
        .where('status', whereIn: ['confirmed', 'accepted', 'in_progress'])
        .snapshots();
  }

  Future<void> _overrideStart(
    String bookingId,
    Map<String, dynamic> data,
  ) async {
    final reasonController = TextEditingController(
      text: 'Worker reported GPS/network issue.',
    );
    final noteController = TextEditingController();
    final result = await showDialog<({String reason, String note})>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Admin Start Override'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${_text(data, ['customerName'], 'Customer')} - ${_text(data, ['service', 'serviceType'], 'Service')}',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Override reason',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: noteController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Customer confirmation note',
                hintText: 'Example: Customer confirmed by phone at 10:32 AM.',
                border: OutlineInputBorder(),
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
              final reason = reasonController.text.trim();
              final note = noteController.text.trim();
              if (reason.isEmpty || note.isEmpty) return;
              Navigator.pop(context, (reason: reason, note: note));
            },
            child: const Text('Start Work'),
          ),
        ],
      ),
    );
    reasonController.dispose();
    noteController.dispose();
    if (result == null) return;

    setState(() => _busy = true);
    try {
      final adminId = FirebaseAuth.instance.currentUser?.uid ?? 'admin';
      await BookingActionRepository().adminOverrideStartWork(
        bookingId,
        adminId: adminId,
        reason: result.reason,
        customerConfirmationNote: result.note,
      );
      if (!mounted) return;
      _showSnack('Work started with admin override.');
    } catch (error) {
      if (!mounted) return;
      _showSnack(_friendlyError(error), isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WorkableDesign.canvas,
      appBar: AppBar(title: const Text('Work Start Override')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _waitingToStart(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return WorkableEmptyState(
              icon: LucideIcons.alertTriangle,
              title: 'Unable to load jobs',
              message: snapshot.error.toString(),
            );
          }

          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return const WorkableEmptyState(
              icon: LucideIcons.playCircle,
              title: 'No jobs waiting to start',
              message:
                  'Accepted bookings that need customer/admin start support will appear here.',
            );
          }

          return ListView(
            padding: const EdgeInsets.all(WorkableDesign.pagePadding),
            children: [
              const WorkablePageHeader(
                title: 'Manual Start Support',
                subtitle:
                    'Use only after customer confirmation when GPS or network prevents the worker from starting.',
                icon: LucideIcons.shieldCheck,
              ),
              const SizedBox(height: 16),
              ...docs.map(
                (doc) => _OverrideCard(
                  bookingId: doc.id,
                  data: doc.data(),
                  dateFormat: _dateFormat,
                  busy: _busy,
                  onOverride: () => _overrideStart(doc.id, doc.data()),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showSnack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError
            ? WorkableDesign.danger
            : WorkableDesign.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _friendlyError(Object error) {
    final text = error.toString().replaceFirst('Bad state: ', '').trim();
    return text.isEmpty ? 'Unable to start work.' : text;
  }

  static String _text(
    Map<String, dynamic> data,
    List<String> keys,
    String fallback,
  ) {
    for (final key in keys) {
      final value = data[key]?.toString().trim();
      if (value != null && value.isNotEmpty && value.toLowerCase() != 'null') {
        return value;
      }
    }
    return fallback;
  }
}

class _OverrideCard extends StatelessWidget {
  const _OverrideCard({
    required this.bookingId,
    required this.data,
    required this.dateFormat,
    required this.busy,
    required this.onOverride,
  });

  final String bookingId;
  final Map<String, dynamic> data;
  final DateFormat dateFormat;
  final bool busy;
  final VoidCallback onOverride;

  @override
  Widget build(BuildContext context) {
    final createdAt = data['createdAt'];
    final isStarted = _text(['status'], '').toLowerCase() == 'in_progress';
    final isManualStart = data['startWorkManualOverride'] == true;
    final adminOverride = data['adminStartOverride'] == true;
    final startInitiatedBy = _text(['startWorkInitiatedBy'], 'worker');
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: WorkableSectionCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _text(['service', 'serviceType'], 'Service'),
                    style: const TextStyle(
                      color: WorkableDesign.ink,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                WorkableStatusPill(
                  label: _text(['status'], 'accepted'),
                  color: isStarted
                      ? WorkableDesign.success
                      : WorkableDesign.accent,
                ),
              ],
            ),
            const SizedBox(height: 10),
            WorkableInfoRow(
              icon: LucideIcons.user,
              text:
                  'Customer: ${_text(['customerName'], 'Customer')} | Worker: ${_text(['workerName'], 'Worker')}',
            ),
            WorkableInfoRow(
              icon: LucideIcons.mapPin,
              text: _text(['address'], 'Address not saved'),
            ),
            WorkableInfoRow(
              icon: LucideIcons.clock,
              text: createdAt is Timestamp
                  ? 'Created: ${dateFormat.format(createdAt.toDate())}'
                  : 'Booking: $bookingId',
            ),
            if (isManualStart) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: WorkableDesign.warning.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(WorkableDesign.radius),
                  border: Border.all(
                    color: WorkableDesign.warning.withValues(alpha: 0.24),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Manual start audit',
                      style: TextStyle(
                        color: WorkableDesign.ink,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    WorkableInfoRow(
                      icon: LucideIcons.userCheck,
                      text: 'Started by: $startInitiatedBy',
                    ),
                    WorkableInfoRow(
                      icon: LucideIcons.fileText,
                      text:
                          'Reason: ${_text(['startWorkOverrideReason', 'adminStartOverrideReason'], 'Not recorded')}',
                    ),
                    if (adminOverride)
                      WorkableInfoRow(
                        icon: LucideIcons.messageSquare,
                        text:
                            'Customer confirmation: ${_text(['adminStartOverrideCustomerConfirmation'], 'Not recorded')}',
                      ),
                    WorkableInfoRow(
                      icon: LucideIcons.clock,
                      text: _auditTimeLabel(),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            if (!isStarted)
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: busy ? null : onOverride,
                  icon: const Icon(LucideIcons.playCircle, size: 18),
                  label: Text(
                    busy ? 'Updating...' : 'Start After Confirmation',
                  ),
                ),
              )
            else
              const WorkableInfoRow(
                icon: LucideIcons.checkCircle,
                text: 'This booking has already started.',
              ),
          ],
        ),
      ),
    );
  }

  String _text(List<String> keys, String fallback) {
    return _AdminWorkStartOverrideScreenState._text(data, keys, fallback);
  }

  String _auditTimeLabel() {
    for (final key in [
      'adminStartOverrideAt',
      'customerConfirmedWorkerArrivedAt',
      'workStartedAt',
    ]) {
      final value = data[key];
      if (value is Timestamp) {
        return 'Started: ${dateFormat.format(value.toDate())}';
      }
    }
    return 'Started time not recorded';
  }
}
