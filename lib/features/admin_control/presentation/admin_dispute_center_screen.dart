import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:workable/core/theme/workable_design.dart';
import 'package:workable/widgets/workable_ui.dart';

import '../domain/admin_dispute_item.dart';
import 'admin_control_providers.dart';

class AdminDisputeCenterScreen extends ConsumerWidget {
  static const routeName = '/admin-dispute-center';

  const AdminDisputeCenterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final disputes = ref.watch(adminDisputesProvider);
    return Scaffold(
      backgroundColor: WorkableDesign.canvas,
      appBar: AppBar(
        title: const Text('Dispute Center'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: () => ref.invalidate(adminDisputesProvider),
            icon: const Icon(LucideIcons.refreshCw),
          ),
        ],
      ),
      body: disputes.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => WorkableEmptyState(
          icon: LucideIcons.alertTriangle,
          title: 'Unable to load disputes',
          message: error.toString(),
        ),
        data: (items) {
          if (items.isEmpty) {
            return const WorkableEmptyState(
              icon: LucideIcons.shieldCheck,
              title: 'No disputes right now',
              message:
                  'Completion disputes, payment disputes, and help issues will appear here.',
            );
          }
          return ListView(
            padding: const EdgeInsets.all(WorkableDesign.pagePadding),
            children: [
              WorkablePageHeader(
                title:
                    '${items.length} open issue${items.length == 1 ? '' : 's'}',
                subtitle:
                    'Review disputed bookings and help requests from one operational screen.',
                icon: LucideIcons.alertTriangle,
              ),
              const SizedBox(height: 16),
              ...items.map((item) => _DisputeCard(item: item)),
            ],
          );
        },
      ),
    );
  }
}

class _DisputeCard extends ConsumerStatefulWidget {
  const _DisputeCard({required this.item});

  final AdminDisputeItem item;

  @override
  ConsumerState<_DisputeCard> createState() => _DisputeCardState();
}

class _DisputeCardState extends ConsumerState<_DisputeCard> {
  final _currency = NumberFormat.currency(locale: 'en_IN', symbol: 'Rs. ');
  final _dateFormat = DateFormat('dd MMM yyyy, h:mm a');
  bool _busy = false;

  Future<void> _markUnderReview() async {
    setState(() => _busy = true);
    try {
      await ref
          .read(adminControlRepositoryProvider)
          .markDisputeUnderReview(widget.item);
      if (!mounted) return;
      _showSnack('Marked under review.');
    } catch (error) {
      if (!mounted) return;
      _showSnack('Unable to update review state: $error', isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _addNote() async {
    final controller = TextEditingController(text: widget.item.adminNote);
    final note = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Admin Note'),
        content: TextField(
          controller: controller,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: 'Write internal dispute note',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (note == null || note.trim().isEmpty) return;

    setState(() => _busy = true);
    try {
      await ref
          .read(adminControlRepositoryProvider)
          .saveDisputeNote(widget.item, note);
      if (!mounted) return;
      _showSnack('Admin note saved.');
    } catch (error) {
      if (!mounted) return;
      _showSnack('Unable to save note: $error', isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
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
                    item.service,
                    style: const TextStyle(
                      color: WorkableDesign.ink,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                WorkableStatusPill(
                  label: item.typeLabel,
                  color: item.isHelpRequest
                      ? WorkableDesign.accent
                      : WorkableDesign.primary,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                WorkableStatusPill(
                  label: item.displayStatus,
                  color: _statusColor(item),
                  icon: LucideIcons.alertTriangle,
                ),
                if (item.amount > 0)
                  WorkableStatusPill(
                    label: _currency.format(item.amount),
                    color: WorkableDesign.success,
                    icon: LucideIcons.wallet,
                  ),
              ],
            ),
            const SizedBox(height: 10),
            WorkableInfoRow(
              icon: LucideIcons.user,
              text:
                  'Customer: ${item.customerName} | Worker: ${item.workerName}',
            ),
            if (item.issue.isNotEmpty)
              WorkableInfoRow(icon: LucideIcons.fileText, text: item.issue),
            if (item.updatedAt != null)
              WorkableInfoRow(
                icon: LucideIcons.clock,
                text: 'Updated: ${_dateFormat.format(item.updatedAt!)}',
              ),
            if (item.adminNote.isNotEmpty)
              WorkableInfoRow(
                icon: LucideIcons.messageSquare,
                text: 'Admin note: ${item.adminNote}',
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : _markUnderReview,
                    icon: const Icon(LucideIcons.eye, size: 18),
                    label: const Text('Under Review'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _busy ? null : _addNote,
                    icon: const Icon(LucideIcons.messageSquare, size: 18),
                    label: Text(_busy ? 'Saving...' : 'Add Note'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _statusColor(AdminDisputeItem item) {
    if (item.paymentStatus == 'payment_under_review' ||
        item.status == 'payment_under_review') {
      return WorkableDesign.warning;
    }
    if (item.status.contains('disputed') || item.paymentStatus == 'disputed') {
      return WorkableDesign.danger;
    }
    return WorkableDesign.primary;
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
}
