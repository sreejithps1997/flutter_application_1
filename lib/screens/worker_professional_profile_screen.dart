import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';

import '../core/theme/workable_design.dart';
import '../services/worker_visibility_service.dart';
import '../widgets/worker_visibility_status_panel.dart';

class WorkerProfessionalProfileScreen extends StatefulWidget {
  static const routeName = '/worker/professional-profile';

  const WorkerProfessionalProfileScreen({super.key});

  @override
  State<WorkerProfessionalProfileScreen> createState() =>
      _WorkerProfessionalProfileScreenState();
}

class _WorkerProfessionalProfileScreenState
    extends State<WorkerProfessionalProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _pincodeController = TextEditingController();
  final _radiusController = TextEditingController();
  final _skillsController = TextEditingController();
  final _pricingController = TextEditingController();
  final _startTimeController = TextEditingController();
  final _endTimeController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  bool _isFlexible = false;
  List<int> _workingDays = const [1, 2, 3, 4, 5, 6];
  Map<String, String> _skillExperience = {};
  String? _imageUrl;
  File? _pickedImage;
  GeoPoint? _location;
  String? _uid;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _pincodeController.dispose();
    _radiusController.dispose();
    _skillsController.dispose();
    _pricingController.dispose();
    _startTimeController.dispose();
    _endTimeController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final workerDoc = await FirebaseFirestore.instance
        .collection('workers')
        .doc(uid)
        .get();
    final data = workerDoc.data() ?? {};
    final schedule = Map<String, dynamic>.from(data['schedule'] ?? {});

    if (!mounted) return;
    setState(() {
      _uid = uid;
      _nameController.text =
          data['name']?.toString() ?? data['fullName']?.toString() ?? '';
      _phoneController.text =
          data['phoneNumber']?.toString() ?? data['phone']?.toString() ?? '';
      _addressController.text = data['address']?.toString() ?? '';
      _cityController.text = data['city']?.toString() ?? '';
      _pincodeController.text = data['pincode']?.toString() ?? '';
      _radiusController.text = (data['serviceRadius'] ?? 2).toString();
      _skillsController.text = List<String>.from(
        data['skills'] ?? data['services'] ?? const [],
      ).join(', ');
      final wageMap = Map<String, dynamic>.from(data['wageMap'] ?? {});
      _pricingController.text = _pricingText(data, wageMap);
      _startTimeController.text = schedule['startTime']?.toString() ?? '';
      _endTimeController.text = schedule['endTime']?.toString() ?? '';
      _isFlexible = schedule['isFlexible'] == true;
      _workingDays = List<int>.from(
        schedule['workingDays'] ??
            schedule['availableDays'] ??
            const [1, 2, 3, 4, 5, 6],
      );
      _skillExperience = Map<String, String>.from(
        data['skillExperience'] ?? {},
      );
      _imageUrl =
          data['imageUrl']?.toString() ?? data['profileImageUrl']?.toString();
      _location = _resolveLocation(data);
      _isLoading = false;
    });
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 75,
      maxWidth: 1200,
      maxHeight: 1200,
    );
    if (picked == null) return;
    setState(() => _pickedImage = File(picked.path));
  }

  Future<void> _useCurrentLocation() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _showSnack('Location permission denied');
        return;
      }

      final position = await Geolocator.getCurrentPosition();
      setState(() {
        _location = GeoPoint(position.latitude, position.longitude);
      });
      _showSnack('Service location updated');
    } catch (e) {
      _showSnack('Unable to get location: $e');
    }
  }

  Future<String?> _uploadImage(String uid) async {
    final image = _pickedImage;
    if (image == null) return _imageUrl;

    final ref = FirebaseStorage.instance
        .ref()
        .child('worker_profile_images')
        .child(uid)
        .child('profile_${DateTime.now().millisecondsSinceEpoch}.jpg');
    await ref.putFile(image, SettableMetadata(contentType: 'image/jpeg'));
    return ref.getDownloadURL();
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    final skills = _skillList();
    if (skills.isEmpty) {
      _showSnack('Add at least one service');
      return;
    }
    final basePrice = _priceValue();
    if (basePrice == null || basePrice <= 0) {
      _showSnack('Add a valid starting price');
      return;
    }
    if (_workingDays.isEmpty) {
      _showSnack('Select at least one working day');
      return;
    }
    if (!_isFlexible &&
        (_startTimeController.text.trim().isEmpty ||
            _endTimeController.text.trim().isEmpty)) {
      _showSnack('Add start and end time, or enable flexible hours');
      return;
    }

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    setState(() => _isSaving = true);
    try {
      final imageUrl = await _uploadImage(uid);
      final serviceRadius = int.tryParse(_radiusController.text.trim()) ?? 2;
      final wageMap = {
        for (final skill in skills) skill: basePrice.toStringAsFixed(0),
      };
      final skillExperience = {
        for (final skill in skills)
          skill: _skillExperience[skill]?.toString() ?? 'Experienced',
      };

      final updates = <String, dynamic>{
        'name': _nameController.text.trim(),
        'fullName': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'phoneNumber': _phoneController.text.trim(),
        'address': _addressController.text.trim(),
        'city': _cityController.text.trim(),
        'pincode': _pincodeController.text.trim(),
        'serviceRadius': serviceRadius,
        'serviceRadiusKm': serviceRadius,
        'skills': skills,
        'services': skills,
        'serviceCategories': skills,
        'pricing': basePrice,
        'displayPricing': 'Starts from Rs ${basePrice.toStringAsFixed(0)}',
        'wageMap': wageMap,
        'skillExperience': skillExperience,
        'schedule': {
          'startTime': _startTimeController.text.trim(),
          'endTime': _endTimeController.text.trim(),
          'isFlexible': _isFlexible,
          'workingDays': _workingDays,
          'availableDays': _workingDays,
        },
        'isOnboardingComplete': true,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (imageUrl != null && imageUrl.isNotEmpty) {
        updates['imageUrl'] = imageUrl;
        updates['profileImageUrl'] = imageUrl;
      }
      if (_location != null) {
        updates['location'] = _location;
        updates['latitude'] = _location!.latitude;
        updates['longitude'] = _location!.longitude;
      }

      await FirebaseFirestore.instance
          .collection('workers')
          .doc(uid)
          .set(updates, SetOptions(merge: true));

      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'name': _nameController.text.trim(),
        if (imageUrl != null && imageUrl.isNotEmpty)
          'profileImageUrl': imageUrl,
      }, SetOptions(merge: true));

      await WorkerVisibilityService().syncWorkerVisibility(uid);

      if (!mounted) return;
      setState(() {
        _imageUrl = imageUrl;
        _pickedImage = null;
        _skillExperience = skillExperience;
      });
      _showSnack('Professional profile saved');
    } catch (e) {
      if (!mounted) return;
      _showSnack('Unable to save profile: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  GeoPoint? _resolveLocation(Map<String, dynamic> data) {
    final location = data['location'];
    if (location is GeoPoint) return location;
    final lat = _asDouble(data['latitude']);
    final lng = _asDouble(data['longitude']);
    if (lat == null || lng == null || (lat == 0 && lng == 0)) return null;
    return GeoPoint(lat, lng);
  }

  double? _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  List<String> _skillList() {
    return _skillsController.text
        .split(',')
        .map((skill) => skill.trim())
        .where((skill) => skill.isNotEmpty)
        .toSet()
        .toList();
  }

  double? _priceValue() {
    final text = _pricingController.text.trim();
    final match = RegExp(r'\d+(\.\d+)?').firstMatch(text);
    return double.tryParse(match?.group(0) ?? '');
  }

  String _pricingText(Map<String, dynamic> data, Map<String, dynamic> wageMap) {
    if (data['pricing'] != null &&
        data['pricing'].toString().trim().isNotEmpty) {
      final pricing = data['pricing'];
      if (pricing is num) return pricing.toStringAsFixed(0);
      return pricing.toString();
    }
    if (wageMap.isNotEmpty) {
      final first = wageMap.values.first;
      return first.toString();
    }
    return '';
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _pickTime(TextEditingController controller) async {
    final initial = _parseTime(controller.text) ?? TimeOfDay.now();
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked == null || !mounted) return;
    setState(() => controller.text = picked.format(context));
  }

  TimeOfDay? _parseTime(String value) {
    final match = RegExp(
      r'^(\d{1,2})(?::(\d{2}))?\s*(AM|PM)?$',
      caseSensitive: false,
    ).firstMatch(value.trim());
    if (match == null) return null;
    var hour = int.tryParse(match.group(1) ?? '');
    final minute = int.tryParse(match.group(2) ?? '0') ?? 0;
    final period = match.group(3)?.toUpperCase();
    if (hour == null || hour > 23 || minute > 59) return null;
    if (period == 'PM' && hour < 12) hour += 12;
    if (period == 'AM' && hour == 12) hour = 0;
    return TimeOfDay(hour: hour, minute: minute);
  }

  int _radiusValue() {
    final value = int.tryParse(_radiusController.text.trim()) ?? 2;
    return value.clamp(1, 50);
  }

  String _scheduleSummary() {
    if (_isFlexible) return 'Flexible hours on ${_workingDays.length} days';
    final start = _startTimeController.text.trim();
    final end = _endTimeController.text.trim();
    if (start.isEmpty || end.isEmpty) return 'Set your daily working window';
    return '$start - $end on ${_workingDays.length} days';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WorkableDesign.canvas,
      appBar: AppBar(
        title: const Text('Professional Profile'),
        backgroundColor: WorkableDesign.surface,
        foregroundColor: WorkableDesign.ink,
      ),
      bottomNavigationBar: _isLoading
          ? null
          : SafeArea(
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                decoration: const BoxDecoration(
                  color: WorkableDesign.surface,
                  border: Border(top: BorderSide(color: WorkableDesign.border)),
                ),
                child: FilledButton.icon(
                  onPressed: _isSaving ? null : _saveProfile,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined),
                  label: Text(_isSaving ? 'Saving Profile...' : 'Save Profile'),
                ),
              ),
            ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                children: [
                  _buildBusinessHeader(),
                  if (_uid != null) ...[
                    const SizedBox(height: 16),
                    WorkerVisibilityStatusPanel(
                      workerId: _uid!,
                      margin: EdgeInsets.zero,
                    ),
                  ],
                  const SizedBox(height: 16),
                  _buildPhotoHeader(),
                  const SizedBox(height: 16),
                  _buildSectionCard(
                    title: 'Business Identity',
                    subtitle: 'This is what customers see before booking.',
                    icon: Icons.storefront_outlined,
                    children: [
                      _buildTextField(
                        controller: _nameController,
                        label: 'Full name',
                        icon: Icons.person_outline,
                        validator: _required,
                      ),
                      _buildTextField(
                        controller: _phoneController,
                        label: 'Phone number',
                        icon: Icons.phone_outlined,
                        keyboardType: TextInputType.phone,
                        validator: _required,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildSectionCard(
                    title: 'Services & Pricing',
                    subtitle:
                        'Keep this specific so customers understand your offer quickly.',
                    icon: Icons.handyman_outlined,
                    children: [
                      _buildTextField(
                        controller: _skillsController,
                        label: 'Skills, comma separated',
                        icon: Icons.handyman_outlined,
                        validator: _required,
                        onChanged: (_) => setState(() {}),
                      ),
                      _buildTextField(
                        controller: _pricingController,
                        label: 'Starting price',
                        icon: Icons.currency_rupee,
                        keyboardType: TextInputType.number,
                        validator: _required,
                        onChanged: (_) => setState(() {}),
                      ),
                      _buildServicesPreview(),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildSectionCard(
                    title: 'Service Area',
                    subtitle: 'Bookings outside this radius will be blocked.',
                    icon: Icons.map_outlined,
                    children: [
                      _buildTextField(
                        controller: _addressController,
                        label: 'Address',
                        icon: Icons.location_on_outlined,
                        validator: _required,
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              controller: _cityController,
                              label: 'City',
                              icon: Icons.location_city_outlined,
                              validator: _required,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildTextField(
                              controller: _pincodeController,
                              label: 'Pincode',
                              icon: Icons.pin_drop_outlined,
                              keyboardType: TextInputType.number,
                              validator: _required,
                            ),
                          ),
                        ],
                      ),
                      _buildRadiusControl(),
                      OutlinedButton.icon(
                        onPressed: _useCurrentLocation,
                        icon: const Icon(Icons.my_location_outlined),
                        label: Text(
                          _location == null
                              ? 'Use current location'
                              : 'Location set. Tap to update',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildSectionCard(
                    title: 'Availability Rules',
                    subtitle: _scheduleSummary(),
                    icon: Icons.event_available_outlined,
                    children: [
                      SwitchListTile(
                        value: _isFlexible,
                        onChanged: (value) =>
                            setState(() => _isFlexible = value),
                        title: const Text('Flexible working hours'),
                        subtitle: const Text(
                          'Customers can request any time on selected days.',
                        ),
                        contentPadding: EdgeInsets.zero,
                      ),
                      const SizedBox(height: 6),
                      _buildWorkingDaysSelector(),
                      const SizedBox(height: 14),
                      if (!_isFlexible)
                        Row(
                          children: [
                            Expanded(
                              child: _buildTimeField(
                                controller: _startTimeController,
                                label: 'Start time',
                                icon: Icons.schedule_outlined,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _buildTimeField(
                                controller: _endTimeController,
                                label: 'End time',
                                icon: Icons.schedule,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildBusinessHeader() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: WorkableDesign.cardDecoration(color: WorkableDesign.ink),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.workspace_premium, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Customer-ready business profile',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Photo, service area and schedule decide where bookings can happen.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.72),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: WorkableDesign.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: WorkableDesign.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(WorkableDesign.radius),
                ),
                child: Icon(icon, color: WorkableDesign.primary, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: WorkableDesign.ink,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: WorkableDesign.muted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }

  Widget _buildRadiusControl() {
    final value = _radiusValue();
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: WorkableDesign.canvas,
        borderRadius: BorderRadius.circular(WorkableDesign.radius),
        border: Border.all(color: WorkableDesign.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.radar_outlined, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Service radius',
                  style: TextStyle(
                    color: WorkableDesign.ink,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                '$value km',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          Slider(
            value: value.toDouble(),
            min: 1,
            max: 50,
            divisions: 49,
            label: '$value km',
            onChanged: (next) {
              setState(() => _radiusController.text = next.round().toString());
            },
          ),
          TextFormField(
            controller: _radiusController,
            keyboardType: TextInputType.number,
            validator: _required,
            decoration: const InputDecoration(
              labelText: 'Exact radius in km',
              prefixIcon: Icon(Icons.pin_drop_outlined),
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
    );
  }

  Widget _buildServicesPreview() {
    final skills = _skillList();
    final price = _priceValue();

    if (skills.isEmpty && price == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: WorkableDesign.warning.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(WorkableDesign.radius),
          border: Border.all(
            color: WorkableDesign.warning.withValues(alpha: 0.18),
          ),
        ),
        child: const Text(
          'Add services and a starting price to become eligible for customer search.',
          style: TextStyle(
            color: WorkableDesign.ink,
            fontWeight: FontWeight.w700,
            height: 1.35,
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: WorkableDesign.accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(WorkableDesign.radius),
        border: Border.all(
          color: WorkableDesign.accent.withValues(alpha: 0.16),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            price == null
                ? 'Add a starting price'
                : 'Customer sees: Starts from Rs ${price.toStringAsFixed(0)}',
            style: const TextStyle(
              color: WorkableDesign.ink,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (skills.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: skills
                  .map(
                    (skill) => Chip(
                      label: Text(skill),
                      avatar: const Icon(Icons.handyman_outlined, size: 16),
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPhotoHeader() {
    ImageProvider? imageProvider;
    if (_pickedImage != null) {
      imageProvider = FileImage(_pickedImage!);
    } else if (_imageUrl != null && _imageUrl!.isNotEmpty) {
      imageProvider = NetworkImage(_imageUrl!);
    }

    return Row(
      children: [
        CircleAvatar(
          radius: 38,
          backgroundImage: imageProvider,
          child: imageProvider == null
              ? const Icon(Icons.person_outline, size: 34)
              : null,
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Profile photo',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
              Text(
                'This photo is required for customer visibility.',
                style: const TextStyle(
                  color: WorkableDesign.muted,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Change photo',
          onPressed: _pickImage,
          icon: const Icon(Icons.photo_camera_outlined),
        ),
      ],
    );
  }

  Widget _buildWorkingDaysSelector() {
    const days = <int, String>{
      1: 'Mon',
      2: 'Tue',
      3: 'Wed',
      4: 'Thu',
      5: 'Fri',
      6: 'Sat',
      7: 'Sun',
    };

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: days.entries.map((entry) {
        final selected = _workingDays.contains(entry.key);
        return FilterChip(
          label: Text(entry.value),
          selected: selected,
          onSelected: (value) {
            setState(() {
              if (value) {
                _workingDays = [..._workingDays, entry.key]..sort();
              } else {
                _workingDays = _workingDays
                    .where((day) => day != entry.key)
                    .toList();
              }
            });
          },
        );
      }).toList(),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
    ValueChanged<String>? onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        validator: validator,
        onChanged: onChanged,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  Widget _buildTimeField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        readOnly: true,
        onTap: () => _pickTime(controller),
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          suffixIcon: const Icon(Icons.expand_more),
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  String? _required(String? value) {
    if (value == null || value.trim().isEmpty) return 'Required';
    return null;
  }
}
