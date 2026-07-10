import 'package:flutter/material.dart';
import 'package:workable/screens/worker_dashboard_screen.dart';

import '../core/theme/workable_design.dart';
import '../services/auth_service.dart';

class WorkerLoginScreen extends StatefulWidget {
  static const routeName = '/worker-login';

  const WorkerLoginScreen({super.key});

  @override
  State<WorkerLoginScreen> createState() => _WorkerLoginScreenState();
}

class _WorkerLoginScreenState extends State<WorkerLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailOrPhoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final AuthService _authService = AuthService();

  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _isPhone = false;

  void _detectInputType(String value) {
    final trimmed = value.trim();
    final isPhone = RegExp(r'^[0-9]+$').hasMatch(trimmed) && trimmed.isNotEmpty;
    if (isPhone != _isPhone) {
      setState(() => _isPhone = isPhone);
    }
  }

  bool _checkIsPhone(String value) {
    final trimmed = value.trim();
    return RegExp(r'^[0-9]+$').hasMatch(trimmed) && trimmed.isNotEmpty;
  }

  Future<void> _submitLogin() async {
    if (_isLoading) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final input = _emailOrPhoneController.text.trim();
    final isPhoneAtSubmit = _checkIsPhone(input);
    final loginEmail = isPhoneAtSubmit ? '$input@phone.workable.com' : input;

    final errorMessage = await _authService.loginUser(
      email: loginEmail,
      password: _passwordController.text.trim(),
      userType: 'worker',
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (errorMessage == null) {
      Navigator.pushReplacementNamed(context, WorkerDashboardScreen.routeName);
    } else {
      _showLoginError(errorMessage);
    }
  }

  void _showLoginError(String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Login Failed'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showForgotPasswordDialog() {
    final input = _emailOrPhoneController.text.trim();
    final isPhone = _checkIsPhone(input);
    final resetController = TextEditingController(text: isPhone ? '' : input);

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Reset Password'),
        content: TextFormField(
          controller: resetController,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            labelText: 'Email address',
            hintText: 'name@example.com',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final email = resetController.text.trim();
              Navigator.pop(dialogContext);
              final error = await _authService.sendPasswordResetEmail(email);
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(error ?? 'Password reset email sent.')),
              );
            },
            child: const Text('Send Link'),
          ),
        ],
      ),
    ).whenComplete(resetController.dispose);
  }

  @override
  void dispose() {
    _emailOrPhoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WorkableDesign.canvas,
      appBar: AppBar(backgroundColor: WorkableDesign.canvas),
      body: SafeArea(
        top: false,
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            children: [
              const SizedBox(height: 18),
              _buildHeader(),
              const SizedBox(height: 28),
              _buildLoginCard(),
              const SizedBox(height: 18),
              _buildTrustNote(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 70,
          height: 70,
          decoration: BoxDecoration(
            color: WorkableDesign.accent.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: WorkableDesign.accent.withValues(alpha: 0.12),
            ),
          ),
          child: const Icon(
            Icons.engineering_outlined,
            color: WorkableDesign.accent,
            size: 36,
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Welcome back.',
          style: TextStyle(
            color: WorkableDesign.ink,
            fontSize: 32,
            height: 1.06,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Continue managing active jobs, profile visibility, reviews, earnings, and payouts.',
          style: TextStyle(
            color: WorkableDesign.muted,
            fontSize: 15,
            height: 1.45,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildLoginCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: WorkableDesign.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildEmailOrPhoneField(WorkableDesign.accent),
          const SizedBox(height: 14),
          _buildPasswordField(),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _showForgotPasswordDialog,
              child: const Text('Forgot password?'),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _isLoading ? null : _submitLogin,
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Log In'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmailOrPhoneField(Color accentColor) {
    return TextFormField(
      controller: _emailOrPhoneController,
      onChanged: _detectInputType,
      keyboardType: TextInputType.emailAddress,
      textInputAction: TextInputAction.next,
      decoration: InputDecoration(
        labelText: 'Email or phone number',
        hintText: 'name@example.com or 10-digit phone',
        prefixIcon: Icon(
          _isPhone ? Icons.phone_outlined : Icons.email_outlined,
          color: accentColor,
        ),
        suffixIcon: _emailOrPhoneController.text.isNotEmpty
            ? Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 14,
                ),
                child: Text(
                  _isPhone ? 'Phone' : 'Email',
                  style: TextStyle(
                    color: accentColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              )
            : null,
      ),
      validator: _validateEmailOrPhone,
    );
  }

  Widget _buildPasswordField() {
    return TextFormField(
      controller: _passwordController,
      obscureText: _obscurePassword,
      textInputAction: TextInputAction.done,
      onFieldSubmitted: (_) => _submitLogin(),
      decoration: InputDecoration(
        labelText: 'Password',
        prefixIcon: const Icon(Icons.lock_outline),
        suffixIcon: IconButton(
          tooltip: _obscurePassword ? 'Show password' : 'Hide password',
          icon: Icon(
            _obscurePassword
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
          ),
          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
        ),
      ),
      validator: (value) => value != null && value.length >= 6
          ? null
          : 'Password must be at least 6 characters',
    );
  }

  String? _validateEmailOrPhone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Enter your email or phone number';
    }
    final trimmed = value.trim();
    final isPhone = RegExp(r'^[0-9]+$').hasMatch(trimmed);
    if (isPhone) {
      return trimmed.length == 10 ? null : 'Enter a valid 10-digit phone';
    }
    return trimmed.contains('@') ? null : 'Enter a valid email address';
  }

  Widget _buildTrustNote() {
    return const Row(
      children: [
        Icon(
          Icons.verified_user_outlined,
          color: WorkableDesign.muted,
          size: 18,
        ),
        SizedBox(width: 8),
        Expanded(
          child: Text(
            'Your worker profile, visibility checks, bookings, reviews, and payout status stay connected securely.',
            style: TextStyle(
              color: WorkableDesign.muted,
              fontSize: 12.5,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
