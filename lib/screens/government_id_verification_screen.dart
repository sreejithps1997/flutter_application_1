import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../core/theme/workable_design.dart';
import '../helpers/document_ocr_helper.dart';
import '../models/verification_document_config.dart';
import '../models/verification_documents.dart';
import '../services/identity_verification_service.dart';

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
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _numberController = TextEditingController();
  bool _isPickerActive = false;
  final IdentityVerificationService _verificationService =
      IdentityVerificationService();
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
      capturedImage = null;
      extractedData = null;
      verificationStatus = null;
      _nameController.clear();
      _numberController.clear();
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
    _nameController.dispose();
    _numberController.dispose();
    _controller.dispose();
    super.dispose();
  }

  Map<String, dynamic>? get selectedDocument {
    if (selectedDocType == null) return null;

    for (final doc in documentTypes) {
      if (doc['id'] == selectedDocType) return doc;
    }
    return null;
  }

  VerificationDocumentConfig? get selectedDocumentConfig {
    switch (selectedDocType) {
      case 'aadhaar':
        return VerificationDocuments.aadhaar;
      case 'voter':
        return VerificationDocuments.voterId;
      case 'driving':
        return VerificationDocuments.drivingLicense;
      case 'passport':
        return VerificationDocuments.passport;
    }
    return null;
  }

  IconData _documentIcon(String id) {
    switch (id) {
      case 'aadhaar':
        return LucideIcons.badgeCheck;
      case 'voter':
        return LucideIcons.vote;
      case 'driving':
        return LucideIcons.car;
      case 'passport':
        return LucideIcons.bookOpen;
      default:
        return LucideIcons.fileText;
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
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
        final doc = selectedDocument;
        if (doc == null) return;
        final extractor =
            doc['extractor'] as Future<Map<String, String>> Function(File);
        final result = await extractor(capturedImage!);

        if (!mounted) return;

        _nameController.text = result['name']?.trim() ?? '';
        _numberController.text = result['number']?.trim() ?? '';

        setState(() {
          extractedData = result;
          currentStep = 'review';
        });
      }
    } catch (e) {
      _showMessage(
        'We could not read this document clearly. Please retake a sharper photo.',
      );
    } finally {
      if (mounted) setState(() => _isPickerActive = false);
    }
  }

  bool _isUploading = false; // add at top in State class

  String? validateExtractedDetails() {
    final name = _nameController.text.trim();
    final number = _numberController.text.trim();

    if (name.isEmpty) return 'Please enter the name shown on the document.';
    if (number.isEmpty) return 'Please enter the document number.';

    switch (selectedDocType) {
      case 'aadhaar':
        final digitsOnly = number.replaceAll(RegExp(r'\D'), '');
        if (!RegExp(r'^\d{12}$').hasMatch(digitsOnly)) {
          return 'Please enter a valid 12-digit Aadhaar number.';
        }
        break;
      case 'voter':
        if (number.length < 6) return 'Please enter a valid voter ID number.';
        break;
      case 'driving':
        if (number.length < 8) {
          return 'Please enter a valid driving license number.';
        }
        break;
      case 'passport':
        if (!RegExp(
          r'^[A-Z][0-9]{7}$',
          caseSensitive: false,
        ).hasMatch(number)) {
          return 'Please enter a valid passport number.';
        }
        break;
    }

    return null;
  }

  Future<void> handleSubmitVerification() async {
    if (_isUploading ||
        capturedImage == null ||
        extractedData == null ||
        selectedDocType == null) {
      _showMessage('Please capture a document before submitting.');
      return;
    }

    final validationMessage = validateExtractedDetails();
    if (validationMessage != null) {
      _showMessage(validationMessage);
      return;
    }

    setState(() {
      _isUploading = true;
      currentStep = 'processing';
    });

    try {
      final doc = selectedDocument;
      final config = selectedDocumentConfig;
      if (doc == null || config == null) {
        _showMessage('Please select a valid document type.');
        if (mounted) setState(() => currentStep = 'select');
        return;
      }

      await _verificationService.submitVerificationDocument(
        config: config,
        uploadMethod: 'file',
        imageFile: capturedImage,
        fields: {
          'type': doc['id'],
          'name': _nameController.text.trim(),
          'number': _numberController.text.trim(),
          'ocrRawText': extractedData.toString(),
        },
      );

      if (!mounted) return;

      setState(() {
        verificationStatus = 'success';
        _controller.forward(from: 0); // animation tick
        currentStep = 'result';
      });
    } catch (e) {
      _showMessage(
        'Upload failed. Please check your connection and try again.',
      );
      if (!mounted) return;
      setState(() {
        verificationStatus = 'failed';
        currentStep = 'result';
      });
    } finally {
      if (mounted) setState(() => _isUploading = false);
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
          return Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            decoration: WorkableDesign.cardDecoration(),
            child: InkWell(
              borderRadius: BorderRadius.circular(WorkableDesign.radius),
              onTap: () => handleDocumentSelect(doc['id']),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: WorkableDesign.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(
                          WorkableDesign.radius,
                        ),
                      ),
                      child: Icon(
                        _documentIcon(doc['id']?.toString() ?? ''),
                        color: WorkableDesign.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            doc['name'],
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: WorkableDesign.ink,
                            ),
                          ),
                          Text(
                            doc['description'],
                            style: const TextStyle(
                              fontSize: 12,
                              color: WorkableDesign.muted,
                            ),
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
                                    backgroundColor: WorkableDesign.primary
                                        .withValues(alpha: 0.08),
                                    labelStyle: const TextStyle(
                                      color: WorkableDesign.primary,
                                    ),
                                    side: BorderSide(
                                      color: WorkableDesign.primary.withValues(
                                        alpha: 0.16,
                                      ),
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
                              color: WorkableDesign.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right,
                      color: WorkableDesign.muted,
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
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
              color: WorkableDesign.border,
              style: BorderStyle.solid,
            ),
            borderRadius: BorderRadius.circular(WorkableDesign.radius),
            color: WorkableDesign.canvas,
          ),
          child: Center(
            child: Icon(
              Icons.camera_alt,
              size: 40,
              color: WorkableDesign.muted,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _isPickerActive ? null : handleImageCapture,
                icon: _isPickerActive
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.camera_alt),
                label: Text(_isPickerActive ? 'Scanning...' : 'Take Photo'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _isPickerActive ? null : handleFileUpload,
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

    final doc = selectedDocument;

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
          'Review Extracted Details',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'Please confirm these details before submitting. You can correct OCR mistakes here.',
          style: TextStyle(fontSize: 12, color: WorkableDesign.muted),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _nameController,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            labelText: 'Name on ${doc?['name'] ?? 'document'}',
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _numberController,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(
            labelText: 'Document Number',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    capturedImage = null;
                    extractedData = null;
                    _nameController.clear();
                    _numberController.clear();
                    currentStep = 'capture';
                  });
                },
                icon: const Icon(Icons.camera_alt_outlined),
                label: const Text('Retake'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _isUploading ? null : handleSubmitVerification,
                icon: const Icon(Icons.verified_user_outlined),
                label: const Text('Submit'),
              ),
            ),
          ],
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
          style: TextStyle(fontSize: 12, color: WorkableDesign.muted),
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
                  color: WorkableDesign.success,
                ),
              )
            : const Icon(Icons.cancel, size: 64, color: WorkableDesign.danger),

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
          style: const TextStyle(fontSize: 13, color: WorkableDesign.muted),
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
                      ? WorkableDesign.success
                      : isActive
                      ? WorkableDesign.primary
                      : WorkableDesign.border,
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
                      color: completed
                          ? WorkableDesign.success
                          : WorkableDesign.border,
                    ),
                  ),
              ],
            ),
          );
        }).toList(),
      );
    }

    return Scaffold(
      backgroundColor: WorkableDesign.canvas,
      appBar: AppBar(
        title: const Text('Government ID Verification'),
        backgroundColor: WorkableDesign.surface,
        foregroundColor: WorkableDesign.ink,
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
                  Icon(
                    LucideIcons.shieldCheck,
                    size: 18,
                    color: WorkableDesign.success,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Your documents are encrypted and stored securely.",
                      style: TextStyle(
                        fontSize: 12,
                        color: WorkableDesign.muted,
                      ),
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
