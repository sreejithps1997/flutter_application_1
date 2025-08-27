import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../helpers/document_ocr_helper.dart';

class GovernmentIdVerificationScreen extends StatefulWidget {
  static const routeName = '/government-id-verification';

  const GovernmentIdVerificationScreen({super.key});

  @override
  State<GovernmentIdVerificationScreen> createState() =>
      _GovernmentIdVerificationScreenState();
}

class _GovernmentIdVerificationScreenState
    extends State<GovernmentIdVerificationScreen>
    with SingleTickerProviderStateMixin {
  String currentStep = 'select';
  String? selectedDocType;
  File? capturedImage;
  Map<String, String>? extractedData;
  String? verificationStatus;
  final ImagePicker _picker = ImagePicker();
  bool _isPickerActive = false;
  final user = FirebaseAuth.instance.currentUser;
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  final List<Map<String, dynamic>> documentTypes = [
    {
      'id': 'aadhaar',
      'name': 'Aadhaar Card',
      'description': 'Most preferred - Instant verification',
      'icon': '🆔',
      'features': ['Auto-verify', 'Instant approval', 'Secure'],
      'requirements': 'Clear front side photo',
      'extractor': DocumentOcrHelper.extractAadharDetails,
      'path': 'aadhaar_cards',
      'firestoreKey': 'aadhaar',
    },
    {
      'id': 'voter',
      'name': 'Voter ID Card',
      'description': 'Government issued photo ID',
      'icon': '🗳️',
      'features': ['Photo verification', '2-3 min processing'],
      'requirements': 'Front side with photo visible',
      'extractor': DocumentOcrHelper.extractVoterIDDetails,
      'path': 'voter_ids',
      'firestoreKey': 'voter_id',
    },
    {
      'id': 'driving',
      'name': 'Driving License',
      'description': 'Valid driving license',
      'icon': '🚗',
      'features': ['Address verification', 'Photo matching'],
      'requirements': 'Front side, must be valid',
      'extractor': DocumentOcrHelper.extractLicenseDetails,
      'path': 'driving_licenses',
      'firestoreKey': 'driving_license',
    },
    {
      'id': 'passport',
      'name': 'Passport',
      'description': 'Indian passport',
      'icon': '📘',
      'features': ['International validity', 'High security'],
      'requirements': 'First page with photo',
      'extractor': DocumentOcrHelper.extractPassportDetails,
      'path': 'passports',
      'firestoreKey': 'passport',
    },
  ];

  void handleDocumentSelect(String docId) {
    setState(() {
      selectedDocType = docId;
      currentStep = 'capture';
    });
  }

  // @override
  // void initState() {
  //   super.initState();
  //   _requestPermissions();

  //   // ✅ Initialize the animation controller here
  //   _controller = AnimationController(
  //     vsync: this,
  //     duration: const Duration(milliseconds: 600),
  //   );

  //   _controller = AnimationController(
  //     vsync: this,
  //     duration: const Duration(milliseconds: 500),
  //   );

  //   _scaleAnimation = CurvedAnimation(
  //     parent: _controller,
  //     curve: Curves.elasticOut,
  //   );
  // }

  @override
  void initState() {
    super.initState();
    _requestPermissions();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500), // or 600
    );

    _scaleAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // Trigger camera capture
  void handleImageCapture() {
    handleImagePick(ImageSource.camera);
  }

  // Trigger file upload
  void handleFileUpload() {
    handleImagePick(ImageSource.gallery);
  }

  // Future<void> _requestPermissions() async {
  //   await Permission.camera.request();
  //   await Permission.storage.request();
  // }
  Future<void> _requestPermissions() async {
    await [Permission.camera, Permission.storage].request();
  }

  Future<void> handleImagePick(ImageSource source) async {
    if (_isPickerActive || selectedDocType == null) return;
    setState(() => _isPickerActive = true);

    try {
      final image = await _picker.pickImage(source: source);
      if (image != null) {
        capturedImage = File(image.path);
        final doc = documentTypes.firstWhere((d) => d['id'] == selectedDocType);
        final extractor =
            doc['extractor'] as Future<Map<String, String>> Function(File);
        final result = await extractor(capturedImage!);

        setState(() {
          extractedData = result;
          currentStep = 'review';
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() => _isPickerActive = false);
    }
  }

  bool _isUploading = false; // add at top in State class

  Future<void> handleSubmitVerification() async {
    if (_isUploading ||
        capturedImage == null ||
        extractedData == null ||
        selectedDocType == null ||
        user == null)
      return;

    final uid = user!.uid; // ✅ Promote once null check is done

    setState(() {
      _isUploading = true;
      currentStep = 'processing';
    });

    try {
      final doc = documentTypes.firstWhere((d) => d['id'] == selectedDocType);
      final fileName = '${uid}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = FirebaseStorage.instance.ref('${doc['path']}/$fileName');
      await ref.putFile(capturedImage!);
      final downloadUrl = await ref.getDownloadURL();

      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('identityVerification')
          .doc(doc['firestoreKey'])
          .set({
            'name': extractedData!['name'],
            'number': extractedData!['number'],
            'imageUrl': downloadUrl,
            'submittedAt': Timestamp.now(),
            'status': 'pending',
            'ocrRawText': extractedData.toString(),
          });

      setState(() {
        verificationStatus = 'success';
        _controller.forward(from: 0); // animation tick
        currentStep = 'result';
      });
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Verification failed: $e')));
      setState(() {
        verificationStatus = 'failed';
        currentStep = 'result';
      });
    } finally {
      _isUploading = false;
    }
  }

  Widget buildSelectStep() {
    return Column(
      children: [
        const Text(
          'Select Document Type',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        ...documentTypes.map((doc) {
          return Card(
            margin: const EdgeInsets.symmetric(vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => handleDocumentSelect(doc['id']),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  children: [
                    Text(doc['icon'], style: const TextStyle(fontSize: 28)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            doc['name'],
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            doc['description'],
                            style: const TextStyle(fontSize: 12),
                          ),
                          Wrap(
                            spacing: 6,
                            children: doc['features']
                                .map<Widget>(
                                  (f) => Chip(
                                    label: Text(
                                      f,
                                      style: const TextStyle(fontSize: 10),
                                    ),
                                    backgroundColor: Colors.blue[50],
                                    labelStyle: const TextStyle(
                                      color: Colors.blue,
                                    ),
                                    padding: EdgeInsets.zero,
                                  ),
                                )
                                .toList(),
                          ),
                          Text(
                            doc['requirements'],
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: Colors.grey),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ],
    );
  }

  Widget buildCaptureStep() {
    final doc = documentTypes.firstWhere(
      (d) => d['id'] == selectedDocType,
      orElse: () => {},
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Capture ${doc['name']}',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 12),
        Container(
          height: 180,
          decoration: BoxDecoration(
            border: Border.all(
              color: Colors.grey.shade300,
              style: BorderStyle.solid,
            ),
            borderRadius: BorderRadius.circular(12),
            color: Colors.grey.shade100,
          ),
          child: const Center(
            child: Icon(Icons.camera_alt, size: 40, color: Colors.grey),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: handleImageCapture,
                icon: const Icon(Icons.camera_alt),
                label: const Text('Take Photo'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: handleFileUpload,
                icon: const Icon(Icons.upload),
                label: const Text('Upload File'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // Widget buildReviewStep() {
  //   return Column(
  //     crossAxisAlignment: CrossAxisAlignment.start,
  //     children: [
  //       if (capturedImage != null)
  //         ClipRRect(
  //           borderRadius: BorderRadius.circular(12),
  //           child: Image.file(capturedImage!, height: 180, fit: BoxFit.cover),
  //         ),
  //       const SizedBox(height: 12),
  //       const Text(
  //         'Extracted Info',
  //         style: TextStyle(fontWeight: FontWeight.bold),
  //       ),
  //       const SizedBox(height: 8),
  //       ...extractedData!.entries.map(
  //         (entry) => Padding(
  //           padding: const EdgeInsets.symmetric(vertical: 4.0),
  //           child: Row(
  //             mainAxisAlignment: MainAxisAlignment.spaceBetween,
  //             children: [
  //               Text(
  //                 '${entry.key}:',
  //                 style: const TextStyle(color: Colors.grey, fontSize: 12),
  //               ),
  //               Text(
  //                 entry.value,
  //                 style: const TextStyle(
  //                   fontWeight: FontWeight.bold,
  //                   fontSize: 13,
  //                 ),
  //               ),
  //             ],
  //           ),
  //         ),
  //       ),
  //       const SizedBox(height: 16),
  //       ElevatedButton(
  //         onPressed: handleSubmitVerification,
  //         child: const Text('Submit for Verification'),
  //       ),
  //     ],
  //   );
  // }
  Widget buildReviewStep() {
    if (extractedData == null) {
      return const Text("No data extracted.");
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (capturedImage != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.file(capturedImage!, height: 180, fit: BoxFit.cover),
          ),
        const SizedBox(height: 12),
        const Text(
          'Extracted Info',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        ...extractedData!.entries.map(
          (entry) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${entry.key}:',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
                Text(
                  entry.value,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: handleSubmitVerification,
          child: const Text('Submit for Verification'),
        ),
      ],
    );
  }

  Widget buildProcessingStep() {
    return Column(
      children: const [
        SizedBox(height: 32),
        CircularProgressIndicator(),
        SizedBox(height: 16),
        Text('Verifying Document...'),
        SizedBox(height: 8),
        Text(
          'This may take a few seconds.',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }

  Widget buildResultStep() {
    return Column(
      children: [
        verificationStatus == 'success'
            ? ScaleTransition(
                scale: _scaleAnimation,
                child: const Icon(
                  Icons.check_circle,
                  size: 64,
                  color: Colors.green,
                ),
              )
            : const Icon(Icons.cancel, size: 64, color: Colors.redAccent),

        const SizedBox(height: 12),
        Text(
          verificationStatus == 'success'
              ? 'Verification Successful!'
              : 'Verification Failed',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        const SizedBox(height: 8),
        Text(
          verificationStatus == 'success'
              ? 'Your ID has been verified.'
              : 'Please try again.',
          style: const TextStyle(fontSize: 13, color: Colors.grey),
        ),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: () {
            if (verificationStatus == 'success') {
              Navigator.pop(context);
            } else {
              setState(() {
                currentStep = 'capture';
              });
            }
          },
          child: Text(verificationStatus == 'success' ? 'Continue' : 'Retry'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget stepIndicator() {
      final steps = ['select', 'capture', 'review', 'result'];
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: steps.map((step) {
          final index = steps.indexOf(step);
          bool completed = steps.indexOf(currentStep) > index;
          bool isActive = step == currentStep;
          return Expanded(
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: completed
                      ? Colors.green
                      : isActive
                      ? Colors.blue
                      : Colors.grey[300],
                  child: completed
                      ? const Icon(Icons.check, size: 16, color: Colors.white)
                      : Text(
                          '${index + 1}',
                          style: const TextStyle(color: Colors.white),
                        ),
                ),
                if (index < steps.length - 1)
                  Expanded(
                    child: Container(
                      height: 2,
                      color: completed ? Colors.green : Colors.grey[300],
                    ),
                  ),
              ],
            ),
          );
        }).toList(),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Government ID Verification'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ListView(
            children: [
              stepIndicator(),
              const SizedBox(height: 24),
              if (currentStep == 'select') buildSelectStep(),
              if (currentStep == 'capture') buildCaptureStep(),
              if (currentStep == 'review') buildReviewStep(),
              if (currentStep == 'processing') buildProcessingStep(),
              if (currentStep == 'result') buildResultStep(),
              const SizedBox(height: 32),
              const Divider(),
              const SizedBox(height: 8),

              Row(
                children: const [
                  Icon(LucideIcons.shieldCheck, size: 18, color: Colors.green),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Your documents are encrypted and stored securely.",
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
