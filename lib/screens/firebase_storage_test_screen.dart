import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

class FirebaseStorageTestScreen extends StatefulWidget {
  static const routeName = '/firebase-storage-test';

  const FirebaseStorageTestScreen({super.key});

  @override
  State<FirebaseStorageTestScreen> createState() =>
      _FirebaseStorageTestScreenState();
}

class _FirebaseStorageTestScreenState extends State<FirebaseStorageTestScreen> {
  File? selectedImage;
  String? downloadUrl;
  bool isLoading = false;

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() {
        selectedImage = File(picked.path);
      });
    }
  }

  Future<void> _uploadToFirebase() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      user = (await FirebaseAuth.instance.signInAnonymously()).user;
      print('Signed in anonymously as ${user?.uid}');
    }

    final uid = user?.uid;
    if (uid == null || selectedImage == null) return;

    setState(() {
      isLoading = true;
    });

    try {
      final ref = FirebaseStorage.instance.ref().child(
        'users/$uid/testUploads/test_file.jpg',
      );

      final uploadTask = ref.putFile(selectedImage!);
      await uploadTask.whenComplete(() {});
      final url = await ref.getDownloadURL();

      setState(() {
        downloadUrl = url;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('✅ Upload successful!')));
    } catch (e) {
      print('Upload error: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('❌ Upload failed: $e')));
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Firebase Storage Test')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            if (selectedImage != null)
              Image.file(selectedImage!, height: 150)
            else
              const Text('No image selected'),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _pickImage,
              child: const Text('Pick Image'),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: isLoading ? null : _uploadToFirebase,
              child: isLoading
                  ? const CircularProgressIndicator()
                  : const Text('Upload to Firebase'),
            ),
            const SizedBox(height: 20),
            if (downloadUrl != null)
              Text(
                'Download URL:\n$downloadUrl',
                style: const TextStyle(fontSize: 12),
              ),
          ],
        ),
      ),
    );
  }
}
