import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../../core/theme/workable_design.dart';
import 'base_account_screen.dart';
import '../customer_bookings_screen.dart';
import '../../features/help_requests/presentation/customer_help_requests_screen.dart';
import '../../features/smart_booking/presentation/smart_booking_assistant_screen.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';

class CustomerAccountScreen extends BaseAccountScreen {
  static const routeName = '/customer-account';

  const CustomerAccountScreen({super.key});

  @override
  State<CustomerAccountScreen> createState() => _CustomerAccountScreenState();
}

class _CustomerAccountScreenState
    extends BaseAccountScreenState<CustomerAccountScreen> {
  // Customer-specific data
  int totalBookings = 0;
  double userRating = 0.0;
  double walletBalance = 0.0;
  int savedAddresses = 0;
  int favoriteWorkers = 0;
  int savedPaymentMethods = 0;
  int totalReviews = 0;
  String membershipLevel = 'Regular';

  // Photo picker state
  File? _pickedImageFile;
  bool _isUploadingPhoto = false;
  int unreadNotificationCount = 0;

  bool hasRejectedVerification = false;

  @override
  Future<void> fetchTypeSpecificData(String uid, String userType) async {
    try {
      final stats = await _loadLiveCustomerStats(uid);
      if (!mounted) return;
      setState(() {
        totalBookings = stats.totalBookings;
        userRating = stats.userRating;
        walletBalance = stats.walletBalance;
        savedAddresses = stats.savedAddresses;
        favoriteWorkers = stats.favoriteWorkers;
        savedPaymentMethods = stats.savedPaymentMethods;
        totalReviews = stats.totalReviews;
        membershipLevel = stats.membershipLevel;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load customer data: $e'),
          backgroundColor: WorkableDesign.danger,
        ),
      );
    }
  }

  Future<_CustomerStats> _loadLiveCustomerStats(String uid) async {
    final customerDocFuture = FirebaseFirestore.instance
        .collection('customers')
        .doc(uid)
        .get();
    final bookingsFuture = FirebaseFirestore.instance
        .collection('bookings')
        .where('customerId', isEqualTo: uid)
        .get();
    final addressesFuture = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('addresses')
        .get();
    final favoritesFuture = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('favoriteWorkers')
        .get();
    final reviewsFuture = FirebaseFirestore.instance
        .collection('reviews')
        .where('customerId', isEqualTo: uid)
        .get();
    final paymentMethodsFuture = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('paymentMethods')
        .get();
    final transactionsFuture = FirebaseFirestore.instance
        .collection('transactions')
        .where('customerId', isEqualTo: uid)
        .get();

    final results = await Future.wait([
      customerDocFuture,
      bookingsFuture,
      addressesFuture,
      favoritesFuture,
      reviewsFuture,
      paymentMethodsFuture,
      transactionsFuture,
    ]);

    final customerDoc = results[0] as DocumentSnapshot<Map<String, dynamic>>;
    final customerData = customerDoc.data() ?? {};
    final bookings = results[1] as QuerySnapshot<Map<String, dynamic>>;
    final addresses = results[2] as QuerySnapshot<Map<String, dynamic>>;
    final favorites = results[3] as QuerySnapshot<Map<String, dynamic>>;
    final reviews = results[4] as QuerySnapshot<Map<String, dynamic>>;
    final paymentMethods = results[5] as QuerySnapshot<Map<String, dynamic>>;
    final transactions = results[6] as QuerySnapshot<Map<String, dynamic>>;

    final ratingValues = reviews.docs
        .map((doc) => doc.data()['rating'])
        .whereType<num>()
        .map((rating) => rating.toDouble())
        .toList();
    final averageRating = ratingValues.isEmpty
        ? (customerData['rating'] as num?)?.toDouble() ?? 0.0
        : ratingValues.reduce((a, b) => a + b) / ratingValues.length;

    final transactionWalletBalance = transactions.docs.fold<double>(0, (
      total,
      doc,
    ) {
      final data = doc.data();
      final type = data['type']?.toString() ?? '';
      final amount = (data['total'] ?? data['amount'] ?? 0) as num;
      if (type == 'wallet_credit' || type == 'cashback' || type == 'refund') {
        return total + amount.toDouble();
      }
      if (type == 'wallet_debit') {
        return total - amount.toDouble();
      }
      return total;
    });

    final savedPaymentMethodCount = paymentMethods.docs.isNotEmpty
        ? paymentMethods.docs.length
        : transactions.docs
              .map((doc) => doc.data()['paymentMethod'])
              .where((method) => method != null && method.toString().isNotEmpty)
              .toSet()
              .length;

    return _CustomerStats(
      totalBookings: bookings.docs.length,
      userRating: averageRating,
      walletBalance: transactionWalletBalance != 0
          ? transactionWalletBalance
          : (customerData['walletBalance'] as num?)?.toDouble() ?? 0.0,
      savedAddresses: addresses.docs.length,
      favoriteWorkers: favorites.docs.length,
      savedPaymentMethods: savedPaymentMethodCount,
      totalReviews: reviews.docs.length,
      membershipLevel: customerData['membershipLevel'] ?? 'Regular',
    );
  }

  // void _listenToNotifications() {
  //   final uid = FirebaseAuth.instance.currentUser?.uid;

  //   if (uid == null) return;

  //   FirebaseFirestore.instance
  //       .collection('users')
  //       .doc(uid)
  //       .collection('notifications')
  //       .where('isRead', isEqualTo: false)
  //       .snapshots()
  //       .listen((snapshot) {
  //         bool rejectedExists = false;

  //         for (var doc in snapshot.docs) {
  //           final data = doc.data();

  //           if (data['status'] == 'rejected') {
  //             rejectedExists = true;
  //           }
  //         }

  //         if (mounted) {
  //           setState(() {
  //             unreadNotificationCount = snapshot.docs.length;

  //             hasRejectedVerification = rejectedExists;
  //           });
  //         }
  //       });
  // }

  void _listenToNotifications() {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) return;

    FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .where('notificationCategory', isEqualTo: 'verification_workflow')
        .snapshots()
        .listen((snapshot) {
          int count = 0;

          bool hasRejected = false;

          for (final doc in snapshot.docs) {
            final data = doc.data();

            final isRead = data['isRead'] == true;

            final requiresAction = data['requiresAction'] == true;

            final status = data['status']?.toString();

            // Badge visible if:
            // 1. Notification unseen
            // OR
            // 2. Action still required
            if (!isRead || requiresAction) {
              count++;
            }

            // Used for warning UI
            if (status == 'rejected' && requiresAction) {
              hasRejected = true;
            }
          }

          if (mounted) {
            setState(() {
              unreadNotificationCount = count;

              hasRejectedVerification = hasRejected;
            });
          }
        });
  }

  @override
  void initState() {
    super.initState();

    _listenToNotifications();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WorkableDesign.canvas,
      // No AppBar — the hero section acts as the header
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── HERO (dark gradient header with profile + stats) ──
            _buildHeroSection(),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),

                  // Live Active Booking Banner
                  _buildLiveActiveBanner(),

                  const SizedBox(height: 20),

                  // Quick Actions
                  _buildQuickActions(),
                  const SizedBox(height: 24),

                  // Bookings Section
                  _buildBookingSection(),
                  const SizedBox(height: 24),

                  // Payment Section
                  _buildPaymentSection(),
                  const SizedBox(height: 24),

                  // Support Section
                  _buildSupportSection(),
                  const SizedBox(height: 24),

                  // Settings Section
                  _buildSettingsSection(),
                  const SizedBox(height: 24),

                  // Additional Services Section
                  _buildAdditionalServicesSection(),
                  const SizedBox(height: 32),

                  // Logout Button
                  _buildLogoutButton(),

                  const SizedBox(height: 16),

                  Center(
                    child: Text(
                      "Workable Customer App v2.1.0",
                      style: const TextStyle(
                        fontSize: 12,
                        color: WorkableDesign.muted,
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // HERO SECTION — dark gradient, greeting, avatar, stats strip
  // ============================================================

  Widget _buildHeroSection() {
    return Container(
      decoration: const BoxDecoration(
        color: WorkableDesign.ink,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 52, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeroTopBar(),
          const SizedBox(height: 20),
          _buildProfileRow(),
          const SizedBox(height: 24),
          _buildStatsStrip(),
        ],
      ),
    );
  }

  Widget _buildHeroTopBar() {
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good morning'
        : hour < 17
        ? 'Good afternoon'
        : 'Good evening';

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          greeting,
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 14,
            fontWeight: FontWeight.w400,
          ),
        ),
        _buildNotificationBell(),
      ],
    );
  }

  Widget _buildNotificationBell() {
    return Stack(
      children: [
        GestureDetector(
          onTap: () => Navigator.pushNamed(context, '/customer/notifications'),
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.18),
                width: 0.5,
              ),
            ),
            child: const Icon(
              Icons.notifications_outlined,
              color: Colors.white,
              size: 20,
            ),
          ),
        ),
        Positioned(
          right: 7,
          top: 7,
          child: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: const Color(0xFFFF6B6B),
              shape: BoxShape.circle,
              border: Border.all(color: WorkableDesign.ink, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProfileRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildEditableAvatar(),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      userName.isNotEmpty ? userName : 'Your Name',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.2,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (isVerified) ...[
                    const SizedBox(width: 6),
                    Container(
                      width: 18,
                      height: 18,
                      decoration: const BoxDecoration(
                        color: Color(0xFF4ade80),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check,
                        color: Colors.white,
                        size: 11,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 4),
              Text(
                userEmail.isNotEmpty ? userEmail : '',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 12,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 10),
              _buildMembershipPill(),
            ],
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () => _navigateToPersonalInformation(),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.2),
                width: 0.5,
              ),
            ),
            child: const Text(
              'Edit',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEditableAvatar() {
    return GestureDetector(
      onTap: _showPhotoOptions,
      child: Stack(
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF4a3f8a),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.22),
                width: 2.5,
              ),
            ),
            child: _isUploadingPhoto
                ? const Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : ClipOval(child: _buildAvatarContent()),
          ),
          // Pencil edit badge
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF1a1a2e), width: 2),
              ),
              child: const Icon(Icons.edit, size: 12, color: Color(0xFF1a1a2e)),
            ),
          ),
          // Gold star for non-Regular members
          if (membershipLevel != 'Regular')
            Positioned(
              right: 0,
              top: 0,
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: membershipLevel == 'Premium'
                      ? const Color(0xFFFFD700)
                      : const Color(0xFFC0C0C0),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: const Icon(Icons.star, size: 10, color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAvatarContent() {
    if (_pickedImageFile != null) {
      return Image.file(
        _pickedImageFile!,
        width: 70,
        height: 70,
        fit: BoxFit.cover,
      );
    }
    if (profileImageUrl != null && profileImageUrl!.isNotEmpty) {
      return Image.network(
        profileImageUrl!,
        width: 70,
        height: 70,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _buildInitialLetter(),
      );
    }
    return _buildInitialLetter();
  }

  Widget _buildInitialLetter() {
    return Center(
      child: Text(
        userName.isNotEmpty ? userName[0].toUpperCase() : 'C',
        style: const TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildMembershipPill() {
    final color = _getMembershipPillColor();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.star_rounded, size: 11, color: color),
          const SizedBox(width: 4),
          Text(
            '${membershipLevel.toUpperCase()} MEMBER',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: color,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Color _getMembershipPillColor() {
    switch (membershipLevel) {
      case 'Premium':
        return const Color(0xFFFFD700);
      case 'Silver':
        return const Color(0xFFC0C0C0);
      default:
        return const Color(0xFF818CF8);
    }
  }

  Widget _buildStatsStrip() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(14),
          topRight: Radius.circular(14),
        ),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
          width: 0.5,
        ),
      ),
      child: Row(
        children: [
          _buildStatCell(
            label: 'Bookings',
            value: totalBookings.toString(),
            icon: Icons.calendar_today_outlined,
            onTap: () => _navigateToBookingHistory(),
            showDivider: true,
          ),
          _buildStatCell(
            label: 'Wallet',
            value: 'Rs ${walletBalance.toStringAsFixed(0)}',
            icon: Icons.account_balance_wallet_outlined,
            onTap: () => _navigateToWalletCredits(),
            showDivider: true,
          ),
          _buildStatCell(
            label: 'Rating',
            value: userRating > 0
                ? '${userRating.toStringAsFixed(1)} star'
                : '-',
            icon: Icons.star_outline_rounded,
            onTap: () => _navigateToMyReviews(),
            showDivider: true,
          ),
          _buildStatCell(
            label: 'Rewards',
            value: 'Rs 0',
            icon: Icons.card_giftcard_outlined,
            onTap: () => _navigateToReferralProgram(),
            showDivider: false,
          ),
        ],
      ),
    );
  }

  Widget _buildStatCell({
    required String label,
    required String value,
    required IconData icon,
    required VoidCallback onTap,
    required bool showDivider,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
          decoration: showDivider
              ? BoxDecoration(
                  border: Border(
                    right: BorderSide(
                      color: Colors.white.withValues(alpha: 0.1),
                      width: 0.5,
                    ),
                  ),
                )
              : null,
          child: Column(
            children: [
              Icon(icon, color: Colors.white54, size: 15),
              const SizedBox(height: 5),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.45),
                  fontSize: 9,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // PHOTO PICKER
  // ============================================================

  void _showPhotoOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: WorkableDesign.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Text(
              'Update profile photo',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: WorkableDesign.ink,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _buildPhotoOption(
                    icon: Icons.camera_alt_outlined,
                    label: 'Camera',
                    color: WorkableDesign.primary,
                    onTap: () {
                      Navigator.pop(context);
                      _pickImage(ImageSource.camera);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildPhotoOption(
                    icon: Icons.photo_library_outlined,
                    label: 'Gallery',
                    color: WorkableDesign.accent,
                    onTap: () {
                      Navigator.pop(context);
                      _pickImage(ImageSource.gallery);
                    },
                  ),
                ),
              ],
            ),
            if (profileImageUrl != null || _pickedImageFile != null) ...[
              const SizedBox(height: 12),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _removePhoto();
                },
                child: const Text(
                  'Remove current photo',
                  style: TextStyle(color: WorkableDesign.danger, fontSize: 14),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoOption({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2), width: 0.5),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 26),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Future<void> _pickImage(ImageSource source) async {
  //   try {
  //     final picker = ImagePicker();
  //     final picked = await picker.pickImage(
  //       source: source,
  //       maxWidth: 512,
  //       maxHeight: 512,
  //       imageQuality: 85,
  //     );
  //     if (picked == null) return;

  //     setState(() {
  //       _pickedImageFile = File(picked.path);
  //       _isUploadingPhoto = true;
  //     });

  //     // ── REPLACE THIS BLOCK WITH YOUR FIREBASE STORAGE UPLOAD ─────────────
  //     // Example:
  //     //   final uid = FirebaseAuth.instance.currentUser!.uid;
  //     //   final ref = FirebaseStorage.instance.ref('profile_photos/$uid.jpg');
  //     //   await ref.putFile(_pickedImageFile!);
  //     //   final url = await ref.getDownloadURL();
  //     //   await FirebaseFirestore.instance
  //     //       .collection('customers').doc(uid).update({'profileImageUrl': url});
  //     //   setState(() { profileImageUrl = url; });
  //     await Future.delayed(
  //       const Duration(milliseconds: 1500),
  //     ); // remove this line after adding upload
  //     // ─────────────────────────────────────────────────────────────────────

  //     if (!mounted) return;
  //     setState(() => _isUploadingPhoto = false);

  //     ScaffoldMessenger.of(context).showSnackBar(
  //       const SnackBar(
  //         content: Text('Profile photo updated'),
  //         backgroundColor: Color(0xFF4ade80),
  //         behavior: SnackBarBehavior.floating,
  //       ),
  //     );
  //   } catch (e) {
  //     if (!mounted) return;
  //     setState(() => _isUploadingPhoto = false);
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       SnackBar(
  //         content: Text('Could not update photo: $e'),
  //         backgroundColor: Colors.red,
  //         behavior: SnackBarBehavior.floating,
  //       ),
  //     );
  //   }
  // }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );
      if (picked == null) return;

      setState(() {
        _pickedImageFile = File(picked.path);
        _isUploadingPhoto = true;
      });

      final uid = FirebaseAuth.instance.currentUser!.uid;
      final ref = FirebaseStorage.instance.ref('users/$uid/profile_photo.jpg');
      await ref.putFile(_pickedImageFile!);
      final url = await ref.getDownloadURL();

      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'profileImageUrl': url,
      });

      setState(() {
        profileImageUrl = url;
        _isUploadingPhoto = false;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile photo updated'),
          backgroundColor: WorkableDesign.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isUploadingPhoto = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not update photo: $e'),
          backgroundColor: WorkableDesign.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _removePhoto() {
    setState(() {
      _pickedImageFile = null;
      profileImageUrl = null;
    });
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      FirebaseFirestore.instance.collection('users').doc(uid).update({
        'profileImageUrl': FieldValue.delete(),
      });
    }
  }

  // ============================================================
  // LIVE ACTIVE BOOKING BANNER
  // ============================================================

  Widget _buildLiveActiveBanner() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('bookings')
          .where('customerId', isEqualTo: uid)
          .where('status', whereIn: ['pending', 'confirmed', 'in_progress'])
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }

        final activeCount = snapshot.data!.docs.length;
        final latestBooking =
            snapshot.data!.docs.first.data() as Map<String, dynamic>;
        final serviceType =
            latestBooking['serviceType'] ?? latestBooking['issue'] ?? 'Service';
        final status = latestBooking['status'] ?? 'pending';

        return GestureDetector(
          onTap: () => _navigateToOngoingServices(),
          child: Container(
            margin: const EdgeInsets.only(bottom: 4),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [WorkableDesign.primary, WorkableDesign.accent],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: WorkableDesign.primary.withValues(alpha: 0.18),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                _buildPulsingDot(),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        activeCount == 1
                            ? 'Active Booking'
                            : '$activeCount Active Bookings',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$serviceType - ${_getStatusLabel(status)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Track',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPulsingDot() {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.6, end: 1.0),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeInOut,
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: WorkableDesign.success,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: WorkableDesign.success.withValues(alpha: 0.55),
                  blurRadius: 8 * value,
                  spreadRadius: 2 * value,
                ),
              ],
            ),
          ),
        );
      },
      onEnd: () => setState(() {}),
    );
  }

  String _getStatusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'Waiting for confirmation';
      case 'confirmed':
        return 'Worker confirmed';
      case 'in_progress':
        return 'Work in progress';
      default:
        return status;
    }
  }

  // ============================================================
  // QUICK ACTIONS
  // ============================================================

  Widget _buildQuickActions() {
    return Row(
      children: [
        Expanded(
          child: _buildQuickActionButton(
            Icons.add_circle_outline,
            'Book Service',
            const Color(0xFF4A00E0),
            () => _navigateToBookService(),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildQuickActionButton(
            Icons.refresh_rounded,
            'Repeat Booking',
            const Color(0xFF0f3460),
            () => _navigateToRepeatBooking(),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildQuickActionButton(
            Icons.volunteer_activism_outlined,
            'Help',
            const Color(0xFF0a7c42),
            () => _navigateToHelpRequests(),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActionButton(
    IconData icon,
    String label,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: WorkableDesign.surface,
          borderRadius: BorderRadius.circular(WorkableDesign.radius),
          border: Border.all(color: WorkableDesign.border, width: 0.5),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: WorkableDesign.ink,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // BOOKING SECTION (real-time badge)
  // ============================================================

  Widget _buildBookingSection() {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return StreamBuilder<QuerySnapshot>(
      stream: uid == null
          ? null
          : FirebaseFirestore.instance
                .collection('bookings')
                .where('customerId', isEqualTo: uid)
                .where(
                  'status',
                  whereIn: ['pending', 'confirmed', 'in_progress'],
                )
                .snapshots(),
      builder: (context, snapshot) {
        final liveOngoingCount = snapshot.data?.docs.length ?? 0;

        return _buildSection('Bookings & Services', [
          buildMenuItem(
            Icons.auto_awesome,
            'Smart Booking',
            'Tell Workable what help you need',
            onTap: () => _navigateToSmartBooking(),
          ),
          buildMenuItem(
            Icons.history,
            'Booking History',
            '$totalBookings total bookings',
            onTap: () => _navigateToBookingHistory(),
          ),
          buildMenuItem(
            Icons.volunteer_activism_outlined,
            'My Help Requests',
            'Pickup, delivery and urgent help',
            onTap: () => _navigateToHelpRequests(),
          ),
          buildMenuItem(
            Icons.pending_actions,
            'Ongoing Services',
            liveOngoingCount > 0
                ? '$liveOngoingCount active booking${liveOngoingCount > 1 ? 's' : ''}'
                : 'No active bookings',
            badge: liveOngoingCount,
            onTap: () => _navigateToOngoingServices(),
          ),
          buildMenuItem(
            Icons.favorite_outline,
            'Favorite Workers',
            '$favoriteWorkers saved favorites',
            onTap: () => _navigateToFavoriteWorkers(),
          ),
        ]);
      },
    );
  }

  // ============================================================
  // PAYMENT SECTION
  // ============================================================

  Widget _buildPaymentSection() {
    return _buildSection('Payment & Wallet', [
      buildMenuItem(
        Icons.payment,
        'Payment Methods',
        '$savedPaymentMethods cards saved',
        onTap: () => _navigateToPaymentMethods(),
      ),
      buildMenuItem(
        Icons.account_balance_wallet_outlined,
        'Wallet & Credits',
        'Rs ${walletBalance.toStringAsFixed(0)} available',
        onTap: () => _navigateToWalletCredits(),
      ),
      buildMenuItem(
        Icons.receipt_long,
        'Transaction History',
        'View all payments',
        onTap: () => _navigateToTransactionHistory(),
      ),
    ]);
  }

  // ============================================================
  // SUPPORT SECTION
  // ============================================================

  Widget _buildSupportSection() {
    return _buildSection('Support & Communication', [
      buildMenuItem(
        Icons.chat_bubble_outline,
        'Messages',
        'Chat with workers & support',
        onTap: () => _navigateToMessages(),
      ),
      buildMenuItem(
        Icons.star_outline,
        'My Reviews',
        '$totalReviews reviews given',
        onTap: () => _navigateToMyReviews(),
      ),
      buildMenuItem(
        Icons.help_outline,
        'Help & Support',
        'FAQ, contact support',
        onTap: () => _navigateToHelpSupport(),
      ),
    ]);
  }

  // ============================================================
  // SETTINGS SECTION
  // ============================================================

  Widget _buildSettingsSection() {
    return _buildSection('Profile & Settings', [
      buildMenuItem(
        Icons.person_outline,
        'Personal Information',
        'Edit your details',
        onTap: () => _navigateToPersonalInformation(),
      ),
      buildMenuItem(
        Icons.location_on_outlined,
        'Address Management',
        '$savedAddresses saved addresses',
        onTap: () => _navigateToAddressManagement(),
      ),
      buildMenuItem(
        Icons.verified_user_outlined,

        'Identity Verification',

        hasRejectedVerification
            ? 'Action required'
            : unreadNotificationCount > 0
            ? '$unreadNotificationCount updates'
            : isVerified
            ? 'Verified'
            : 'Verify identity',

        isVerified: isVerified,

        badge: unreadNotificationCount,
        onTap: () => _navigateToIdentityVerification(),
      ),
      buildMenuItem(
        Icons.settings_outlined,
        'App Settings',
        'Preferences & privacy',
        onTap: () => _navigateToAppSettings(),
      ),
    ]);
  }

  // ============================================================
  // MORE OPTIONS SECTION
  // ============================================================

  Widget _buildAdditionalServicesSection() {
    return _buildSection('More Options', [
      buildMenuItem(
        Icons.card_giftcard,
        'Referral Program',
        'Invite friends & earn rewards',
        onTap: () => _navigateToReferralProgram(),
      ),
      buildMenuItem(
        Icons.work_outline,
        'Become a Worker',
        'Start offering services',
        onTap: () => _navigateToBecomeWorker(),
      ),
      buildMenuItem(
        Icons.description_outlined,
        'Terms & Privacy',
        'Terms of service & privacy policy',
        onTap: () => _navigateToTermsPrivacy(),
      ),
    ]);
  }

  // ============================================================
  // SHARED SECTION BUILDER
  // ============================================================

  Widget _buildSection(String title, List<Widget> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 10),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: WorkableDesign.ink,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: WorkableDesign.surface,
            borderRadius: BorderRadius.circular(WorkableDesign.radius),
            border: Border.all(color: WorkableDesign.border, width: 0.5),
          ),
          child: Column(children: items),
        ),
      ],
    );
  }

  // ============================================================
  // LOGOUT BUTTON
  // ============================================================

  Widget _buildLogoutButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: handleLogout,
        style: ElevatedButton.styleFrom(
          backgroundColor: WorkableDesign.danger.withValues(alpha: 0.08),
          foregroundColor: WorkableDesign.danger,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(WorkableDesign.radius),
            side: BorderSide(
              color: WorkableDesign.danger.withValues(alpha: 0.22),
            ),
          ),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.logout, size: 18),
            SizedBox(width: 8),
            Text(
              'Sign Out',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // NAVIGATION
  // ============================================================

  void _navigateToOngoingServices() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const CustomerBookingsScreen(initialTab: 0),
      ),
    );
  }

  void _navigateToBookingHistory() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const CustomerBookingsScreen(initialTab: 2),
      ),
    );
  }

  void _navigateToBookService() =>
      Navigator.pushNamed(context, '/book-service');

  void _navigateToRepeatBooking() =>
      Navigator.pushNamed(context, '/repeat-booking');

  void _navigateToSmartBooking() =>
      Navigator.pushNamed(context, SmartBookingAssistantScreen.routeName);

  void _navigateToHelpRequests() =>
      Navigator.pushNamed(context, CustomerHelpRequestsScreen.routeName);

  void _navigateToFavoriteWorkers() =>
      Navigator.pushNamed(context, '/customer/favorite-workers');

  void _navigateToPaymentMethods() =>
      Navigator.pushNamed(context, '/customer/payment-methods');

  void _navigateToWalletCredits() =>
      Navigator.pushNamed(context, '/customer/wallet-credits');

  void _navigateToTransactionHistory() =>
      Navigator.pushNamed(context, '/customer/transaction-history');

  void _navigateToMessages() =>
      Navigator.pushNamed(context, '/customer/messages');

  void _navigateToMyReviews() =>
      Navigator.pushNamed(context, '/customer/my-reviews');

  void _navigateToHelpSupport() =>
      Navigator.pushNamed(context, '/customer/help-support');

  void _navigateToPersonalInformation() =>
      Navigator.pushNamed(context, '/customer/personal-information');

  void _navigateToAddressManagement() =>
      Navigator.pushNamed(context, '/customer/address-management');

  void _navigateToIdentityVerification() =>
      Navigator.pushNamed(context, '/customer/identity-verification');

  void _navigateToAppSettings() =>
      Navigator.pushNamed(context, '/customer/app-settings');

  void _navigateToReferralProgram() =>
      Navigator.pushNamed(context, '/customer/referral-program');

  void _navigateToBecomeWorker() =>
      Navigator.pushNamed(context, '/become-worker');

  void _navigateToTermsPrivacy() =>
      Navigator.pushNamed(context, '/terms-privacy');
}

class _CustomerStats {
  final int totalBookings;
  final double userRating;
  final double walletBalance;
  final int savedAddresses;
  final int favoriteWorkers;
  final int savedPaymentMethods;
  final int totalReviews;
  final String membershipLevel;

  const _CustomerStats({
    required this.totalBookings,
    required this.userRating,
    required this.walletBalance,
    required this.savedAddresses,
    required this.favoriteWorkers,
    required this.savedPaymentMethods,
    required this.totalReviews,
    required this.membershipLevel,
  });
}
