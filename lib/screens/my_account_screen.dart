import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'personal_information_screen.dart';
import 'address_management_screen.dart';
import 'identity_verification_screen.dart';
import 'booking_history_screen.dart'; // Make sure the path is correct
import 'ongoing_services_screen.dart';
import 'favorite_workers_screen.dart';
import 'payment_methods_screen.dart';
import 'wallet_credits_screen.dart'; // ⬅️ Make sure this import is at the top
import 'transaction_history_screen.dart';
import 'help_support_screen.dart'; // Adjust path if needed
import 'app_settings_screen.dart'; // Add this import at the top
import 'language_selection_screen.dart';
import 'security_privacy_screen.dart';
import 'referral_programme_screen.dart';
import 'messages_screen.dart'; // ✅ Import if not already
import 'my_reviews_screen.dart'; // Make sure path is correct

import 'profile_tab_screen.dart';
import '../widgets/custom_button.dart';

class MyAccountScreen extends StatefulWidget {
  static const routeName = '/my-account';

  const MyAccountScreen({super.key});

  @override
  State<MyAccountScreen> createState() => _MyAccountScreenState();
}

class _MyAccountScreenState extends State<MyAccountScreen> {
  String userName = '';
  String userEmail = '';
  String userPhone = '';
  String? profileImageUrl;
  bool isVerified = false;
  int totalBookings = 0;
  double userRating = 0.0;
  double walletBalance = 0.0;
  int savedAddresses = 0;
  int favoriteWorkers = 0;
  int savedPaymentMethods = 0;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    if (doc.exists) {
      final data = doc.data()!;
      setState(() {
        userName = data['name'] ?? '';
        userEmail = data['email'] ?? user.email ?? '';
        userPhone = data['phone'] ?? '';
        profileImageUrl = data['imageUrl'];
        isVerified = data['isVerified'] ?? false;
        totalBookings = data['totalBookings'] ?? 0;
        userRating = (data['rating'] ?? 0.0).toDouble();
        walletBalance = (data['walletBalance'] ?? 0.0).toDouble();
        savedAddresses = data['savedAddresses'] ?? 0;
        favoriteWorkers = data['favoriteWorkers'] ?? 0;
        savedPaymentMethods = data['savedPaymentMethods'] ?? 0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text("My Account"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile Card
            _buildProfileCard(),
            const SizedBox(height: 24),

            // Quick Stats
            _buildQuickStats(),
            const SizedBox(height: 24),

            // Profile Management Section
            _buildSectionTitle("Profile & Settings"),
            const SizedBox(height: 12),
            _buildMenuGroup([
              _buildMenuItem(
                Icons.person_outline,
                "Personal Information",
                "Edit your basic details",
                isVerified: isVerified,
                onTap: () => _navigateToPersonalInfo(),
              ),
              _buildMenuItem(
                Icons.location_on_outlined,
                "Address Management",
                "${savedAddresses} saved addresses",
                onTap: () => _navigateToAddresses(),
              ),
              _buildMenuItem(
                Icons.verified_user_outlined,
                "Identity Verification",
                isVerified ? "Verified" : "Verify your identity",
                isVerified: isVerified,
                onTap: () => _navigateToVerification(),
              ),
            ]),

            const SizedBox(height: 24),

            // Booking & Orders Section
            _buildSectionTitle("Bookings & Orders"),
            const SizedBox(height: 12),
            _buildMenuGroup([
              _buildMenuItem(
                Icons.history,
                "Booking History",
                "View all past bookings",
                onTap: () => _navigateToBookingHistory(),
              ),
              _buildMenuItem(
                Icons.pending_actions,
                "Ongoing Services",
                "Track active bookings",
                badge: _getOngoingBookingsCount(),
                onTap: () => _navigateToOngoingServices(),
              ),
              _buildMenuItem(
                Icons.favorite_outline,
                "Favorite Workers",
                "${favoriteWorkers} saved favorites",
                onTap: () => _navigateToFavorites(),
              ),
            ]),

            const SizedBox(height: 24),

            // Payment & Financial Section
            _buildSectionTitle("Payment & Wallet"),
            const SizedBox(height: 12),
            _buildMenuGroup([
              _buildMenuItem(
                Icons.payment,
                "Payment Methods",
                "${savedPaymentMethods} cards saved",
                onTap: () => _navigateToPaymentMethods(),
              ),
              _buildMenuItem(
                Icons.account_balance_wallet_outlined,
                "Wallet & Credits",
                "₹${walletBalance.toStringAsFixed(0)} available",
                onTap: () => _navigateToWallet(),
              ),
              _buildMenuItem(
                Icons.receipt_long,
                "Transaction History",
                "View all payments",
                onTap: () => _navigateToTransactions(),
              ),
            ]),

            const SizedBox(height: 24),

            // Support & Communication Section
            _buildSectionTitle("Support & Communication"),
            const SizedBox(height: 12),
            _buildMenuGroup([
              _buildMenuItem(
                Icons.chat_bubble_outline,
                "Messages",
                "Chat with workers & support",
                onTap: () => _navigateToMessages(),
              ),
              _buildMenuItem(
                Icons.star_outline,
                "My Reviews",
                "Reviews & ratings given",
                onTap: () => _navigateToReviews(),
              ),
              _buildMenuItem(
                Icons.help_outline,
                "Help & Support",
                "FAQ, contact support",
                onTap: () => _navigateToSupport(),
              ),
            ]),

            const SizedBox(height: 24),

            // App Settings Section
            _buildSectionTitle("App Settings"),
            const SizedBox(height: 12),
            _buildMenuGroup([
              _buildMenuItem(
                Icons.notifications_outlined,
                "Notifications",
                "Manage your preferences",
                onTap: () => _navigateToNotifications(),
              ),
              _buildMenuItem(
                Icons.settings_outlined,
                "App Settings",
                "Language, theme, privacy",
                onTap: () => _navigateToSettings(),
              ),
              _buildMenuItem(
                Icons.language,
                "Language Selection",
                "Choose your preferred language",
                onTap: () => _navigateToLanguage(),
              ),
              _buildMenuItem(
                Icons.security,
                "Security & Privacy",
                "Password, 2FA, privacy settings",
                onTap: () => _navigateToSecurity(),
              ),
              _buildMenuItem(
                Icons.card_giftcard,
                "Referral Program",
                "Invite friends & earn rewards",
                onTap: () => _navigateToReferrals(),
              ),
            ]),

            const SizedBox(height: 24),

            // Additional Features Section
            _buildSectionTitle("More Options"),
            const SizedBox(height: 12),
            _buildMenuGroup([
              _buildMenuItem(
                Icons.work_outline,
                "Become a Worker",
                "Start offering services",
                onTap: () => _navigateToBecomeWorker(),
              ),
              _buildMenuItem(
                Icons.description_outlined,
                "Terms & Privacy",
                "Terms of service & privacy policy",
                onTap: () => _navigateToTerms(),
              ),
              _buildMenuItem(
                Icons.info_outline,
                "About App",
                "App info & version details",
                onTap: () => _navigateToAbout(),
              ),
            ]),

            const SizedBox(height: 32),

            // Logout Button
            _buildLogoutButton(),

            const SizedBox(height: 16),

            // App Version
            Center(
              child: Text(
                "Workable App v2.1.0",
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Stack(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ProfileTabScreen(),
                      ),
                    ),
                    child: CircleAvatar(
                      radius: 32,
                      backgroundColor: Colors.blue.shade100,
                      backgroundImage: profileImageUrl != null
                          ? NetworkImage(profileImageUrl!)
                          : null,
                      child: profileImageUrl == null
                          ? Text(
                              userName.isNotEmpty
                                  ? userName[0].toUpperCase()
                                  : 'U',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            )
                          : null,
                    ),
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.blue,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.camera_alt,
                        size: 12,
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
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            userName.isNotEmpty ? userName : 'User Name',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isVerified) ...[
                          const SizedBox(width: 8),
                          const Icon(
                            Icons.verified,
                            size: 16,
                            color: Colors.green,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      userEmail,
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                    if (userPhone.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        userPhone,
                        style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStats() {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            totalBookings.toString(),
            "Bookings",
            Icons.work_outline,
            Colors.blue,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            userRating > 0 ? userRating.toStringAsFixed(1) : "0.0",
            "Rating",
            Icons.star_outline,
            Colors.orange,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            "₹${walletBalance.toStringAsFixed(0)}",
            "Wallet",
            Icons.account_balance_wallet_outlined,
            Colors.green,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String number,
    String label,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            number,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Colors.black87,
      ),
    );
  }

  Widget _buildMenuGroup(List<Widget> items) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(children: items),
    );
  }

  Widget _buildMenuItem(
    IconData icon,
    String title,
    String subtitle, {
    bool isVerified = false,
    int badge = 0,
    required VoidCallback onTap,
  }) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: Colors.blue.shade600, size: 20),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 16),
            ),
          ),
          if (isVerified)
            const Icon(Icons.check_circle, color: Colors.green, size: 16),
          if (badge > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                badge.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: Colors.grey[600], fontSize: 14),
      ),
      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
    );
  }

  Widget _buildLogoutButton() {
    return Container(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _handleLogout,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red.shade50,
          foregroundColor: Colors.red,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.red.shade200),
          ),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.logout),
            SizedBox(width: 8),
            Text(
              "Sign Out",
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  // Helper methods
  int _getOngoingBookingsCount() {
    // Return actual count from your data source
    return 2; // Placeholder
  }

  // Navigation methods - implement these based on your app structure
  // void _navigateToPersonalInfo() {
  //   Navigator.push(
  //     context,
  //     MaterialPageRoute(builder: (_) => const ProfileTabScreen()),
  //   );
  // }

  void _navigateToPersonalInfo() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PersonalInformationScreen()),
    );
  }

  void _navigateToAddresses() {
    // Navigate to address management screen
    Navigator.pushNamed(context, AddressManagementScreen.routeName);
  }

  // void _navigateToVerification() {
  //   // Navigate to identity verification screen
  //   Navigator.pushNamed(context, IdentityVerificationScreen.routeName);
  // }

  void _navigateToVerification() {
    final user = FirebaseAuth.instance.currentUser;
    print("🔍 Trying to navigate to IdentityVerificationScreen...");
    print("👤 currentUser UID: ${user?.uid}");

    if (user == null) {
      print("❌ Navigation blocked: No authenticated user.");
      return;
    }

    try {
      Navigator.pushNamed(context, IdentityVerificationScreen.routeName);
      print("✅ Navigation to IdentityVerificationScreen triggered.");
    } catch (e, stack) {
      print("❌ Navigation error: $e");
      print(stack);
    }
  }

  void _navigateToBookingHistory() {
    // Navigate to booking history screen
    Navigator.pushNamed(context, BookingHistoryScreen.routeName);
  }

  void _navigateToOngoingServices() {
    // Navigate to ongoing services screen
    Navigator.pushNamed(context, OngoingServicesScreen.routeName);
  }

  void _navigateToFavorites() {
    // Navigate to favorites screen
    Navigator.pushNamed(context, FavoriteWorkersScreen.routeName);
  }

  void _navigateToPaymentMethods() {
    // Navigate to payment methods screen
    Navigator.pushNamed(context, '/payment-methods');
  }

  void _navigateToWallet() {
    // Navigate to wallet screen
    Navigator.pushNamed(context, WalletCreditsScreen.routeName);
  }

  void _navigateToTransactions() {
    // Navigate to transaction history screen
    Navigator.pushNamed(context, TransactionHistoryScreen.routeName);
  }

  void _navigateToMessages() {
    // Navigate to messages screen
    Navigator.pushNamed(context, MessagesScreen.routeName);
  }

  void _navigateToReviews() {
    // Navigate to reviews screen
    Navigator.pushNamed(context, MyReviewsScreen.routeName);
  }

  void _navigateToSupport() {
    // Navigate to support screen
    Navigator.pushNamed(context, HelpSupportScreen.routeName);
  }

  void _navigateToNotifications() {
    // Navigate to notification settings screen
  }

  void _navigateToSettings() {
    // Navigate to app settings screen
    Navigator.pushNamed(context, AppSettingsScreen.routeName);
  }

  void _navigateToReferrals() {
    // Navigate to referral program screen
    Navigator.pushNamed(context, ReferralProgrammeScreen.routeName);
  }

  void _navigateToLanguage() {
    // Navigate to language selection screen
    Navigator.pushNamed(context, LanguageSelectionScreen.routeName);
  }

  void _navigateToSecurity() {
    // Navigate to security & privacy screen
    Navigator.pushNamed(context, SecurityPrivacyScreen.routeName);
  }

  void _navigateToTerms() {
    // Navigate to terms & privacy screen
  }

  void _navigateToAbout() {
    // Navigate to about app screen
  }

  void _navigateToBecomeWorker() {
    // Navigate to become worker screen
    Navigator.pushNamed(context, '/become-worker');
  }

  Future<void> _handleLogout() async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Sign Out'),
          content: const Text('Are you sure you want to sign out?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                await FirebaseAuth.instance.signOut();
                Navigator.of(context).pop();
                Navigator.of(context).pushReplacementNamed('/login');
              },
              child: const Text('Sign Out'),
            ),
          ],
        );
      },
    );
  }
}
