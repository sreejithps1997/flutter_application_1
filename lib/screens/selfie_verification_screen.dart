import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../core/theme/workable_design.dart';
import '../models/verification_documents.dart';
import '../services/identity_verification_service.dart';
import '../widgets/workable_ui.dart';

class SelfieVerificationScreen extends StatefulWidget {
  static const routeName = '/selfie-verification';

  const SelfieVerificationScreen({super.key});

  @override
  State<SelfieVerificationScreen> createState() =>
      _SelfieVerificationScreenState();
}

class _SelfieVerificationScreenState extends State<SelfieVerificationScreen> {
  final ImagePicker _picker = ImagePicker();
  final IdentityVerificationService _verificationService =
      IdentityVerificationService();

  String _step = 'instructions';
  File? _capturedImage;
  bool _isUploading = false;
  String _error = '';

  Future<void> _captureSelfie() async {
    setState(() => _error = '');

    try {
      final pickedFile = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        preferredCameraDevice: CameraDevice.front,
      );

      if (pickedFile == null) return;

      setState(() {
        _capturedImage = File(pickedFile.path);
        _step = 'preview';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Camera could not be opened. Please try again.');
    }
  }

  Future<void> _submitSelfie() async {
    if (_capturedImage == null || _isUploading) return;

    setState(() {
      _isUploading = true;
      _error = '';
    });

    try {
      final userData = await _verificationService.loadCurrentUserData();
      await _verificationService.submitVerificationDocument(
        config: VerificationDocuments.selfie,
        uploadMethod: 'camera',
        imageFile: _capturedImage,
        fields: {
          'name': userData['name'] ?? userData['fullName'] ?? '',
          'captureMethod': 'front_camera',
        },
      );

      if (!mounted) return;
      setState(() => _step = 'submitted');
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Selfie upload failed. Please retake and retry.');
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WorkableDesign.canvas,
      appBar: AppBar(
        title: const Text('Selfie Verification'),
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          onPressed: () {
            if (_step == 'preview') {
              setState(() => _step = 'instructions');
            } else {
              Navigator.pop(context, _step == 'submitted');
            }
          },
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(WorkableDesign.pagePadding),
          child: Column(
            children: [
              const WorkablePageHeader(
                title: 'Face match check',
                subtitle:
                    'Capture a clear selfie so the account owner and identity documents can be trusted.',
                icon: LucideIcons.camera,
              ),
              const SizedBox(height: 16),
              _buildStepIndicator(),
              const SizedBox(height: 16),
              WorkableSectionCard(
                child: _step == 'preview'
                    ? _buildPreviewScreen()
                    : _step == 'submitted'
                    ? _buildSubmittedScreen()
                    : _buildInstructionsScreen(),
              ),
              if (_error.isNotEmpty) ...[
                const SizedBox(height: 16),
                _buildErrorCard(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepIndicator() {
    final steps = ['instructions', 'preview', 'submitted'];
    final labels = ['Guide', 'Preview', 'Review'];
    final currentIndex = steps.indexOf(_step);

    return WorkableSectionCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: List.generate(3, (index) {
          final isActive = index == currentIndex;
          final isDone = index < currentIndex;

          return Expanded(
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: isActive || isDone
                        ? WorkableDesign.primary
                        : WorkableDesign.border,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Center(
                    child: isDone
                        ? const Icon(
                            LucideIcons.check,
                            size: 15,
                            color: Colors.white,
                          )
                        : Text(
                            '${index + 1}',
                            style: TextStyle(
                              color: isActive
                                  ? Colors.white
                                  : WorkableDesign.muted,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    labels[index],
                    style: TextStyle(
                      color: isActive || isDone
                          ? WorkableDesign.ink
                          : WorkableDesign.muted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildInstructionsScreen() {
    return Column(
      children: [
        _buildIconTitle(
          icon: LucideIcons.scanFace,
          title: 'Take a live selfie',
          subtitle:
              'Use good lighting, keep your face centered, and remove masks or sunglasses.',
        ),
        const SizedBox(height: 20),
        const WorkableInfoRow(
          icon: LucideIcons.sun,
          text: 'Stand in bright, even lighting.',
        ),
        const SizedBox(height: 10),
        const WorkableInfoRow(
          icon: LucideIcons.eye,
          text: 'Look directly at the camera with your full face visible.',
        ),
        const SizedBox(height: 10),
        const WorkableInfoRow(
          icon: LucideIcons.shieldCheck,
          text: 'Your selfie is only used for account verification review.',
        ),
        const SizedBox(height: 22),
        FilledButton.icon(
          onPressed: _captureSelfie,
          icon: const Icon(LucideIcons.camera),
          label: const Text('Capture Selfie'),
        ),
      ],
    );
  }

  Widget _buildPreviewScreen() {
    return Column(
      children: [
        if (_capturedImage != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(WorkableDesign.radius),
            child: Image.file(
              _capturedImage!,
              height: 360,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
        const SizedBox(height: 16),
        const Text(
          'Confirm your selfie is clear before submitting.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: WorkableDesign.ink,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Blurry, cropped, or dark photos may be rejected by review.',
          textAlign: TextAlign.center,
          style: TextStyle(color: WorkableDesign.muted),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _isUploading ? null : _captureSelfie,
                icon: const Icon(LucideIcons.refreshCw),
                label: const Text('Retake'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                onPressed: _isUploading ? null : _submitSelfie,
                icon: _isUploading
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(LucideIcons.upload),
                label: Text(_isUploading ? 'Submitting...' : 'Submit'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSubmittedScreen() {
    return Column(
      children: [
        _buildIconTitle(
          icon: LucideIcons.checkCircle,
          title: 'Selfie submitted',
          subtitle:
              'Your face match is now under review. Most reviews finish within 2-3 hours.',
          color: WorkableDesign.success,
        ),
        const SizedBox(height: 20),
        const WorkableInfoRow(
          icon: LucideIcons.clock,
          text: 'You can continue using the app while review is pending.',
        ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Back to Verification'),
        ),
      ],
    );
  }

  Widget _buildIconTitle({
    required IconData icon,
    required String title,
    required String subtitle,
    Color color = WorkableDesign.primary,
  }) {
    return Column(
      children: [
        Container(
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(WorkableDesign.radius),
          ),
          child: Icon(icon, color: color, size: 30),
        ),
        const SizedBox(height: 14),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: WorkableDesign.ink,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: const TextStyle(color: WorkableDesign.muted, height: 1.35),
        ),
      ],
    );
  }

  Widget _buildErrorCard() {
    return WorkableSectionCard(
      color: WorkableDesign.danger.withValues(alpha: 0.06),
      borderColor: WorkableDesign.danger.withValues(alpha: 0.18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(LucideIcons.alertCircle, color: WorkableDesign.danger),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _error,
              style: const TextStyle(
                color: WorkableDesign.danger,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
