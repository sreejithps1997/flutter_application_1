import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../core/theme/workable_design.dart';
import '../models/worker_onboarding_data.dart';
import '../services/auth_service.dart';
import '../widgets/worker_onboarding_shell.dart';
import 'worker_signup/step1_profile_screen.dart';

class WorkerSignupScreen extends StatefulWidget {
  static const routeName = '/worker-signup';

  const WorkerSignupScreen({super.key});

  @override
  State<WorkerSignupScreen> createState() => _WorkerSignupScreenState();
}

class _WorkerSignupScreenState extends State<WorkerSignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _ageController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _referralCodeController = TextEditingController();
  final _authService = AuthService();
  final _picker = ImagePicker();

  String _selectedGender = 'Male';
  File? _profileImage;
  String _verificationId = '';
  String _enteredOtp = '';

  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _otpSent = false;
  bool _isOtpSending = false;
  bool _isVerifyingOtp = false;
  bool _isPhoneVerified = false;
  bool _isTestMode = false;

  String? get _cleanReferralCode {
    final clean = _referralCodeController.text
        .trim()
        .replaceAll(RegExp(r'[^a-zA-Z0-9]'), '')
        .toUpperCase();
    return clean.isEmpty ? null : clean;
  }

  bool _isTestNumber(String phone) {
    const testNumbers = ['+919999999999', '+91123456'];
    return testNumbers.contains(phone);
  }

  Future<void> _submitSignup() async {
    if (_isLoading) return;
    if (!_formKey.currentState!.validate()) {
      _showSnackbar('Please fill all required fields correctly.');
      return;
    }
    if (!_isPhoneVerified) {
      _showSnackbar('Please verify your phone number first.');
      return;
    }
    if (_profileImage == null) {
      _showSnackbar('Please add a clear profile photo.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final signupResult = await _authService.signUpUser(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        name: _fullNameController.text.trim(),
        userType: 'worker',
        phone: _phoneController.text.trim(),
        profileImage: _profileImage,
      );

      if (signupResult != null) {
        throw Exception(signupResult);
      }

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('Failed to get user after signup');
      }

      final uid = user.uid;
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'phoneNumber': '+91${_phoneController.text.trim()}',
        'phoneVerified': true,
        if (_cleanReferralCode != null) 'referredByCode': _cleanReferralCode,
        if (_cleanReferralCode != null)
          'referralStatus': 'pending_backend_check',
      }, SetOptions(merge: true));

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      final userData = userDoc.data();
      final profileImageUrl = userData?['profileImage'] ?? '';

      final onboardingData = WorkerOnboardingData(
        uid: uid,
        fullName: _fullNameController.text.trim(),
        phone: _phoneController.text.trim(),
        phoneNumber: _phoneController.text.trim(),
        gender: _selectedGender,
        age: int.tryParse(_ageController.text.trim()) ?? 0,
        email: _emailController.text.trim(),
        consent: true,
        profileImageUrl: profileImageUrl,
        imagePicked: profileImageUrl.isNotEmpty,
      );

      await FirebaseFirestore.instance.collection('workers').doc(uid).set({
        'uid': uid,
        'fullName': onboardingData.fullName,
        'phone': onboardingData.phone,
        'phoneNumber': onboardingData.phoneNumber,
        'gender': onboardingData.gender,
        'age': onboardingData.age,
        'email': onboardingData.email,
        'profileImageUrl': profileImageUrl,
        'consent': true,
        'imagePicked': profileImageUrl.isNotEmpty,
        'isTestUser': _isTestMode,
        'createdAt': FieldValue.serverTimestamp(),
        'workerStatus': 'onboarding',
        'profileVisibility': false,
        'visibilityBlockedReason': 'Complete onboarding and verification',
        'skills': [],
        'experienceLevel': '',
        'paymentMethod': '',
        'schedule': {},
        'primaryIdType': '',
        'location': '',
        'address': '',
        'city': '',
        'pincode': '',
        'serviceRadius': 2,
        'latitude': 0.0,
        'longitude': 0.0,
        'wageMap': {},
        'isOnboardingComplete': false,
        'averageRating': 0.0,
        'completedJobsCount': 0,
        'earnings': 0.0,
        'pricing': 'Rs 300',
      });

      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isTestMode
                ? 'Test account created. Continue profile setup.'
                : 'Account created. Continue profile setup.',
          ),
          backgroundColor: WorkableDesign.success,
        ),
      );

      Navigator.pushReplacementNamed(
        context,
        Step1ProfileScreen.routeName,
        arguments: onboardingData,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showErrorDialog(_friendlySignupError(e));
    }
  }

  String _friendlySignupError(Object e) {
    if (e is FirebaseAuthException) {
      switch (e.code) {
        case 'email-already-in-use':
          return 'This email is already registered. Please log in or use another email.';
        case 'weak-password':
          return 'Password is too weak. Use at least 6 characters with a number and uppercase letter.';
        case 'invalid-email':
          return 'Invalid email format. Please check your email.';
        case 'operation-not-allowed':
          return 'Email/password signup is not enabled. Please contact support.';
        default:
          return e.message ?? 'Authentication failed.';
      }
    }
    if (e is FirebaseException) {
      return e.message ?? 'Firebase error. Please try again.';
    }
    return e.toString().replaceAll('Exception: ', '');
  }

  Future<void> _sendOtp() async {
    final phone = '+91${_phoneController.text.trim()}';

    if (!RegExp(r'^\d{10}$').hasMatch(_phoneController.text.trim())) {
      _showSnackbar('Enter a valid 10-digit phone number.');
      return;
    }

    setState(() {
      _otpSent = true;
      _isOtpSending = true;
      _isPhoneVerified = false;
      _isTestMode = _isTestNumber(phone);
    });

    if (_isTestMode) {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return;
      setState(() {
        _isPhoneVerified = true;
        _isOtpSending = false;
        _otpSent = false;
      });
      _showSnackbar('Test number verified automatically.');
      return;
    }

    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: phone,
        timeout: const Duration(seconds: 60),
        verificationCompleted: (_) {
          if (!mounted) return;
          setState(() {
            _isPhoneVerified = true;
            _isOtpSending = false;
            _otpSent = false;
          });
          _showSnackbar('Phone number verified automatically.');
        },
        verificationFailed: (FirebaseAuthException e) {
          if (!mounted) return;
          setState(() {
            _isOtpSending = false;
            _otpSent = false;
          });
          _showSnackbar(_friendlyOtpError(e));
        },
        codeSent: (verificationId, resendToken) {
          if (!mounted) return;
          setState(() {
            _verificationId = verificationId;
            _isOtpSending = false;
          });
          _showSnackbar('OTP sent to $phone.');
        },
        codeAutoRetrievalTimeout: (verificationId) {
          _verificationId = verificationId;
        },
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isOtpSending = false;
        _otpSent = false;
      });
      _showSnackbar('Failed to send OTP. Please try again.');
    }
  }

  String _friendlyOtpError(FirebaseAuthException e) {
    if (e.code == 'invalid-phone-number') {
      return 'Invalid phone number format.';
    }
    if (e.code == 'too-many-requests') {
      return 'Too many requests. Please try again later.';
    }
    return e.message ?? 'Failed to send OTP.';
  }

  Future<void> _verifyOtpAndContinue() async {
    if (_enteredOtp.trim().length != 6) {
      _showSnackbar('Please enter the 6-digit OTP.');
      return;
    }

    setState(() => _isVerifyingOtp = true);

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId,
        smsCode: _enteredOtp.trim(),
      );

      await FirebaseAuth.instance.signInWithCredential(credential);
      await FirebaseAuth.instance.signOut();

      if (!mounted) return;
      setState(() {
        _isPhoneVerified = true;
        _isVerifyingOtp = false;
        _otpSent = false;
      });
      _showSnackbar('Phone number verified successfully.');
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() => _isVerifyingOtp = false);
      _showSnackbar(
        e.code == 'session-expired'
            ? 'OTP expired. Please request a new one.'
            : 'Invalid OTP. Please check and try again.',
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _isVerifyingOtp = false);
      _showSnackbar('Verification failed. Please try again.');
    }
  }

  void _showSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 3)),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Signup Failed'),
        content: Text(message),
        actions: [
          TextButton(
            child: const Text('OK'),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Future<void> _pickImage() async {
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
        maxWidth: 1024,
        maxHeight: 1024,
      );
      if (picked != null && mounted) {
        setState(() => _profileImage = File(picked.path));
      }
    } catch (_) {
      _showSnackbar('Failed to pick image. Please try again.');
    }
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _ageController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _referralCodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isTest = _isTestNumber('+91${_phoneController.text.trim()}');
    final canSubmit = !_isLoading && _isPhoneVerified && _profileImage != null;

    return WorkerOnboardingShell(
      title: 'Create your worker account',
      subtitle:
          'Start with a real identity, verified phone, and clear profile photo. This helps customers trust you before they book.',
      step: 1,
      totalSteps: 6,
      bottom: FilledButton(
        onPressed: canSubmit ? _submitSignup : null,
        child: _isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: Colors.white,
                ),
              )
            : const Text('Create Account'),
      ),
      children: [
        Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
            children: [
              _buildPhotoCard(),
              const SizedBox(height: 14),
              WorkerOnboardingCard(
                child: Column(
                  children: [
                    _buildTextField(
                      controller: _fullNameController,
                      label: 'Full name',
                      icon: Icons.person_outline,
                      textInputAction: TextInputAction.next,
                      validator: (value) {
                        final trimmed = value?.trim() ?? '';
                        if (trimmed.isEmpty) return 'Enter your full name';
                        if (trimmed.length < 3) {
                          return 'Name must be at least 3 characters';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                            controller: _ageController,
                            label: 'Age',
                            icon: Icons.cake_outlined,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            textInputAction: TextInputAction.next,
                            validator: (value) {
                              final age = int.tryParse(value ?? '');
                              if (age == null) return 'Enter age';
                              if (age < 18 || age > 70) {
                                return 'Age must be 18-70';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: _buildGenderField()),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _buildPhoneField(isTest),
                    if (_otpSent && !isTest) ...[
                      const SizedBox(height: 12),
                      _buildOtpField(),
                    ],
                    if (_isPhoneVerified) ...[
                      const SizedBox(height: 12),
                      _buildStatusPill(
                        icon: Icons.verified_outlined,
                        label: 'Phone number verified',
                        color: WorkableDesign.success,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 14),
              WorkerOnboardingCard(
                child: Column(
                  children: [
                    _buildTextField(
                      controller: _emailController,
                      label: 'Email address',
                      icon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      validator: (value) {
                        final trimmed = value?.trim() ?? '';
                        if (trimmed.isEmpty) return 'Enter your email';
                        return RegExp(
                              r'^[\w-.]+@([\w-]+\.)+[\w-]{2,4}$',
                            ).hasMatch(trimmed)
                            ? null
                            : 'Enter a valid email address';
                      },
                    ),
                    const SizedBox(height: 14),
                    _buildPasswordField(),
                    const SizedBox(height: 14),
                    _buildReferralField(),
                  ],
                ),
              ),
              if (isTest) ...[
                const SizedBox(height: 14),
                _buildStatusPill(
                  icon: Icons.info_outline,
                  label: 'Test mode: OTP verification will be skipped',
                  color: WorkableDesign.warning,
                ),
              ],
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Already have an account? Log in'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPhotoCard() {
    return WorkerOnboardingCard(
      child: Row(
        children: [
          GestureDetector(
            onTap: _pickImage,
            child: CircleAvatar(
              radius: 38,
              backgroundColor: WorkableDesign.accent.withValues(alpha: 0.1),
              backgroundImage: _profileImage != null
                  ? FileImage(_profileImage!)
                  : null,
              child: _profileImage == null
                  ? const Icon(
                      Icons.add_a_photo_outlined,
                      color: WorkableDesign.accent,
                      size: 30,
                    )
                  : null,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Profile photo',
                  style: TextStyle(
                    color: WorkableDesign.ink,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _profileImage == null
                      ? 'Add a clear face photo. Required for verification.'
                      : 'Photo added. You can tap to replace it.',
                  style: const TextStyle(
                    color: WorkableDesign.muted,
                    fontSize: 12.5,
                    height: 1.35,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          TextButton(onPressed: _pickImage, child: const Text('Add')),
        ],
      ),
    );
  }

  Widget _buildGenderField() {
    return DropdownButtonFormField<String>(
      value: _selectedGender,
      decoration: const InputDecoration(
        labelText: 'Gender',
        prefixIcon: Icon(Icons.badge_outlined),
      ),
      items: const [
        DropdownMenuItem(value: 'Male', child: Text('Male')),
        DropdownMenuItem(value: 'Female', child: Text('Female')),
        DropdownMenuItem(value: 'Other', child: Text('Other')),
      ],
      onChanged: (val) => setState(() => _selectedGender = val ?? 'Male'),
    );
  }

  Widget _buildPhoneField(bool isTest) {
    return Column(
      children: [
        _buildTextField(
          controller: _phoneController,
          label: 'Phone number',
          icon: Icons.phone_outlined,
          keyboardType: TextInputType.phone,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(10),
          ],
          textInputAction: TextInputAction.next,
          onChanged: (_) {
            if (_isPhoneVerified || _otpSent) {
              setState(() {
                _isPhoneVerified = false;
                _otpSent = false;
              });
            } else {
              setState(() {});
            }
          },
          validator: (value) => RegExp(r'^\d{10}$').hasMatch(value ?? '')
              ? null
              : 'Enter a valid 10-digit phone number',
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: (_isOtpSending || _isPhoneVerified) ? null : _sendOtp,
            icon: _isOtpSending
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    _isPhoneVerified
                        ? Icons.verified_outlined
                        : Icons.sms_outlined,
                  ),
            label: Text(
              _isPhoneVerified
                  ? 'Phone Verified'
                  : (isTest ? 'Verify Test Number' : 'Send OTP'),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOtpField() {
    return Column(
      children: [
        _buildTextField(
          label: 'Enter 6-digit OTP',
          icon: Icons.password_outlined,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(6),
          ],
          onChanged: (val) => _enteredOtp = val,
          validator: (value) {
            if (_otpSent && (value == null || value.length != 6)) {
              return 'Please enter the 6-digit OTP';
            }
            return null;
          },
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _isVerifyingOtp ? null : _verifyOtpAndContinue,
            icon: _isVerifyingOtp
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.verified_user_outlined),
            label: const Text('Verify OTP'),
          ),
        ),
      ],
    );
  }

  Widget _buildPasswordField() {
    return TextFormField(
      controller: _passwordController,
      obscureText: _obscurePassword,
      textInputAction: TextInputAction.done,
      decoration: InputDecoration(
        labelText: 'Password',
        helperText: 'Use 6+ characters, one uppercase letter, and one number.',
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
      validator: (value) {
        final password = value ?? '';
        if (password.isEmpty) return 'Please enter a password';
        if (password.length < 6) {
          return 'Password must be at least 6 characters';
        }
        if (!RegExp(r'\d').hasMatch(password)) {
          return 'Password must include at least one number';
        }
        if (!RegExp(r'[A-Z]').hasMatch(password)) {
          return 'Password must include one uppercase letter';
        }
        return null;
      },
    );
  }

  Widget _buildReferralField() {
    return _buildTextField(
      controller: _referralCodeController,
      label: 'Referral code (optional)',
      icon: Icons.card_giftcard_outlined,
      textCapitalization: TextCapitalization.characters,
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),
      ],
      validator: (value) {
        final clean =
            value?.trim().replaceAll(RegExp(r'[^a-zA-Z0-9]'), '') ?? '';
        if (clean.isEmpty) return null;
        if (clean.length < 4) return 'Enter a valid referral code';
        return null;
      },
    );
  }

  Widget _buildTextField({
    TextEditingController? controller,
    String? label,
    IconData? icon,
    TextInputType keyboardType = TextInputType.text,
    TextInputAction? textInputAction,
    List<TextInputFormatter>? inputFormatters,
    TextCapitalization textCapitalization = TextCapitalization.none,
    String? Function(String?)? validator,
    ValueChanged<String>? onChanged,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      inputFormatters: inputFormatters,
      textCapitalization: textCapitalization,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: icon != null ? Icon(icon) : null,
      ),
      validator: validator,
      onChanged: onChanged,
    );
  }

  Widget _buildStatusPill({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(WorkableDesign.radius),
        border: Border.all(color: color.withValues(alpha: 0.16)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 19),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
