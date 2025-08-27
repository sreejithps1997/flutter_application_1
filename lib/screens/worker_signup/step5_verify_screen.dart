import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // compute
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:workable/screens/worker_dashboard_screen.dart';
import 'package:workable/services/auth_service.dart';
import '../../models/worker_onboarding_data.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:workable/helpers/document_ocr_helper.dart';
import 'package:workable/helpers/face_match_helper.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:flutter/painting.dart';
import 'package:workable/screens/selfie_camera_screen.dart';

/// ---- TOP-LEVEL worker for compute (must be top-level, not inside a class) ----
Future<double?> _compareWorker(List args) async {
  final String selfiePath = args[0] as String;
  final String profileUrl = args[1] as String;
  // Runs in background isolate
  return FaceMatchHelper.compareFaces(
    selfieFile: File(selfiePath),
    profileImageUrl: profileUrl,
  );
}

/// -----------------------------------------------------------------------------

class Step5VerifyScreen extends StatefulWidget {
  static const routeName = '/step5-verify';
  final WorkerOnboardingData onboardingData;

  const Step5VerifyScreen({super.key, required this.onboardingData});

  @override
  State<Step5VerifyScreen> createState() => _Step5VerifyScreenState();
}

class _Step5VerifyScreenState extends State<Step5VerifyScreen> {
  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  final ImagePicker _picker = ImagePicker();
  final AuthService _authService = AuthService();

  File? primaryFront;
  File? primaryBack;
  File? selfie;

  String? selectedPrimaryId;
  bool consentChecked = false;
  bool _isSubmitting = false;
  bool _picking = false;

  String? extractedName;
  String? extractedNumber;

  late WorkerOnboardingData onboardingData;

  final List<String> idOptions = [
    "Aadhar Card",
    "Passport",
    "Driving License",
    "Voter ID Card",
  ];

  // @override
  // void initState() {
  //   super.initState();
  //   onboardingData = widget.onboardingData;

  //   // Ensure we have profileImageUrl (for face match) by fetching from Firestore if missing
  //   if ((onboardingData.profileImageUrl ?? '').isEmpty) {
  //     final uid = FirebaseAuth.instance.currentUser?.uid;
  //     if (uid != null) {
  //       FirebaseFirestore.instance.collection('workers').doc(uid).get().then((
  //         doc,
  //       ) {
  //         if (doc.exists && mounted) {
  //           final url = doc.data()?['profileImageUrl'] as String?;
  //           if ((url ?? '').isNotEmpty) {
  //             setState(() {
  //               onboardingData = onboardingData.copyWith(profileImageUrl: url);
  //             });
  //           }
  //         }
  //       });
  //     }
  //   }
  // }

  @override
  void initState() {
    super.initState();
    onboardingData = widget.onboardingData;

    // Ensure profileImageUrl is available (for face match)
    if ((onboardingData.profileImageUrl ?? '').isEmpty) {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        // Try workers collection first
        FirebaseFirestore.instance.collection('workers').doc(uid).get().then((
          doc,
        ) async {
          String? url = doc.data()?['profileImageUrl'] as String?;

          // If not found, fallback to users collection
          if ((url ?? '').isEmpty) {
            final userDoc = await FirebaseFirestore.instance
                .collection('users')
                .doc(uid)
                .get();
            url =
                userDoc.data()?['profileImageUrl'] as String? ??
                userDoc.data()?['profileImage'] as String?; // legacy fallback
          }

          // Update onboardingData if URL found
          if ((url ?? '').isNotEmpty && mounted) {
            setState(() {
              onboardingData = onboardingData.copyWith(profileImageUrl: url);
            });
            print("✅ Profile image URL loaded for verification: $url");
          } else {
            print("⚠️ No profile image found in workers or users for uid=$uid");
          }
        });
      }
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
    return (out != null) ? File(out.path) : src;
  }

  void _clearImageCache() {
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
  }

  Future<void> _pickImageFromCamera(Function(File) onPicked) async {
    if (!mounted) return;
    // Navigate to our in-app camera
    final File? file = await Navigator.of(
      context,
    ).push<File>(MaterialPageRoute(builder: (_) => const SelfieCameraScreen()));
    if (file != null && mounted) {
      // tiny settle delay (harmless)
      await Future<void>.delayed(const Duration(milliseconds: 80));
      onPicked(file);
    }
  }

  Future<void> _pickImageFromGallery(Function(File) onPicked) async {
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? "OCR Successful: $extractedName | $extractedNumber"
              : "Failed to extract details from ID",
        ),
        backgroundColor: success ? Colors.green : Colors.red,
      ),
    );
  }

  Future<String?> _uploadSelfieToStorage() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _showError("Not signed in.");
        return null;
      }
      if (selfie == null) {
        _showError("No selfie selected.");
        return null;
      }

      final uid = user.uid;
      final fileName = 'selfie_${DateTime.now().millisecondsSinceEpoch}.jpg';

      final ref = FirebaseStorage.instance
          .ref()
          .child('selfie_images')
          .child(uid)
          .child(fileName);

      await ref.putFile(selfie!, SettableMetadata(contentType: 'image/jpeg'));
      final url = await ref.getDownloadURL();
      return url;
    } on FirebaseException catch (e) {
      debugPrint('❌ Storage upload failed: ${e.code} ${e.message}');
      _showError('Selfie upload failed: ${e.code}');
      return null;
    } catch (e) {
      debugPrint('❌ Storage upload failed: $e');
      _showError('Selfie upload failed.');
      return null;
    }
  }

  // ---- Face match off UI isolate ----
  Future<double?> _compareFacesOffUiIsolate({
    required File selfie,
    required String profileImageUrl,
  }) async {
    // Pass only simple values to compute (path + url). Worker reads the file.
    return compute(_compareWorker, [
      selfie.path,
      profileImageUrl,
    ]).timeout(const Duration(seconds: 25), onTimeout: () => null);
  }
  // -----------------------------------

  Future<bool> _validateSelfieWithProfile() async {
    try {
      final profileUrl = onboardingData.profileImageUrl;
      if (profileUrl == null || profileUrl.isEmpty) {
        _showError("Profile photo missing from Step 1. Please re-add it.");
        return false;
      }
      if (selfie == null) {
        _showError("Please upload a selfie.");
        return false;
      }

      // Upload selfie
      final selfieUrl = await _uploadSelfieToStorage();
      if (selfieUrl == null) {
        _showError("Selfie upload failed. Check internet/permissions.");
        return false;
      }

      // Compare faces in background
      double? confidence;
      try {
        confidence = await _compareFacesOffUiIsolate(
          selfie: selfie!,
          profileImageUrl: profileUrl,
        );
      } catch (e, st) {
        debugPrint("FaceMatch error: $e\n$st");
        _showError("Face comparison crashed. Please try again.");
        return false;
      }
      if (confidence == null) {
        _showError(
          "Face comparison failed or timed out. Please retake a clear selfie.",
        );
        return false;
      }

      // Persist results
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
          "Face mismatch detected (score: ${confidence.toStringAsFixed(2)})",
        );
        return false;
      }

      return true;
    } catch (e, st) {
      debugPrint("❌ _validateSelfieWithProfile error: $e\n$st");
      _showError("Selfie validation failed. Please try again.");
      return false;
    }
  }

  Future<void> _skipVerification() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _showError("User not signed in.");
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
          // removed location, address, phone/otp
        });

      await FirebaseFirestore.instance
          .collection('workers')
          .doc(user.uid)
          .set(dataToSave, SetOptions(merge: true));

      if (!mounted) return;
      Navigator.pushReplacementNamed(context, WorkerDashboardScreen.routeName);
    } catch (e, stack) {
      debugPrint("❌ Error while skipping: $e\n$stack");
      _showError("Failed to skip verification. Try again.");
    }
  }

  Widget _buildUploadCard({
    required String label,
    required File? file,
    required VoidCallback onPick,
    required VoidCallback onRemove,
  }) {
    return GestureDetector(
      onTap: onPick,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.deepPurple.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.deepPurple),
        ),
        child: Row(
          children: [
            const Icon(Icons.upload_file, color: Colors.deepPurple),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                file != null ? "Uploaded: ${file.path.split('/').last}" : label,
                style: const TextStyle(fontSize: 15),
              ),
            ),
            if (file != null)
              IconButton(
                icon: const Icon(Icons.close, color: Colors.red),
                onPressed: onRemove,
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitVerification() async {
    if (_isSubmitting) return;
    _isSubmitting = true;
    if (mounted) setState(() {});

    try {
      debugPrint("▶️ Verification started");

      if (selectedPrimaryId == null) {
        _showError("Please select a primary ID type.");
        return;
      }
      if (primaryFront == null) {
        _showError("Please upload the front side of your ID.");
        return;
      }
      if (primaryBack == null) {
        _showError("Please upload the back side of your ID.");
        return;
      }
      if (selfie == null) {
        _showError("Please upload a selfie.");
        return;
      }
      if (!consentChecked) {
        _showError("Please accept the consent.");
        return;
      }

      debugPrint("✅ All fields validated");

      final isFaceMatch = await _validateSelfieWithProfile();
      if (!isFaceMatch) {
        debugPrint("❌ Face match failed");
        return;
      }
      debugPrint("✅ Face match passed");

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _showError("User not signed in.");
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
          // removed location, address, phone/otp
        });

      debugPrint("🔁 Saving data to Firestore...");
      final result = await _authService.saveWorkerOnboardingData(dataToSave);
      debugPrint("✅ Firestore save result: $result");

      if (result == null) {
        _clearImageCache();
        if (!mounted) return;
        debugPrint("🚀 Navigating to dashboard");
        Navigator.pushReplacementNamed(
          context,
          WorkerDashboardScreen.routeName,
        );
      } else {
        _showError(result);
      }
    } catch (e, st) {
      debugPrint("🔥 Exception in _submitVerification: $e\n$st");
      _showError("Something went wrong during verification.");
    } finally {
      _isSubmitting = false;
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Verify Identity"),
        backgroundColor: Colors.deepPurple,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            LinearProgressIndicator(
              value: 1.0,
              backgroundColor: Colors.grey[300],
              color: Colors.deepPurple,
            ),
            const SizedBox(height: 24),
            const Text(
              "Primary ID Verification",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: selectedPrimaryId,
              items: idOptions
                  .map((id) => DropdownMenuItem(value: id, child: Text(id)))
                  .toList(),
              onChanged: (val) => setState(() => selectedPrimaryId = val),
              decoration: const InputDecoration(
                labelText: "Select Primary ID",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            _buildUploadCard(
              label: "Upload Front Side",
              file: primaryFront,
              onPick: () => _pickImageFromGallery((f) async {
                final compressed = await _compressToTemp(
                  f,
                  maxW: 800, // reduced from 1024
                  maxH: 800, // reduced from 1024
                  quality: 65,
                );
                try {
                  if (await f.exists()) await f.delete();
                } catch (_) {}
                if (!mounted) return;
                setState(() => primaryFront = compressed);
                if (selectedPrimaryId != null) {
                  WidgetsBinding.instance.addPostFrameCallback((_) async {
                    try {
                      await _runOcrOnFrontImage(compressed);
                    } catch (_) {}
                  });
                }
              }),
              onRemove: () => setState(() => primaryFront = null),
            ),

            _buildUploadCard(
              label: "Upload Back Side",
              file: primaryBack,
              onPick: () => _pickImageFromGallery((f) async {
                final compressed = await _compressToTemp(
                  f,
                  maxW: 800, // reduced from 1024
                  maxH: 800, // reduced from 1024
                  quality: 65,
                );
                try {
                  if (await f.exists()) await f.delete();
                } catch (_) {}
                if (!mounted) return;
                setState(() => primaryBack = compressed);
              }),
              onRemove: () => setState(() => primaryBack = null),
            ),

            const SizedBox(height: 24),
            const Text(
              "Selfie (Face Match)",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),

            _buildUploadCard(
              label: "Capture Selfie",
              file: selfie,
              onPick: () => _pickImageFromCamera((f) async {
                // Let camera surfaces settle to avoid buffer starvation
                await Future<void>.delayed(const Duration(milliseconds: 120));
                if (!mounted) return;
                // DO NOT recompress here — rely on image_picker's 640×640 output
                setState(() => selfie = f);
              }),
              onRemove: () => setState(() => selfie = null),
            ),

            const SizedBox(height: 16),
            CheckboxListTile(
              value: consentChecked,
              onChanged: (val) => setState(() => consentChecked = val ?? false),
              title: const Text(
                "I consent to the use of my data for verification purposes.",
              ),
            ),

            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _submitVerification,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text(
                  "Complete Setup",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: _skipVerification,
                child: const Text(
                  "Skip for Now",
                  style: TextStyle(fontSize: 14, color: Colors.deepPurple),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _clearImageCache();
    super.dispose();
  }
}
