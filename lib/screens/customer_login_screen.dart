import 'package:flutter/material.dart';
import 'package:workable/screens/customer_dashboard_screen.dart';
import '../widgets/custom_button.dart';
import '../widgets/form_section.dart';
import '../services/auth_service.dart';

class CustomerLoginScreen extends StatefulWidget {
  static const routeName = '/customer-login';

  const CustomerLoginScreen({super.key});

  @override
  State<CustomerLoginScreen> createState() => _CustomerLoginScreenState();
}

class _CustomerLoginScreenState extends State<CustomerLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  final AuthService _authService = AuthService();

  bool _obscurePassword = true;
  bool _isLoading = false;

  void _submitLogin() async {
    if (_isLoading) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final errorMessage = await _authService.loginUser(
      email: _emailController.text.trim(),
      password: _passwordController.text.trim(),
    );

    setState(() => _isLoading = false);

    if (errorMessage == null) {
      if (mounted) {
        Navigator.pushReplacementNamed(
          context,
          CustomerDashboardScreen.routeName,
        );
      }
    } else {
      if (mounted) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: Text("Login Failed"),
            content: Text(errorMessage),
            actions: [
              TextButton(
                child: Text("OK"),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        );
      }
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
              Navigator.pop(context); // close dialog

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
        title: Text("Customer Login"),
        backgroundColor: Colors.deepPurple,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: ListView(
            children: [
              Icon(Icons.lock_outline, size: 80, color: Colors.deepPurple),
              SizedBox(height: 20),
              Text(
                "Log in to your customer account",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 32),
              FormSection(
                children: [
                  TextFormField(
                    controller: _emailController,
                    decoration: InputDecoration(
                      labelText: "Email",
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.email),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) => value != null && value.contains('@')
                        ? null
                        : 'Enter a valid email',
                  ),
                  SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: "Password",
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.lock),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility
                              : Icons.visibility_off,
                        ),
                        onPressed: () => setState(
                          () => _obscurePassword = !_obscurePassword,
                        ),
                      ),
                    ),
                    validator: (value) => value != null && value.length >= 6
                        ? null
                        : 'Password must be at least 6 characters',
                  ),
                  SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _showForgotPasswordDialog,
                      child: const Text("Forgot Password?"),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 20),
              _isLoading
                  ? Center(child: CircularProgressIndicator())
                  : CustomButton(text: "Log In", onPressed: _submitLogin),
            ],
          ),
        ),
      ),
    );
  }
}
