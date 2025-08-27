import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PersonalInformationScreen extends StatefulWidget {
  static const routeName = '/personal-information';

  const PersonalInformationScreen({Key? key}) : super(key: key);

  @override
  State<PersonalInformationScreen> createState() =>
      _PersonalInformationScreenState();
}

class _PersonalInformationScreenState extends State<PersonalInformationScreen> {
  final userId = FirebaseAuth.instance.currentUser?.uid;
  late DocumentReference userDoc;

  bool isEditing = false;
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

  String gender = "Male";
  String preferredLanguage = "English";
  String emergencyRelation = "Spouse";

  @override
  void initState() {
    super.initState();
    if (userId != null) {
      userDoc = FirebaseFirestore.instance.collection('users').doc(userId);
      _loadUserData();
    }
  }

  Future<void> _loadUserData() async {
    try {
      final snapshot = await userDoc.get();
      final data = snapshot.data() as Map<String, dynamic>?; // ✅ FIXED

      if (data != null) {
        setState(() {
          firstNameController.text = data['firstName'] ?? '';
          lastNameController.text = data['lastName'] ?? '';
          emailController.text = data['email'] ?? '';
          phoneController.text = data['phoneNumber'] ?? '';
          altPhoneController.text = data['altPhone'] ?? '';
          dobController.text = data['dob'] ?? '';
          occupationController.text = data['occupation'] ?? '';
          companyController.text = data['company'] ?? '';
          emergencyNameController.text = data['emergencyName'] ?? '';
          emergencyPhoneController.text = data['emergencyPhone'] ?? '';
          gender = data['gender'] ?? 'Male';
          preferredLanguage = data['preferredLanguage'] ?? 'English';
          emergencyRelation = data['emergencyRelation'] ?? 'Spouse';
        });

        addresses =
            (data['addresses'] as List<dynamic>?)
                ?.map((e) => Map<String, dynamic>.from(e))
                .toList() ??
            [];
      }
    } catch (e) {
      debugPrint('Error loading user data: $e');
    }
  }

  Future<void> _showSaveDialog() async {
    final shouldSave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Save Changes?"),
        content: const Text(
          "Do you want to save the changes made to your profile?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Save"),
          ),
        ],
      ),
    );

    if (shouldSave ?? false) {
      try {
        await userDoc.update({
          'firstName': firstNameController.text.trim(),
          'lastName': lastNameController.text.trim(),
          'email': emailController.text.trim(),
          'phoneNumber': phoneController.text.trim(),
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
        });

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Profile changes saved.')));

        setState(() => isEditing = false);
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error saving profile: $e')));
      }
    }
  }

  @override
  void dispose() {
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

  // Your UI widgets (textInput, dropdownField, sectionCard) remain unchanged...
  // Your entire `build()` method remains unchanged...

  Widget sectionCard({required String title, required List<Widget> children}) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
    TextInputType? type,
  }) {
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
          ],
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          enabled: isEditing,
          keyboardType: type ?? TextInputType.text,
          decoration: InputDecoration(
            isDense: true,
            filled: !isEditing,
            fillColor: isEditing ? null : Colors.grey[100],
            contentPadding: const EdgeInsets.symmetric(
              vertical: 12,
              horizontal: 12,
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget dropdownField(
    String label,
    String value,
    List<String> options,
    void Function(String?) onChanged, {
    bool required = false,
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
            contentPadding: const EdgeInsets.symmetric(
              vertical: 12,
              horizontal: 12,
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
          items: options
              .map((opt) => DropdownMenuItem(value: opt, child: Text(opt)))
              .toList(),
          onChanged: isEditing ? onChanged : null,
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  double calculateProfileCompletion() {
    int filled = 0;
    int total = 10;

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

  @override
  Widget build(BuildContext context) {
    final profileCompletion = calculateProfileCompletion(); // ✅ Add here
    return Scaffold(
      appBar: AppBar(
        title: const Text('Personal Information'),
        leading: const BackButton(),

        // actions: [
        //   TextButton.icon(
        //     icon: Icon(isEditing ? LucideIcons.save : LucideIcons.edit3),
        //     label: Text(isEditing ? 'Save' : 'Edit'),
        //     onPressed: () {
        //       if (isEditing) {
        //         // 👉 TODO: Save logic — Firestore or Local Storage here
        //         ScaffoldMessenger.of(context).showSnackBar(
        //           const SnackBar(content: Text('Profile changes saved.')),
        //         );
        //       }
        //       setState(() {
        //         isEditing = !isEditing;
        //       });
        //     },
        //   ),
        // ],
        actions: [
          IconButton(
            tooltip: isEditing ? 'Save' : 'Edit',
            icon: Icon(
              isEditing ? Icons.save_outlined : Icons.edit_outlined,
              color: Colors.white, // or Theme.of(context).iconTheme.color
            ),
            onPressed: () {
              if (isEditing) {
                _showSaveDialog(); // Or inline save
              } else {
                setState(() => isEditing = true);
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          children: [
            // Profile Completion
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
                          '$profileCompletion%',
                          style: const TextStyle(color: Colors.blue),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: profileCompletion / 100,
                        color: Colors.blue,
                        backgroundColor: Colors.grey[300],
                        minHeight: 8,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Profile Photo
            sectionCard(
              title: 'Profile Photo',
              children: [
                Row(
                  children: [
                    Stack(
                      children: [
                        CircleAvatar(
                          radius: 40,
                          backgroundColor: Colors.blue,
                          child: Text(
                            getInitials(),
                            style: const TextStyle(
                              fontSize: 24,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        if (isEditing)
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: CircleAvatar(
                              radius: 14,
                              backgroundColor: Colors.blueAccent,
                              child: const Icon(
                                Icons.camera_alt,
                                size: 16,
                                color: Colors.white,
                              ),
                            ),
                          ),
                      ],
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

            // Basic Info
            sectionCard(
              title: 'Basic Information',
              children: [
                Row(
                  children: [
                    Expanded(
                      child: textInput(
                        "First Name",
                        firstNameController,
                        required: true,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: textInput(
                        "Last Name",
                        lastNameController,
                        required: true,
                      ),
                    ),
                  ],
                ),
                textInput(
                  "Email Address",
                  emailController,
                  type: TextInputType.emailAddress,
                  required: true,
                  verified: true,
                ),
                textInput(
                  "Phone Number",
                  phoneController,
                  type: TextInputType.phone,
                  required: true,
                  verified: true,
                ),
                textInput(
                  "Alternate Phone",
                  altPhoneController,
                  type: TextInputType.phone,
                ),
                textInput("Date of Birth", dobController, required: true),
                dropdownField(
                  "Gender",
                  gender,
                  ["Male", "Female", "Other", "Prefer not to say"],
                  (val) => setState(() => gender = val ?? gender),
                  required: true,
                ),
              ],
            ),

            // Professional Info
            sectionCard(
              title: 'Professional Details',
              children: [
                textInput("Occupation", occupationController),
                textInput("Company/Organization", companyController),
                dropdownField(
                  "Preferred Language",
                  preferredLanguage,
                  ["English", "Hindi", "Kannada", "Tamil", "Telugu"],
                  (val) => setState(
                    () => preferredLanguage = val ?? preferredLanguage,
                  ),
                ),
              ],
            ),

            // Emergency Contact
            sectionCard(
              title: 'Emergency Contact',
              children: [
                textInput("Contact Name", emergencyNameController),
                textInput(
                  "Contact Phone",
                  emergencyPhoneController,
                  type: TextInputType.phone,
                ),
                dropdownField(
                  "Relationship",
                  emergencyRelation,
                  ["Spouse", "Parent", "Sibling", "Friend", "Other"],
                  (val) => setState(
                    () => emergencyRelation = val ?? emergencyRelation,
                  ),
                ),
              ],
            ),
            // Addresses
            sectionCard(
              title: 'Saved Addresses',
              children: [
                ...addresses.map((address) {
                  final isHome = address['type'] == 'Home';
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
                                    if (address['isDefault'])
                                      const Chip(
                                        label: Text("Default"),
                                        backgroundColor: Color(0xFFEDEDED),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  address['address'],
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                          if (isEditing)
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () {
                                setState(() {
                                  addresses.removeWhere(
                                    (a) => a['id'] == address['id'],
                                  );
                                });
                              },
                            ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
                if (isEditing)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () {
                        // Add address logic
                      },
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text("Add Address"),
                    ),
                  ),
              ],
            ),

            // Identity Verification
            sectionCard(
              title: 'Identity Verification',
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      const Icon(Icons.verified_user, color: Colors.green),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              "Aadhaar Card",
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Colors.green,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              "Verified",
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.check_circle,
                        color: Colors.green,
                        size: 20,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.yellow[50],
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.yellow.shade200),
                  ),
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        color: Colors.orange,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              "PAN Card",
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Colors.orange,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              "Pending Verification",
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.orange,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isEditing)
                        TextButton(
                          onPressed: () {
                            // upload PAN logic
                          },
                          child: const Text("Upload"),
                        ),
                    ],
                  ),
                ),
              ],
            ),

            // Account Security
            sectionCard(
              title: 'Account Security',
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Password",
                          style: TextStyle(fontWeight: FontWeight.w500),
                        ),
                        SizedBox(height: 4),
                        Text(
                          "Last updated 2 months ago",
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                    if (isEditing)
                      TextButton(
                        onPressed: () {
                          // open change password dialog
                        },
                        child: const Text("Change"),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Two-Factor Authentication",
                          style: TextStyle(fontWeight: FontWeight.w500),
                        ),
                        SizedBox(height: 4),
                        Text(
                          "Add extra security to your account",
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        const Text("Off", style: TextStyle(color: Colors.grey)),
                        if (isEditing) Switch(value: false, onChanged: (_) {}),
                      ],
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 16),
            if (isEditing)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => setState(() => isEditing = false),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        // Save logic here
                        _showSaveDialog();
                        setState(() => isEditing = false);
                      },
                      child: const Text('Save Changes'),
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
