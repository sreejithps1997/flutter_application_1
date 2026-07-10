import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../core/theme/workable_design.dart';
import '../widgets/workable_ui.dart';
import 'map_picker_screen.dart';

class AddNewAddressScreen extends StatefulWidget {
  static const routeName = '/add-new-address';

  final bool isEdit;
  final Map<String, dynamic>? addressData;

  const AddNewAddressScreen({super.key, this.isEdit = false, this.addressData});

  @override
  State<AddNewAddressScreen> createState() => _AddNewAddressScreenState();
}

class _AddNewAddressScreenState extends State<AddNewAddressScreen> {
  Map<String, dynamic> formData = {
    'addressType': 'home',
    'customLabel': '',
    'fullAddress': '',
    'area': '',
    'landmark': '',
    'pincode': '',
    'primaryContact': '',
    'alternateContact': '',
    'instructions': '',
    'isDefault': false,
    'allowLateNight': false,
    'safetyPreference': 'standard',
    'latitude': null,
    'longitude': null,
  };

  bool isResolvingLocation = false;
  bool isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.isEdit && widget.addressData != null) {
      final savedLocation = widget.addressData!['location'];
      formData = {
        'addressType': widget.addressData!['type'] ?? 'home',
        'customLabel': widget.addressData!['label'] ?? '',
        'fullAddress': widget.addressData!['address'] ?? '',
        'area': widget.addressData!['area'] ?? '',
        'landmark': widget.addressData!['landmark'] ?? '',
        'pincode': widget.addressData!['pincode'] ?? '',
        'primaryContact': widget.addressData!['contact'] ?? '',
        'alternateContact': widget.addressData!['alternateContact'] ?? '',
        'instructions': widget.addressData!['instructions'] ?? '',
        'isDefault': widget.addressData!['isDefault'] ?? false,
        'allowLateNight': widget.addressData!['allowLateNight'] ?? false,
        'safetyPreference': widget.addressData!['safetyRating'] ?? 'standard',
        'latitude':
            widget.addressData!['latitude'] ??
            (savedLocation is GeoPoint ? savedLocation.latitude : null),
        'longitude':
            widget.addressData!['longitude'] ??
            (savedLocation is GeoPoint ? savedLocation.longitude : null),
      };
    }
  }

  void updateForm(String key, dynamic value) {
    setState(() => formData[key] = value);
  }

  LatLng? get selectedLocation {
    final latitude = formData['latitude'];
    final longitude = formData['longitude'];
    if (latitude is num && longitude is num) {
      return LatLng(latitude.toDouble(), longitude.toDouble());
    }
    return null;
  }

  Future<void> pickLocationFromMap() async {
    final pickedLatLng = await Navigator.push<LatLng>(
      context,
      MaterialPageRoute(
        builder: (_) => MapPickerScreen(initialLocation: selectedLocation),
      ),
    );

    if (pickedLatLng == null) return;

    setState(() {
      isResolvingLocation = true;
      formData['latitude'] = pickedLatLng.latitude;
      formData['longitude'] = pickedLatLng.longitude;
    });

    try {
      final placemarks = await placemarkFromCoordinates(
        pickedLatLng.latitude,
        pickedLatLng.longitude,
      );

      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        final streetParts = [
          place.name,
          place.street,
          place.subLocality,
        ].where((part) => part != null && part.trim().isNotEmpty).toList();
        final areaParts = [
          place.locality,
          place.subAdministrativeArea,
          place.administrativeArea,
        ].where((part) => part != null && part.trim().isNotEmpty).toList();

        setState(() {
          if (streetParts.isNotEmpty) {
            formData['fullAddress'] = streetParts.join(', ');
          }
          if (areaParts.isNotEmpty) {
            formData['area'] = areaParts.join(', ');
          }
          if ((place.postalCode ?? '').trim().isNotEmpty) {
            formData['pincode'] = place.postalCode!.trim();
          }
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Location selected. Please enter address details.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => isResolvingLocation = false);
      }
    }
  }

  Future<void> saveAddressToFirebase() async {
    if (isSaving) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final validationError = _validateAddress();
    if (validationError != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(validationError)));
      return;
    }

    setState(() => isSaving = true);

    final uid = user.uid;
    final addressData = {
      'type': formData['addressType'],
      'label': formData['addressType'] == 'other'
          ? formData['customLabel']
          : formData['addressType'],
      'address': formData['fullAddress'],
      'area': formData['area'],
      'pincode': formData['pincode'],
      'landmark': formData['landmark'],
      'contact': formData['primaryContact'],
      'alternateContact': formData['alternateContact'],
      'instructions': formData['instructions'],
      'isDefault': formData['isDefault'],
      'allowLateNight': formData['allowLateNight'],
      'safetyRating': formData['safetyPreference'],
      'isVerified': false,
      'lastUsed': 'Just now',
      'createdAt': Timestamp.now(),
      'latitude': formData['latitude'],
      'longitude': formData['longitude'],
      if (formData['latitude'] is num && formData['longitude'] is num)
        'location': GeoPoint(
          (formData['latitude'] as num).toDouble(),
          (formData['longitude'] as num).toDouble(),
        ),
    };

    try {
      final ref = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('addresses');

      String? addressId = widget.addressData?['id'];
      if (widget.isEdit && widget.addressData?['id'] != null) {
        await ref.doc(addressId).update(addressData);
      } else {
        final doc = await ref.add(addressData);
        addressId = doc.id;
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.isEdit
                ? 'Address updated successfully'
                : 'Address saved successfully',
          ),
        ),
      );
      Navigator.pop(context, {...addressData, 'id': addressId});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not save address: $e')));
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  String? _validateAddress() {
    final label = formData['addressType'] == 'other'
        ? formData['customLabel']?.toString().trim()
        : formData['addressType']?.toString().trim();
    final fullAddress = formData['fullAddress']?.toString().trim() ?? '';
    final area = formData['area']?.toString().trim() ?? '';
    final pincode = formData['pincode']?.toString().trim() ?? '';
    final contact = formData['primaryContact']?.toString().trim() ?? '';

    if (label == null || label.isEmpty) return 'Enter an address label.';
    if (fullAddress.length < 8) return 'Enter the full address.';
    if (area.length < 2) return 'Enter the area or locality.';
    if (!RegExp(r'^\d{5,6}$').hasMatch(pincode)) {
      return 'Enter a valid pincode.';
    }
    if (!RegExp(r'^\d{10}$').hasMatch(contact)) {
      return 'Enter a valid 10-digit primary contact number.';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final isOther = formData['addressType'] == 'other';

    return Scaffold(
      backgroundColor: WorkableDesign.canvas,
      appBar: AppBar(
        title: Text(widget.isEdit ? 'Edit Address' : 'Add New Address'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            WorkablePageHeader(
              title: widget.isEdit ? 'Update address' : 'Add trusted address',
              subtitle:
                  'Save accurate doorstep details so workers can arrive faster and bookings stay smooth.',
              icon: LucideIcons.mapPin,
            ),
            const SizedBox(height: 16),
            const Text(
              'Address Type',
              style: TextStyle(
                color: WorkableDesign.ink,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _buildTypeChip('home', LucideIcons.home),
                const SizedBox(width: 8),
                _buildTypeChip('work', LucideIcons.building2),
                const SizedBox(width: 8),
                _buildTypeChip('other', LucideIcons.heart),
              ],
            ),
            if (isOther)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: TextField(
                  decoration: const InputDecoration(
                    labelText: 'Custom Label',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (val) => updateForm('customLabel', val),
                ),
              ),
            const SizedBox(height: 16),
            _buildMapPickerCard(),
            const SizedBox(height: 16),
            _buildTextField('Full Address', 'fullAddress'),
            _buildTextField('Area/Locality', 'area'),
            _buildTextField(
              'Pincode',
              'pincode',
              keyboardType: TextInputType.number,
            ),
            _buildTextField('Landmark (Optional)', 'landmark'),
            _buildTextField(
              'Primary Contact',
              'primaryContact',
              keyboardType: TextInputType.phone,
            ),
            _buildTextField(
              'Alternate Contact (Optional)',
              'alternateContact',
              keyboardType: TextInputType.phone,
            ),
            _buildTextField(
              'Special Instructions',
              'instructions',
              maxLines: 2,
            ),
            SwitchListTile(
              title: const Text('Allow Late Night Services'),
              subtitle: const Text('Between 9 PM - 6 AM'),
              value: formData['allowLateNight'],
              onChanged: (val) => updateForm('allowLateNight', val),
            ),
            const SizedBox(height: 8),
            const Text(
              'Safety Rating Preference',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            _buildRadioTile('high', 'High Safety Only'),
            _buildRadioTile('standard', 'Standard'),
            _buildRadioTile('any', 'Any'),
            CheckboxListTile(
              value: formData['isDefault'],
              onChanged: (val) => updateForm('isDefault', val),
              title: const Text('Set as Default Address'),
              subtitle: const Text('Use this address for all new bookings'),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: isSaving ? null : saveAddressToFirebase,
              icon: isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(LucideIcons.save),
              label: Text(
                isSaving
                    ? 'Saving...'
                    : widget.isEdit
                    ? 'Update Address'
                    : 'Save Address',
              ),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(
    String label,
    String key, {
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        keyboardType: keyboardType,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        onChanged: (val) => updateForm(key, val),
        controller: TextEditingController(text: formData[key])
          ..selection = TextSelection.collapsed(
            offset: formData[key]?.length ?? 0,
          ),
      ),
    );
  }

  Widget _buildMapPickerCard() {
    final location = selectedLocation;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: WorkableDesign.primary.withValues(alpha: 0.06),
        border: Border.all(
          color: WorkableDesign.primary.withValues(alpha: 0.18),
        ),
        borderRadius: BorderRadius.circular(WorkableDesign.radius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.mapPin, color: WorkableDesign.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  location == null
                      ? 'Pick location from map'
                      : 'Map location selected',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            location == null
                ? 'Choose the exact doorstep location to fill address details faster.'
                : '${location.latitude.toStringAsFixed(6)}, ${location.longitude.toStringAsFixed(6)}',
            style: const TextStyle(color: WorkableDesign.muted, fontSize: 13),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: isResolvingLocation ? null : pickLocationFromMap,
              icon: isResolvingLocation
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(LucideIcons.crosshair, size: 18),
              label: Text(
                isResolvingLocation
                    ? 'Fetching address...'
                    : location == null
                    ? 'Use Map Location'
                    : 'Change Map Location',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeChip(String id, IconData icon) {
    final selected = formData['addressType'] == id;
    return ChoiceChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: selected ? Colors.white : WorkableDesign.ink,
          ),
          const SizedBox(width: 6),
          Text(id[0].toUpperCase() + id.substring(1)),
        ],
      ),
      selected: selected,
      onSelected: (_) => updateForm('addressType', id),
      selectedColor: WorkableDesign.primary,
      backgroundColor: WorkableDesign.surface,
      labelStyle: TextStyle(
        color: selected ? Colors.white : WorkableDesign.ink,
      ),
    );
  }

  Widget _buildRadioTile(String value, String title) {
    return RadioListTile<String>(
      value: value,
      groupValue: formData['safetyPreference'],
      onChanged: (val) => updateForm('safetyPreference', val),
      title: Text(title),
    );
  }
}
