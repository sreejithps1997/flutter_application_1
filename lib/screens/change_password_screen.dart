import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../core/theme/workable_design.dart';
import '../widgets/workable_ui.dart';

class ChangePasswordScreen extends StatefulWidget {
  static const routeName = '/change-password';

  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _isProcessing = false;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submitChange() async {
    if (!_formKey.currentState!.validate() || _isProcessing) return;

    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email;
    if (user == null || email == null || email.isEmpty) {
      _showSnack('Please log in again to change your password.');
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final credential = EmailAuthProvider.credential(
        email: email,
        password: _currentPasswordController.text.trim(),
      );

      await user.reauthenticateWithCredential(credential);
      await user.updatePassword(_newPasswordController.text.trim());

      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'passwordUpdatedAt': FieldValue.serverTimestamp(),
        'securityUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;
      _showSnack('Password changed successfully.');
      Navigator.pop(context, true);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      _showSnack(_passwordErrorMessage(e));
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  String _passwordErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'wrong-password':
      case 'invalid-credential':
        return 'Current password is incorrect.';
      case 'weak-password':
        return 'New password is too weak.';
      case 'requires-recent-login':
        return 'Please log in again before changing password.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      default:
        return e.message ?? 'Unable to change password. Please try again.';
    }
  }

  String? _validateNewPassword(String? value) {
    final password = value?.trim() ?? '';
    if (password.length < 8) return 'Use at least 8 characters.';
    if (!RegExp(r'[A-Z]').hasMatch(password)) {
      return 'Add at least one uppercase letter.';
    }
    if (!RegExp(r'[a-z]').hasMatch(password)) {
      return 'Add at least one lowercase letter.';
    }
    if (!RegExp(r'\d').hasMatch(password)) return 'Add at least one number.';
    if (password == _currentPasswordController.text.trim()) {
      return 'New password must be different from current password.';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WorkableDesign.canvas,
      appBar: AppBar(
        title: const Text('Change Password'),
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(WorkableDesign.pagePadding),
          child: Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Column(
              children: [
                const WorkablePageHeader(
                  title: 'Protect your account',
                  subtitle:
                      'Update your password with a stronger one before sensitive profile or payment changes.',
                  icon: LucideIcons.shieldCheck,
                ),
                const SizedBox(height: 16),
                WorkableSectionCard(
                  child: Column(
                    children: [
                      _buildPasswordField(
                        label: 'Current password',
                        controller: _currentPasswordController,
                        obscure: _obscureCurrent,
                        onToggle: () =>
                            setState(() => _obscureCurrent = !_obscureCurrent),
                        validator: (value) => (value ?? '').trim().isEmpty
                            ? 'Enter your current password.'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      _buildPasswordField(
                        label: 'New password',
                        controller: _newPasswordController,
                        obscure: _obscureNew,
                        onToggle: () =>
                            setState(() => _obscureNew = !_obscureNew),
                        validator: _validateNewPassword,
                      ),
                      const SizedBox(height: 12),
                      _buildPasswordField(
                        label: 'Confirm new password',
                        controller: _confirmPasswordController,
                        obscure: _obscureConfirm,
                        onToggle: () =>
                            setState(() => _obscureConfirm = !_obscureConfirm),
                        validator: (value) {
                          if ((value ?? '').trim().isEmpty) {
                            return 'Confirm your new password.';
                          }
                          if (value!.trim() !=
                              _newPasswordController.text.trim()) {
                            return 'Passwords do not match.';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _buildPasswordRules(),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: _isProcessing ? null : _submitChange,
                  icon: _isProcessing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(LucideIcons.lock),
                  label: Text(
                    _isProcessing ? 'Updating...' : 'Update Password',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPasswordField({
    required String label,
    required TextEditingController controller,
    required bool obscure,
    required VoidCallback onToggle,
    required String? Function(String?) validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      textInputAction: TextInputAction.next,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(LucideIcons.lock),
        suffixIcon: IconButton(
          tooltip: obscure ? 'Show password' : 'Hide password',
          icon: Icon(obscure ? LucideIcons.eye : LucideIcons.eyeOff),
          onPressed: onToggle,
        ),
      ),
      validator: validator,
    );
  }

  Widget _buildPasswordRules() {
    return const WorkableSectionCard(
      color: WorkableDesign.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Password standard',
            style: TextStyle(
              color: WorkableDesign.ink,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 10),
          WorkableInfoRow(
            icon: LucideIcons.check,
            text: 'At least 8 characters.',
          ),
          SizedBox(height: 8),
          WorkableInfoRow(
            icon: LucideIcons.check,
            text: 'Includes uppercase, lowercase, and a number.',
          ),
          SizedBox(height: 8),
          WorkableInfoRow(
            icon: LucideIcons.check,
            text: 'Different from your current password.',
          ),
        ],
      ),
    );
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }
}
