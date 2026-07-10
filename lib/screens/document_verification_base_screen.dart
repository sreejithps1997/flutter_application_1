import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

class DocumentVerificationBaseScreen extends StatefulWidget {
  final String title;
  final String documentType; // e.g., 'aadhar', 'license'
  final String storagePath; // e.g., 'aadhar_cards'
  final Future<Map<String, String>> Function(File) extractor;
  final bool Function(String number) validator;

  const DocumentVerificationBaseScreen({
    super.key,
    required this.title,
    required this.documentType,
    required this.storagePath,
    required this.extractor,
    required this.validator,
  });

  @override
  State<DocumentVerificationBaseScreen> createState() =>
      _DocumentVerificationBaseScreenState();
}

class _DocumentVerificationBaseScreenState
    extends State<DocumentVerificationBaseScreen> {
  int step = 1;
  String? uploadMethod;
  File? imageFile;
  String number = '';
  String name = '';
  bool isLoading = false;
  bool isOcrProcessing = false;
  bool showNumber = false;
  final picker = ImagePicker();
  final TextEditingController numberController = TextEditingController();
  final TextEditingController nameController = TextEditingController();

  Future<File> compress(File file) async {
    final targetPath =
        '${file.parent.path}/compressed_${file.uri.pathSegments.last}';

    final result = await FlutterImageCompress.compressAndGetFile(
      file.absolute.path,
      targetPath,
      quality: 85,
      minWidth: 1024,
      minHeight: 1024,
    );

    return result != null ? File(result.path) : file;
  }

  Future<void> pickImage(ImageSource source) async {
    final picked = await picker.pickImage(source: source, imageQuality: 80);
    if (picked == null) return;

    setState(() {
      isOcrProcessing = true;
      uploadMethod = source == ImageSource.camera ? 'camera' : 'file';
    });

    final file = await compress(File(picked.path));
    final data = await widget.extractor(file);

    setState(() {
      imageFile = file;
      number = data['number'] ?? '';
      name = data['name'] ?? '';
      numberController.text = number;
      nameController.text = name;
      isOcrProcessing = false;
    });

    if (number.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('OCR failed. Try again or enter manually.'),
        ),
      );
    }
  }

  void goToReview() {
    if (uploadMethod == 'manual') {
      if (!widget.validator(numberController.text.trim())) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Invalid format')));
        return;
      }
    }
    setState(() => step = 2);
  }

  Future<void> submit() async {
    if (isLoading || isOcrProcessing) return;

    setState(() => isLoading = true);
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
    final storageRef = FirebaseStorage.instance.ref(
      'users/$uid/identityVerification/${widget.storagePath}/$fileName',
    );
    await storageRef.putFile(imageFile!);
    final url = await storageRef.getDownloadURL();

    final docRef = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('identityVerification')
        .doc(widget.documentType);

    await docRef.set({
      'number': numberController.text.trim(),
      'name': nameController.text.trim(),
      'uploadMethod': uploadMethod,
      'imageUrl': url,
      'status': 'pending',
      'submittedAt': Timestamp.now(),
    });

    setState(() {
      isLoading = false;
      step = 3;
    });

    Future.delayed(const Duration(seconds: 2), () {
      Navigator.pop(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: step == 1
          ? buildStep1()
          : step == 2
          ? buildStep2()
          : buildStep3(),
    );
  }

  Widget buildStep1() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const Text(
            'Select Upload Method:',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              ElevatedButton.icon(
                onPressed: () => pickImage(ImageSource.camera),
                icon: const Icon(Icons.camera_alt),
                label: const Text('Camera'),
              ),
              ElevatedButton.icon(
                onPressed: () => pickImage(ImageSource.gallery),
                icon: const Icon(Icons.upload_file),
                label: const Text('Upload'),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    uploadMethod = 'manual';
                    step = 2;
                  });
                },
                icon: const Icon(Icons.edit),
                label: const Text('Manual'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget buildStep2() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          if (uploadMethod != 'manual' && imageFile != null) ...[
            const Text('Document Preview:'),
            const SizedBox(height: 8),
            Image.file(imageFile!, height: 200),
          ],
          if (uploadMethod == 'manual' || number.isNotEmpty) ...[
            const SizedBox(height: 16),
            TextField(
              controller: numberController,
              decoration: const InputDecoration(labelText: 'Document Number'),
            ),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Full Name'),
            ),
          ],
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: isLoading || isOcrProcessing ? null : submit,
            child: isLoading
                ? const CircularProgressIndicator()
                : const Text('Submit for Verification'),
          ),
        ],
      ),
    );
  }

  Widget buildStep3() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.verified, size: 80, color: Colors.green),
          SizedBox(height: 12),
          Text('Submitted Successfully!', style: TextStyle(fontSize: 18)),
        ],
      ),
    );
  }
}
