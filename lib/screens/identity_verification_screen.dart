import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../widgets/custom_button.dart';
import 'dart:async';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as path;
import 'background_check_screen.dart';
import 'government_id_verification_screen.dart';
import 'pan_card_verification_screen.dart';
import 'phone_verification_screen.dart';

import '../services/verification_tier_manager.dart';

class IdentityVerificationScreen extends StatefulWidget {
  static const routeName = '/identity-verification';

  const IdentityVerificationScreen({super.key});

  @override
  State<IdentityVerificationScreen> createState() =>
      _IdentityVerificationScreenState();
}

class _IdentityVerificationScreenState
    extends State<IdentityVerificationScreen> {
  Map<String, String> statuses = {};
  bool isLoading = true;
  String? userPhone;
  String? userEmail;
  String? currentTier;
  int _completedSteps = 0;
  int _totalSteps = 5;
  String _userTier = 'new';
  StreamSubscription<QuerySnapshot>? _statusSubscription;

  void _calculateTierProgress(Map<String, String> status) {
    _completedSteps = 0;

    if (status['selfie'] == 'verified') _completedSteps++;
    if ([
      status['aadhaar'],
      status['passport'],
      status['voter'],
      status['driving_license'],
    ].contains('verified'))
      _completedSteps++;
    if (status['pan'] == 'verified') _completedSteps++;
    if (status['addressProof'] == 'verified' || status['address'] == 'verified')
      _completedSteps++;
    if (status['phone'] == 'verified') _completedSteps++;

    _userTier = VerificationTierManager().determineTierFromStatus(status);
  }

  void _startVerificationStatusListener() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    _statusSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('identityVerification')
        .snapshots()
        .listen((snapshot) {
          final updatedStatuses = <String, String>{};
          for (var doc in snapshot.docs) {
            final key = doc.id;
            final data = doc.data();
            if (data.containsKey('status')) {
              updatedStatuses[key] = data['status'].toString();
            }
          }

          setState(() {
            statuses = updatedStatuses;
            _calculateTierProgress(updatedStatuses);
          });
        });
  }

  void _showUploadOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          runSpacing: 16,
          children: [
            ListTile(
              leading: const Icon(Icons.insert_drive_file, color: Colors.blue),
              title: const Text('Upload PAN Card'),
              onTap: () {
                Navigator.pop(context);
                _pickAndUploadImage('pan', 'pan_card.jpg');
              },
            ),
            ListTile(
              leading: const Icon(Icons.home_work, color: Colors.teal),
              title: const Text('Upload Address Proof'),
              onTap: () {
                Navigator.pop(context);
                _pickAndUploadImage('addressProof', 'address_proof.jpg');
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Colors.orange),
              title: const Text('Take Selfie'),
              onTap: () {
                Navigator.pop(context);
                _captureAndUploadSelfie();
              },
            ),
          ],
        ),
      ),
    );
  }

  final ImagePicker _picker = ImagePicker();

  Future<void> _pickAndUploadImage(String fieldKey, String fileName) async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    // Safely get the current user. If not logged in, simply return.
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print('❌ Cannot upload image: no authenticated user.');
      return;
    }
    final uid = user.uid;

    final file = File(picked.path);
    final storageRef = FirebaseStorage.instance.ref().child(
      'identity_verification/$uid/$fileName',
    );

    await storageRef.putFile(file);
    final downloadUrl = await storageRef.getDownloadURL();

    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('identityVerification')
        .doc(fieldKey)
        .set({
          'status': 'pending',
          'fileUrl': downloadUrl,
          'submittedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

    // Refresh status after upload
    _loadVerificationStatus();
  }

  Future<void> _captureAndUploadSelfie() async {
    final picked = await _picker.pickImage(source: ImageSource.camera);
    if (picked == null) return;

    // Safely get the current user. If not logged in, simply return.
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print('❌ Cannot upload selfie: no authenticated user.');
      return;
    }
    final uid = user.uid;

    final file = File(picked.path);
    final storageRef = FirebaseStorage.instance.ref().child(
      'identity_verification/$uid/selfie.jpg',
    );

    await storageRef.putFile(file);
    final downloadUrl = await storageRef.getDownloadURL();

    // Update the status and file reference in Firestore
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('identityVerification')
        .doc('status')
        .set({'selfie': 'pending'}, SetOptions(merge: true));

    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('identityVerification')
        .doc('files')
        .set({'selfie': downloadUrl}, SetOptions(merge: true));

    // Refresh status after upload
    _loadVerificationStatus();
  }

  final List<Map<String, dynamic>> verificationItems = [
    {
      'key': 'aadhaar',
      'icon': LucideIcons.fileText,
      'title': 'Government ID',
      'subtitle': 'Aadhaar Card',
    },
    {
      'key': 'pan',
      'icon': LucideIcons.fileText,
      'title': 'PAN Card',
      'subtitle': 'Upload your PAN card',
    },
    {
      'key': 'addressProof',
      'icon': LucideIcons.mapPin,
      'title': 'Address Proof',
      'subtitle': 'Utility bill or bank statement',
    },
    {
      'key': 'selfie',
      'icon': LucideIcons.camera,
      'title': 'Selfie Verification',
      'subtitle': 'Take a clear selfie for identity matching',
      'onTap': true, // custom flag to identify interactive item
    },
    {
      'key': 'backgroundCheck',
      'icon': LucideIcons.shield,
      'title': 'Background Check',
      'subtitle': 'Police verification certificate',
      'isRequired': false,
    },
  ];

  @override
  void initState() {
    super.initState();
    _safeLoadStatus();
    _fetchVerificationTier();
    _startVerificationStatusListener();
  }

  @override
  void dispose() {
    _statusSubscription?.cancel();
    super.dispose();
  }

  Future<void> _fetchVerificationTier() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final tier = await VerificationTierManager().getUserVerificationTier(uid);
    setState(() {
      currentTier = tier;
    });
  }

  Future<void> _safeLoadStatus() async {
    try {
      await _loadVerificationStatus();
    } catch (e, stack) {
      print('❌ Error loading verification status: $e');
      print(stack); // will help pinpoint Firestore/logic errors
    }
  }

  Future<void> _loadVerificationStatus() async {
    // Always start by showing the loading indicator
    setState(() => isLoading = true);

    try {
      // Safely retrieve the current user. If no user is logged in, exit early.
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('❌ No authenticated user found.');
        setState(() => isLoading = false);
        return;
      }

      final uid = user.uid;
      print("🔍 Fetching user data for UID: $uid");

      // Fetch the user document from Firestore
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();

      final userData = userDoc.data();
      if (userData == null) {
        print("❌ No user document found.");
        setState(() => isLoading = false);
        return;
      }

      // Extract phone and email, defaulting to empty strings if missing
      userPhone = userData['phoneNumber']?.toString() ?? '';
      userEmail = userData['email']?.toString() ?? '';
      print("👤 userPhone: $userPhone");
      print("📧 userEmail: $userEmail");

      // Now load the identityVerification subcollection for this user
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('identityVerification')
          .get();

      // Reset the statuses map before repopulating it
      statuses.clear();

      const validKeys = {
        'aadhaar',
        'pan',
        'addressProof',
        'selfie',
        'email',
        'phone',
        'backgroundCheck',
      };

      for (var doc in snapshot.docs) {
        final key = doc.id;
        final data = doc.data();

        // Skip any unknown keys so we only track expected verification items
        if (!validKeys.contains(key)) {
          print("⚠️ Skipping unknown document: $key");
          continue;
        }

        if (data.containsKey('status')) {
          statuses[key] = data['status'].toString();
          print("📄 $key = ${data['status']}");
        } else {
          print("⚠️ '$key' has no status field");
        }
      }
    } catch (e, stack) {
      // Catch and log any unexpected errors
      print('❌ Error loading verification status: $e');
      print(stack);
    }
    print("✅ Done loading verification status.");

    // Finally, hide the loading indicator
    setState(() => isLoading = false);
    _calculateTierProgress(statuses);
  }

  int get completedCount =>
      statuses.values.where((status) => status == 'verified').length;

  double get progress => completedCount / 6.0;

  String getProgressLabel() => "$completedCount of 6 completed";

  String getActionText(String status) {
    switch (status) {
      case 'verified':
        return 'Verified successfully';
      case 'pending':
        return 'Under review (2–3 hours)';
      case 'failed':
        return 'Reupload required - Image unclear';
      default:
        return 'Click to start verification';
    }
  }

  Widget _buildPhoneVerificationCard() {
    final status = statuses['phone'];
    final isVerified = status == 'verified';

    return GestureDetector(
      onTap: () async {
        final result = await Navigator.pushNamed(
          context,
          PhoneVerificationScreen.routeName,
        );
        if (result == true) {
          _loadVerificationStatus(); // Refresh after return
        }
      },
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isVerified ? Colors.green.shade50 : Colors.white,
          border: Border.all(
            color: isVerified ? Colors.green : Colors.grey.shade300,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const CircleAvatar(
              backgroundColor: Color(0xFFEFFDF5),
              child: Icon(LucideIcons.phone, color: Colors.green),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Phone Verification',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isVerified
                        ? 'Phone number verified successfully'
                        : 'Tap to verify your phone number',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isVerified
                    ? Colors.green.shade100
                    : Colors.orange.shade100,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                isVerified ? 'Verified' : 'Not Verified',
                style: TextStyle(
                  fontSize: 12,
                  color: isVerified ? Colors.green : Colors.orange,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    print("🛠️ Build called. isLoading = $isLoading");

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Identity Verification'),
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.helpCircle),
            onPressed: () {},
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStatusCard(),

                  if (currentTier != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12, bottom: 4),
                      child: Chip(
                        label: Text(
                          'Your Tier: ${currentTier!.replaceAll('_', ' ').toUpperCase()}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        backgroundColor: Colors.indigo.shade50,
                        avatar: const Icon(
                          Icons.verified_user,
                          color: Colors.indigo,
                        ),
                      ),
                    ),

                  const SizedBox(height: 20),
                  _buildSectionTitle('Basic Information'),
                  if (userPhone != null)
                    _buildVerificationItem({
                      'key': 'phone',
                      'icon': LucideIcons.phone,
                      'title': 'Phone Number',
                      'subtitle': userPhone ?? 'Phone not linked',
                      'status': userPhone != null ? 'verified' : 'incomplete',
                    }),
                  if (userEmail != null)
                    _buildVerificationItem({
                      'key': 'email',
                      'icon': LucideIcons.mail,
                      'title': 'Email Address',
                      'subtitle': userEmail!,
                      'status': 'verified',
                    }),
                  if (userPhone == null)
                    _buildVerificationItem({
                      'key': 'phone',
                      'icon': LucideIcons.phone,
                      'title': 'Phone Number',
                      'subtitle': 'Phone not linked',
                      'status': 'incomplete',
                    }),
                  if (userEmail == null)
                    _buildVerificationItem({
                      'key': 'email',
                      'icon': LucideIcons.mail,
                      'title': 'Email Address',
                      'subtitle': 'Email not linked',
                      'status': 'incomplete',
                    }),

                  const SizedBox(height: 20),
                  _buildSectionTitle('Document Verification'),
                  _buildVerificationItem(verificationItems[0]), // Aadhaar
                  _buildVerificationItem(verificationItems[1]), // PAN
                  _buildVerificationItem(verificationItems[2]), // Address Proof

                  const SizedBox(height: 20),
                  _buildSectionTitle('Photo Verification'),
                  _buildVerificationItem(verificationItems[3]), // Selfie

                  const SizedBox(height: 20),
                  _buildSectionTitle('Additional Checks'),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.shade100,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Worker Only',
                      style: TextStyle(fontSize: 12, color: Colors.green),
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildPhoneVerificationCard(),

                  _buildVerificationItem(
                    verificationItems[4],
                  ), // Background Check
                  const SizedBox(height: 20),
                  _buildQuickActions(),
                  const SizedBox(height: 20),
                  _buildBenefitsCard(),
                  const SizedBox(height: 20),
                  _buildSupportCard(),
                ],
              ),
            ),
    );
  }

  Widget _buildStatusCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade100),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const CircleAvatar(
                backgroundColor: Color(0xFFE0F2FE),
                child: Icon(LucideIcons.shield, color: Colors.blue),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Verification Status',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      getProgressLabel(),
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.orange,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text('Progress', style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: LinearProgressIndicator(
                  //value: progress,
                  value: _completedSteps / _totalSteps,

                  minHeight: 8,
                  color: Colors.blue,
                  backgroundColor: Colors.grey,
                ),
              ),
              const SizedBox(width: 8),

              Text(
                '${(progress * 100).toInt()}%',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              Text(
                'Tier: ${_userTier.replaceAll('_', ' ').toUpperCase()} ($_completedSteps of $_totalSteps verified)',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: 'Almost there! ',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextSpan(
                    text:
                        'Complete your remaining verifications to unlock full platform access and build customer trust.',
                  ),
                ],
              ),
              style: TextStyle(fontSize: 13, color: Colors.blue),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerificationItem(Map<String, dynamic> item) {
    final status = item['status'] ?? statuses[item['key']] ?? 'incomplete';
    final isRequired = item['isRequired'] != false;
    final actionText = getActionText(status);
    final icon = item['icon'] as IconData;
    final String key = item['key'];

    Color bgColor, borderColor;
    Icon statusIcon;

    switch (status) {
      case 'verified':
        bgColor = Colors.green.shade50;
        borderColor = Colors.green.shade200;
        statusIcon = const Icon(
          LucideIcons.check,
          size: 18,
          color: Colors.green,
        );
        break;
      case 'pending':
        bgColor = Colors.yellow.shade50;
        borderColor = Colors.yellow.shade200;
        statusIcon = const Icon(
          LucideIcons.clock,
          size: 18,
          color: Colors.orange,
        );
        break;
      case 'failed':
        bgColor = Colors.red.shade50;
        borderColor = Colors.red.shade200;
        statusIcon = const Icon(
          LucideIcons.alertCircle,
          size: 18,
          color: Colors.red,
        );
        break;
      default:
        bgColor = Colors.grey.shade100;
        borderColor = Colors.grey.shade300;
        statusIcon = const Icon(LucideIcons.chevronRight, size: 18);
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: Colors.white,
            child: Icon(icon, color: Colors.blue),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      item['title'],
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    if (isRequired)
                      Container(
                        margin: const EdgeInsets.only(left: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade100,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'Required',
                          style: TextStyle(fontSize: 10, color: Colors.blue),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(item['subtitle'], style: const TextStyle(fontSize: 13)),
                const SizedBox(height: 2),

                // 👉 Dynamic clickable logic based on status + key
                GestureDetector(
                  onTap: () async {
                    final key = item['key'];

                    if (key == 'pan') {
                      final result = await Navigator.pushNamed(
                        context,
                        PANCardVerificationScreen.routeName,
                      );
                      if (result == true) _loadVerificationStatus();
                    }

                    if (key == 'aadhaar') {
                      final result = await Navigator.pushNamed(
                        context,
                        '/government-id-verification',
                      );
                      if (result == true) _loadVerificationStatus();
                    }

                    if (key == 'phone' && status != 'verified') {
                      final result = await Navigator.pushNamed(
                        context,
                        '/phone-verification',
                      );
                      if (result == true) _loadVerificationStatus();
                    }

                    if (key == 'email' && status == 'pending') {
                      final result = await Navigator.pushNamed(
                        context,
                        '/email-verification',
                      );
                      if (result == true) _loadVerificationStatus();
                    }

                    if (key == 'addressProof') {
                      Navigator.pushNamed(context, '/address-verification');
                    }

                    if (key == 'selfie' && status != 'verified') {
                      final result = await Navigator.pushNamed(
                        context,
                        '/selfie-verification',
                      );
                      if (result == true) _loadVerificationStatus();
                    }
                    if (key == 'backgroundCheck') {
                      Navigator.pushNamed(context, '/background-check');
                    }
                  },
                  child: Text(
                    actionText,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.blue,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
          ),
          statusIcon,
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Text(
        title,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildQuickActions() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade100),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          const Text(
            'Quick Actions',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: CustomButton(
                  text: 'Upload Documents',
                  icon: LucideIcons.upload,
                  backgroundColor: Colors.blue.shade50,
                  textColor: Colors.blue,
                  // onPressed: () {
                  //   // TODO: Navigate to upload screen
                  // },
                  onPressed: () => _showUploadOptions(context),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: CustomButton(
                  text: 'Refresh Status',
                  icon: LucideIcons.refreshCw,
                  backgroundColor: Colors.grey.shade100,
                  textColor: Colors.grey.shade800,
                  onPressed: _loadVerificationStatus,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBenefitsCard() {
    final benefits = [
      'Build trust with customers and workers',
      'Access premium features and priority support',
      'Secure your account and transactions',
      'Higher visibility in search results',
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFE6F4EA), Color(0xFFE0F2FE)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.green.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Why Verify Your Identity?',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),
          ...benefits.map(
            (text) => Row(
              children: [
                const Icon(LucideIcons.check, size: 16, color: Colors.green),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(text, style: const TextStyle(fontSize: 13)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSupportCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade100),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            backgroundColor: Color(0xFFE0F2FE),
            child: Icon(LucideIcons.helpCircle, color: Colors.blue),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Need Help?',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                SizedBox(height: 4),
                Text(
                  'Contact our verification support team',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () {
              // TODO: Navigate to support screen
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Contact', style: TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }
}
