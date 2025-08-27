import 'dart:io'; // Add this import
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart'; // Ensure this import is included
import 'package:flutter_image_compress/flutter_image_compress.dart';

import 'package:firebase_auth/firebase_auth.dart';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class PANCardVerificationScreen extends StatefulWidget {
  static const routeName = '/pan-card-verification';

  const PANCardVerificationScreen({super.key});

  @override
  State<PANCardVerificationScreen> createState() =>
      _PANCardVerificationScreenState();
}

class _PANCardVerificationScreenState extends State<PANCardVerificationScreen>
    with SingleTickerProviderStateMixin {
  int currentStep = 1;
  String? uploadMethod; // 'camera', 'file', 'manual'
  String panNumber = '';
  String fullName = '';
  bool showPAN = false;
  bool isLoading = false;
  bool showSuccessScreen = false;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  bool isOcrProcessing = false;

  File? capturedImage; // Declare the captured image here

  final ImagePicker _picker = ImagePicker(); // ImagePicker instance
  final TextEditingController _panController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();

  bool validatePAN(String pan) {
    final regex = RegExp(r'^[A-Z]{5}[0-9]{4}[A-Z]{1}$');
    return regex.hasMatch(pan);
  }

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
  }

  @override
  void dispose() {
    _panController.dispose();
    _nameController.dispose();
    _animationController.dispose(); // 👈 add this
    super.dispose();
  }

  String formatPAN(String input) {
    // Remove all non-alphanumeric characters and convert to uppercase
    input = input.replaceAll(RegExp(r'[^A-Z0-9]'), '').toUpperCase();

    // Ensure the substring does not go out of range if the input length is less than 10
    return input.substring(0, input.length.clamp(0, 10));
  }

  Future<Map<String, String>> extractPANDetailsFromImage(File imageFile) async {
    final inputImage = InputImage.fromFile(imageFile);
    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
    final RecognizedText recognizedText = await textRecognizer.processImage(
      inputImage,
    );

    String pan = '';
    String name = '';

    for (TextBlock block in recognizedText.blocks) {
      for (TextLine line in block.lines) {
        final text = line.text.trim();

        // Detect PAN number using regex
        if (pan.isEmpty && RegExp(r'^[A-Z]{5}[0-9]{4}[A-Z]$').hasMatch(text)) {
          pan = text;
        }

        // Heuristically detect name (long text line with no digits and not common headers)
        if (name.isEmpty &&
            text.length > 5 &&
            !text.contains(RegExp(r'\d')) &&
            !text.toUpperCase().contains('INCOME TAX') &&
            !text.toUpperCase().contains('GOVT') &&
            !text.toUpperCase().contains('DEPARTMENT')) {
          name = text;
        }
      }
    }

    return {'pan': pan, 'name': name};
  }

  Future<File> compressImage(File file) async {
    final targetPath =
        '${file.parent.path}/compressed_${file.uri.pathSegments.last}';

    final result = await FlutterImageCompress.compressAndGetFile(
      file.absolute.path,
      targetPath,
      quality: 85,
      minWidth: 1024,
      minHeight: 1024,
    );

    // ✅ Convert result (XFile or File?) to File
    if (result != null) {
      return File(result.path);
    } else {
      return file; // fallback to original file
    }
  }

  // Future<void> _captureImage() async {
  //   try {
  //     capturedImage = await compressImage(File(pickedFile.path));

  //     setState(() => isLoading = true);
  //     final pickedFile = await _picker.pickImage(source: ImageSource.camera);

  //     if (pickedFile != null) {
  //       setState(() {
  //         capturedImage = File(pickedFile.path);
  //         uploadMethod = 'camera';
  //       });

  //       final extracted = await extractPANDetailsFromImage(capturedImage!);
  //       if (extracted['pan']!.isNotEmpty) {
  //         setState(() {
  //           panNumber = extracted['pan']!;
  //           fullName = extracted['name'] ?? '';
  //           _panController.text = panNumber;
  //           _nameController.text = fullName;
  //           currentStep = 2; // 👈 Auto move to review
  //         });
  //       }
  //     } else {
  //       // User cancelled capture
  //       setState(() {
  //         uploadMethod = null;
  //         capturedImage = null;
  //       });

  //       ScaffoldMessenger.of(
  //         context,
  //       ).showSnackBar(const SnackBar(content: Text('No image captured.')));
  //     }
  //   } catch (e) {
  //     setState(() => isLoading = false);
  //     ScaffoldMessenger.of(
  //       context,
  //     ).showSnackBar(SnackBar(content: Text('Camera error: $e')));
  //   } finally {
  //     setState(() => isLoading = false);
  //   }
  // }

  // Future<void> _pickImageFromGallery() async {
  //   try {

  //     setState(() => isLoading = true);
  //     final pickedFile = await _picker.pickImage(source: ImageSource.gallery);

  //     if (pickedFile != null) {
  //       setState(() {
  //         capturedImage = File(pickedFile.path);
  //         uploadMethod = 'file';
  //       });
  //     } else {
  //       // User cancelled selection
  //       setState(() {
  //         uploadMethod = null;
  //         capturedImage = null;
  //       });

  //       ScaffoldMessenger.of(
  //         context,
  //       ).showSnackBar(const SnackBar(content: Text('No image selected.')));
  //     }
  //   } catch (e) {
  //     setState(() => isLoading = false);
  //     ScaffoldMessenger.of(
  //       context,
  //     ).showSnackBar(SnackBar(content: Text('Gallery error: $e')));
  //   } finally {
  //     setState(() => isLoading = false);
  //   }
  // }
  Future<void> _captureImage() async {
    try {
      setState(() => isLoading = true);
      final pickedFile = await _picker.pickImage(source: ImageSource.camera);

      if (pickedFile != null) {
        File imageFile = File(pickedFile.path);
        imageFile = await compressImage(imageFile); // ✅ compress before OCR

        setState(() {
          capturedImage = imageFile;
          uploadMethod = 'camera';
        });

        try {
          setState(() => isOcrProcessing = true);
          final extracted = await extractPANDetailsFromImage(capturedImage!);
          if (extracted['pan']!.isNotEmpty) {
            setState(() {
              panNumber = extracted['pan']!;
              fullName = extracted['name'] ?? '';
              _panController.text = panNumber;
              _nameController.text = fullName;
              currentStep = 2; // ✅ Auto-move to review step
              isOcrProcessing = false; // ✅ FIXED HERE
            });
          }
        } catch (e) {
          setState(() => isOcrProcessing = false);
          debugPrint('OCR failed: $e');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Failed to extract PAN. Try again or enter manually.',
              ),
            ),
          );
        }
      } else {
        setState(() {
          uploadMethod = null;
          capturedImage = null;
        });

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('No image captured.')));
      }
    } catch (e) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Camera error: $e')));
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _pickImageFromGallery() async {
    try {
      setState(() => isLoading = true);
      final pickedFile = await _picker.pickImage(source: ImageSource.gallery);

      if (pickedFile != null) {
        File imageFile = File(pickedFile.path);
        imageFile = await compressImage(imageFile);

        setState(() {
          capturedImage = imageFile;
          uploadMethod = 'file';
        });

        try {
          setState(() => isOcrProcessing = true);
          final extracted = await extractPANDetailsFromImage(capturedImage!);
          if (extracted['pan']!.isNotEmpty) {
            setState(() {
              panNumber = extracted['pan']!;
              fullName = extracted['name'] ?? '';
              _panController.text = panNumber;
              _nameController.text = fullName;
              currentStep = 2;
              isOcrProcessing = false; // ✅ FIXED HERE
            });
          }
        } catch (e) {
          setState(() => isOcrProcessing = false);
          debugPrint('OCR failed: $e');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Failed to extract PAN. Try again or enter manually.',
              ),
            ),
          );
        }
      } else {
        setState(() {
          uploadMethod = null;
          capturedImage = null;
        });

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('No image selected.')));
      }
    } catch (e) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gallery error: $e')));
    } finally {
      setState(() => isLoading = false);
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
          panNumber = '';
          fullName = '';
          _panController.clear();
          _nameController.clear();
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
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    setState(() => isLoading = true);

    try {
      String? downloadUrl;

      // Upload image if available
      if (capturedImage != null) {
        final storageRef = FirebaseStorage.instance.ref(
          'pan_cards/$uid/${DateTime.now().millisecondsSinceEpoch}.jpg',
        );
        final uploadTask = await storageRef.putFile(capturedImage!);
        downloadUrl = await uploadTask.ref.getDownloadURL();
      }

      // Only validate PAN if using manual method
      if (uploadMethod == 'manual' && !validatePAN(panNumber)) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Invalid PAN number')));
        setState(() => isLoading = false);
        return;
      }

      final panData = {
        'status': 'pending',
        'uploadedAt': Timestamp.now(),
        'method': uploadMethod, // ✅ store upload method
        if (uploadMethod == 'manual') ...{
          'number': panNumber,
          'fullName': fullName,
        },
        if (downloadUrl != null) 'imageUrl': downloadUrl,
      };

      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('identityVerification')
          .doc('pan')
          .set(panData);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PAN submitted for verification')),
      );
    } catch (e) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }

    // 👇 Add this here
    Future.delayed(const Duration(seconds: 2), () {
      Navigator.pushReplacementNamed(
        context,
        '/identity-verification',
      ); // or your actual screen
    });

    // Step 3: move to verification in progress
    setState(() {
      currentStep = 3;
    });

    // Wait and then show success
    await Future.delayed(const Duration(seconds: 2));

    setState(() {
      showSuccessScreen = true;
    });
    _animationController.forward();

    // Auto-dismiss and navigate back after success
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) {
      Navigator.pushReplacementNamed(context, '/identity-verification');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        elevation: 0,
        title: Text(
          currentStep == 1
              ? 'PAN Card Verification'
              : currentStep == 2
              ? 'Review & Confirm'
              : 'Verification Status',
          style: const TextStyle(color: Colors.black),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => currentStep == 1
              ? Navigator.pop(context)
              : setState(() => currentStep--),
        ),
        backgroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Progress steps
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

              if (currentStep == 1) ...[
                // Instructions
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
                            Text("• Clear, readable PAN card image"),
                            Text("• All corners visible"),
                            Text("• No glare or shadows"),
                            Text("• Name should match your profile"),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Upload Options
                buildUploadOption(
                  icon: LucideIcons.camera,
                  title: 'Take Photo',
                  subtitle: 'Use camera to capture PAN card',
                  method: 'camera',
                ),
                buildUploadOption(
                  icon: LucideIcons.upload,
                  title: 'Upload File',
                  subtitle: 'Select image from gallery',
                  method: 'file',
                ),
                buildUploadOption(
                  icon: LucideIcons.fileText,
                  title: 'Enter Manually',
                  subtitle: 'Type PAN details manually',
                  method: 'manual',
                ),

                if (uploadMethod == 'manual') ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      children: [
                        // PAN input
                        TextFormField(
                          controller: _panController,
                          maxLength: 10,
                          textCapitalization:
                              TextCapitalization.characters, // optional
                          onChanged: (value) {
                            final upperCaseValue = value.toUpperCase();
                            if (value != upperCaseValue) {
                              final cursorPos = _panController.selection;
                              _panController.value = TextEditingValue(
                                text: upperCaseValue,
                                selection:
                                    cursorPos, // keeps cursor in correct position
                              );
                            }
                            setState(() {
                              panNumber = formatPAN(
                                upperCaseValue,
                              ); // also update your panNumber
                            });
                          },
                          decoration: InputDecoration(
                            labelText: 'PAN Number *',
                            suffixIcon: IconButton(
                              icon: Icon(
                                showPAN ? LucideIcons.eyeOff : LucideIcons.eye,
                              ),
                              onPressed: () =>
                                  setState(() => showPAN = !showPAN),
                            ),
                            border: const OutlineInputBorder(),
                            counterText: '',
                          ),
                        ),

                        const SizedBox(height: 10),
                        if (panNumber.isNotEmpty && !validatePAN(panNumber))
                          Row(
                            children: const [
                              Icon(
                                LucideIcons.alertCircle,
                                color: Colors.red,
                                size: 16,
                              ),
                              SizedBox(width: 6),
                              Text(
                                'Please enter a valid PAN',
                                style: TextStyle(color: Colors.red),
                              ),
                            ],
                          ),
                        const SizedBox(height: 16),

                        // Full name
                        TextFormField(
                          controller: _nameController,
                          onChanged: (value) =>
                              setState(() => fullName = value.toUpperCase()),
                          decoration: const InputDecoration(
                            labelText: 'Full Name (as on PAN) *',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Continue button
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    if (isLoading || isOcrProcessing) return;

                    if (uploadMethod == 'manual') {
                      if (validatePAN(panNumber) && fullName.isNotEmpty) {
                        setState(() => currentStep = 2);
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please enter valid PAN details'),
                          ),
                        );
                      }
                    } else if ((uploadMethod == 'camera' ||
                        uploadMethod == 'file')) {
                      if (capturedImage != null) {
                        setState(() => currentStep = 2);
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Please capture or upload a PAN image',
                            ),
                          ),
                        );
                      }
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please select an upload method'),
                        ),
                      );
                    }
                  },

                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    minimumSize: const Size.fromHeight(50),
                  ),
                  child: isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Continue to Review'),
                ),
              ],

              if (currentStep == 2) ...[
                // Card-style layout for review info
                Container(
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Verify Your Information',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // If manual, show PAN + Name
                      if (uploadMethod == 'manual') ...[
                        Row(
                          children: [
                            const Text(
                              'PAN: ',
                              style: TextStyle(fontWeight: FontWeight.w500),
                            ),
                            Text(
                              showPAN ? panNumber : '••••••••••',
                              style: const TextStyle(letterSpacing: 1.2),
                            ),
                            TextButton(
                              onPressed: () =>
                                  setState(() => showPAN = !showPAN),
                              child: Text(showPAN ? 'Hide' : 'Show'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Full Name: $fullName',
                          style: const TextStyle(
                            fontSize: 14,
                            height: 1.4,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],

                      // If image uploaded
                      if (uploadMethod == 'camera' ||
                          uploadMethod == 'file') ...[
                        const SizedBox(height: 8),
                        const Text(
                          'PAN Image:',
                          style: TextStyle(fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.file(
                            capturedImage!,
                            height: 180,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ],
                      if (panNumber.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(
                          'PAN: ${showPAN ? panNumber : '••••••••••'}',
                          style: TextStyle(fontWeight: FontWeight.w500),
                        ),
                        TextButton(
                          onPressed: () => setState(() => showPAN = !showPAN),
                          child: Text(showPAN ? 'Hide PAN' : 'Show PAN'),
                        ),
                      ],

                      if (fullName.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Name: $fullName',
                          style: TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ],

                      if ((uploadMethod == 'camera' ||
                              uploadMethod == 'file') &&
                          capturedImage != null &&
                          panNumber.isEmpty &&
                          !isOcrProcessing) ...[
                        const SizedBox(height: 10),
                        TextButton(
                          onPressed: _captureImage,
                          child: const Text('Try OCR Again'),
                        ),
                      ],
                    ],
                  ),
                ),

                // Submit button with icon
                ElevatedButton.icon(
                  onPressed: () {
                    if (isLoading || isOcrProcessing) return; // ✅ added here
                    _submitForm();
                  },
                  icon: const Icon(Icons.verified_user, color: Colors.white),
                  label: const Text('Submit for Verification'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    minimumSize: const Size.fromHeight(50),
                    elevation: 3,
                  ),
                ),
              ],

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
                          Text('• Document authenticity check'),
                          Text('• Validation with govt database'),
                          Text('• Profile matching & approval'),
                        ],
                      ),
                    ],
                  ),
                ),
              ],

              if (showSuccessScreen) ...[
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
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.verified,
                          color: Colors.green,
                          size: 60,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Submitted Successfully!',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'We\'ll notify you after verification is completed.',
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
