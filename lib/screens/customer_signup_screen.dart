import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:workable/screens/customer_dashboard_screen.dart';
import '../widgets/custom_button.dart';
import '../widgets/form_section.dart';
import '../services/auth_service.dart';
import 'package:geocoding/geocoding.dart';

class CustomerSignupScreen extends StatefulWidget {
  static const routeName = '/customer-signup';

  const CustomerSignupScreen({super.key});

  @override
  State<CustomerSignupScreen> createState() => _CustomerSignupScreenState();
}

class _CustomerSignupScreenState extends State<CustomerSignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController(); // ✅ NEW
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _addressController = TextEditingController();

  final AuthService _authService = AuthService();
  Position? _currentPosition;
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _addressText;

  // OTP Verification
  String _verificationId = '';
  String _enteredOtp = '';

  bool _otpSent = false;
  bool _isOtpSending = false;
  bool _isVerifyingOtp = false;
  bool _isPhoneVerified = false;

  @override
  void initState() {
    super.initState();
    _fetchLocation();
  }

  Future<void> _fetchLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please enable location services.")),
        );
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Location permission denied.")),
          );
          return;
        }
      }

      _currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final placemarks = await placemarkFromCoordinates(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
      );

      if (placemarks.isNotEmpty) {
        final address = placemarks.first;
        _addressText =
            '${address.street}, ${address.locality}, '
            '${address.administrativeArea}, ${address.postalCode}';
        _addressController.text = _addressText!;
        print("📍 Address resolved: $_addressText");
      }

      setState(() {});
    } catch (e) {
      print("📍 Location fetch error: $e");
    }
  }

  Future<void> _sendOtp() async {
    final phone = '+91${_phoneController.text.trim()}';

    if (_phoneController.text.trim().length != 10) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Enter valid phone number")));
      return;
    }

    setState(() {
      _otpSent = true;
      _isOtpSending = true;
      _isPhoneVerified = false;
    });

    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: phone,

        verificationCompleted: (PhoneAuthCredential credential) async {
          setState(() {
            _isPhoneVerified = true;
            _isOtpSending = false;
            _otpSent = false;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Phone verified automatically")),
          );
        },

        verificationFailed: (FirebaseAuthException e) {
          setState(() {
            _isOtpSending = false;
            _otpSent = false;
          });

          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(e.message ?? "OTP failed")));
        },

        codeSent: (verificationId, resendToken) {
          setState(() {
            _verificationId = verificationId;
            _isOtpSending = false;
          });

          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text("OTP sent")));
        },

        codeAutoRetrievalTimeout: (verificationId) {
          _verificationId = verificationId;
        },
      );
    } catch (e) {
      setState(() {
        _isOtpSending = false;
        _otpSent = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _verifyOtp() async {
    if (_enteredOtp.length != 6) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Enter 6 digit OTP")));
      return;
    }

    setState(() => _isVerifyingOtp = true);

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId,
        smsCode: _enteredOtp,
      );

      await FirebaseAuth.instance.signInWithCredential(credential);

      await FirebaseAuth.instance.signOut();

      setState(() {
        _isPhoneVerified = true;
        _otpSent = false;
        _isVerifyingOtp = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Phone verified successfully")),
      );
    } catch (e) {
      setState(() => _isVerifyingOtp = false);

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Invalid OTP")));
    }
  }

  void _handleGoogleSignup() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    final userCredential = await _authService.signInWithGoogle(
      userType: 'customer',
    );

    // if (userCredential != null) {
    //   final uid = userCredential.user?.uid;
    //   if (uid != null) {
    //     // ✅ Save phone + location for Google signup too
    //     await FirebaseFirestore.instance.collection('users').doc(uid).update({
    //       if (_currentPosition != null)
    //         'location': GeoPoint(
    //           _currentPosition!.latitude,
    //           _currentPosition!.longitude,
    //         ),
    //       if (_currentPosition != null)
    //         'address': _addressController.text.trim(),
    //       //'phone': _phoneController.text.trim(), // ✅ NEW
    //       'phoneNumber': '+91${_phoneController.text.trim()}',
    //       'phoneVerified': true,
    //     });
    //   }

    //   if (mounted) {
    //     Navigator.pushReplacementNamed(
    //       context,
    //       CustomerDashboardScreen.routeName,
    //     );
    //   }
    // } else {
    //   ScaffoldMessenger.of(
    //     context,
    //   ).showSnackBar(const SnackBar(content: Text("Google Sign-In failed")));
    // }

    if (userCredential != null) {
      final uid = userCredential.user?.uid;

      if (uid != null) {
        // SAVE MAIN USER DATA
        await FirebaseFirestore.instance.collection('users').doc(uid).update({
          if (_currentPosition != null)
            'location': GeoPoint(
              _currentPosition!.latitude,
              _currentPosition!.longitude,
            ),

          if (_currentPosition != null)
            'address': _addressController.text.trim(),

          'phoneNumber': '+91${_phoneController.text.trim()}',
          'phoneVerified': true,
        });

        // SAVE PHONE VERIFICATION DETAILS
        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('identityVerification')
            .doc('phone')
            .set({
              'number': '+91${_phoneController.text.trim()}',
              'status': 'verified',
              'verifiedAt': Timestamp.now(),
              'verificationMethod': 'signup_otp',
            });
      }

      if (mounted) {
        Navigator.pushReplacementNamed(
          context,
          CustomerDashboardScreen.routeName,
        );
      }
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Google Sign-In failed")));
    }

    setState(() => _isLoading = false);
  }

  void _submitSignup() async {
    if (_isLoading) return;
    if (!_formKey.currentState!.validate()) return;
    if (!_isPhoneVerified) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please verify phone number first")),
      );
      return;
    }

    setState(() => _isLoading = true);

    final errorMessage = await _authService.signUpUser(
      email: _emailController.text.trim(),
      password: _passwordController.text.trim(),
      name: _nameController.text.trim(),
      userType: 'customer',
      //phone: _phoneController.text.trim(), // ✅ NEW
      phone: '+91${_phoneController.text.trim()}',
    );

    if (errorMessage == null) {
      final uid = _authService.currentUser?.uid;
      if (uid != null && _currentPosition != null) {
        await FirebaseFirestore.instance.collection('users').doc(uid).update({
          'location': GeoPoint(
            _currentPosition!.latitude,
            _currentPosition!.longitude,
          ),
          'address': _addressController.text.trim(),
          //'phone': _phoneController.text.trim(), // ✅ NEW
          'phoneNumber': '+91${_phoneController.text.trim()}',
          'phoneVerified': true,
        });
      }

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
            title: const Text("Signup Failed"),
            content: Text(errorMessage),
            actions: [
              TextButton(
                child: const Text("OK"),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        );
      }
    }

    setState(() => _isLoading = false);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose(); // ✅ NEW
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Customer Sign Up"),
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
                Icons.person_add_alt,
                size: 80,
                color: Colors.deepPurple,
              ),
              const SizedBox(height: 20),
              const Text(
                "Create your customer account",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              FormSection(
                children: [
                  // Full name — unchanged
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: "Full Name",
                      prefixIcon: Icon(Icons.person),
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) =>
                        value != null && value.trim().length >= 2
                        ? null
                        : 'Enter your name',
                  ),
                  const SizedBox(height: 16),

                  // Email — unchanged
                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: "Email",
                      prefixIcon: Icon(Icons.email),
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) => value != null && value.contains('@')
                        ? null
                        : 'Enter a valid email',
                  ),
                  const SizedBox(height: 16),

                  // ✅ NEW — Phone number field
                  TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(10),
                    ],
                    decoration: const InputDecoration(
                      labelText: "Phone Number",
                      hintText: "10-digit mobile number",
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

                  ElevatedButton(
                    onPressed: (_isOtpSending || _isPhoneVerified)
                        ? null
                        : _sendOtp,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      minimumSize: const Size.fromHeight(50),
                    ),
                    child: _isOtpSending
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Text(
                            _isPhoneVerified ? "✓ Phone Verified" : "Send OTP",
                            style: const TextStyle(color: Colors.white),
                          ),
                  ),

                  if (_otpSent) ...[
                    const SizedBox(height: 12),

                    TextFormField(
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: "Enter OTP",
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.lock),
                      ),
                      onChanged: (val) => _enteredOtp = val,
                    ),

                    const SizedBox(height: 12),

                    ElevatedButton(
                      onPressed: _isVerifyingOtp ? null : _verifyOtp,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        minimumSize: const Size.fromHeight(50),
                      ),
                      child: _isVerifyingOtp
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text(
                              "Verify OTP",
                              style: TextStyle(color: Colors.white),
                            ),
                    ),
                  ],

                  if (_isPhoneVerified)
                    Container(
                      margin: const EdgeInsets.only(top: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green),
                      ),
                      child: Row(
                        children: const [
                          Icon(Icons.check_circle, color: Colors.green),
                          SizedBox(width: 8),
                          Text(
                            "Phone number verified",
                            style: TextStyle(color: Colors.green),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 16),

                  // Password — unchanged
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: "Password",
                      prefixIcon: const Icon(Icons.lock),
                      border: const OutlineInputBorder(),
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
                  const SizedBox(height: 16),

                  // Confirm password — unchanged
                  TextFormField(
                    controller: _confirmPasswordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: "Confirm Password",
                      prefixIcon: const Icon(Icons.lock_outline),
                      border: const OutlineInputBorder(),
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
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please confirm your password';
                      }
                      if (value != _passwordController.text) {
                        return 'Passwords do not match';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Address — unchanged
                  TextFormField(
                    controller: _addressController,
                    decoration: const InputDecoration(
                      labelText: "Address (auto-detected, editable)",
                      prefixIcon: Icon(Icons.location_on),
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 2,
                    validator: (value) =>
                        value != null && value.trim().isNotEmpty
                        ? null
                        : 'Please enter your address',
                  ),
                ],
              ),

              const SizedBox(height: 30),

              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : CustomButton(text: "Sign Up", onPressed: _submitSignup),

              const SizedBox(height: 10),

              ElevatedButton.icon(
                icon: const Icon(Icons.login),
                label: const Text("Continue with Google"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  minimumSize: const Size.fromHeight(50),
                  elevation: 1,
                  side: const BorderSide(color: Colors.grey),
                ),
                onPressed: _handleGoogleSignup,
              ),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Already have an account?"),
                  TextButton(
                    onPressed: () {
                      Navigator.pushNamed(context, '/customer-login');
                    },
                    child: const Text("Login"),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
