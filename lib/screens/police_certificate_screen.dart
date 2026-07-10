import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../core/theme/workable_design.dart';
import '../models/verification_documents.dart';
import '../services/identity_verification_service.dart';

class PoliceCertificateScreen extends StatefulWidget {
  static const routeName = '/police-certificate';

  const PoliceCertificateScreen({super.key});

  @override
  State<PoliceCertificateScreen> createState() =>
      _PoliceCertificateScreenState();
}

class _PoliceCertificateScreenState extends State<PoliceCertificateScreen>
    with SingleTickerProviderStateMixin {
  int currentStep = 1;

  String? uploadMethod;

  bool isLoading = false;

  bool showSuccessScreen = false;

  File? capturedImage;

  final ImagePicker _picker = ImagePicker();

  late AnimationController _animationController;

  late Animation<double> _scaleAnimation;

  Map<String, dynamic>? verificationData;

  String verificationStatus = 'incomplete';

  bool isInitialLoading = true;

  final IdentityVerificationService _verificationService =
      IdentityVerificationService();

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _scaleAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutBack,
    );
    _loadVerificationStatus();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _captureImage() async {
    try {
      setState(() => isLoading = true);

      final pickedFile = await _picker.pickImage(source: ImageSource.camera);

      if (pickedFile != null) {
        setState(() {
          capturedImage = File(pickedFile.path);

          uploadMethod = 'camera';
        });
      } else {
        if (!mounted) return;
        setState(() {
          uploadMethod = null;

          capturedImage = null;
        });

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('No image captured')));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Camera error: $e')));
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _pickImageFromGallery() async {
    try {
      setState(() => isLoading = true);

      final pickedFile = await _picker.pickImage(source: ImageSource.gallery);

      if (pickedFile != null) {
        setState(() {
          capturedImage = File(pickedFile.path);

          uploadMethod = 'file';
        });
      } else {
        if (!mounted) return;
        setState(() {
          uploadMethod = null;

          capturedImage = null;
        });

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('No image selected')));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gallery error: $e')));
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _loadVerificationStatus() async {
    try {
      final data = await _verificationService.loadVerificationStatus(
        VerificationDocuments.policeCertificate.documentId,
      );

      if (data != null) {
        verificationData = data;

        verificationStatus = data['status'] ?? 'incomplete';

        // AUTO MOVE UI BASED ON STATUS
        if (verificationStatus == 'pending') {
          currentStep = 3;
        }

        if (verificationStatus == 'verified') {
          currentStep = 3;
          showSuccessScreen = false;
        }

        if (verificationStatus == 'rejected') {
          currentStep = 1;
        }
      }
    } catch (e) {
      debugPrint('Error loading police verification status: $e');
    }

    if (mounted) {
      setState(() {
        isInitialLoading = false;
      });
    }
  }

  Widget buildStepIndicator(
    int step,
    String title, {
    bool isActive = false,
    bool isCompleted = false,
  }) {
    return Row(
      children: [
        CircleAvatar(
          radius: 14,
          backgroundColor: isCompleted
              ? Colors.green
              : isActive
              ? Colors.blue
              : Colors.grey.shade300,
          child: isCompleted
              ? const Icon(Icons.check, color: Colors.white, size: 16)
              : Text(
                  '$step',
                  style: TextStyle(
                    color: isActive ? Colors.white : Colors.black,
                  ),
                ),
        ),

        const SizedBox(width: 6),

        Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: isActive ? Colors.blue : Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget buildUploadOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required String method,
  }) {
    final isSelected = uploadMethod == method;

    return InkWell(
      onTap: () {
        setState(() {
          uploadMethod = method;
        });

        if (method == 'camera') {
          _captureImage();
        } else if (method == 'file') {
          _pickImageFromGallery();
        }
      },

      child: Container(
        padding: const EdgeInsets.all(14),

        margin: const EdgeInsets.only(bottom: 12),

        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.shade50 : Colors.white,

          border: Border.all(
            color: isSelected ? Colors.blue : Colors.grey.shade300,
          ),

          borderRadius: BorderRadius.circular(12),
        ),

        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: isSelected ? Colors.blue : Colors.grey.shade200,

              child: Icon(
                icon,
                color: isSelected ? Colors.white : Colors.black,
              ),
            ),

            const SizedBox(width: 12),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,

                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),

                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                ],
              ),
            ),

            if (isSelected) const Icon(Icons.check_circle, color: Colors.blue),
          ],
        ),
      ),
    );
  }

  Future<void> _submitForm() async {
    setState(() => isLoading = true);

    try {
      final policeData = await _verificationService.submitVerificationDocument(
        config: VerificationDocuments.policeCertificate,
        uploadMethod: uploadMethod,
        imageFile: capturedImage,
        replaceExistingImage:
            verificationData != null && verificationData?['imageUrl'] != null,
        existingData: verificationData,
      );
      verificationData = policeData;

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Police certificate submitted for verification'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => isLoading = false);

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));

      return;
    }

    setState(() {
      currentStep = 3;

      verificationStatus = 'pending';
    });

    await Future.delayed(const Duration(seconds: 2));

    setState(() {
      showSuccessScreen = true;
    });

    _animationController.forward();

    await Future.delayed(const Duration(seconds: 2));

    if (mounted) {
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isInitialLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: WorkableDesign.canvas,

      appBar: AppBar(
        elevation: 0,

        backgroundColor: Colors.white,

        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),

          onPressed: () => currentStep == 1
              ? Navigator.pop(context)
              : setState(() => currentStep--),
        ),

        title: Text(
          currentStep == 1
              ? 'Police Clearance Certificate'
              : currentStep == 2
              ? 'Review & Confirm'
              : 'Verification Status',

          style: const TextStyle(color: Colors.black),
        ),
      ),

      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),

        child: SingleChildScrollView(
          child: Column(
            children: [
              // STEP INDICATOR
              Container(
                padding: const EdgeInsets.all(12),

                decoration: BoxDecoration(
                  color: Colors.white,

                  borderRadius: BorderRadius.circular(12),

                  border: Border.all(color: Colors.grey.shade200),
                ),

                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,

                  children: [
                    buildStepIndicator(
                      1,
                      'Upload',
                      isActive: currentStep == 1,
                      isCompleted: currentStep > 1,
                    ),

                    buildStepIndicator(
                      2,
                      'Review',
                      isActive: currentStep == 2,
                      isCompleted: currentStep > 2,
                    ),

                    buildStepIndicator(3, 'Verify', isActive: currentStep == 3),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              if (verificationStatus == 'verified') ...[
                Container(
                  padding: const EdgeInsets.all(20),

                  decoration: BoxDecoration(
                    color: Colors.green.shade50,

                    borderRadius: BorderRadius.circular(12),

                    border: Border.all(color: Colors.green.shade200),
                  ),

                  child: Column(
                    children: [
                      const Icon(Icons.verified, color: Colors.green, size: 60),

                      const SizedBox(height: 16),

                      const Text(
                        'Police Certificate Verified',

                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 8),

                      const Text(
                        'Your police clearance certificate has been successfully verified.',

                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // STEP 1
              if (currentStep == 1) ...[
                if (verificationStatus == 'rejected') ...[
                  Container(
                    padding: const EdgeInsets.all(14),

                    margin: const EdgeInsets.only(bottom: 16),

                    decoration: BoxDecoration(
                      color: Colors.red.shade50,

                      borderRadius: BorderRadius.circular(12),

                      border: Border.all(color: Colors.red.shade200),
                    ),

                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,

                      children: [
                        const Text(
                          'Verification Rejected',

                          style: TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        const SizedBox(height: 8),

                        Text(
                          verificationData?['rejectionReason']?.toString() ??
                              'Please upload a valid document.',
                        ),
                      ],
                    ),
                  ),
                ],

                Container(
                  padding: const EdgeInsets.all(14),

                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,

                    border: Border.all(color: Colors.blue.shade100),

                    borderRadius: BorderRadius.circular(12),
                  ),

                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,

                    children: [
                      const Icon(
                        LucideIcons.info,
                        color: Colors.blue,
                        size: 20,
                      ),

                      const SizedBox(width: 10),

                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,

                          children: const [
                            Text(
                              "Required for verification:",
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),

                            SizedBox(height: 6),

                            Text("• Upload valid police clearance certificate"),

                            Text("• Document should be clearly visible"),

                            Text("• All details must be readable"),

                            Text("• Certificate should not be expired"),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                buildUploadOption(
                  icon: LucideIcons.camera,

                  title: 'Take Photo',

                  subtitle: 'Use camera to capture certificate',

                  method: 'camera',
                ),

                buildUploadOption(
                  icon: LucideIcons.upload,

                  title: 'Upload File',

                  subtitle: 'Select certificate from gallery',

                  method: 'file',
                ),

                const SizedBox(height: 20),

                ElevatedButton(
                  onPressed: () {
                    if (isLoading) return;

                    if ((uploadMethod == 'camera' || uploadMethod == 'file') &&
                        capturedImage != null) {
                      setState(() {
                        currentStep = 2;
                      });
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please upload a certificate'),
                        ),
                      );
                    }
                  },

                  style: ElevatedButton.styleFrom(
                    backgroundColor: WorkableDesign.primary,

                    foregroundColor: Colors.white,

                    padding: const EdgeInsets.symmetric(vertical: 16),

                    minimumSize: const Size.fromHeight(50),

                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),

                  child: isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Continue to Review'),
                ),
              ],

              // STEP 2
              if (currentStep == 2) ...[
                Container(
                  padding: const EdgeInsets.all(16),

                  margin: const EdgeInsets.only(bottom: 16),

                  decoration: BoxDecoration(
                    color: Colors.white,

                    borderRadius: BorderRadius.circular(12),

                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),

                        blurRadius: 10,

                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),

                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,

                    children: [
                      const Text(
                        'Verify Uploaded Certificate',

                        style: TextStyle(
                          fontWeight: FontWeight.bold,

                          fontSize: 16,
                        ),
                      ),

                      const SizedBox(height: 16),

                      if (capturedImage != null)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),

                          child: Image.file(
                            capturedImage!,

                            height: 220,

                            width: double.infinity,

                            fit: BoxFit.cover,
                          ),
                        ),
                    ],
                  ),
                ),

                ElevatedButton.icon(
                  onPressed: () {
                    if (isLoading) return;

                    _submitForm();
                  },

                  icon: const Icon(Icons.verified_user, color: Colors.white),

                  label: const Text('Submit for Verification'),

                  style: ElevatedButton.styleFrom(
                    backgroundColor: WorkableDesign.primary,

                    foregroundColor: Colors.white,

                    padding: const EdgeInsets.symmetric(vertical: 16),

                    minimumSize: const Size.fromHeight(50),

                    elevation: 3,

                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],

              // STEP 3
              if (currentStep == 3 && !showSuccessScreen) ...[
                Container(
                  padding: const EdgeInsets.all(16),

                  decoration: BoxDecoration(
                    color: Colors.white,

                    borderRadius: BorderRadius.circular(12),

                    border: Border.all(color: Colors.grey.shade200),
                  ),

                  child: Column(
                    children: [
                      const Icon(
                        LucideIcons.clock,

                        size: 48,

                        color: Colors.orange,
                      ),

                      const SizedBox(height: 12),

                      const Text(
                        'Verification in Progress',

                        style: TextStyle(
                          fontSize: 18,

                          fontWeight: FontWeight.w600,
                        ),
                      ),

                      const SizedBox(height: 8),

                      const Text(
                        'This usually takes 2–3 hours',

                        style: TextStyle(color: Colors.grey),
                      ),

                      const SizedBox(height: 20),

                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,

                        children: const [
                          Text(
                            'What happens next?',

                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),

                          SizedBox(height: 8),

                          Text('• Document authenticity review'),

                          Text('• Manual admin verification'),

                          Text('• Trust & safety approval'),
                        ],
                      ),
                    ],
                  ),
                ),
              ],

              // SUCCESS
              if (showSuccessScreen && verificationStatus != 'verified') ...[
                ScaleTransition(
                  scale: _scaleAnimation,

                  child: Container(
                    padding: const EdgeInsets.all(24),

                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 24,
                    ),

                    decoration: BoxDecoration(
                      color: Colors.white,

                      borderRadius: BorderRadius.circular(16),

                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),

                          blurRadius: 12,

                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),

                    child: Column(
                      children: const [
                        Icon(Icons.verified, color: Colors.green, size: 60),

                        SizedBox(height: 16),

                        Text(
                          'Police Certificate Submitted Successfully!',

                          style: TextStyle(
                            fontSize: 18,

                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        SizedBox(height: 8),

                        Text(
                          'Your document is now under review.',

                          textAlign: TextAlign.center,

                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
