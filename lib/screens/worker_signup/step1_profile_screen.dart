import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';

import 'step2_skills_screen.dart';
import 'package:workable/models/worker_onboarding_data.dart';
import 'package:workable/screens/map_picker_screen.dart';

class Step1ProfileScreen extends StatefulWidget {
  static const routeName = '/step1-profile';
  final WorkerOnboardingData onboardingData;

  const Step1ProfileScreen({super.key, required this.onboardingData});

  @override
  State<Step1ProfileScreen> createState() => _Step1ProfileScreenState();
}

class _Step1ProfileScreenState extends State<Step1ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _pincodeController = TextEditingController();
  int? _selectedRadius;
  LatLng? _currentLatLng;

  final List<int> _radiusOptions = [2, 5, 10, 20, 50];

  @override
  void initState() {
    super.initState();
    _addressController.text = widget.onboardingData.address.trim();
    _cityController.text = widget.onboardingData.city.trim();
    _pincodeController.text = widget.onboardingData.pincode.trim();

    if (_radiusOptions.contains(widget.onboardingData.serviceRadius)) {
      _selectedRadius = widget.onboardingData.serviceRadius;
    }

    if (widget.onboardingData.latitude != 0.0 &&
        widget.onboardingData.longitude != 0.0) {
      _currentLatLng = LatLng(
        widget.onboardingData.latitude,
        widget.onboardingData.longitude,
      );
    } else {
      _loadCurrentLocation();
    }
  }

  Future<void> _loadCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever ||
          permission == LocationPermission.denied)
        return;

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() {
        _currentLatLng = LatLng(position.latitude, position.longitude);
      });
    } catch (e) {
      debugPrint('📍 Failed to get location: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to get current location")),
      );
    }
  }

  void _continueToNextStep() {
    if (!_formKey.currentState!.validate() ||
        _currentLatLng == null ||
        _selectedRadius == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please fill all fields and allow location access."),
        ),
      );
      return;
    }

    final updatedData = widget.onboardingData.copyWith(
      address: _addressController.text.trim(),
      city: _cityController.text.trim(),
      pincode: _pincodeController.text.trim(),
      serviceRadius: _selectedRadius!,
      latitude: _currentLatLng!.latitude,
      longitude: _currentLatLng!.longitude,
      location: "${_currentLatLng!.latitude},${_currentLatLng!.longitude}",
    );

    Navigator.pushNamed(
      context,
      Step2SkillsScreen.routeName,
      arguments: updatedData,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(title: const Text("Location & Address")),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LinearProgressIndicator(value: 0.2, color: Colors.deepPurple),
              const SizedBox(height: 24),
              const Text(
                "Set your address and work location",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _addressController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Full Address',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) => value == null || value.isEmpty
                          ? 'Enter address'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _cityController,
                      decoration: const InputDecoration(
                        labelText: 'City',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) =>
                          value == null || value.isEmpty ? 'Enter city' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _pincodeController,
                      decoration: const InputDecoration(
                        labelText: 'Pincode',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) =>
                          value == null || !RegExp(r'^\d{6}$').hasMatch(value)
                          ? 'Enter valid 6-digit pincode'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<int>(
                      value: _selectedRadius,
                      decoration: const InputDecoration(
                        labelText: 'How far can you travel? (in km)',
                        border: OutlineInputBorder(),
                      ),
                      items: _radiusOptions
                          .map(
                            (radius) => DropdownMenuItem<int>(
                              value: radius,
                              child: Text('$radius km'),
                            ),
                          )
                          .toList(),
                      onChanged: (value) =>
                          setState(() => _selectedRadius = value),
                      validator: (value) =>
                          value == null ? 'Please select travel range' : null,
                    ),
                    const SizedBox(height: 20),
                    _currentLatLng == null
                        ? const Center(child: CircularProgressIndicator())
                        : GestureDetector(
                            onTap: () async {
                              final pickedLatLng = await Navigator.push<LatLng>(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => MapPickerScreen(
                                    initialLocation: _currentLatLng,
                                  ),
                                ),
                              );
                              if (pickedLatLng != null) {
                                setState(() => _currentLatLng = pickedLatLng);
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text("Location not selected."),
                                  ),
                                );
                              }
                            },
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "Current Service Location (tap to change)",
                                  style: TextStyle(fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 8),
                                SizedBox(
                                  height: 200,
                                  child: GoogleMap(
                                    initialCameraPosition: CameraPosition(
                                      target: _currentLatLng!,
                                      zoom: 15,
                                    ),
                                    markers: {
                                      Marker(
                                        markerId: const MarkerId("current"),
                                        position: _currentLatLng!,
                                      ),
                                    },
                                    zoomControlsEnabled: false,
                                    scrollGesturesEnabled: false,
                                    rotateGesturesEnabled: false,
                                    tiltGesturesEnabled: false,
                                    gestureRecognizers:
                                        <Factory<OneSequenceGestureRecognizer>>{
                                          Factory<OneSequenceGestureRecognizer>(
                                            () => EagerGestureRecognizer(),
                                          ),
                                        },
                                  ),
                                ),
                              ],
                            ),
                          ),
                  ],
                ),
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _continueToNextStep,
                  child: const Text("Continue"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
