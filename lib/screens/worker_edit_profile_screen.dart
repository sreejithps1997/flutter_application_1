import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/custom_button.dart';
import '../widgets/form_section.dart';

class WorkerEditProfileScreen extends StatefulWidget {
  static const routeName = '/worker-edit-profile';

  const WorkerEditProfileScreen({super.key});

  @override
  State<WorkerEditProfileScreen> createState() =>
      _WorkerEditProfileScreenState();
}

class _WorkerEditProfileScreenState extends State<WorkerEditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final doc = await FirebaseFirestore.instance
        .collection('workers')
        .doc(uid)
        .get();

    final data = doc.data();
    if (data != null) {
      _nameController.text = data['name'] ?? '';
      _phoneController.text = data['phone'] ?? '';
      _addressController.text = data['address'] ?? '';
    }

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    await FirebaseFirestore.instance.collection('workers').doc(uid).update({
      'name': _nameController.text.trim(),
      'phone': _phoneController.text.trim(),
      'address': _addressController.text.trim(),
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Profile updated successfully")),
    );

    Navigator.pop(context);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Edit Worker Profile"),
        backgroundColor: Colors.deepPurple,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                child: ListView(
                  children: [
                    const Icon(
                      Icons.engineering,
                      size: 80,
                      color: Colors.deepPurple,
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      "Update your profile details",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 24),

                    FormSection(
                      children: [
                        TextFormField(
                          controller: _nameController,
                          decoration: const InputDecoration(
                            labelText: "Full Name",
                            prefixIcon: Icon(Icons.person),
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) =>
                              value != null && value.trim().isNotEmpty
                              ? null
                              : "Name cannot be empty",
                        ),
                        TextFormField(
                          controller: _phoneController,
                          decoration: const InputDecoration(
                            labelText: "Phone Number",
                            prefixIcon: Icon(Icons.phone),
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.phone,
                          validator: (value) =>
                              value != null && value.length >= 10
                              ? null
                              : "Enter a valid phone number",
                        ),
                        TextFormField(
                          controller: _addressController,
                          decoration: const InputDecoration(
                            labelText: "Address",
                            prefixIcon: Icon(Icons.location_on),
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) =>
                              value != null && value.trim().isNotEmpty
                              ? null
                              : "Address cannot be empty",
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),
                    CustomButton(text: "Save Changes", onPressed: _saveProfile),
                  ],
                ),
              ),
            ),
    );
  }
}
