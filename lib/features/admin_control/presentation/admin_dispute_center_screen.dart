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

  Future<void> _requestEvidence() async {
    final result = await showDialog<_EvidenceRequestDraft>(
      context: context,
      builder: (_) => const _EvidenceRequestDialog(),
    );
    if (result == null) return;

    setState(() => _busy = true);
    try {
      await ref
          .read(adminControlRepositoryProvider)
          .requestEvidence(
            item: widget.item,
            requestedFrom: result.requestedFrom,
            requestNote: result.note,
          );
      if (!mounted) return;
      _showSnack('Evidence requested from ${result.requestedFrom}.');
    } catch (error) {
      if (!mounted) return;
      _showSnack('Unable to request evidence: $error', isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _flagRisk() async {
    final result = await showDialog<_RiskFlagDraft>(
      context: context,
      builder: (_) => const _RiskFlagDialog(),
    );
    if (result == null) return;

    setState(() => _busy = true);
    try {
      await ref
          .read(adminControlRepositoryProvider)
          .flagRisk(
            item: widget.item,
            riskFlag: result.flag,
            note: result.note,
          );
      if (!mounted) return;
      _showSnack('Risk flag added.');
    } catch (error) {
      if (!mounted) return;
      _showSnack('Unable to flag risk: $error', isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resolveDispute() async {
    final result = await showDialog<_ResolutionDraft>(
      context: context,
      builder: (_) => const _ResolutionDialog(),
    );
    if (result == null) return;

    setState(() => _busy = true);
    try {
      await ref
          .read(adminControlRepositoryProvider)
          .resolveDispute(
            item: widget.item,
            decision: result.decision,
            note: result.note,
            creditAmount: result.creditAmount,
          );
      if (!mounted) return;
      _showSnack('Dispute resolved.');
    } catch (error) {
      if (!mounted) return;
      _showSnack('Unable to resolve dispute: $error', isError: true);
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
                if (item.evidenceStatus.isNotEmpty)
                  WorkableStatusPill(
                    label: 'Evidence: ${_label(item.evidenceStatus)}',
                    color: WorkableDesign.warning,
                    icon: LucideIcons.fileQuestion,
                  ),
                if (item.resolutionStatus.isNotEmpty)
                  WorkableStatusPill(
                    label: 'Resolved: ${_label(item.resolutionStatus)}',
                    color: WorkableDesign.success,
                    icon: LucideIcons.badgeCheck,
                  ),
                if (item.riskFlags.isNotEmpty)
                  WorkableStatusPill(
                    label: '${item.riskFlags.length} risk flag',
                    color: WorkableDesign.danger,
                    icon: LucideIcons.flag,
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
            if (item.riskFlags.isNotEmpty)
              WorkableInfoRow(
                icon: LucideIcons.flag,
                text: 'Risk flags: ${item.riskFlags.map(_label).join(', ')}',
              ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _ActionButton(
                  onPressed: _busy ? null : _markUnderReview,
                  icon: LucideIcons.eye,
                  label: 'Under Review',
                  outlined: true,
                ),
                _ActionButton(
                  onPressed: _busy ? null : _requestEvidence,
                  icon: LucideIcons.fileQuestion,
                  label: 'Evidence',
                  outlined: true,
                ),
                _ActionButton(
                  onPressed: _busy ? null : _flagRisk,
                  icon: LucideIcons.flag,
                  label: 'Risk Flag',
                  outlined: true,
                ),
                _ActionButton(
                  onPressed: _busy ? null : _addNote,
                  icon: LucideIcons.messageSquare,
                  label: _busy ? 'Saving...' : 'Note',
                ),
                _ActionButton(
                  onPressed: _busy ? null : _resolveDispute,
                  icon: LucideIcons.checkCircle2,
                  label: 'Resolve',
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

  String _label(String value) => value.replaceAll('_', ' ');
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.onPressed,
    required this.icon,
    required this.label,
    this.outlined = false,
  });

  final VoidCallback? onPressed;
  final IconData icon;
  final String label;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    final child = Row(
      mainAxisSize: MainAxisSize.min,
      children: [Icon(icon, size: 18), const SizedBox(width: 8), Text(label)],
    );
    if (outlined) {
      return OutlinedButton(onPressed: onPressed, child: child);
    }
    return FilledButton(onPressed: onPressed, child: child);
  }
}

class _EvidenceRequestDraft {
  const _EvidenceRequestDraft({
    required this.requestedFrom,
    required this.note,
  });

  final String requestedFrom;
  final String note;
}

class _EvidenceRequestDialog extends StatefulWidget {
  const _EvidenceRequestDialog();

  @override
  State<_EvidenceRequestDialog> createState() => _EvidenceRequestDialogState();
}

class _EvidenceRequestDialogState extends State<_EvidenceRequestDialog> {
  String _requestedFrom = 'customer';
  final _noteController = TextEditingController();

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Request Evidence'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<String>(
            value: _requestedFrom,
            decoration: const InputDecoration(
              labelText: 'Request from',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: 'customer', child: Text('Customer')),
              DropdownMenuItem(value: 'worker', child: Text('Worker')),
              DropdownMenuItem(value: 'both', child: Text('Both')),
            ],
            onChanged: (value) {
              if (value != null) setState(() => _requestedFrom = value);
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _noteController,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Evidence needed',
              hintText: 'Photos, payment proof, work proof, invoice, notes...',
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
            final note = _noteController.text.trim();
            if (note.isEmpty) return;
            Navigator.pop(
              context,
              _EvidenceRequestDraft(requestedFrom: _requestedFrom, note: note),
            );
          },
          child: const Text('Request'),
        ),
      ],
    );
  }
}

class _RiskFlagDraft {
  const _RiskFlagDraft({required this.flag, required this.note});

  final String flag;
  final String note;
}

class _RiskFlagDialog extends StatefulWidget {
  const _RiskFlagDialog();

  @override
  State<_RiskFlagDialog> createState() => _RiskFlagDialogState();
}

class _RiskFlagDialogState extends State<_RiskFlagDialog> {
  String _flag = 'fake_payment_report';
  final _noteController = TextEditingController();

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Flag Risk'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<String>(
            value: _flag,
            decoration: const InputDecoration(
              labelText: 'Risk type',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(
                value: 'fake_payment_report',
                child: Text('Fake payment report'),
              ),
              DropdownMenuItem(
                value: 'repeated_cancellation',
                child: Text('Repeated cancellation'),
              ),
              DropdownMenuItem(
                value: 'suspicious_start_override',
                child: Text('Suspicious start override'),
              ),
              DropdownMenuItem(
                value: 'repeat_dispute_pattern',
                child: Text('Repeat dispute pattern'),
              ),
              DropdownMenuItem(
                value: 'outside_payment_attempt',
                child: Text('Outside payment attempt'),
              ),
              DropdownMenuItem(
                value: 'referral_abuse',
                child: Text('Referral abuse'),
              ),
            ],
            onChanged: (value) {
              if (value != null) setState(() => _flag = value);
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _noteController,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Reason',
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
            final note = _noteController.text.trim();
            if (note.isEmpty) return;
            Navigator.pop(context, _RiskFlagDraft(flag: _flag, note: note));
          },
          child: const Text('Flag'),
        ),
      ],
    );
  }
}

class _ResolutionDraft {
  const _ResolutionDraft({
    required this.decision,
    required this.note,
    this.creditAmount,
  });

  final String decision;
  final String note;
  final double? creditAmount;
}

class _ResolutionDialog extends StatefulWidget {
  const _ResolutionDialog();

  @override
  State<_ResolutionDialog> createState() => _ResolutionDialogState();
}

class _ResolutionDialogState extends State<_ResolutionDialog> {
  String _decision = 'customer_favor';
  final _noteController = TextEditingController();
  final _creditController = TextEditingController();

  @override
  void dispose() {
    _noteController.dispose();
    _creditController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isPartialCredit = _decision == 'partial_credit';
    return AlertDialog(
      title: const Text('Resolve Dispute'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<String>(
            value: _decision,
            decoration: const InputDecoration(
              labelText: 'Decision',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(
                value: 'customer_favor',
                child: Text('Customer favor'),
              ),
              DropdownMenuItem(
                value: 'worker_favor',
                child: Text('Worker favor'),
              ),
              DropdownMenuItem(
                value: 'partial_credit',
                child: Text('Partial refund / credit'),
              ),
            ],
            onChanged: (value) {
              if (value != null) setState(() => _decision = value);
            },
          ),
          if (isPartialCredit) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _creditController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Credit amount',
                prefixText: 'Rs. ',
                border: OutlineInputBorder(),
              ),
            ),
          ],
          const SizedBox(height: 12),
          TextField(
            controller: _noteController,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Resolution reason',
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
            final note = _noteController.text.trim();
            if (note.isEmpty) return;
            final creditAmount = isPartialCredit
                ? double.tryParse(_creditController.text.trim())
                : null;
            if (isPartialCredit &&
                (creditAmount == null || creditAmount <= 0)) {
              return;
            }
            Navigator.pop(
              context,
              _ResolutionDraft(
                decision: _decision,
                note: note,
                creditAmount: creditAmount,
              ),
            );
          },
          child: const Text('Resolve'),
        ),
      ],
    );
  }
}
