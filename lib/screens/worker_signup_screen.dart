import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../services/auth_service.dart';
import '../../models/worker_onboarding_data.dart';
import 'package:workable/screens/worker_signup/step1_profile_screen.dart';

class WorkerSignupScreen extends StatefulWidget {
  static const routeName = '/worker-signup';
  const WorkerSignupScreen({super.key});

  @override
  State<WorkerSignupScreen> createState() => _WorkerSignupScreenState();
}

class _WorkerSignupScreenState extends State<WorkerSignupScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _fullNameController = TextEditingController();
  final _ageController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  final _authService = AuthService();
  final _picker = ImagePicker();

  // State flags
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

  // Test mode tracking
  bool _isTestMode = false;

  // ======== TEST NUMBER CONFIG ========
  bool _isTestNumber(String phone) {
    const testNumbers = ['+919999999999', '+91123456'];
    return testNumbers.contains(phone);
  }

  // ============ FIXED SIGN UP LOGIC ============
  Future<void> _submitSignup() async {
    // Validate all fields
    if (!_formKey.currentState!.validate()) {
      _showSnackbar("Please fill all required fields correctly");
      return;
    }

    if (!_isPhoneVerified) {
      _showSnackbar("Please verify your phone number first");
      return;
    }

    if (_profileImage == null) {
      _showSnackbar("Please select a profile image");
      return;
    }

    setState(() => _isLoading = true);

    try {
      print("DEBUG: Starting signup process...");

      // Step 1: Sign up with email and password, including profile image
      final signupResult = await _authService.signUpUser(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        name: _fullNameController.text.trim(),
        userType: 'worker',
        profileImage: _profileImage, // Pass the image file
      );

      // Check for signup errors
      if (signupResult != null) {
        throw Exception(signupResult);
      }

      // Step 2: Get the authenticated user
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception("Failed to get user after signup");
      }

      final uid = user.uid;
      print("DEBUG: User created successfully with UID: $uid");

      // Step 3: Get the profile image URL from Firestore (saved by AuthService)
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();

      final userData = userDoc.data();
      final profileImageUrl = userData?['profileImage'] ?? '';

      print("DEBUG: Profile image URL: $profileImageUrl");

      // Step 4: Create WorkerOnboardingData
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

      // Step 5: Save initial worker data
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
        // Initialize empty fields for onboarding
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
        'pricing': '₹300',
      });

      print("DEBUG: Worker data saved successfully");

      setState(() => _isLoading = false);

      // Success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isTestMode
                ? "Test account created! Starting onboarding..."
                : "Account created successfully! Starting onboarding...",
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );

      // Navigate to next step
      Navigator.pushReplacementNamed(
        context,
        Step1ProfileScreen.routeName,
        arguments: onboardingData,
      );
    } catch (e) {
      setState(() => _isLoading = false);

      String errorMessage = "Signup failed";

      if (e is FirebaseAuthException) {
        switch (e.code) {
          case 'email-already-in-use':
            errorMessage =
                "This email is already registered. Please use a different email or login.";
            break;
          case 'weak-password':
            errorMessage =
                "Password is too weak. Please use at least 6 characters.";
            break;
          case 'invalid-email':
            errorMessage = "Invalid email format. Please check your email.";
            break;
          case 'operation-not-allowed':
            errorMessage =
                "Email/password signup is not enabled. Please contact support.";
            break;
          default:
            errorMessage = e.message ?? "Authentication failed";
        }
      } else if (e is FirebaseException) {
        if (e.code.contains('storage')) {
          errorMessage =
              "Failed to upload profile image. Please check your internet connection and try again.";
        } else {
          errorMessage = "Firebase error: ${e.message}";
        }
      } else {
        errorMessage = e.toString().replaceAll('Exception: ', '');
      }

      print("Signup error: $e");
      _showErrorDialog(errorMessage);
    }
  }

  // ============ FIXED OTP VERIFICATION LOGIC ============
  Future<void> _sendOtp() async {
    final phone = '+91${_phoneController.text.trim()}';

    if (_phoneController.text.trim().length != 10) {
      _showSnackbar("Enter a valid 10-digit phone number");
      return;
    }

    setState(() {
      _otpSent = true;
      _isOtpSending = true;
      _isPhoneVerified = false;
      _isTestMode = _isTestNumber(phone);
    });

    if (_isTestMode) {
      // TEST MODE: Auto-verify without actual OTP
      await Future.delayed(const Duration(seconds: 1));
      setState(() {
        _isPhoneVerified = true;
        _isOtpSending = false;
        _otpSent = false;
      });
      _showSnackbar("Test number verified automatically!");
      return;
    }

    // PRODUCTION MODE: Real Firebase Phone Auth
    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: phone,
        timeout: const Duration(seconds: 60),
        verificationCompleted: (PhoneAuthCredential credential) async {
          // Auto-verification (rare on most devices)
          setState(() {
            _isPhoneVerified = true;
            _isOtpSending = false;
            _otpSent = false;
          });
          _showSnackbar("Phone number verified automatically!");
        },
        verificationFailed: (FirebaseAuthException e) {
          setState(() {
            _isOtpSending = false;
            _otpSent = false;
          });

          String errorMsg = "Verification failed";
          if (e.code == 'invalid-phone-number') {
            errorMsg = "Invalid phone number format";
          } else if (e.code == 'too-many-requests') {
            errorMsg = "Too many requests. Please try again later";
          } else {
            errorMsg = e.message ?? "Failed to send OTP";
          }

          _showSnackbar(errorMsg);
        },
        codeSent: (verificationId, resendToken) {
          setState(() {
            _verificationId = verificationId;
            _isOtpSending = false;
          });
          _showSnackbar("OTP sent to $phone");
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
      _showSnackbar("Failed to send OTP: ${e.toString()}");
    }
  }

  Future<void> _verifyOtpAndContinue() async {
    if (_enteredOtp.trim().length != 6) {
      _showSnackbar("Please enter the 6-digit OTP");
      return;
    }

    setState(() => _isVerifyingOtp = true);

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId,
        smsCode: _enteredOtp.trim(),
      );

      // Just verify the credential without signing in
      // We'll create the account with email/password later
      await FirebaseAuth.instance.signInWithCredential(credential);

      // Sign out immediately as we only wanted to verify the phone
      await FirebaseAuth.instance.signOut();

      setState(() {
        _isPhoneVerified = true;
        _isVerifyingOtp = false;
        _otpSent = false;
      });

      _showSnackbar("Phone number verified successfully!");
    } on FirebaseAuthException catch (e) {
      setState(() => _isVerifyingOtp = false);

      String errorMsg = "Invalid OTP";
      if (e.code == 'invalid-verification-code') {
        errorMsg = "Invalid OTP. Please check and try again";
      } else if (e.code == 'session-expired') {
        errorMsg = "OTP expired. Please request a new one";
      }

      _showSnackbar(errorMsg);
    } catch (e) {
      setState(() => _isVerifyingOtp = false);
      _showSnackbar("Verification failed: ${e.toString()}");
    }
  }

  // ============ UTILITY METHODS ============
  void _showSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 3)),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Signup Failed"),
        content: Text(message),
        actions: [
          TextButton(
            child: const Text("OK"),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Future<void> _pickImage() async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70, // Compress image to reduce size
      );

      if (picked != null) {
        setState(() => _profileImage = File(picked.path));
      }
    } catch (e) {
      _showSnackbar("Failed to pick image: ${e.toString()}");
    }
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _ageController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ============ UI BUILD ============
  @override
  Widget build(BuildContext context) {
    final isTest = _isTestNumber('+91${_phoneController.text.trim()}');

    return Scaffold(
      appBar: AppBar(
        title: const Text("Worker Sign Up"),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: ListView(
              children: [
                const Icon(
                  Icons.engineering,
                  size: 80,
                  color: Colors.deepPurple,
                ),
                const SizedBox(height: 20),
                const Text(
                  "Create your worker account",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),

                // Profile Image Picker
                GestureDetector(
                  onTap: _pickImage,
                  child: CircleAvatar(
                    radius: 70,
                    backgroundColor: Colors.grey[300],
                    backgroundImage: _profileImage != null
                        ? FileImage(_profileImage!)
                        : null,
                    child: _profileImage == null
                        ? Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(
                                Icons.camera_alt,
                                size: 40,
                                color: Colors.deepPurple,
                              ),
                              SizedBox(height: 4),
                              Text(
                                "Add Photo",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.deepPurple,
                                ),
                              ),
                            ],
                          )
                        : null,
                  ),
                ),
                const SizedBox(height: 8),
                if (_profileImage == null)
                  const Text(
                    "* Profile photo is required",
                    style: TextStyle(color: Colors.red, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                const SizedBox(height: 24),

                // Full Name
                _buildTextField(
                  controller: _fullNameController,
                  label: "Full Name",
                  icon: Icons.person,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return "Please enter your full name";
                    }
                    if (value.length < 3) {
                      return "Name must be at least 3 characters";
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Age
                _buildTextField(
                  controller: _ageController,
                  label: "Age",
                  icon: Icons.calendar_today,
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return "Please enter your age";
                    }
                    final age = int.tryParse(value);
                    if (age == null || age < 18 || age > 70) {
                      return "Age must be between 18 and 70";
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Gender
                DropdownButtonFormField<String>(
                  value: _selectedGender,
                  decoration: const InputDecoration(
                    labelText: "Gender",
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.transgender),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'Male', child: Text('Male')),
                    DropdownMenuItem(value: 'Female', child: Text('Female')),
                    DropdownMenuItem(value: 'Other', child: Text('Other')),
                  ],
                  onChanged: (val) =>
                      setState(() => _selectedGender = val ?? 'Male'),
                ),
                const SizedBox(height: 16),

                // Phone Number
                _buildTextField(
                  controller: _phoneController,
                  label: "Phone Number (10 digits)",
                  icon: Icons.phone,
                  keyboardType: TextInputType.phone,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return "Please enter your phone number";
                    }
                    if (!RegExp(r'^\d{10}$').hasMatch(value)) {
                      return "Please enter a valid 10-digit phone number";
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 8),

                // Send OTP Button
                ElevatedButton(
                  onPressed: (_isOtpSending || _isPhoneVerified)
                      ? null
                      : _sendOtp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: _isOtpSending
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          _isPhoneVerified
                              ? "✓ Phone Verified"
                              : (isTest ? "Verify Test Number" : "Send OTP"),
                          style: const TextStyle(color: Colors.white),
                        ),
                ),

                // OTP Input (only for real numbers)
                if (_otpSent && !isTest) ...[
                  const SizedBox(height: 12),
                  _buildTextField(
                    label: "Enter 6-digit OTP",
                    icon: Icons.lock,
                    keyboardType: TextInputType.number,
                    onChanged: (val) => _enteredOtp = val,
                    validator: (value) {
                      if (_otpSent && (value == null || value.length != 6)) {
                        return "Please enter the 6-digit OTP";
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: _isVerifyingOtp ? null : _verifyOtpAndContinue,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: _isVerifyingOtp
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            "Verify OTP",
                            style: TextStyle(color: Colors.white),
                          ),
                  ),
                ],

                // Phone Verified Indicator
                if (_isPhoneVerified)
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green),
                    ),
                    child: Row(
                      children: const [
                        Icon(Icons.check_circle, color: Colors.green, size: 20),
                        SizedBox(width: 8),
                        Text(
                          "Phone number verified",
                          style: TextStyle(color: Colors.green),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 16),

                // Email
                _buildTextField(
                  controller: _emailController,
                  label: "Email",
                  icon: Icons.email,
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your email';
                    }

                    if (!RegExp(
                      r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                    ).hasMatch(value)) {
                      return 'Please enter a valid email address';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Password
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
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                    ),
                    helperText:
                        "Must be at least 6 characters with 1 uppercase and 1 number",
                    helperStyle: const TextStyle(fontSize: 12),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a password';
                    }
                    if (value.length < 6) {
                      return 'Password must be at least 6 characters';
                    }
                    if (!RegExp(r'\d').hasMatch(value)) {
                      return 'Password must include at least one number';
                    }
                    if (!RegExp(r'[A-Z]').hasMatch(value)) {
                      return 'Password must include at least one uppercase letter';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 30),

                // Sign Up Button
                _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: Colors.deepPurple,
                        ),
                      )
                    : SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed:
                              (_isLoading ||
                                  !_isPhoneVerified ||
                                  _profileImage == null)
                              ? null
                              : _submitSignup,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepPurple,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            "Sign Up",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),

                const SizedBox(height: 16),

                // Test Mode Indicator
                if (isTest)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange),
                    ),
                    child: Row(
                      children: const [
                        Icon(Icons.info_outline, color: Colors.orange),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            "Test mode enabled - OTP verification skipped",
                            style: TextStyle(
                              color: Colors.orange,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 20),

                // Already have an account
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("Already have an account? "),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        "Login",
                        style: TextStyle(
                          color: Colors.deepPurple,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Helper method to build text fields
  Widget _buildTextField({
    TextEditingController? controller,
    String? label,
    IconData? icon,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
    Function(String)? onChanged,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: icon != null ? Icon(icon) : null,
        border: const OutlineInputBorder(),
      ),
      keyboardType: keyboardType,
      validator: validator,
      onChanged: onChanged,
    );
  }
}
