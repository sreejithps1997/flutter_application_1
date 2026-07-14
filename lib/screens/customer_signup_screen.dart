import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

import '../core/theme/workable_design.dart';
import '../features/customer_signup/domain/customer_signup_state.dart';
import '../features/customer_signup/presentation/customer_signup_providers.dart';
import '../features/signup_referral/data/signup_referral_repository.dart';
import '../services/auth_service.dart';
import '../widgets/custom_button.dart';
import '../widgets/form_section.dart';
import 'customer_dashboard_screen.dart';

class CustomerSignupScreen extends ConsumerStatefulWidget {
  const CustomerSignupScreen({super.key});

  static const routeName = '/customer-signup';

  @override
  ConsumerState<CustomerSignupScreen> createState() =>
      _CustomerSignupScreenState();
}

class _CustomerSignupScreenState extends ConsumerState<CustomerSignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  final _addressController = TextEditingController();
  final _referralCodeController = TextEditingController();

  final _authService = AuthService();
  final _referralRepository = SignupReferralRepository();

  Position? _currentPosition;
  bool _locationRequested = false;
  bool _referralAutoFilled = false;
  bool _googleLoading = false;

  String? get _cleanReferralCode {
    final clean = _referralRepository.normalizeCode(
      _referralCodeController.text,
    );
    return clean.isEmpty ? null : clean;
  }

  @override
  void initState() {
    super.initState();
    _prefillReferralCode();
  }

  Future<void> _prefillReferralCode() async {
    final code = await _referralRepository.loadPendingCode();
    if (!mounted || code == null || _referralCodeController.text.isNotEmpty) {
      return;
    }
    setState(() {
      _referralCodeController.text = code;
      _referralAutoFilled = true;
    });
  }

  Future<void> _fetchLocation() async {
    setState(() => _locationRequested = true);
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!mounted) return;
      if (!serviceEnabled) {
        _showSnack('Please enable location services.');
        setState(() => _locationRequested = false);
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (!mounted) return;
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _showSnack('Location permission denied.');
        setState(() => _locationRequested = false);
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      if (!mounted) return;

      _currentPosition = position;
      if (placemarks.isNotEmpty) {
        final address = placemarks.first;
        _addressController.text = [
          address.street,
          address.locality,
          address.administrativeArea,
          address.postalCode,
        ].where((part) => (part ?? '').trim().isNotEmpty).join(', ');
      }
      setState(() {});
    } catch (error) {
      if (!mounted) return;
      _showSnack('Unable to fetch location. You can add it later.');
      setState(() => _locationRequested = false);
    }
  }

  Future<void> _sendOtp() async {
    await ref
        .read(customerSignupControllerProvider.notifier)
        .sendOtp(_phoneController.text);
  }

  Future<void> _verifyOtp() async {
    await ref
        .read(customerSignupControllerProvider.notifier)
        .verifyOtp(_otpController.text);
  }

  Future<void> _submitSignup() async {
    final signup = ref.read(customerSignupControllerProvider);
    if (signup.isSubmitting) return;
    if (!_formKey.currentState!.validate()) return;
    if (!signup.isPhoneVerified) {
      _showSnack('Please verify phone number first.');
      return;
    }

    try {
      await ref
          .read(customerSignupControllerProvider.notifier)
          .completePhoneSignup(
            phone: _phoneController.text,
            name: _nameController.text,
            email: _emailController.text,
            address: _addressController.text,
            referralCode: _cleanReferralCode,
            position: _currentPosition,
          );
      if (!mounted) return;
      Navigator.pushReplacementNamed(
        context,
        CustomerDashboardScreen.routeName,
      );
    } catch (error) {
      if (!mounted) return;
      _showFailure(error.toString().replaceFirst('Bad state: ', ''));
    }
  }

  Future<void> _handleGoogleSignup() async {
    final signup = ref.read(customerSignupControllerProvider);
    if (_googleLoading) return;
    if (!signup.isPhoneVerified) {
      _showSnack('Please verify phone number first.');
      return;
    }

    setState(() => _googleLoading = true);
    final userCredential = await _authService.signInWithGoogle(
      userType: 'customer',
    );

    try {
      final uid = userCredential?.user?.uid;
      if (uid == null) {
        _showSnack('Google Sign-In failed.');
        return;
      }

      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        if (_nameController.text.trim().isNotEmpty)
          'name': _nameController.text.trim(),
        if (_emailController.text.trim().isNotEmpty)
          'email': _emailController.text.trim(),
        'userType': 'customer',
        'phoneNumber': _normalizedPhone,
        'phone': _normalizedPhone,
        'phoneVerified': true,
        'authProvider': 'google_phone_verified',
        if (_currentPosition != null)
          'location': GeoPoint(
            _currentPosition!.latitude,
            _currentPosition!.longitude,
          ),
        if (_addressController.text.trim().isNotEmpty)
          'address': _addressController.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
        ..._referralRepository
            .attributionFromInput(
              _cleanReferralCode,
              source: 'customer_google_signup',
            )
            .toUserFields(),
      }, SetOptions(merge: true));

      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('identityVerification')
          .doc('phone')
          .set({
            'number': _normalizedPhone,
            'status': 'verified',
            'verifiedAt': FieldValue.serverTimestamp(),
            'verificationMethod': 'signup_otp',
          }, SetOptions(merge: true));

      if (_cleanReferralCode != null) {
        await _referralRepository.consumePendingCodeIfMatches(
          _cleanReferralCode,
        );
      }

      if (!mounted) return;
      Navigator.pushReplacementNamed(
        context,
        CustomerDashboardScreen.routeName,
      );
    } catch (error) {
      if (mounted) _showFailure(error.toString());
    } finally {
      if (mounted) setState(() => _googleLoading = false);
    }
  }

  String get _normalizedPhone {
    final digits = _phoneController.text.replaceAll(RegExp(r'[^0-9]'), '');
    return digits.length == 10 ? '+91$digits' : '+$digits';
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _showFailure(String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Signup Failed'),
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

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _otpController.dispose();
    _addressController.dispose();
    _referralCodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final signup = ref.watch(customerSignupControllerProvider);

    ref.listen<CustomerSignupState>(customerSignupControllerProvider, (
      previous,
      next,
    ) {
      final message = next.message;
      final error = next.error;
      if (message != null && message != previous?.message) {
        _showSnack(message);
        ref
            .read(customerSignupControllerProvider.notifier)
            .clearTransientMessages();
      } else if (error != null && error != previous?.error) {
        _showSnack(error);
        ref
            .read(customerSignupControllerProvider.notifier)
            .clearTransientMessages();
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Customer Sign Up')),
      backgroundColor: WorkableDesign.canvas,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: ListView(
            children: [
              const Icon(
                Icons.phone_iphone,
                size: 78,
                color: WorkableDesign.primary,
              ),
              const SizedBox(height: 20),
              const Text(
                'Create account with phone',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 6),
              const Text(
                'Verify your phone and continue. Name, email and address can be added now or later.',
                style: TextStyle(color: WorkableDesign.muted, height: 1.35),
              ),
              const SizedBox(height: 24),
              FormSection(
                children: [
                  _optionalTextField(
                    controller: _nameController,
                    label: 'Name (optional)',
                    icon: Icons.person,
                    validator: (value) {
                      final text = value?.trim() ?? '';
                      if (text.isEmpty || text.length >= 2) return null;
                      return 'Enter at least 2 characters';
                    },
                  ),
                  const SizedBox(height: 16),
                  _optionalTextField(
                    controller: _emailController,
                    label: 'Email (optional)',
                    icon: Icons.email,
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      final text = value?.trim() ?? '';
                      if (text.isEmpty || text.contains('@')) return null;
                      return 'Enter a valid email';
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(10),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Phone Number',
                      hintText: '10-digit mobile number',
                      prefixIcon: Icon(Icons.phone),
                      prefixText: '+91 ',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Enter your phone number';
                      }
                      if (value.trim().length != 10) {
                        return 'Enter a valid 10-digit phone number';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: (signup.isOtpSending || signup.isPhoneVerified)
                          ? null
                          : _sendOtp,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: WorkableDesign.primary,
                        minimumSize: const Size.fromHeight(50),
                      ),
                      child: signup.isOtpSending
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text(
                              signup.isPhoneVerified
                                  ? 'Phone Verified'
                                  : 'Send OTP',
                              style: const TextStyle(color: Colors.white),
                            ),
                    ),
                  ),
                  if (signup.otpSent) ...[
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _otpController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(6),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Enter OTP',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.lock),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: signup.isVerifyingOtp ? null : _verifyOtp,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: WorkableDesign.success,
                          minimumSize: const Size.fromHeight(50),
                        ),
                        child: signup.isVerifyingOtp
                            ? const CircularProgressIndicator(
                                color: Colors.white,
                              )
                            : const Text(
                                'Verify OTP',
                                style: TextStyle(color: Colors.white),
                              ),
                      ),
                    ),
                  ],
                  if (signup.isPhoneVerified) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: WorkableDesign.success.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: WorkableDesign.success.withValues(alpha: 0.28),
                        ),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.check_circle,
                            color: WorkableDesign.success,
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Phone verified. You can create your account now.',
                              style: TextStyle(color: WorkableDesign.success),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  _optionalTextField(
                    controller: _addressController,
                    label: 'Address/location (optional)',
                    icon: Icons.location_on,
                    maxLines: 2,
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: _locationRequested ? null : _fetchLocation,
                    icon: const Icon(Icons.my_location_outlined),
                    label: const Text('Use current location'),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _referralCodeController,
                    textCapitalization: TextCapitalization.characters,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Referral code (optional)',
                      prefixIcon: Icon(Icons.card_giftcard),
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      final clean =
                          value?.trim().replaceAll(
                            RegExp(r'[^a-zA-Z0-9]'),
                            '',
                          ) ??
                          '';
                      if (clean.isEmpty) return null;
                      if (clean.length < 4) {
                        return 'Enter a valid referral code';
                      }
                      return null;
                    },
                  ),
                  if (_referralAutoFilled) ...[
                    const SizedBox(height: 8),
                    const Text(
                      'Invite code filled automatically from your shared link.',
                      style: TextStyle(
                        color: WorkableDesign.success,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 30),
              signup.isSubmitting
                  ? const Center(child: CircularProgressIndicator())
                  : CustomButton(
                      text: 'Create Account',
                      onPressed: _submitSignup,
                    ),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                icon: const Icon(Icons.login),
                label: Text(
                  _googleLoading
                      ? 'Connecting...'
                      : 'Continue with Google after phone',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  minimumSize: const Size.fromHeight(50),
                  elevation: 1,
                  side: const BorderSide(color: Colors.grey),
                ),
                onPressed: _googleLoading ? null : _handleGoogleSignup,
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Already have an account?'),
                  TextButton(
                    onPressed: () =>
                        Navigator.pushNamed(context, '/customer-login'),
                    child: const Text('Login'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _optionalTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: const OutlineInputBorder(),
      ),
      validator: validator,
    );
  }
}
