import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../widgets/custom_button.dart';
import '../widgets/form_section.dart';
import 'worker_edit_profile_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class WorkerProfileUpdateScreen extends StatefulWidget {
  static const routeName = '/worker-profile-update';

  const WorkerProfileUpdateScreen({super.key});

  @override
  State<WorkerProfileUpdateScreen> createState() =>
      _WorkerProfileUpdateScreenState();
}

class _WorkerProfileUpdateScreenState extends State<WorkerProfileUpdateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  String? _deadlineText;

  File? _profileImage;
  @override
  void initState() {
    super.initState();
    _loadWorkerProfile();
  }

  Future<void> _loadWorkerProfile() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final doc = await FirebaseFirestore.instance
        .collection('workers')
        .doc(uid)
        .get();
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();

    if (doc.exists) {
      final data = doc.data();
      print("Fetched worker data: $data");

      setState(() {
        _nameController.text = data?['fullName'] ?? data?['name'] ?? '';
        _emailController.text = data?['email'] ?? '';
        _phoneController.text = data?['phoneNumber'] ?? '';
        _addressController.text = data?['address'] ?? '';
      });
    }

    // 🧠 Fetch verification start time
    final verification = userDoc.data()?['verification'];
    if (verification != null && verification['startAt'] != null) {
      final Timestamp ts = verification['startAt'];
      final startDate = ts.toDate();
      final deadline = startDate.add(const Duration(days: 14));
      final daysLeft = deadline.difference(DateTime.now()).inDays;

      setState(() {
        _deadlineText = daysLeft >= 0
            ? "⚠️ You have $daysLeft day(s) left to complete address and police verification."
            : "❌ Deadline missed. Your account may be restricted.";
      });
    }
  }

  final _picker = ImagePicker();

  Future<void> _pickProfileImage() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() => _profileImage = File(picked.path));
    }
  }

  void _submitUpdate() async {
    if (_formKey.currentState!.validate()) {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        await FirebaseFirestore.instance.collection('workers').doc(uid).update({
          'name': _nameController.text.trim(),
          'email': _emailController.text.trim(),
          'phoneNumber': _phoneController.text.trim(),
          'location': _addressController.text.trim(),
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Profile updated successfully!")),
        );
      }
    }
  }

  void _goToEditProfile() {
    Navigator.pushNamed(context, WorkerEditProfileScreen.routeName);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Update Profile"),
        backgroundColor: Colors.deepPurple,
        automaticallyImplyLeading: false, // ✅ Fixes the double back arrow issue

        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: "Go to Edit Profile",
            onPressed: _goToEditProfile,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: ListView(
            children: [
              Center(
                child: GestureDetector(
                  onTap: _pickProfileImage,
                  child: CircleAvatar(
                    radius: 50,
                    backgroundColor: Colors.deepPurple.shade100,
                    backgroundImage: _profileImage != null
                        ? FileImage(_profileImage!)
                        : null,
                    child: _profileImage == null
                        ? const Icon(
                            Icons.camera_alt,
                            size: 32,
                            color: Colors.deepPurple,
                          )
                        : null,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              FormSection(
                children: [
                  _buildTextField(
                    controller: _nameController,
                    label: "Full Name",
                    icon: Icons.person,
                    validator: (val) => val != null && val.trim().isNotEmpty
                        ? null
                        : "Enter your name",
                  ),
                  _buildTextField(
                    controller: _emailController,
                    label: "Email",
                    icon: Icons.email,
                    keyboardType: TextInputType.emailAddress,
                    validator: (val) => val != null && val.contains('@')
                        ? null
                        : "Enter a valid email",
                  ),
                  _buildTextField(
                    controller: _phoneController,
                    label: "Phone Number",
                    icon: Icons.phone,
                    keyboardType: TextInputType.phone,
                    validator: (val) => val != null && val.length >= 10
                        ? null
                        : "Enter a valid number",
                  ),
                  _buildTextField(
                    controller: _addressController,
                    label: "Address",
                    icon: Icons.location_on,
                    validator: (val) => val != null && val.trim().isNotEmpty
                        ? null
                        : "Enter your address",
                  ),
                ],
              ),

              if (_deadlineText != null) ...[
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    _deadlineText!,
                    style: const TextStyle(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
              CustomButton(text: "Update Profile", onPressed: _submitUpdate),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? Function(String?)? validator,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: const OutlineInputBorder(),
      ),
    );
  }
}
