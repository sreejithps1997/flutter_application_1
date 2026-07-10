import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../core/theme/workable_design.dart';
import '../widgets/workable_ui.dart';

class CustomerRescheduleScreen extends StatefulWidget {
  static const routeName = '/customer-reschedule';

  final String bookingId;

  const CustomerRescheduleScreen({super.key, required this.bookingId});

  @override
  State<CustomerRescheduleScreen> createState() =>
      _CustomerRescheduleScreenState();
}

class _CustomerRescheduleScreenState extends State<CustomerRescheduleScreen> {
  final _formKey = GlobalKey<FormState>();
  final _dateController = TextEditingController();
  final _timeController = TextEditingController();

  bool _isSubmitting = false;
  bool _submitted = false;

  Future<void> _submitReschedule() async {
    if (!_formKey.currentState!.validate() || _isSubmitting) return;

    setState(() => _isSubmitting = true);

    try {
      await FirebaseFirestore.instance
          .collection('bookings')
          .doc(widget.bookingId)
          .update({
            'preferredDate': _dateController.text.trim(),
            'preferredTime': _timeController.text.trim(),
            'status': 'reschedule_requested',
            'rescheduleRequestedAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });

      if (!mounted) return;
      setState(() => _submitted = true);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to submit reschedule request.'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: WorkableDesign.danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 60)),
    );
    if (!mounted || picked == null) return;
    _dateController.text = '${picked.day}/${picked.month}/${picked.year}';
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (!mounted || picked == null) return;
    _timeController.text = picked.format(context);
  }

  @override
  void dispose() {
    _dateController.dispose();
    _timeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_submitted) return _buildSubmittedScreen();

    return Scaffold(
      backgroundColor: WorkableDesign.canvas,
      appBar: AppBar(title: const Text('Reschedule Booking')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(WorkableDesign.pagePadding),
          children: [
            const WorkablePageHeader(
              title: 'Request a new time',
              subtitle:
                  'Choose a preferred date and time. The worker can review the request before the booking changes.',
              icon: LucideIcons.calendarClock,
            ),
            const SizedBox(height: 16),
            WorkableSectionCard(
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _dateController,
                      readOnly: true,
                      onTap: _pickDate,
                      decoration: const InputDecoration(
                        labelText: 'Preferred date',
                        prefixIcon: Icon(LucideIcons.calendar),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Select a date';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _timeController,
                      readOnly: true,
                      onTap: _pickTime,
                      decoration: const InputDecoration(
                        labelText: 'Preferred time',
                        prefixIcon: Icon(LucideIcons.clock),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Select a time';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            const WorkableSectionCard(
              color: WorkableDesign.surface,
              child: WorkableInfoRow(
                icon: LucideIcons.info,
                text:
                    'This sends a reschedule request. The booking remains trackable from booking details.',
              ),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _isSubmitting ? null : _submitReschedule,
              icon: _isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(LucideIcons.send),
              label: Text(_isSubmitting ? 'Submitting...' : 'Submit Request'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubmittedScreen() {
    return Scaffold(
      backgroundColor: WorkableDesign.canvas,
      appBar: AppBar(title: const Text('Request Submitted')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(WorkableDesign.pagePadding),
          children: [
            const WorkablePageHeader(
              title: 'Reschedule requested',
              subtitle:
                  'The worker can review your new preferred date and time.',
              icon: LucideIcons.checkCircle,
            ),
            const SizedBox(height: 16),
            WorkableSectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  WorkableInfoRow(
                    icon: LucideIcons.calendar,
                    text: 'New date: ${_dateController.text}',
                  ),
                  const SizedBox(height: 10),
                  WorkableInfoRow(
                    icon: LucideIcons.clock,
                    text: 'New time: ${_timeController.text}',
                  ),
                  const SizedBox(height: 10),
                  const WorkableInfoRow(
                    icon: LucideIcons.hourglass,
                    text: 'Status: Pending worker review',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: () => Navigator.pop(context, true),
              icon: const Icon(LucideIcons.arrowLeft),
              label: const Text('Back to Booking'),
            ),
          ],
        ),
      ),
    );
  }
}
