import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _addressController = TextEditingController(); // 🆕

  final AuthService _authService = AuthService();
  Position? _currentPosition;
  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchLocation(); // ✅ Automatically fetch location
  }

  String? _addressText; // 🆕 Add this as a class-level variable

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
      ); // ✅ This line is missing in your code

      if (placemarks.isNotEmpty) {
        final address = placemarks.first;
        _addressText =
            '${address.street}, ${address.locality}, ${address.administrativeArea}, ${address.postalCode}';

        _addressController.text = _addressText!; // 🆕 assign to controller
        print("📍 Address resolved: $_addressText");
      }

      setState(() {}); // Trigger UI update if needed
    } catch (e) {
      print("📍 Location fetch error: $e");
    }
  }

  void _handleGoogleSignup() async {
    if (_isLoading) return; // ✅ Prevent multiple taps
    setState(() => _isLoading = true);

    final userCredential = await _authService.signInWithGoogle(
      userType: 'customer',
    );

    if (userCredential != null) {
      final uid = userCredential.user?.uid;
      if (uid != null && _currentPosition != null) {
        await FirebaseFirestore.instance.collection('users').doc(uid).update({
          'location': GeoPoint(
            _currentPosition!.latitude,
            _currentPosition!.longitude,
          ),
          'address': _addressController.text.trim(),
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
    if (_isLoading) return; // ✅ Prevent multiple taps
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final errorMessage = await _authService.signUpUser(
      email: _emailController.text.trim(),
      password: _passwordController.text.trim(),
      name: _nameController.text.trim(),
      userType: 'customer',
    );

    // ✅ If signup successful, save location to Firestore
    if (errorMessage == null) {
      final uid = _authService.currentUser?.uid;
      if (uid != null && _currentPosition != null) {
        await FirebaseFirestore.instance.collection('users').doc(uid).update({
          'location': GeoPoint(
            _currentPosition!.latitude,
            _currentPosition!.longitude,
          ),
          'address': _addressController.text.trim(),
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
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _addressController.dispose(); // This too ✅
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
                      if (value == null || value.isEmpty)
                        return 'Please confirm your password';
                      if (value != _passwordController.text)
                        return 'Passwords do not match';
                      return null;
                    },
                  ),

                  const SizedBox(height: 16),
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
