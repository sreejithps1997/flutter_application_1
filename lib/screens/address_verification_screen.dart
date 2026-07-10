import 'dart:io';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import '../core/theme/workable_design.dart';
import '../models/verification_documents.dart';
import '../services/identity_verification_service.dart';
import '../widgets/workable_ui.dart';

class AddressVerificationScreen extends StatefulWidget {
  static const routeName = '/address-verification';

  const AddressVerificationScreen({super.key});

  @override
  State<AddressVerificationScreen> createState() =>
      _AddressVerificationScreenState();
}

class _AddressVerificationScreenState extends State<AddressVerificationScreen> {
  String? selectedDocType;
  String verificationStatus = 'pending';
  String? rejectionReason;
  File? pickedImage;
  bool isLoading = false;
  bool hasSubmittedDocument = false;
  final IdentityVerificationService _verificationService =
      IdentityVerificationService();

  final documentTypes = [
    {
      'id': 'utility',
      'name': 'Utility Bill',
      'description': 'Electricity, Water, Gas bill (Last 3 months)',
      'icon': LucideIcons.zap,
      'popular': true,
    },
    {
      'id': 'bank',
      'name': 'Bank Statement',
      'description': 'Bank statement (Last 3 months)',
      'icon': LucideIcons.fileText,
      'popular': true,
    },
    {
      'id': 'rent',
      'name': 'Rent Agreement',
      'description': 'Registered rental agreement',
      'icon': LucideIcons.fileText,
      'popular': false,
    },
    {
      'id': 'property',
      'name': 'Property Tax Receipt',
      'description': 'Municipal property tax receipt',
      'icon': LucideIcons.fileText,
      'popular': false,
    },
  ];

  final requirements = [
    'Document should be clearly visible and readable',
    'All four corners of the document should be visible',
    'Document should be issued within last 3 months',
    'Your name and address should match your profile',
    'No photocopies - original documents only',
  ];

  @override
  void initState() {
    super.initState();
    _loadVerificationStatus();
  }

  Future<void> _loadVerificationStatus() async {
    final data = await _verificationService.loadVerificationStatus(
      VerificationDocuments.addressProof.documentId,
    );

    if (data != null) {
      final status = data['status'] ?? 'pending';
      final type = data['type'];
      final imageUrl = data['imageUrl'];
      final rejectionReason = data['rejectionReason'];

      setState(() {
        verificationStatus = status;
        selectedDocType = type;
        this.rejectionReason = rejectionReason;
      });

      // ✅ Load the uploaded image from URL into pickedImage
      if (imageUrl != null) {
        try {
          final httpClient = HttpClient();
          final request = await httpClient.getUrl(Uri.parse(imageUrl));
          final response = await request.close();
          final bytes = await consolidateHttpClientResponseBytes(response);
          final tempDir = await getTemporaryDirectory();
          final file = File('${tempDir.path}/uploaded_address.jpg');
          await file.writeAsBytes(bytes);

          setState(() {
            pickedImage = file;
            hasSubmittedDocument = true;
          });
        } catch (e) {
          debugPrint("Failed to load uploaded image: $e");
        }
      }
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    final permission = source == ImageSource.camera
        ? Permission.camera
        : Permission.photos;

    final granted = await permission.request();
    if (!granted.isGranted) return;

    final picked = await ImagePicker().pickImage(source: source);
    if (picked != null) {
      setState(() {
        pickedImage = File(picked.path);
        hasSubmittedDocument = false;
      });
    }
  }

  Future<void> _uploadImage() async {
    if (pickedImage == null || selectedDocType == null) return;

    setState(() {
      isLoading = true;
    });

    try {
      await _verificationService.submitVerificationDocument(
        config: VerificationDocuments.addressProof,
        uploadMethod: 'file',
        imageFile: pickedImage,
        fields: {'type': selectedDocType},
      );

      setState(() {
        verificationStatus = 'pending';
        hasSubmittedDocument = true;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Document uploaded for review.')),
      );

      await _loadVerificationStatus(); // re-fetch updated status
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  // ...keep all your existing _buildHeader(), _buildStepTile(), etc unchanged

  Widget _buildStatusCard() {
    IconData icon;
    Color color;
    String title, message, timeframe;

    switch (verificationStatus) {
      case 'verified':
        icon = LucideIcons.checkCircle;
        color = Colors.green;
        title = 'Address Verified!';
        message = 'Your address has been successfully verified';
        timeframe = 'Completed just now';
        break;
      case 'rejected':
        icon = LucideIcons.alertCircle;
        color = Colors.red;
        title = 'Verification Failed';
        message = rejectionReason ?? 'Please upload a valid document';
        timeframe = 'Try uploading again';
        break;
      case 'pending':
        icon = LucideIcons.eye;
        color = Colors.blue;
        title = 'Under Review';
        message = 'Our team is currently verifying your address proof';
        timeframe = 'This may take up to 24 hours';
        break;
      default:
        icon = LucideIcons.clock;
        color = Colors.orange;
        title = 'Verification Pending';
        message = 'Your document is being reviewed by our team';
        timeframe = 'Usually takes 2-4 hours';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        border: Border.all(color: color.withValues(alpha: 0.18)),
        borderRadius: BorderRadius.circular(WorkableDesign.radius),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontWeight: FontWeight.bold, color: color),
                ),
                const SizedBox(height: 4),
                Text(message),
                const SizedBox(height: 4),
                Text(
                  timeframe,
                  style: const TextStyle(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                if (verificationStatus == 'rejected') ...[
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => _pickImage(ImageSource.gallery),
                    child: const Text("Retry Upload"),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerificationSteps() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Verification Steps',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 12),
        Column(
          children: [
            _buildStepTile('1', 'Select document type', true),
            _buildStepTile('2', 'Upload clear photo', selectedDocType != null),
            _buildStepTile('3', 'Wait for verification', pickedImage != null),
          ],
        ),
      ],
    );
  }

  Widget _buildStepTile(String number, String label, bool isActive) {
    return Row(
      children: [
        CircleAvatar(
          radius: 12,
          backgroundColor: isActive ? Colors.blue : Colors.grey.shade400,
          child: Text(
            number,
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          label,
          style: TextStyle(color: isActive ? Colors.black : Colors.grey),
        ),
      ],
    );
  }

  Widget _buildDocumentTypeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select Document Type',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 12),
        Column(
          children: documentTypes.map((doc) {
            final isSelected = selectedDocType == doc['id'];
            return GestureDetector(
              onTap: () {
                setState(() {
                  selectedDocType = doc['id']?.toString();
                  pickedImage = null;
                });
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: isSelected ? Colors.blue : Colors.grey.shade300,
                  ),
                  borderRadius: BorderRadius.circular(10),
                  color: isSelected ? Colors.blue.shade50 : Colors.white,
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: isSelected
                          ? Colors.blue.shade100
                          : Colors.grey.shade200,
                      child: Icon(
                        doc['icon'] as IconData,
                        color: isSelected ? Colors.blue : Colors.grey,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                doc['name'] as String,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (doc['popular'] as bool)
                                Container(
                                  margin: const EdgeInsets.only(left: 6),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.green.shade100,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const Text(
                                    'Popular',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.green,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            doc['description'] as String,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    if (isSelected)
                      const Icon(
                        LucideIcons.checkCircle,
                        color: Colors.blue,
                        size: 20,
                      ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildUploadSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Upload Document',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(
              color: Colors.grey.shade300,
              style: BorderStyle.solid,
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            children: [
              if (pickedImage != null) ...[
                Image.file(pickedImage!, height: 150),
                const SizedBox(height: 12),
              ] else
                const Icon(LucideIcons.upload, size: 40, color: Colors.blue),

              const Text(
                'Upload your document',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 4),
              const Text(
                'Take a photo or upload from gallery',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 12),

              if (isLoading)
                const CircularProgressIndicator()
              else if (pickedImage != null && hasSubmittedDocument) ...[
                ElevatedButton.icon(
                  icon: const Icon(Icons.check_circle, color: Colors.white),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: WorkableDesign.success,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  onPressed: () {}, // Optional: Show details or confirmation
                  label: const Text("Document Uploaded"),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  icon: const Icon(Icons.edit, size: 16),
                  label: const Text("Re-upload"),
                  onPressed: () => _pickImage(ImageSource.gallery),
                ),
              ] else if (pickedImage != null) ...[
                FilledButton.icon(
                  icon: const Icon(LucideIcons.uploadCloud),
                  label: const Text("Submit for Review"),
                  onPressed: _uploadImage,
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  icon: const Icon(LucideIcons.refreshCw, size: 16),
                  label: const Text("Choose Different File"),
                  onPressed: () => _pickImage(ImageSource.gallery),
                ),
              ] else ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      icon: const Icon(LucideIcons.camera, size: 16),
                      label: const Text("Take Photo"),
                      onPressed: () => _pickImage(ImageSource.camera),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      icon: const Icon(LucideIcons.upload, size: 16),
                      label: const Text("From Gallery"),
                      onPressed: () => _pickImage(ImageSource.gallery),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRequirementTips() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: const [
            Icon(LucideIcons.info, color: Colors.blue),
            SizedBox(width: 6),
            Text(
              "Document Requirements",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...requirements.map(
          (req) => Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(LucideIcons.check, color: Colors.green, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  req,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: Colors.black87,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  PreferredSizeWidget _buildHeader() {
    return AppBar(
      leading: IconButton(
        icon: const Icon(LucideIcons.arrowLeft),
        onPressed: () => Navigator.pop(context),
      ),
      title: const Text(
        'Address Verification',
        style: TextStyle(fontWeight: FontWeight.w800),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WorkableDesign.canvas,
      appBar: _buildHeader(),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: Column(
            children: [
              const WorkablePageHeader(
                title: 'Address trust check',
                subtitle:
                    'Upload a current proof of address so bookings, invoices, and worker/customer trust stay reliable.',
                icon: LucideIcons.mapPin,
              ),
              const SizedBox(height: 16),
              _buildStatusCard(),
              const SizedBox(height: 20),
              _buildVerificationSteps(),
              const SizedBox(height: 24),
              _buildDocumentTypeSelector(),
              const SizedBox(height: 24),
              if (selectedDocType != null) _buildUploadSection(),
              const SizedBox(height: 24),
              _buildRequirementTips(),
            ],
          ),
        ),
      ),
    );
  }
}
