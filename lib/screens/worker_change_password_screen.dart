import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../widgets/custom_button.dart';
import '../widgets/form_section.dart';

class WorkerChangePasswordScreen extends StatefulWidget {
  static const routeName = '/worker-change-password';

  const WorkerChangePasswordScreen({super.key});

  @override
  State<WorkerChangePasswordScreen> createState() =>
      _WorkerChangePasswordScreenState();
}

class _WorkerChangePasswordScreenState
    extends State<WorkerChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isProcessing = false;

  Future<void> _submitChange() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isProcessing = true);

    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email;
    final currentPassword = _currentPasswordController.text.trim();
    final newPassword = _newPasswordController.text.trim();

    try {
      // Re-authenticate
      final cred = EmailAuthProvider.credential(
        email: email!,
        password: currentPassword,
      );
      await user!.reauthenticateWithCredential(cred);

      // Update password
      await user.updatePassword(newPassword);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Password changed successfully")),
        );
        Navigator.pop(context);
      }
    } on FirebaseAuthException catch (e) {
      String errorMsg = "Something went wrong";
      if (e.code == 'wrong-password') {
        errorMsg = "Current password is incorrect";
      } else if (e.code == 'requires-recent-login') {
        errorMsg = "Please log in again to change password";
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(errorMsg)));
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Change Password"),
        backgroundColor: Colors.deepPurple,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: ListView(
            children: [
              const Icon(Icons.lock, size: 80, color: Colors.deepPurple),
              const SizedBox(height: 20),
              const Text(
                "Update your password",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              FormSection(
                children: [
                  TextFormField(
                    controller: _currentPasswordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: "Current Password",
                      prefixIcon: Icon(Icons.lock_outline),
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) => value != null && value.length >= 6
                        ? null
                        : "Enter your current password",
                  ),
                  TextFormField(
                    controller: _newPasswordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: "New Password",
                      prefixIcon: Icon(Icons.lock),
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) => value != null && value.length >= 6
                        ? null
                        : "Password must be at least 6 characters",
                  ),
                  TextFormField(
                    controller: _confirmPasswordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: "Confirm Password",
                      prefixIcon: Icon(Icons.lock),
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) => value == _newPasswordController.text
                        ? null
                        : "Passwords do not match",
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _isProcessing
                  ? const Center(child: CircularProgressIndicator())
                  : CustomButton(
                      text: "Change Password",
                      onPressed: _submitChange,
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
