import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

import '../widgets/custom_button.dart';

class ReportIssueScreen extends StatefulWidget {
  static const routeName = '/report-issue';

  const ReportIssueScreen({super.key});

  @override
  State<ReportIssueScreen> createState() => _ReportIssueScreenState();
}

class _ReportIssueScreenState extends State<ReportIssueScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController descriptionController = TextEditingController();

  final List<String> issueTypes = [
    'App Bug',
    'Payment Issue',
    'Fake Profile',
    'Booking Problem',
    'Abuse or Misconduct',
    'Other',
  ];

  String selectedIssueType = 'App Bug';
  File? selectedImage;
  bool isSubmitting = false;

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 60,
    );
    if (picked != null) {
      setState(() => selectedImage = File(picked.path));
    }
  }

  Future<void> _submitIssue() async {
    if (!_formKey.currentState!.validate()) return;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    setState(() => isSubmitting = true);

    await FirebaseFirestore.instance.collection('reported_issues').add({
      'userId': uid,
      'issueType': selectedIssueType,
      'description': descriptionController.text.trim(),
      'timestamp': Timestamp.now(),
    });

    setState(() => isSubmitting = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Issue reported successfully')),
      );
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Report an Issue'),
        backgroundColor: Colors.deepPurple,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text(
              'Help us improve by reporting issues you encounter.',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            Form(
              key: _formKey,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              child: Column(
                children: [
                  DropdownButtonFormField<String>(
                    value: selectedIssueType,
                    items: issueTypes.map((type) {
                      return DropdownMenuItem(value: type, child: Text(type));
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => selectedIssueType = value);
                      }
                    },
                    decoration: const InputDecoration(
                      labelText: 'Issue Type',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: descriptionController,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Describe the issue',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) => value == null || value.isEmpty
                        ? 'Please describe the issue'
                        : null,
                  ),
                  const SizedBox(height: 16),

                  if (selectedImage != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(selectedImage!, height: 100),
                    ),
                  TextButton.icon(
                    icon: const Icon(Icons.image),
                    label: const Text('Attach Screenshot (optional)'),
                    onPressed: _pickImage,
                  ),

                  const SizedBox(height: 20),
                  isSubmitting
                      ? const CircularProgressIndicator()
                      : CustomButton(
                          text: 'Submit Issue',
                          onPressed: _submitIssue,
                        ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
