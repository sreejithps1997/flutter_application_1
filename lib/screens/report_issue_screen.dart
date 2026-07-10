import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../core/theme/workable_design.dart';
import '../widgets/workable_ui.dart';

class ReportIssueScreen extends StatefulWidget {
  static const routeName = '/report-issue';

  const ReportIssueScreen({super.key});

  @override
  State<ReportIssueScreen> createState() => _ReportIssueScreenState();
}

class _ReportIssueScreenState extends State<ReportIssueScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _bookingIdController = TextEditingController();

  final List<String> _issueTypes = const [
    'Booking problem',
    'Payment issue',
    'Worker behavior',
    'Fake profile',
    'App bug',
    'Safety concern',
    'Other',
  ];

  String _selectedIssueType = 'Booking problem';
  File? _selectedImage;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _descriptionController.dispose();
    _bookingIdController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );
    if (picked != null) {
      setState(() => _selectedImage = File(picked.path));
    }
  }

  Future<void> _submitIssue() async {
    if (!_formKey.currentState!.validate() || _isSubmitting) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showSnack('Please sign in to report an issue.');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await FirebaseFirestore.instance.collection('reported_issues').add({
        'userId': user.uid,
        'userEmail': user.email,
        'issueType': _selectedIssueType,
        'description': _descriptionController.text.trim(),
        'bookingId': _bookingIdController.text.trim(),
        'hasLocalAttachment': _selectedImage != null,
        'status': 'open',
        'priority': _selectedIssueType == 'Safety concern' ? 'high' : 'normal',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      _showSnack('Issue reported. Our team will review it.');
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      _showSnack('Could not submit issue. Please try again.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WorkableDesign.canvas,
      appBar: AppBar(
        title: const Text('Report Issue'),
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(WorkableDesign.pagePadding),
          child: Column(
            children: [
              const WorkablePageHeader(
                title: 'Tell us what went wrong',
                subtitle:
                    'Report safety, payment, booking, or app issues so the support team can act with context.',
                icon: LucideIcons.alertTriangle,
              ),
              const SizedBox(height: 16),
              WorkableSectionCard(
                child: Form(
                  key: _formKey,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DropdownButtonFormField<String>(
                        value: _selectedIssueType,
                        decoration: const InputDecoration(
                          labelText: 'Issue type',
                        ),
                        items: _issueTypes
                            .map(
                              (type) => DropdownMenuItem(
                                value: type,
                                child: Text(type),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _selectedIssueType = value);
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _bookingIdController,
                        decoration: const InputDecoration(
                          labelText: 'Booking ID (optional)',
                          prefixIcon: Icon(LucideIcons.hash),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _descriptionController,
                        minLines: 4,
                        maxLines: 6,
                        decoration: const InputDecoration(
                          labelText: 'Describe the issue',
                          alignLabelWithHint: true,
                        ),
                        validator: (value) {
                          final text = value?.trim() ?? '';
                          if (text.length < 15) {
                            return 'Please add at least 15 characters.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      if (_selectedImage != null) ...[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(
                            WorkableDesign.radius,
                          ),
                          child: Image.file(
                            _selectedImage!,
                            height: 140,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],
                      OutlinedButton.icon(
                        onPressed: _pickImage,
                        icon: const Icon(LucideIcons.imagePlus),
                        label: Text(
                          _selectedImage == null
                              ? 'Attach Screenshot'
                              : 'Change Screenshot',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _buildSafetyNote(),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: _isSubmitting ? null : _submitIssue,
                icon: _isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(LucideIcons.send),
                label: Text(_isSubmitting ? 'Submitting...' : 'Submit Issue'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSafetyNote() {
    return WorkableSectionCard(
      color: _selectedIssueType == 'Safety concern'
          ? WorkableDesign.danger.withValues(alpha: 0.06)
          : WorkableDesign.primary.withValues(alpha: 0.06),
      borderColor: _selectedIssueType == 'Safety concern'
          ? WorkableDesign.danger.withValues(alpha: 0.18)
          : WorkableDesign.primary.withValues(alpha: 0.18),
      child: WorkableInfoRow(
        icon: _selectedIssueType == 'Safety concern'
            ? LucideIcons.shieldAlert
            : LucideIcons.info,
        text: _selectedIssueType == 'Safety concern'
            ? 'Safety reports are marked high priority for support review.'
            : 'Screenshots are kept on this device for now; the report stores the issue details for admin review.',
      ),
    );
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }
}
