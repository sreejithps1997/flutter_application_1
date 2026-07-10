import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../core/theme/workable_design.dart';
import '../widgets/workable_ui.dart';
import 'add_new_address_screen.dart';
import 'change_password_screen.dart';
import 'government_id_verification_screen.dart';
import 'identity_verification_screen.dart';
import 'pan_card_verification_screen.dart';

class PersonalInformationScreen extends StatefulWidget {
  static const routeName = '/personal-information';

  const PersonalInformationScreen({super.key});

  @override
  State<PersonalInformationScreen> createState() =>
      _PersonalInformationScreenState();
}

class _PersonalInformationScreenState extends State<PersonalInformationScreen> {
  final userId = FirebaseAuth.instance.currentUser?.uid;
  late DocumentReference userDoc;

  bool _isLoading = true;

  // BUG FIX 1: No edit mode toggle — page is always editable.
  // We track the original (saved) values to know if anything changed.
  Map<String, String> _originalValues = {};

  List<Map<String, dynamic>> addresses = [];

  final TextEditingController firstNameController = TextEditingController();
  final TextEditingController lastNameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController altPhoneController = TextEditingController();
  final TextEditingController dobController = TextEditingController();
  final TextEditingController occupationController = TextEditingController();
  final TextEditingController companyController = TextEditingController();
  final TextEditingController emergencyNameController = TextEditingController();
  final TextEditingController emergencyPhoneController =
      TextEditingController();

  String gender = 'Male';
  String preferredLanguage = 'English';
  String emergencyRelation = 'Spouse';
  String? profileImageUrl;

  Map<String, dynamic> verifications = {};
  String passwordLastUpdated = 'Unknown';

  // BUG FIX 2: Validation error string for alt phone
  String? _altPhoneError;

  // BUG FIX 1: True when any field differs from the last saved snapshot
  bool get _hasChanges {
    if (_isLoading) return false;
    return firstNameController.text.trim() !=
            (_originalValues['firstName'] ?? '') ||
        lastNameController.text.trim() != (_originalValues['lastName'] ?? '') ||
        altPhoneController.text.trim() != (_originalValues['altPhone'] ?? '') ||
        dobController.text.trim() != (_originalValues['dob'] ?? '') ||
        occupationController.text.trim() !=
            (_originalValues['occupation'] ?? '') ||
        companyController.text.trim() != (_originalValues['company'] ?? '') ||
        emergencyNameController.text.trim() !=
            (_originalValues['emergencyName'] ?? '') ||
        emergencyPhoneController.text.trim() !=
            (_originalValues['emergencyPhone'] ?? '') ||
        gender != (_originalValues['gender'] ?? 'Male') ||
        preferredLanguage !=
            (_originalValues['preferredLanguage'] ?? 'English') ||
        emergencyRelation != (_originalValues['emergencyRelation'] ?? 'Spouse');
  }

  // BUG FIX 2: Alt phone is valid if empty OR exactly 10 digits
  bool get _isAltPhoneValid {
    final val = altPhoneController.text.trim();
    return val.isEmpty || val.length == 10;
  }

  // BUG FIX 3: Emergency contact is valid if all empty OR name+10-digit phone both filled
  bool get _isEmergencyContactValid {
    final name = emergencyNameController.text.trim();
    final phone = emergencyPhoneController.text.trim();
    final anyFilled = name.isNotEmpty || phone.isNotEmpty;
    if (!anyFilled) return true;
    return name.isNotEmpty && phone.length == 10;
  }

  bool get _canSave =>
      _hasChanges && _isAltPhoneValid && _isEmergencyContactValid;

  List<TextEditingController> get _editableControllers => [
    firstNameController,
    lastNameController,
    altPhoneController,
    dobController,
    occupationController,
    companyController,
    emergencyNameController,
    emergencyPhoneController,
  ];

  @override
  void initState() {
    super.initState();
    if (userId != null) {
      userDoc = FirebaseFirestore.instance.collection('users').doc(userId);
      _loadUserData();
    }
    // BUG FIX 1: Listen to every editable controller to recheck _hasChanges
    for (final c in _editableControllers) {
      c.addListener(_onFieldChanged);
    }
  }

  void _onFieldChanged() {
    // BUG FIX 2: Live validation for alt phone
    final alt = altPhoneController.text.trim();
    setState(() {
      _altPhoneError = (alt.isNotEmpty && alt.length != 10)
          ? 'Enter a valid 10-digit phone number'
          : null;
    });
  }

  Future<void> _loadUserData() async {
    try {
      final snapshot = await userDoc.get();
      final data = snapshot.data() as Map<String, dynamic>?;

      if (data != null) {
        String pwUpdated = 'Unknown';
        final pwTimestamp = data['passwordUpdatedAt'];
        if (pwTimestamp is Timestamp) {
          final dt = pwTimestamp.toDate();
          final diff = DateTime.now().difference(dt);
          if (diff.inDays < 30) {
            pwUpdated = '${diff.inDays} days ago';
          } else if (diff.inDays < 365) {
            pwUpdated = '${(diff.inDays / 30).floor()} months ago';
          } else {
            pwUpdated = '${(diff.inDays / 365).floor()} years ago';
          }
        }

        setState(() {
          firstNameController.text = data['firstName'] ?? '';
          lastNameController.text = data['lastName'] ?? '';
          emailController.text =
              data['email'] ?? FirebaseAuth.instance.currentUser?.email ?? '';
          phoneController.text =
              data['phoneNumber'] ??
              FirebaseAuth.instance.currentUser?.phoneNumber ??
              '';
          altPhoneController.text = data['altPhone'] ?? '';
          dobController.text = data['dob'] ?? '';
          occupationController.text = data['occupation'] ?? '';
          companyController.text = data['company'] ?? '';
          emergencyNameController.text = data['emergencyName'] ?? '';
          emergencyPhoneController.text = data['emergencyPhone'] ?? '';
          gender = data['gender'] ?? 'Male';
          preferredLanguage = data['preferredLanguage'] ?? 'English';
          emergencyRelation = data['emergencyRelation'] ?? 'Spouse';
          profileImageUrl = data['profileImageUrl'] ?? '';
          verifications = Map<String, dynamic>.from(
            data['verifications'] ?? {},
          );
          passwordLastUpdated = pwUpdated;
          _isLoading = false;
        });

        // BUG FIX 1: Snapshot loaded values as the saved baseline
        _snapshotOriginalValues();

        addresses =
            (data['addresses'] as List<dynamic>?)
                ?.map((e) => Map<String, dynamic>.from(e))
                .toList() ??
            [];
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('Error loading user data: $e');
      setState(() => _isLoading = false);
    }
  }

  void _snapshotOriginalValues() {
    _originalValues = {
      'firstName': firstNameController.text.trim(),
      'lastName': lastNameController.text.trim(),
      'altPhone': altPhoneController.text.trim(),
      'dob': dobController.text.trim(),
      'occupation': occupationController.text.trim(),
      'company': companyController.text.trim(),
      'emergencyName': emergencyNameController.text.trim(),
      'emergencyPhone': emergencyPhoneController.text.trim(),
      'gender': gender,
      'preferredLanguage': preferredLanguage,
      'emergencyRelation': emergencyRelation,
    };
  }

  Future<void> _saveChanges() async {
    if (!_canSave) return;

    final shouldSave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Save Changes?'),
        content: const Text(
          'Do you want to save the changes made to your profile?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (shouldSave ?? false) {
      try {
        await userDoc.update({
          'firstName': firstNameController.text.trim(),
          'lastName': lastNameController.text.trim(),
          'altPhone': altPhoneController.text.trim(),
          'dob': dobController.text.trim(),
          'occupation': occupationController.text.trim(),
          'company': companyController.text.trim(),
          'emergencyName': emergencyNameController.text.trim(),
          'emergencyPhone': emergencyPhoneController.text.trim(),
          'gender': gender,
          'preferredLanguage': preferredLanguage,
          'emergencyRelation': emergencyRelation,
          'addresses': addresses,
          'profileUpdatedAt': FieldValue.serverTimestamp(),
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile updated successfully.')),
          );
          // BUG FIX 1: Update baseline so Save fades out again
          _snapshotOriginalValues();
          setState(() {});
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error saving profile: $e')));
        }
      }
    }
  }

  Future<void> _pickDateOfBirth() async {
    DateTime? initial;
    if (dobController.text.isNotEmpty) {
      try {
        initial = DateFormat('dd/MM/yyyy').parse(dobController.text);
      } catch (_) {
        initial = null;
      }
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: initial ?? DateTime(1990, 1, 1),
      firstDate: DateTime(1920),
      lastDate: DateTime.now().subtract(const Duration(days: 365 * 5)),
      helpText: 'Select Date of Birth',
    );

    if (picked != null) {
      setState(() {
        dobController.text = DateFormat('dd/MM/yyyy').format(picked);
      });
    }
  }

  @override
  void dispose() {
    for (final c in _editableControllers) {
      c.removeListener(_onFieldChanged);
    }
    firstNameController.dispose();
    lastNameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    altPhoneController.dispose();
    dobController.dispose();
    occupationController.dispose();
    companyController.dispose();
    emergencyNameController.dispose();
    emergencyPhoneController.dispose();
    super.dispose();
  }

  String getInitials() {
    final first = firstNameController.text.trim();
    final last = lastNameController.text.trim();
    return '${first.isNotEmpty ? first[0] : ''}${last.isNotEmpty ? last[0] : ''}';
  }

  double calculateProfileCompletion() {
    int filled = 0;
    const int total = 10;
    if (firstNameController.text.trim().isNotEmpty) filled++;
    if (lastNameController.text.trim().isNotEmpty) filled++;
    if (emailController.text.trim().isNotEmpty) filled++;
    if (phoneController.text.trim().isNotEmpty) filled++;
    if (dobController.text.trim().isNotEmpty) filled++;
    if (occupationController.text.trim().isNotEmpty) filled++;
    if (companyController.text.trim().isNotEmpty) filled++;
    if (emergencyNameController.text.trim().isNotEmpty) filled++;
    if (emergencyPhoneController.text.trim().isNotEmpty) filled++;
    if (gender.isNotEmpty) filled++;
    return (filled / total) * 100;
  }

  // ─── Reusable widgets ──────────────────────────────────────────────────────

  Widget sectionCard({required String title, required List<Widget> children}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: WorkableSectionCard(
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
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget textInput(
    String label,
    TextEditingController controller, {
    bool required = false,
    bool verified = false,
    bool alwaysReadOnly = false,
    TextInputType? type,
    VoidCallback? onTap,
    String? errorText,
    // BUG FIX 2: digit enforcement and length cap
    bool digitsOnly = false,
    int? maxLength,
    // BUG FIX 3: grey-out when disabled
    bool disabled = false,
  }) {
    final effectivelyReadOnly = alwaysReadOnly || disabled;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            if (required) const Text(' *', style: TextStyle(color: Colors.red)),
            const Spacer(),
            if (verified)
              const Icon(Icons.check_circle, color: Colors.green, size: 18),
            if (alwaysReadOnly)
              const Padding(
                padding: EdgeInsets.only(left: 4),
                child: Icon(Icons.lock_outline, size: 16, color: Colors.grey),
              ),
          ],
        ),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: onTap,
          child: AbsorbPointer(
            absorbing: onTap != null,
            child: TextField(
              controller: controller,
              enabled: !effectivelyReadOnly,
              readOnly: onTap != null,
              keyboardType: type ?? TextInputType.text,
              inputFormatters: [
                if (digitsOnly) FilteringTextInputFormatter.digitsOnly,
                if (maxLength != null)
                  LengthLimitingTextInputFormatter(maxLength),
              ],
              decoration: InputDecoration(
                isDense: true,
                filled: effectivelyReadOnly,
                fillColor: alwaysReadOnly
                    ? Colors.grey[200]
                    : disabled
                    ? Colors.grey[100]
                    : null,
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                errorText: errorText,
                suffixIcon: onTap != null
                    ? const Icon(Icons.calendar_today_outlined, size: 18)
                    : null,
              ),
            ),
          ),
        ),
        SizedBox(height: errorText != null ? 4 : 12),
      ],
    );
  }

  Widget dropdownField(
    String label,
    String value,
    List<String> options,
    void Function(String?) onChanged, {
    bool required = false,
    bool disabled = false, // BUG FIX 3
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          value: value,
          decoration: InputDecoration(
            isDense: true,
            filled: disabled,
            fillColor: disabled ? Colors.grey[100] : null,
            contentPadding: const EdgeInsets.symmetric(
              vertical: 12,
              horizontal: 12,
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
          items: options
              .map((opt) => DropdownMenuItem(value: opt, child: Text(opt)))
              .toList(),
          onChanged: disabled ? null : onChanged,
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _verificationTile(String label, String firestoreKey) {
    final status = (verifications[firestoreKey] as String? ?? 'not_uploaded')
        .toLowerCase();
    final isVerified = status == 'verified';
    final isPending = status == 'pending';

    final color = isVerified
        ? Colors.green
        : isPending
        ? Colors.orange
        : Colors.grey;
    final bg = isVerified
        ? Colors.green[50]
        : isPending
        ? Colors.yellow[50]
        : Colors.grey[100];
    final border = isVerified
        ? Colors.green.shade200
        : isPending
        ? Colors.yellow.shade200
        : Colors.grey.shade300;
    final icon = isVerified
        ? Icons.verified_user
        : isPending
        ? Icons.warning_amber_rounded
        : Icons.upload_file_outlined;
    final statusText = isVerified
        ? 'Verified'
        : isPending
        ? 'Pending Verification'
        : 'Not Uploaded';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontWeight: FontWeight.w600, color: color),
                ),
                const SizedBox(height: 4),
                Text(statusText, style: TextStyle(fontSize: 12, color: color)),
              ],
            ),
          ),
          if (isVerified)
            Icon(Icons.check_circle, color: color, size: 20)
          else
            TextButton(
              onPressed: () => _openVerificationUpload(firestoreKey),
              child: const Text('Upload'),
            ),
        ],
      ),
    );
  }

  Future<void> _openVerificationUpload(String firestoreKey) async {
    if (firestoreKey == 'pan') {
      await Navigator.pushNamed(context, PANCardVerificationScreen.routeName);
    } else if (firestoreKey == 'aadhaar') {
      await Navigator.pushNamed(
        context,
        GovernmentIdVerificationScreen.routeName,
      );
    } else {
      await Navigator.pushNamed(
        context,
        IdentityVerificationScreen.routeName,
        arguments: {'focusKey': firestoreKey},
      );
    }

    if (mounted) {
      await _loadUserData();
    }
  }

  // ─── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: WorkableDesign.canvas,
        appBar: AppBar(title: const Text('Personal Information')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final profileCompletion = calculateProfileCompletion();

    // BUG FIX 3: Relationship dropdown disabled until name + 10-digit phone filled
    final relationDisabled =
        emergencyNameController.text.trim().isEmpty ||
        emergencyPhoneController.text.trim().length != 10;

    return Scaffold(
      backgroundColor: WorkableDesign.canvas,
      appBar: AppBar(
        title: const Text('Personal Information'),
        leading: const BackButton(),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          children: [
            const WorkablePageHeader(
              title: 'Personal profile',
              subtitle:
                  'Keep contact, safety, and identity details accurate for faster bookings and trusted support.',
              icon: Icons.person_outline,
            ),
            const SizedBox(height: 16),
            // ── Profile Completion ──────────────────────────────────────
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Profile Completion',
                          style: TextStyle(fontWeight: FontWeight.w500),
                        ),
                        Text(
                          '${profileCompletion.toStringAsFixed(0)}%',
                          style: const TextStyle(
                            color: WorkableDesign.primary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: profileCompletion / 100,
                        color: WorkableDesign.primary,
                        backgroundColor: WorkableDesign.border,
                        minHeight: 8,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Profile Photo ───────────────────────────────────────────
            sectionCard(
              title: 'Profile Photo',
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundColor: WorkableDesign.primary,
                      backgroundImage:
                          (profileImageUrl != null &&
                              profileImageUrl!.isNotEmpty)
                          ? NetworkImage(profileImageUrl!)
                          : null,
                      child:
                          (profileImageUrl == null || profileImageUrl!.isEmpty)
                          ? Text(
                              getInitials(),
                              style: const TextStyle(
                                fontSize: 24,
                                color: Colors.white,
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'Update Profile Picture',
                            style: TextStyle(fontWeight: FontWeight.w500),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'JPG, PNG, GIF up to 5MB',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),

            // ── Basic Info ──────────────────────────────────────────────
            sectionCard(
              title: 'Basic Information',
              children: [
                Row(
                  children: [
                    Expanded(
                      child: textInput(
                        'First Name',
                        firstNameController,
                        required: true,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: textInput(
                        'Last Name',
                        lastNameController,
                        required: true,
                      ),
                    ),
                  ],
                ),
                textInput(
                  'Email Address',
                  emailController,
                  type: TextInputType.emailAddress,
                  required: true,
                  verified: true,
                  alwaysReadOnly: true,
                ),
                textInput(
                  'Phone Number',
                  phoneController,
                  type: TextInputType.phone,
                  required: true,
                  verified: true,
                  alwaysReadOnly: true,
                ),
                // BUG FIX 2: digits only, max 10, live error
                textInput(
                  'Alternate Phone',
                  altPhoneController,
                  type: TextInputType.phone,
                  digitsOnly: true,
                  maxLength: 10,
                  errorText: _altPhoneError,
                ),
                textInput(
                  'Date of Birth',
                  dobController,
                  required: true,
                  onTap: _pickDateOfBirth,
                ),
                dropdownField(
                  'Gender',
                  gender,
                  ['Male', 'Female', 'Other', 'Prefer not to say'],
                  (val) => setState(() => gender = val ?? gender),
                  required: true,
                ),
              ],
            ),

            // ── Professional Info ───────────────────────────────────────
            sectionCard(
              title: 'Professional Details',
              children: [
                textInput('Occupation', occupationController),
                textInput('Company / Organization', companyController),
                dropdownField(
                  'Preferred Language',
                  preferredLanguage,
                  ['English', 'Hindi', 'Kannada', 'Tamil', 'Telugu'],
                  (val) => setState(
                    () => preferredLanguage = val ?? preferredLanguage,
                  ),
                ),
              ],
            ),

            // ── Emergency Contact ───────────────────────────────────────
            sectionCard(
              title: 'Emergency Contact',
              children: [
                textInput('Contact Name', emergencyNameController),
                // BUG FIX 2: digits only, max 10
                textInput(
                  'Contact Phone',
                  emergencyPhoneController,
                  type: TextInputType.phone,
                  digitsOnly: true,
                  maxLength: 10,
                ),
                // BUG FIX 3: Relationship locked until name + phone complete
                dropdownField(
                  'Relationship',
                  emergencyRelation,
                  ['Spouse', 'Parent', 'Sibling', 'Friend', 'Other'],
                  (val) => setState(
                    () => emergencyRelation = val ?? emergencyRelation,
                  ),
                  disabled: relationDisabled,
                ),
                if (relationDisabled)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: Text(
                      'Enter a contact name and 10-digit phone number to select the relationship.',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ),
              ],
            ),

            // ── Saved Addresses ─────────────────────────────────────────
            // BUG FIX 4: Always visible with empty state + Add button always shown
            sectionCard(
              title: 'Saved Addresses',
              children: [
                if (addresses.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: const [
                        Icon(
                          Icons.location_off_outlined,
                          color: Colors.grey,
                          size: 20,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'No saved addresses yet.',
                          style: TextStyle(fontSize: 13, color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                else
                  ...addresses.map((address) {
                    final isHome = address['type'] == 'Home';
                    final isDefault = address['isDefault'] == true;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: const BorderSide(color: Colors.grey),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 6,
                                    children: [
                                      Chip(
                                        label: Text(address['type']),
                                        backgroundColor: isHome
                                            ? Colors.green[100]
                                            : Colors.blue[100],
                                        labelStyle: TextStyle(
                                          color: isHome
                                              ? Colors.green[700]
                                              : Colors.blue[700],
                                        ),
                                      ),
                                      if (isDefault)
                                        const Chip(
                                          label: Text('Default'),
                                          backgroundColor: Color(0xFFEDEDED),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    address['address'] ?? '',
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => setState(() {
                                addresses.removeWhere(
                                  (a) => a['id'] == address['id'],
                                );
                              }),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                // BUG FIX 4: Always visible
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () async {
                      await Navigator.pushNamed(
                        context,
                        AddNewAddressScreen.routeName,
                      );
                      if (mounted) {
                        await _loadUserData();
                      }
                    },
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add Address'),
                  ),
                ),
              ],
            ),

            // ── Identity Verification ───────────────────────────────────
            sectionCard(
              title: 'Identity Verification',
              children: [
                _verificationTile('Aadhaar Card', 'aadhaar'),
                _verificationTile('PAN Card', 'pan'),
              ],
            ),

            // ── Account Security ────────────────────────────────────────
            sectionCard(
              title: 'Account Security',
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Password',
                          style: TextStyle(fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Last updated $passwordLastUpdated',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                    TextButton(
                      onPressed: () async {
                        final changed = await Navigator.pushNamed(
                          context,
                          ChangePasswordScreen.routeName,
                        );
                        if (changed == true && mounted) {
                          await _loadUserData();
                        }
                      },
                      child: const Text('Change'),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 16),

            // ── Save Button ─────────────────────────────────────────────
            // BUG FIX 1: Always visible. Fades in when user makes a change.
            // Stays disabled (faded) if nothing changed or validation fails.
            SizedBox(
              width: double.infinity,
              child: AnimatedOpacity(
                opacity: _canSave ? 1.0 : 0.4,
                duration: const Duration(milliseconds: 200),
                child: ElevatedButton(
                  onPressed: _canSave ? _saveChanges : null,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text('Save Changes'),
                ),
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
