import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class ForgotPasswordScreen extends StatefulWidget {
  static const routeName = '/forgot-password';

  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  final AuthService _authService = AuthService();

  bool _isLoading = false;

  void _sendResetLink() async {
    if (_emailController.text.trim().isEmpty) return;

    setState(() => _isLoading = true);

    final error = await _authService.sendPasswordResetEmail(
      _emailController.text.trim(),
    );

    setState(() => _isLoading = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error ?? "Password reset email sent"),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final prefilledEmail =
        ModalRoute.of(context)?.settings.arguments as String?;

    if (prefilledEmail != null && _emailController.text.isEmpty) {
      _emailController.text = prefilledEmail;
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Forgot Password")),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Text(
              "Enter your email to receive reset link",
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 20),

            TextField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: "Email",
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 20),

            _isLoading
                ? const CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: _sendResetLink,
                    child: const Text("Send Reset Link"),
                  ),
          ],
        ),
      ),
    );
  }
}