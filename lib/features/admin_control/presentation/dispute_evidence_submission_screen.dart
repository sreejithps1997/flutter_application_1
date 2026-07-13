import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:workable/core/theme/workable_design.dart';
import 'package:workable/widgets/workable_ui.dart';

import '../domain/dispute_evidence_case.dart';
import 'admin_control_providers.dart';

class DisputeEvidenceSubmissionScreen extends ConsumerStatefulWidget {
  static const routeName = '/dispute-evidence-submission';

  const DisputeEvidenceSubmissionScreen({super.key});

  @override
  ConsumerState<DisputeEvidenceSubmissionScreen> createState() =>
      _DisputeEvidenceSubmissionScreenState();
}

class _DisputeEvidenceSubmissionScreenState
    extends ConsumerState<DisputeEvidenceSubmissionScreen> {
  final _noteController = TextEditingController();
  final _proofLinksController = TextEditingController();
  final _picker = ImagePicker();
  final List<XFile> _selectedPhotos = [];
  bool _busy = false;

  @override
  void dispose() {
    _noteController.dispose();
    _proofLinksController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final collection = args?['collection']?.toString() ?? '';
    final id = args?['id']?.toString() ?? '';

    if (collection.isEmpty || id.isEmpty) {
      return const Scaffold(
        body: WorkableEmptyState(
          icon: LucideIcons.alertTriangle,
          title: 'Evidence request missing',
          message:
              'Open this page from a booking, help request, or notification.',
        ),
      );
    }

    final evidenceCase = ref.watch(
      disputeEvidenceCaseProvider((collection: collection, id: id)),
    );

    return Scaffold(
      backgroundColor: WorkableDesign.canvas,
      appBar: AppBar(title: const Text('Submit Evidence')),
      body: evidenceCase.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => WorkableEmptyState(
          icon: LucideIcons.alertTriangle,
          title: 'Unable to open evidence request',
          message: error.toString(),
        ),
        data: (item) => _buildForm(item),
      ),
    );
  }

  Widget _buildForm(DisputeEvidenceCase item) {
    return ListView(
      padding: const EdgeInsets.all(WorkableDesign.pagePadding),
      children: [
        WorkablePageHeader(
          title: 'Evidence for ${item.service}',
          subtitle:
              'Submit clear proof so support can resolve the issue fairly.',
          icon: LucideIcons.fileQuestion,
        ),
        const SizedBox(height: 16),
        WorkableSectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              WorkableInfoRow(
                icon: LucideIcons.clipboardList,
                text:
                    'Case type: ${item.isBooking ? 'Booking' : 'Help request'}',
              ),
              WorkableInfoRow(
                icon: LucideIcons.activity,
                text: 'Status: ${_label(item.status)}',
              ),
              WorkableInfoRow(
                icon: LucideIcons.userCheck,
                text: 'Requested from: ${_label(item.requestedFrom)}',
              ),
              if (item.requestNote.isNotEmpty)
                WorkableInfoRow(
                  icon: LucideIcons.messageSquare,
                  text: item.requestNote,
                ),
              if (item.evidenceStatus.isNotEmpty)
                WorkableInfoRow(
                  icon: LucideIcons.badgeCheck,
                  text: 'Evidence status: ${_label(item.evidenceStatus)}',
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        WorkableSectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Your proof',
                style: TextStyle(
                  color: WorkableDesign.ink,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _noteController,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Notes',
                  hintText:
                      'Explain what happened, payment status, work proof, or issue details.',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _proofLinksController,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Proof links',
                  hintText:
                      'Paste photo/video/payment proof links, one per line.',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _busy ? null : _pickPhotos,
                icon: const Icon(LucideIcons.imagePlus, size: 18),
                label: Text(
                  _selectedPhotos.isEmpty
                      ? 'Add Photos'
                      : '${_selectedPhotos.length} photo${_selectedPhotos.length == 1 ? '' : 's'} selected',
                ),
              ),
              if (_selectedPhotos.isNotEmpty) ...[
                const SizedBox(height: 8),
                WorkableInfoRow(
                  icon: LucideIcons.image,
                  text: _selectedPhotos.map((file) => file.name).join(', '),
                ),
              ],
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _busy ? null : () => _submit(item),
                  icon: const Icon(LucideIcons.send, size: 18),
                  label: Text(_busy ? 'Submitting...' : 'Submit Evidence'),
                ),
              ),
            ],
          ),
        ),
        if (item.submissionNote.isNotEmpty || item.proofLinks.isNotEmpty) ...[
          const SizedBox(height: 12),
          WorkableSectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Last submitted evidence',
                  style: TextStyle(
                    color: WorkableDesign.ink,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (item.submissionNote.isNotEmpty)
                  WorkableInfoRow(
                    icon: LucideIcons.messageSquare,
                    text: item.submissionNote,
                  ),
                ...item.proofLinks.map(
                  (link) => WorkableInfoRow(icon: LucideIcons.link, text: link),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _submit(DisputeEvidenceCase item) async {
    setState(() => _busy = true);
    try {
      final links = _proofLinksController.text
          .split('\n')
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty)
          .toList();
      final repository = ref.read(disputeEvidenceRepositoryProvider);
      final uploadedLinks = _selectedPhotos.isEmpty
          ? <String>[]
          : await repository.uploadEvidenceFiles(
              item: item,
              files: _selectedPhotos,
            );
      await repository.submitEvidence(
        item: item,
        note: _noteController.text,
        proofLinks: [...links, ...uploadedLinks],
      );
      ref.invalidate(
        disputeEvidenceCaseProvider((collection: item.collection, id: item.id)),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Evidence submitted. Support can now review it.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to submit evidence: $error'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: WorkableDesign.danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickPhotos() async {
    final photos = await _picker.pickMultiImage(imageQuality: 78);
    if (photos.isEmpty) return;
    setState(() {
      _selectedPhotos
        ..clear()
        ..addAll(photos.take(6));
    });
  }

  String _label(String value) {
    if (value.trim().isEmpty) return 'Not recorded';
    return value.replaceAll('_', ' ');
  }
}
