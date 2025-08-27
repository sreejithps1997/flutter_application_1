import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
  };

  @override
  void initState() {
    super.initState();
    if (widget.isEdit && widget.addressData != null) {
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
      };
    }
  }

  void updateForm(String key, dynamic value) {
    setState(() => formData[key] = value);
  }

  Future<void> saveAddressToFirebase() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

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
    };

    final ref = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('addresses');

    if (widget.isEdit && widget.addressData?['id'] != null) {
      await ref.doc(widget.addressData!['id']).update(addressData);
    } else {
      await ref.add(addressData);
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          widget.isEdit
              ? 'Address updated successfully'
              : 'Address saved successfully',
        ),
        backgroundColor: Colors.green,
      ),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isOther = formData['addressType'] == 'other';

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEdit ? 'Edit Address' : 'Add New Address'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Address Type',
              style: TextStyle(fontWeight: FontWeight.w600),
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
              onPressed: saveAddressToFirebase,
              icon: const Icon(LucideIcons.save),
              label: Text(widget.isEdit ? 'Update Address' : 'Save Address'),
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

  Widget _buildTypeChip(String id, IconData icon) {
    final selected = formData['addressType'] == id;
    return ChoiceChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: selected ? Colors.white : Colors.black),
          const SizedBox(width: 6),
          Text(id[0].toUpperCase() + id.substring(1)),
        ],
      ),
      selected: selected,
      onSelected: (_) => updateForm('addressType', id),
      selectedColor: Colors.blue,
      backgroundColor: Colors.grey[200],
      labelStyle: TextStyle(color: selected ? Colors.white : Colors.black),
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
