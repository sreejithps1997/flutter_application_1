import 'package:flutter/material.dart';
import 'package:workable/screens/worker_dashboard_screen.dart';
import '../../services/auth_service.dart';

class WorkerLoginScreen extends StatefulWidget {
  static const routeName = '/worker-login';

  const WorkerLoginScreen({super.key});

  @override
  State<WorkerLoginScreen> createState() => _WorkerLoginScreenState();
}

class _WorkerLoginScreenState extends State<WorkerLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  final AuthService _authService = AuthService();

  bool _obscurePassword = true;
  bool _isLoading = false;

  Future<void> _submitLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final errorMessage = await _authService.loginUser(
      email: _emailController.text.trim(),
      password: _passwordController.text.trim(),
    );

    if (!mounted) return;

    setState(() => _isLoading = false);

    if (errorMessage == null) {
      Navigator.pushReplacementNamed(context, WorkerDashboardScreen.routeName);
    } else {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text("Login Failed"),
          content: Text(errorMessage),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("OK"),
            ),
          ],
        ),
      );
    }
  }

  void _showForgotPasswordDialog() {
    final TextEditingController _resetEmailController = TextEditingController(
      text: _emailController.text,
    );

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Reset Password"),
        content: TextFormField(
          controller: _resetEmailController,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            labelText: "Enter your email",
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              final email = _resetEmailController.text.trim();
              Navigator.pop(context); // Close the dialog

              final error = await _authService.sendPasswordResetEmail(email);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(error ?? "Password reset email sent.")),
              );
            },
            child: const Text("Send Reset Link"),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Worker Login"),
        backgroundColor: Colors.deepPurple,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: ListView(
            children: [
              const Icon(
                Icons.lock_outline,
                size: 80,
                color: Colors.deepPurple,
              ),
              const SizedBox(height: 20),
              const Text(
                "Log in to your worker account",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 32),

              // Email Field
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: "Email",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (value) => value != null && value.contains('@')
                    ? null
                    : 'Enter a valid email',
              ),
              const SizedBox(height: 16),

              // Password Field
              TextFormField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: "Password",
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.lock),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility
                          : Icons.visibility_off,
                    ),
                    onPressed: () => setState(() {
                      _obscurePassword = !_obscurePassword;
                    }),
                  ),
                ),
                validator: (value) => value != null && value.length >= 6
                    ? null
                    : 'Password must be at least 6 characters',
              ),

              const SizedBox(height: 8), // spacing before forgot password
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _showForgotPasswordDialog,
                  child: const Text("Forgot Password?"),
                ),
              ),
              const SizedBox(height: 30),
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _submitLogin,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepPurple,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text(
                          "Log In",
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
