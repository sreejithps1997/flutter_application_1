import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:workable/helpers/document_ocr_helper.dart';
import 'package:workable/helpers/face_match_helper.dart';
import 'package:workable/screens/selfie_camera_screen.dart';
import 'package:workable/screens/worker_dashboard_screen.dart';
import 'package:workable/services/auth_service.dart';

import '../../core/theme/workable_design.dart';
import '../../models/worker_onboarding_data.dart';
import '../../widgets/worker_onboarding_shell.dart';

Future<double?> _compareWorker(List args) async {
  final selfiePath = args[0] as String;
  final profileUrl = args[1] as String;
  return FaceMatchHelper.compareFaces(
    selfieFile: File(selfiePath),
    profileImageUrl: profileUrl,
  );
}

class Step5VerifyScreen extends StatefulWidget {
  static const routeName = '/step5-verify';
  final WorkerOnboardingData onboardingData;

  const Step5VerifyScreen({super.key, required this.onboardingData});

  @override
  State<Step5VerifyScreen> createState() => _Step5VerifyScreenState();
}

class _Step5VerifyScreenState extends State<Step5VerifyScreen> {
  final _picker = ImagePicker();
  final _authService = AuthService();

  File? primaryFront;
  File? primaryBack;
  File? selfie;

  String? selectedPrimaryId;
  bool consentChecked = false;
  bool _isSubmitting = false;

  String? extractedName;
  String? extractedNumber;

  late WorkerOnboardingData onboardingData;

  final List<String> idOptions = const [
    'Aadhar Card',
    'Passport',
    'Driving License',
    'Voter ID Card',
  ];

  @override
  void initState() {
    super.initState();
    onboardingData = widget.onboardingData;
    _loadProfileImageIfMissing();
  }

  Future<void> _loadProfileImageIfMissing() async {
    if ((onboardingData.profileImageUrl ?? '').isNotEmpty) return;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final workerDoc = await FirebaseFirestore.instance
        .collection('workers')
        .doc(uid)
        .get();
    var url = workerDoc.data()?['profileImageUrl'] as String?;

    if ((url ?? '').isEmpty) {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      url =
          userDoc.data()?['profileImageUrl'] as String? ??
          userDoc.data()?['profileImage'] as String?;
    }

    if (!mounted) return;
    if ((url ?? '').isNotEmpty) {
      setState(() {
        onboardingData = onboardingData.copyWith(profileImageUrl: url);
      });
    } else {
      debugPrint('No profile image found for worker verification uid=$uid');
    }
  }

  Future<File> _compressToTemp(
    File src, {
    int maxW = 1024,
    int maxH = 1024,
    int quality = 70,
  }) async {
    final dir = await getTemporaryDirectory();
    final target = File(
      p.join(dir.path, 'img_${DateTime.now().millisecondsSinceEpoch}.jpg'),
    );
    final out = await FlutterImageCompress.compressAndGetFile(
      src.path,
      target.path,
      quality: quality,
      minWidth: maxW,
      minHeight: maxH,
      keepExif: false,
    );
    return out != null ? File(out.path) : src;
  }

  void _clearImageCache() {
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
  }

  Future<void> _pickImageFromCamera(ValueChanged<File> onPicked) async {
    final file = await Navigator.of(
      context,
    ).push<File>(MaterialPageRoute(builder: (_) => const SelfieCameraScreen()));
    if (file != null && mounted) {
      await Future<void>.delayed(const Duration(milliseconds: 120));
      onPicked(file);
    }
  }

  Future<void> _pickImageFromGallery(ValueChanged<File> onPicked) async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 65,
      maxWidth: 1024,
      maxHeight: 1024,
    );
    if (picked != null) onPicked(File(picked.path));
  }

  Future<void> _runOcrOnFrontImage(File file) async {
    Map<String, String> result = {};
    switch (selectedPrimaryId) {
      case 'Aadhar Card':
        result = await DocumentOcrHelper.extractAadharDetails(file);
        break;
      case 'Passport':
        result = await DocumentOcrHelper.extractPassportDetails(file);
        break;
      case 'Voter ID Card':
        result = await DocumentOcrHelper.extractVoterIDDetails(file);
        break;
      case 'Driving License':
        result = await DocumentOcrHelper.extractLicenseDetails(file);
        break;
    }

    if (!mounted) return;
    setState(() {
      extractedName = result['name'];
      extractedNumber = result['number'];
    });

    final success =
        (extractedName?.isNotEmpty ?? false) ||
        (extractedNumber?.isNotEmpty ?? false);
    _showMessage(
      success
          ? 'ID details detected for review.'
          : 'Could not read ID details.',
      success ? WorkableDesign.success : WorkableDesign.danger,
    );
  }

  Future<String?> _uploadSelfieToStorage() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _showError('Not signed in.');
        return null;
      }
      if (selfie == null) {
        _showError('No selfie selected.');
        return null;
      }

      final fileName = 'selfie_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = FirebaseStorage.instance
          .ref()
          .child('selfie_images')
          .child(user.uid)
          .child(fileName);

      await ref.putFile(selfie!, SettableMetadata(contentType: 'image/jpeg'));
      return ref.getDownloadURL();
    } on FirebaseException catch (e) {
      debugPrint('Selfie upload failed: ${e.code} ${e.message}');
      _showError('Selfie upload failed: ${e.code}');
      return null;
    } catch (e) {
      debugPrint('Selfie upload failed: $e');
      _showError('Selfie upload failed.');
      return null;
    }
  }

  Future<double?> _compareFacesOffUiIsolate({
    required File selfie,
    required String profileImageUrl,
  }) {
    return compute(_compareWorker, [
      selfie.path,
      profileImageUrl,
    ]).timeout(const Duration(seconds: 25), onTimeout: () => null);
  }

  Future<bool> _validateSelfieWithProfile() async {
    final profileUrl = onboardingData.profileImageUrl;
    if (profileUrl == null || profileUrl.isEmpty) {
      _showError('Profile photo missing. Please re-add it.');
      return false;
    }
    if (selfie == null) {
      _showError('Please capture a selfie.');
      return false;
    }

    final selfieUrl = await _uploadSelfieToStorage();
    if (selfieUrl == null) return false;

    final confidence = await _compareFacesOffUiIsolate(
      selfie: selfie!,
      profileImageUrl: profileUrl,
    );
    if (confidence == null) {
      _showError('Face comparison timed out. Please retake a clear selfie.');
      return false;
    }

    final uid = FirebaseAuth.instance.currentUser!.uid;
    await FirebaseFirestore.instance.collection('workers').doc(uid).set({
      'selfieUrl': selfieUrl,
      'faceMatchScore': confidence,
      'verification': {
        'selfieUrl': selfieUrl,
        'faceMatchScore': confidence,
        'updatedAt': FieldValue.serverTimestamp(),
      },
    }, SetOptions(merge: true));

    if (confidence < 70) {
      _showError(
        'Face mismatch detected. Retake a clear selfie and try again.',
      );
      return false;
    }

    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('identityVerification')
        .doc('selfie')
        .set({
          'type': 'selfie',
          'documentId': 'selfie',
          'documentName': 'Selfie Verification',
          'status': 'verified',
          'imageUrl': selfieUrl,
          'faceMatchScore': confidence,
          'verificationMethod': 'worker_signup_face_match',
          'verifiedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

    return true;
  }

  Future<void> _skipVerification() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _showError('User not signed in.');
        return;
      }

      final updatedData = onboardingData.copyWith(
        primaryIdType: selectedPrimaryId ?? '',
        consent: consentChecked,
        email: user.email ?? '',
      );

      final dataToSave = updatedData.toMap()
        ..addAll({
          'submittedAt': DateTime.now().toIso8601String(),
          'ocrName': extractedName ?? '',
          'ocrNumber': extractedNumber ?? '',
          'verificationSkipped': true,
          'isOnboardingComplete': true,
          'workerStatus': 'verification_pending',
          'profileVisibility': false,
          'visibleToUsers': false,
          'visibilityBlockedReason': 'Identity verification is pending',
          'verificationStatus': 'skipped',
        });

      await FirebaseFirestore.instance
          .collection('workers')
          .doc(user.uid)
          .set(dataToSave, SetOptions(merge: true));

      if (!mounted) return;
      Navigator.pushReplacementNamed(context, WorkerDashboardScreen.routeName);
    } catch (e, stack) {
      debugPrint('Error while finishing without visibility: $e\n$stack');
      _showError('Failed to finish setup. Try again.');
    }
  }

  Future<void> _submitVerification() async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);

    try {
      if (selectedPrimaryId == null) {
        _showError('Please select a primary ID type.');
        return;
      }
      if (primaryFront == null) {
        _showError('Please upload the front side of your ID.');
        return;
      }
      if (primaryBack == null) {
        _showError('Please upload the back side of your ID.');
        return;
      }
      if (selfie == null) {
        _showError('Please capture a selfie.');
        return;
      }
      if (!consentChecked) {
        _showError('Please accept the verification consent.');
        return;
      }

      final isFaceMatch = await _validateSelfieWithProfile();
      if (!isFaceMatch) return;

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _showError('User not signed in.');
        return;
      }

      final updatedData = onboardingData.copyWith(
        primaryIdType: selectedPrimaryId!,
        consent: consentChecked,
        email: user.email ?? '',
      );

      final dataToSave = updatedData.toMap()
        ..addAll({
          'submittedAt': DateTime.now().toIso8601String(),
          'ocrName': extractedName ?? '',
          'ocrNumber': extractedNumber ?? '',
          'isOnboardingComplete': true,
          'workerStatus': 'verification_submitted',
          'profileVisibility': false,
          'visibleToUsers': false,
          'visibilityBlockedReason': 'Admin verification review pending',
          'verificationStatus': 'submitted',
        });

      final result = await _authService.saveWorkerOnboardingData(dataToSave);
      if (result == null) {
        _clearImageCache();
        if (!mounted) return;
        Navigator.pushReplacementNamed(
          context,
          WorkerDashboardScreen.routeName,
        );
      } else {
        _showError(result);
      }
    } catch (e, st) {
      debugPrint('Verification submit failed: $e\n$st');
      _showError('Something went wrong during verification.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showError(String message) {
    _showMessage(message, WorkableDesign.danger);
  }

  void _showMessage(String message, Color color) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message), backgroundColor: color));
  }

  @override
  Widget build(BuildContext context) {
    return WorkerOnboardingShell(
      title: 'Verify your identity',
      subtitle:
          'Verified workers earn more trust. Your profile stays hidden from customers until verification is reviewed.',
      step: 6,
      totalSteps: 6,
      bottom: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _isSubmitting ? null : _submitVerification,
              child: _isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Submit for Review'),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _isSubmitting ? null : _skipVerification,
            child: const Text('Finish without visibility'),
          ),
        ],
      ),
      children: [
        _buildVisibilityWarning(),
        const SizedBox(height: 14),
        _buildIdCard(),
        const SizedBox(height: 14),
        _buildSelfieCard(),
        const SizedBox(height: 14),
        _buildConsentCard(),
      ],
    );
  }

  Widget _buildVisibilityWarning() {
    return WorkerOnboardingCard(
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: WorkableDesign.warning.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.visibility_off_outlined,
              color: WorkableDesign.warning,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Skipping verification opens the worker dashboard, but your profile will not be visible to customers.',
              style: TextStyle(
                color: WorkableDesign.ink,
                fontSize: 12.5,
                height: 1.35,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIdCard() {
    return WorkerOnboardingCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Government ID',
            style: TextStyle(
              color: WorkableDesign.ink,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Upload clear photos of the front and back side. OCR helps our review team check details faster.',
            style: TextStyle(
              color: WorkableDesign.muted,
              fontSize: 12.5,
              height: 1.35,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            value: selectedPrimaryId,
            items: idOptions
                .map((id) => DropdownMenuItem(value: id, child: Text(id)))
                .toList(),
            onChanged: (val) => setState(() => selectedPrimaryId = val),
            decoration: const InputDecoration(
              labelText: 'Primary ID type',
              prefixIcon: Icon(Icons.badge_outlined),
            ),
          ),
          const SizedBox(height: 14),
          _buildUploadCard(
            label: 'Upload front side',
            file: primaryFront,
            icon: Icons.credit_card_outlined,
            onPick: () => _pickImageFromGallery(_handleFrontIdPicked),
            onRemove: () => setState(() => primaryFront = null),
          ),
          _buildUploadCard(
            label: 'Upload back side',
            file: primaryBack,
            icon: Icons.credit_card_outlined,
            onPick: () => _pickImageFromGallery(_handleBackIdPicked),
            onRemove: () => setState(() => primaryBack = null),
          ),
          if ((extractedName?.isNotEmpty ?? false) ||
              (extractedNumber?.isNotEmpty ?? false))
            _buildOcrResult(),
        ],
      ),
    );
  }

  Future<void> _handleFrontIdPicked(File file) async {
    final compressed = await _compressToTemp(
      file,
      maxW: 800,
      maxH: 800,
      quality: 65,
    );
    try {
      if (await file.exists()) await file.delete();
    } catch (_) {}
    if (!mounted) return;
    setState(() => primaryFront = compressed);
    if (selectedPrimaryId != null) {
      await _runOcrOnFrontImage(compressed);
    }
  }

  Future<void> _handleBackIdPicked(File file) async {
    final compressed = await _compressToTemp(
      file,
      maxW: 800,
      maxH: 800,
      quality: 65,
    );
    try {
      if (await file.exists()) await file.delete();
    } catch (_) {}
    if (!mounted) return;
    setState(() => primaryBack = compressed);
  }

  Widget _buildSelfieCard() {
    return WorkerOnboardingCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Selfie face match',
            style: TextStyle(
              color: WorkableDesign.ink,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Capture a fresh selfie so we can match it with your profile photo.',
            style: TextStyle(
              color: WorkableDesign.muted,
              fontSize: 12.5,
              height: 1.35,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 14),
          _buildUploadCard(
            label: 'Capture selfie',
            file: selfie,
            icon: Icons.photo_camera_outlined,
            onPick: () =>
                _pickImageFromCamera((file) => setState(() => selfie = file)),
            onRemove: () => setState(() => selfie = null),
          ),
        ],
      ),
    );
  }

  Widget _buildConsentCard() {
    return WorkerOnboardingCard(
      child: CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        value: consentChecked,
        onChanged: (val) => setState(() => consentChecked = val ?? false),
        controlAffinity: ListTileControlAffinity.leading,
        title: const Text(
          'I consent to identity, document, and selfie checks for worker verification.',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  Widget _buildUploadCard({
    required String label,
    required File? file,
    required VoidCallback onPick,
    required VoidCallback onRemove,
    IconData icon = Icons.upload_file_outlined,
  }) {
    final uploaded = file != null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onPick,
        borderRadius: BorderRadius.circular(WorkableDesign.radius),
        child: Ink(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: uploaded
                ? WorkableDesign.success.withValues(alpha: 0.08)
                : WorkableDesign.canvas,
            borderRadius: BorderRadius.circular(WorkableDesign.radius),
            border: Border.all(
              color: uploaded
                  ? WorkableDesign.success.withValues(alpha: 0.28)
                  : WorkableDesign.border,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: uploaded
                      ? WorkableDesign.success.withValues(alpha: 0.12)
                      : WorkableDesign.accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  uploaded ? Icons.check_circle_outline : icon,
                  color: uploaded
                      ? WorkableDesign.success
                      : WorkableDesign.accent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      uploaded ? 'Uploaded' : label,
                      style: const TextStyle(
                        color: WorkableDesign.ink,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      uploaded ? file.path.split('/').last : 'Tap to add file',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: WorkableDesign.muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (uploaded)
                IconButton(
                  tooltip: 'Remove',
                  icon: const Icon(Icons.close, color: WorkableDesign.danger),
                  onPressed: onRemove,
                )
              else
                const Icon(
                  Icons.add_circle_outline,
                  color: WorkableDesign.accent,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOcrResult() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: WorkableDesign.success.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(WorkableDesign.radius),
        border: Border.all(
          color: WorkableDesign.success.withValues(alpha: 0.18),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.document_scanner_outlined,
            color: WorkableDesign.success,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              [
                if (extractedName?.isNotEmpty ?? false) extractedName,
                if (extractedNumber?.isNotEmpty ?? false) extractedNumber,
              ].whereType<String>().join(' | '),
              style: const TextStyle(
                color: WorkableDesign.ink,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _clearImageCache();
    super.dispose();
  }
}
