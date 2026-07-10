import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../widgets/custom_button.dart';
import 'dart:async';
import '../core/theme/workable_design.dart';
import 'pan_card_verification_screen.dart';
import 'address_verification_screen.dart';
import '../services/verification_tier_manager.dart';
import '../services/notification_service.dart';
import '../services/worker_visibility_service.dart';

class IdentityVerificationScreen extends StatefulWidget {
  static const routeName = '/identity-verification';
  const IdentityVerificationScreen({super.key});
  @override
  State<IdentityVerificationScreen> createState() =>
      _IdentityVerificationScreenState();
}

class _IdentityVerificationScreenState extends State<IdentityVerificationScreen>
    with SingleTickerProviderStateMixin {
  Map<String, Map<String, dynamic>> verificationData = {};
  bool isLoading = true;
  String? userPhone;
  String? userEmail;
  bool isPhoneVerified = false;
  String? currentTier;
  int _completedSteps = 0;
  final int _totalSteps = 6;
  String _userTier = 'new';
  StreamSubscription<QuerySnapshot>? _statusSubscription;
  final ScrollController _scrollController = ScrollController();
  final Map<String, GlobalKey> _verificationItemKeys = {
    'aadhaar': GlobalKey(),
    'pan': GlobalKey(),
    'addressProof': GlobalKey(),
    'selfie': GlobalKey(),
    'phone': GlobalKey(),
    'email': GlobalKey(),
    'backgroundCheck': GlobalKey(),
  };
  late final AnimationController _focusPulseController;
  late final Animation<double> _focusPulseAnimation;
  String? _requestedFocusKey;
  String? _highlightedKey;
  bool _didHandleInitialFocus = false;

  void _calculateTierProgress(Map<String, String> status) {
    _completedSteps = 0;

    if (status['selfie'] == 'verified') _completedSteps++;
    if ([
      status['aadhaar'],
      status['passport'],
      status['voter'],
      status['driving_license'],
    ].contains('verified')) {
      _completedSteps++;
    }
    if (status['pan'] == 'verified') _completedSteps++;
    if (status['addressProof'] == 'verified' ||
        status['address'] == 'verified') {
      _completedSteps++;
    }
    if (status['phone'] == 'verified') _completedSteps++;
    _userTier = VerificationTierManager().determineTierFromStatus(status);
  }

  // void _startVerificationStatusListener() {
  //   final uid = FirebaseAuth.instance.currentUser?.uid;
  //   if (uid == null) return;

  //   _statusSubscription = FirebaseFirestore.instance
  //       .collection('users')
  //       .doc(uid)
  //       .collection('identityVerification')
  //       .snapshots()
  //       .listen((snapshot) {
  //         final updatedStatuses = <String, String>{};
  //         for (var doc in snapshot.docs) {
  //           final key = doc.id;
  //           final data = doc.data();
  //           if (data.containsKey('status')) {
  //             updatedStatuses[key] = data['status'].toString();
  //           }
  //         }

  //         setState(() {
  //           statuses = updatedStatuses;
  //           _calculateTierProgress(updatedStatuses);
  //         });
  //       });
  // }
  void _startVerificationStatusListener() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    _statusSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('identityVerification')
        .snapshots()
        .listen((snapshot) {
          final updatedVerificationData = <String, Map<String, dynamic>>{};

          final extractedStatuses = <String, String>{};

          for (var doc in snapshot.docs) {
            final key = doc.id;
            final data = doc.data();

            updatedVerificationData[key] = data;

            extractedStatuses[key] = data['status']?.toString() ?? 'incomplete';
          }

          setState(() {
            verificationData = updatedVerificationData;
            _calculateTierProgress(extractedStatuses);
          });

          WorkerVisibilityService().syncWorkerVisibility(uid);
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
              leading: const Icon(Icons.badge, color: WorkableDesign.primary),
              title: const Text('Verify Government ID'),
              onTap: () {
                Navigator.pop(context);
                _openVerificationDestination('aadhaar');
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.insert_drive_file,
                color: WorkableDesign.primary,
              ),
              title: const Text('Upload PAN Card'),
              onTap: () {
                Navigator.pop(context);
                _openVerificationDestination('pan');
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.home_work,
                color: WorkableDesign.accent,
              ),
              title: const Text('Upload Address Proof'),
              onTap: () {
                Navigator.pop(context);
                _openVerificationDestination('addressProof');
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.camera_alt,
                color: WorkableDesign.warning,
              ),
              title: const Text('Take Selfie'),
              onTap: () {
                Navigator.pop(context);
                _openVerificationDestination('selfie');
              },
            ),
          ],
        ),
      ),
    );
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
      'key': 'policeCertificate',
      'icon': LucideIcons.shieldCheck,
      'title': 'Police Clearance Certificate',
      'subtitle': 'Optional trust & safety verification',
      'isRequired': false,
    },
  ];

  @override
  void initState() {
    super.initState();
    _focusPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _focusPulseAnimation = CurvedAnimation(
      parent: _focusPulseController,
      curve: Curves.easeInOut,
    );
    _safeLoadStatus();
    _fetchVerificationTier();
    _startVerificationStatusListener();

    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid != null) {
      NotificationService.markSuccessNotificationsAsRead(uid: uid);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map && args['focusKey'] is String) {
      _requestedFocusKey = args['focusKey'] as String;
    }
  }

  @override
  void dispose() {
    _statusSubscription?.cancel();
    _focusPulseController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scheduleInitialFocusIfNeeded() {
    if (_didHandleInitialFocus || isLoading || _requestedFocusKey == null) {
      return;
    }
    _didHandleInitialFocus = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusVerificationItem(_requestedFocusKey!);
    });
  }

  Future<void> _focusVerificationItem(String key) async {
    final targetContext = _verificationItemKeys[key]?.currentContext;
    if (targetContext == null || !mounted) return;

    await Scrollable.ensureVisible(
      targetContext,
      duration: const Duration(milliseconds: 650),
      curve: Curves.easeOutCubic,
      alignment: 0.22,
    );

    if (!mounted) return;
    setState(() => _highlightedKey = key);
    _focusPulseController
      ..reset()
      ..repeat(reverse: true);

    await Future.delayed(const Duration(milliseconds: 1800));
    if (!mounted) return;
    _focusPulseController.stop();
    _focusPulseController.reset();
    setState(() => _highlightedKey = null);
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
      debugPrint('Error loading verification status: $e');
      debugPrint(stack.toString());
    }
  }

  Future<void> _loadVerificationStatus() async {
    // Always start by showing the loading indicator
    setState(() => isLoading = true);

    try {
      // Safely retrieve the current user. If no user is logged in, exit early.
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        debugPrint('No authenticated user found.');
        setState(() => isLoading = false);
        return;
      }

      final uid = user.uid;
      debugPrint('Fetching user data for UID: $uid');

      // Fetch the user document from Firestore
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();

      final userData = userDoc.data();
      if (userData == null) {
        debugPrint('No user document found.');
        setState(() => isLoading = false);
        return;
      }

      // Extract phone and email, defaulting to empty strings if missing
      userPhone = userData['phoneNumber']?.toString() ?? '';
      userEmail = userData['email']?.toString() ?? '';
      isPhoneVerified = userData['phoneVerified'] == true;
      debugPrint('Loaded verification contact details.');

      // Now load the identityVerification subcollection for this user
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('identityVerification')
          .get();

      // Reset the statuses map before repopulating it
      verificationData.clear();

      const validKeys = {
        'aadhaar',
        'pan',
        'addressProof',
        'selfie',
        'email',
        'phone',
        'backgroundCheck',
        'policeCertificate',
      };

      for (var doc in snapshot.docs) {
        final key = doc.id;
        final data = doc.data();

        // Skip any unknown keys so we only track expected verification items
        if (!validKeys.contains(key)) {
          debugPrint('Skipping unknown verification document: $key');
          continue;
        }

        if (data.containsKey('status')) {
          verificationData[key] = data;
          debugPrint('Verification $key = ${data['status']}');
        } else {
          debugPrint('Verification $key has no status field');
        }
      }
    } catch (e, stack) {
      // Catch and log any unexpected errors
      debugPrint('Error loading verification status: $e');
      debugPrint(stack.toString());
    }
    debugPrint('Done loading verification status.');

    // Finally, hide the loading indicator
    setState(() => isLoading = false);
    final extractedStatuses = <String, String>{};

    verificationData.forEach((key, value) {
      extractedStatuses[key] = value['status']?.toString() ?? 'incomplete';
    });

    _calculateTierProgress(extractedStatuses);
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid != null) {
      await WorkerVisibilityService().syncWorkerVisibility(currentUid);
    }
  }

  double get progress => _completedSteps / _totalSteps;

  String getProgressLabel() => "$_completedSteps of $_totalSteps completed";

  String getActionText(String status) {
    switch (status) {
      case 'verified':
        return 'Verified successfully';
      case 'pending':
        return 'Under review (2-3 hours)';
      case 'rejected':
        return 'Rejected - Please re-upload';
      default:
        return 'Click to start verification';
    }
  }

  Future<void> _openVerificationDestination(String key) async {
    Object? result;

    if (key == 'pan') {
      result = await Navigator.pushNamed(
        context,
        PANCardVerificationScreen.routeName,
      );
    } else if (key == 'aadhaar') {
      result = await Navigator.pushNamed(
        context,
        '/government-id-verification',
      );
    } else if (key == 'phone') {
      result = await Navigator.pushNamed(context, '/phone-verification');
    } else if (key == 'email') {
      result = await Navigator.pushNamed(context, '/email-verification');
    } else if (key == 'addressProof') {
      result = await Navigator.pushNamed(
        context,
        AddressVerificationScreen.routeName,
      );
    } else if (key == 'selfie') {
      result = await Navigator.pushNamed(context, '/selfie-verification');
    } else if (key == 'policeCertificate') {
      result = await Navigator.pushNamed(context, '/police-certificate');
    }

    if (!mounted) return;
    if (result == true ||
        key == 'addressProof' ||
        key == 'backgroundCheck' ||
        key == 'aadhaar' ||
        key == 'pan') {
      _loadVerificationStatus();
    }
  }

  @override
  Widget build(BuildContext context) {
    _scheduleInitialFocusIfNeeded();

    return Scaffold(
      backgroundColor: WorkableDesign.canvas,
      appBar: AppBar(
        title: const Text('Identity Verification'),
        backgroundColor: WorkableDesign.surface,
        foregroundColor: WorkableDesign.ink,
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
              controller: _scrollController,
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
                        backgroundColor: WorkableDesign.primary.withValues(
                          alpha: 0.08,
                        ),
                        avatar: const Icon(
                          Icons.verified_user,
                          color: WorkableDesign.primary,
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

                      //'status': userPhone != null ? 'verified' : 'incomplete'
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
                      color: WorkableDesign.success.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      'Worker Only',
                      style: TextStyle(
                        fontSize: 12,
                        color: WorkableDesign.success,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
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
        color: WorkableDesign.surface,
        border: Border.all(color: WorkableDesign.border),
        borderRadius: BorderRadius.circular(WorkableDesign.radius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: WorkableDesign.primary.withValues(alpha: 0.1),
                child: const Icon(
                  LucideIcons.shield,
                  color: WorkableDesign.primary,
                ),
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
                        color: WorkableDesign.warning,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text('Progress', style: TextStyle(color: WorkableDesign.muted)),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  color: WorkableDesign.primary,
                  backgroundColor: WorkableDesign.border,
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
              color: WorkableDesign.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(WorkableDesign.radius),
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
              style: TextStyle(fontSize: 13, color: WorkableDesign.primary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerificationItem(Map<String, dynamic> item) {
    String status;

    if (item['key'] == 'phone') {
      status =
          isPhoneVerified || verificationData['phone']?['status'] == 'verified'
          ? 'verified'
          : 'incomplete';
    } else {
      status =
          item['status'] ??
          verificationData[item['key']]?['status'] ??
          'incomplete';
    }
    final isRequired = item['isRequired'] != false;
    final actionText = getActionText(status);
    final icon = item['icon'] as IconData;
    final String key = item['key'];
    final rejectionReason = verificationData[key]?['rejectionReason'];

    Color bgColor, borderColor;
    Icon statusIcon;

    switch (status) {
      case 'verified':
        bgColor = WorkableDesign.success.withValues(alpha: 0.08);
        borderColor = WorkableDesign.success.withValues(alpha: 0.22);
        statusIcon = const Icon(
          LucideIcons.check,
          size: 18,
          color: WorkableDesign.success,
        );
        break;
      case 'pending':
        bgColor = WorkableDesign.warning.withValues(alpha: 0.08);
        borderColor = WorkableDesign.warning.withValues(alpha: 0.22);
        statusIcon = const Icon(
          LucideIcons.clock,
          size: 18,
          color: WorkableDesign.warning,
        );
        break;
      case 'rejected':
        bgColor = WorkableDesign.danger.withValues(alpha: 0.08);
        borderColor = WorkableDesign.danger.withValues(alpha: 0.22);
        statusIcon = const Icon(
          LucideIcons.alertCircle,
          size: 18,
          color: WorkableDesign.danger,
        );
        break;
      default:
        bgColor = WorkableDesign.surface;
        borderColor = WorkableDesign.border;
        statusIcon = const Icon(LucideIcons.chevronRight, size: 18);
    }

    final shouldHighlight = _highlightedKey == key;

    return AnimatedBuilder(
      animation: _focusPulseAnimation,
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: WorkableDesign.primary.withValues(alpha: 0.08),
            child: Icon(icon, color: WorkableDesign.primary),
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
                          color: WorkableDesign.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text(
                          'Required',
                          style: TextStyle(
                            fontSize: 10,
                            color: WorkableDesign.primary,
                          ),
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
                    if (status == 'verified' &&
                        key != 'addressProof' &&
                        key != 'backgroundCheck') {
                      return;
                    }
                    await _openVerificationDestination(key);
                  },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        actionText,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: WorkableDesign.primary,
                          decoration: TextDecoration.underline,
                        ),
                      ),

                      if (status == 'rejected' && rejectionReason != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            rejectionReason,
                            style: const TextStyle(
                              fontSize: 12,
                              color: WorkableDesign.danger,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          statusIcon,
        ],
      ),
      builder: (context, child) {
        final pulse = shouldHighlight ? _focusPulseAnimation.value : 0.0;
        final effectiveBgColor = Color.lerp(
          bgColor,
          WorkableDesign.primary.withValues(alpha: 0.08),
          pulse,
        )!;
        final effectiveBorderColor = Color.lerp(
          borderColor,
          WorkableDesign.primary,
          pulse,
        )!;

        return Container(
          key: _verificationItemKeys[key],
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: effectiveBgColor,
            border: Border.all(color: effectiveBorderColor, width: 1 + pulse),
            borderRadius: BorderRadius.circular(WorkableDesign.radius),
            boxShadow: shouldHighlight
                ? [
                    BoxShadow(
                      color: WorkableDesign.primary.withValues(
                        alpha: 0.18 * pulse,
                      ),
                      blurRadius: 14,
                      spreadRadius: 1,
                    ),
                  ]
                : const [],
          ),
          child: child,
        );
      },
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
        color: WorkableDesign.surface,
        border: Border.all(color: WorkableDesign.border),
        borderRadius: BorderRadius.circular(WorkableDesign.radius),
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
                  backgroundColor: WorkableDesign.primary.withValues(
                    alpha: 0.08,
                  ),
                  textColor: WorkableDesign.primary,
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
                  backgroundColor: WorkableDesign.canvas,
                  textColor: WorkableDesign.ink,
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
        borderRadius: BorderRadius.circular(WorkableDesign.radius),
        border: Border.all(
          color: WorkableDesign.success.withValues(alpha: 0.2),
        ),
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
                const Icon(
                  LucideIcons.check,
                  size: 16,
                  color: WorkableDesign.success,
                ),
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
        color: WorkableDesign.surface,
        border: Border.all(color: WorkableDesign.border),
        borderRadius: BorderRadius.circular(WorkableDesign.radius),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: WorkableDesign.primary.withValues(alpha: 0.1),
            child: const Icon(
              LucideIcons.helpCircle,
              color: WorkableDesign.primary,
            ),
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
                  style: TextStyle(fontSize: 13, color: WorkableDesign.muted),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () {
              // TODO: Navigate to support screen
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: WorkableDesign.primary,
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
