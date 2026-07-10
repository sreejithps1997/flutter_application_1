import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:workable/models/worker_onboarding_data.dart';
import 'package:workable/screens/map_picker_screen.dart';

import '../../core/theme/workable_design.dart';
import '../../widgets/worker_onboarding_shell.dart';
import 'step2_skills_screen.dart';

class Step1ProfileScreen extends StatefulWidget {
  static const routeName = '/step1-profile';
  final WorkerOnboardingData onboardingData;

  const Step1ProfileScreen({super.key, required this.onboardingData});

  @override
  State<Step1ProfileScreen> createState() => _Step1ProfileScreenState();
}

class _Step1ProfileScreenState extends State<Step1ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _pincodeController = TextEditingController();

  int? _selectedRadius;
  LatLng? _currentLatLng;
  bool _isLocating = false;

  final List<int> _radiusOptions = [2, 5, 10, 20, 50, 100];

  @override
  void initState() {
    super.initState();
    _addressController.text = widget.onboardingData.address.trim();
    _cityController.text = widget.onboardingData.city.trim();
    _pincodeController.text = widget.onboardingData.pincode.trim();

    if (_radiusOptions.contains(widget.onboardingData.serviceRadius)) {
      _selectedRadius = widget.onboardingData.serviceRadius;
    } else {
      _selectedRadius = 5;
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
    setState(() => _isLocating = true);
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showMessage('Turn on location services to set your work area.');
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever ||
          permission == LocationPermission.denied) {
        _showMessage('Location permission is needed to set your service area.');
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      if (!mounted) return;
      setState(() {
        _currentLatLng = LatLng(position.latitude, position.longitude);
      });
    } catch (e) {
      debugPrint('Failed to get worker location: $e');
      if (!mounted) return;
      _showMessage('Failed to get current location.');
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  Future<void> _openMapPicker() async {
    final pickedLatLng = await Navigator.push<LatLng>(
      context,
      MaterialPageRoute(
        builder: (_) => MapPickerScreen(initialLocation: _currentLatLng),
      ),
    );
    if (!context.mounted) return;
    if (pickedLatLng != null) {
      setState(() => _currentLatLng = pickedLatLng);
    } else {
      _showMessage('Location not selected.');
    }
  }

  void _continueToNextStep() {
    if (!_formKey.currentState!.validate() ||
        _currentLatLng == null ||
        _selectedRadius == null) {
      _showMessage('Complete address, service radius, and map location.');
      return;
    }

    final updatedData = widget.onboardingData.copyWith(
      address: _addressController.text.trim(),
      city: _cityController.text.trim(),
      pincode: _pincodeController.text.trim(),
      serviceRadius: _selectedRadius!,
      latitude: _currentLatLng!.latitude,
      longitude: _currentLatLng!.longitude,
      location: '${_currentLatLng!.latitude},${_currentLatLng!.longitude}',
    );

    Navigator.pushNamed(
      context,
      Step2SkillsScreen.routeName,
      arguments: updatedData,
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    _addressController.dispose();
    _cityController.dispose();
    _pincodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WorkerOnboardingShell(
      title: 'Set your service area',
      subtitle:
          'Customers nearby will discover you based on this address, map pin, and travel radius.',
      step: 2,
      totalSteps: 6,
      bottom: FilledButton(
        onPressed: _continueToNextStep,
        child: const Text('Continue'),
      ),
      children: [
        Form(
          key: _formKey,
          child: Column(
            children: [
              WorkerOnboardingCard(
                child: Column(
                  children: [
                    TextFormField(
                      controller: _addressController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Full address',
                        prefixIcon: Icon(Icons.home_outlined),
                      ),
                      validator: (value) => (value?.trim().isEmpty ?? true)
                          ? 'Enter your address'
                          : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _cityController,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'City',
                        prefixIcon: Icon(Icons.location_city_outlined),
                      ),
                      validator: (value) =>
                          (value?.trim().isEmpty ?? true) ? 'Enter city' : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _pincodeController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Pincode',
                        prefixIcon: Icon(Icons.pin_drop_outlined),
                      ),
                      validator: (value) =>
                          value == null || !RegExp(r'^\d{6}$').hasMatch(value)
                          ? 'Enter valid 6-digit pincode'
                          : null,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              WorkerOnboardingCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Travel radius',
                      style: TextStyle(
                        color: WorkableDesign.ink,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Choose how far you can travel for normal jobs. Urgent-job matching can use this later.',
                      style: TextStyle(
                        color: WorkableDesign.muted,
                        fontSize: 12.5,
                        height: 1.35,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _radiusOptions.map(_buildRadiusChip).toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              WorkerOnboardingCard(child: _buildMapSection()),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRadiusChip(int radius) {
    final selected = _selectedRadius == radius;
    return ChoiceChip(
      selected: selected,
      label: Text('$radius km'),
      onSelected: (_) => setState(() => _selectedRadius = radius),
      selectedColor: WorkableDesign.accent.withValues(alpha: 0.14),
      checkmarkColor: WorkableDesign.accent,
      side: BorderSide(
        color: selected
            ? WorkableDesign.accent.withValues(alpha: 0.35)
            : WorkableDesign.border,
      ),
      labelStyle: TextStyle(
        color: selected ? WorkableDesign.accent : WorkableDesign.ink,
        fontWeight: FontWeight.w800,
      ),
    );
  }

  Widget _buildMapSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Map pin',
                style: TextStyle(
                  color: WorkableDesign.ink,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: _isLocating ? null : _loadCurrentLocation,
              icon: _isLocating
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.my_location_outlined),
              label: const Text('Use current'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_currentLatLng == null)
          Container(
            height: 190,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: WorkableDesign.canvas,
              borderRadius: BorderRadius.circular(WorkableDesign.radius),
              border: Border.all(color: WorkableDesign.border),
            ),
            child: _isLocating
                ? const CircularProgressIndicator()
                : OutlinedButton.icon(
                    onPressed: _loadCurrentLocation,
                    icon: const Icon(Icons.my_location_outlined),
                    label: const Text('Set location'),
                  ),
          )
        else
          InkWell(
            onTap: _openMapPicker,
            borderRadius: BorderRadius.circular(WorkableDesign.radius),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(WorkableDesign.radius),
              child: SizedBox(
                height: 210,
                child: Stack(
                  children: [
                    GoogleMap(
                      initialCameraPosition: CameraPosition(
                        target: _currentLatLng!,
                        zoom: 15,
                      ),
                      markers: {
                        Marker(
                          markerId: const MarkerId('current'),
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
                    Positioned(
                      left: 10,
                      right: 10,
                      bottom: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 9,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(
                            WorkableDesign.radius,
                          ),
                          border: Border.all(color: WorkableDesign.border),
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.touch_app_outlined,
                              color: WorkableDesign.accent,
                              size: 18,
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Tap map to adjust your service pin',
                                style: TextStyle(
                                  color: WorkableDesign.ink,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
