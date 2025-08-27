import 'package:flutter/material.dart';
import '../widgets/custom_button.dart';
import '../widgets/form_section.dart';

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

  void _submitChange() {
    if (_formKey.currentState!.validate()) {
      // TODO: Connect with backend and validate old password, update new one

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Password updated successfully")),
      );

      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
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
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.lock),
        suffixIcon: IconButton(
          icon: Icon(obscure ? Icons.visibility : Icons.visibility_off),
          onPressed: onToggle,
        ),
      ),
      validator: validator,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Change Password"),
        backgroundColor: Colors.deepPurple,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: ListView(
            children: [
              Icon(Icons.password, size: 80, color: Colors.deepPurple),
              SizedBox(height: 24),
              Text(
                "Update your password",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 24),

              FormSection(
                children: [
                  _buildPasswordField(
                    label: "Current Password",
                    controller: _currentPasswordController,
                    obscure: _obscureCurrent,
                    onToggle: () =>
                        setState(() => _obscureCurrent = !_obscureCurrent),
                    validator: (value) => value != null && value.length >= 6
                        ? null
                        : "Enter your current password",
                  ),
                  _buildPasswordField(
                    label: "New Password",
                    controller: _newPasswordController,
                    obscure: _obscureNew,
                    onToggle: () =>
                        setState(() => _obscureNew = !_obscureNew),
                    validator: (value) => value != null && value.length >= 6
                        ? null
                        : "New password must be at least 6 characters",
                  ),
                  _buildPasswordField(
                    label: "Confirm New Password",
                    controller: _confirmPasswordController,
                    obscure: _obscureConfirm,
                    onToggle: () =>
                        setState(() => _obscureConfirm = !_obscureConfirm),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return "Please confirm your password";
                      }
                      if (value != _newPasswordController.text) {
                        return "Passwords do not match";
                      }
                      return null;
                    },
                  ),
                ],
              ),

              CustomButton(
                text: "Save Changes",
                onPressed: _submitChange,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
