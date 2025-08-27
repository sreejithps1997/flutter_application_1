import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'base_account_screen.dart';

class CustomerAccountScreen extends BaseAccountScreen {
  static const routeName = '/customer-account';

  const CustomerAccountScreen({Key? key}) : super(key: key);

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
  int ongoingBookings = 0;
  int totalReviews = 0;
  String membershipLevel = 'Regular';

  @override
  Future<void> fetchTypeSpecificData(String uid, String userType) async {
    try {
      // Fetch customer-specific data
      final customerDoc = await FirebaseFirestore.instance
          .collection('customers')
          .doc(uid)
          .get();

      if (customerDoc.exists) {
        final data = customerDoc.data()!;
        setState(() {
          totalBookings = data['totalBookings'] ?? 0;
          userRating = (data['rating'] ?? 0.0).toDouble();
          walletBalance = (data['walletBalance'] ?? 0.0).toDouble();
          savedAddresses = data['savedAddresses'] ?? 0;
          favoriteWorkers = data['favoriteWorkers'] ?? 0;
          savedPaymentMethods = data['savedPaymentMethods'] ?? 0;
          ongoingBookings = data['ongoingBookings'] ?? 0;
          totalReviews = data['totalReviews'] ?? 0;
          membershipLevel = data['membershipLevel'] ?? 'Regular';
        });
      }
    } catch (e) {
      print('Error fetching customer data: $e');
      // Handle error gracefully
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load customer data: $e'),
          backgroundColor: Colors.red,
        ),
      );
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
            // Enhanced Profile Card
            _buildCustomerProfileCard(),
            const SizedBox(height: 24),

            // Customer Stats
            _buildCustomerStats(),
            const SizedBox(height: 24),

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

            // App Version
            Center(
              child: Text(
                "Workable Customer App v2.1.0",
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomerProfileCard() {
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
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: Colors.blue.shade100,
                    backgroundImage: profileImageUrl != null
                        ? NetworkImage(profileImageUrl!)
                        : null,
                    child: profileImageUrl == null
                        ? Text(
                            userName.isNotEmpty
                                ? userName[0].toUpperCase()
                                : 'C',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          )
                        : null,
                  ),
                  // Membership badge
                  if (membershipLevel != 'Regular')
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: membershipLevel == 'Premium'
                              ? const Color(0xFFFFD700) // Gold
                              : const Color(0xFFC0C0C0), // Silver
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: Icon(Icons.star, size: 12, color: Colors.white),
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
                            userName.isNotEmpty ? userName : 'Customer Name',
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
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _getMembershipColor().withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '$membershipLevel Member',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _getMembershipColor(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getMembershipColor() {
    switch (membershipLevel) {
      case 'Premium':
        return Colors.amber;
      case 'Silver':
        return Colors.grey;
      default:
        return Colors.blue;
    }
  }

  Widget _buildCustomerStats() {
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
            userRating > 0 ? "${userRating.toStringAsFixed(1)}★" : "0.0★",
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

  Widget _buildQuickActions() {
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Quick Actions",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildQuickActionButton(
                  Icons.add,
                  "Book Service",
                  Colors.blue,
                  () => _navigateToBookService(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildQuickActionButton(
                  Icons.refresh,
                  "Repeat Booking",
                  Colors.green,
                  () => _navigateToRepeatBooking(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionButton(
    IconData icon,
    String label,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBookingSection() {
    return _buildSection("Bookings & Services", [
      buildMenuItem(
        Icons.history,
        "Booking History",
        "$totalBookings total bookings",
        onTap: () => _navigateToBookingHistory(),
      ),
      buildMenuItem(
        Icons.pending_actions,
        "Ongoing Services",
        "$ongoingBookings active bookings",
        badge: ongoingBookings,
        onTap: () => _navigateToOngoingServices(),
      ),
      buildMenuItem(
        Icons.favorite_outline,
        "Favorite Workers",
        "$favoriteWorkers saved favorites",
        onTap: () => _navigateToFavoriteWorkers(),
      ),
    ]);
  }

  Widget _buildPaymentSection() {
    return _buildSection("Payment & Wallet", [
      buildMenuItem(
        Icons.payment,
        "Payment Methods",
        "$savedPaymentMethods cards saved",
        onTap: () => _navigateToPaymentMethods(),
      ),
      buildMenuItem(
        Icons.account_balance_wallet_outlined,
        "Wallet & Credits",
        "₹${walletBalance.toStringAsFixed(0)} available",
        onTap: () => _navigateToWalletCredits(),
      ),
      buildMenuItem(
        Icons.receipt_long,
        "Transaction History",
        "View all payments",
        onTap: () => _navigateToTransactionHistory(),
      ),
    ]);
  }

  Widget _buildSupportSection() {
    return _buildSection("Support & Communication", [
      buildMenuItem(
        Icons.chat_bubble_outline,
        "Messages",
        "Chat with workers & support",
        onTap: () => _navigateToMessages(),
      ),
      buildMenuItem(
        Icons.star_outline,
        "My Reviews",
        "$totalReviews reviews given",
        onTap: () => _navigateToMyReviews(),
      ),
      buildMenuItem(
        Icons.help_outline,
        "Help & Support",
        "FAQ, contact support",
        onTap: () => _navigateToHelpSupport(),
      ),
    ]);
  }

  Widget _buildSettingsSection() {
    return _buildSection("Profile & Settings", [
      buildMenuItem(
        Icons.person_outline,
        "Personal Information",
        "Edit your details",
        onTap: () => _navigateToPersonalInformation(),
      ),
      buildMenuItem(
        Icons.location_on_outlined,
        "Address Management",
        "$savedAddresses saved addresses",
        onTap: () => _navigateToAddressManagement(),
      ),
      buildMenuItem(
        Icons.verified_user_outlined,
        "Identity Verification",
        isVerified ? "Verified" : "Verify identity",
        isVerified: isVerified,
        onTap: () => _navigateToIdentityVerification(),
      ),
      buildMenuItem(
        Icons.settings_outlined,
        "App Settings",
        "Preferences & privacy",
        onTap: () => _navigateToAppSettings(),
      ),
    ]);
  }

  Widget _buildAdditionalServicesSection() {
    return _buildSection("More Options", [
      buildMenuItem(
        Icons.card_giftcard,
        "Referral Program",
        "Invite friends & earn rewards",
        onTap: () => _navigateToReferralProgram(),
      ),
      buildMenuItem(
        Icons.work_outline,
        "Become a Worker",
        "Start offering services",
        onTap: () => _navigateToBecomeWorker(),
      ),
      buildMenuItem(
        Icons.description_outlined,
        "Terms & Privacy",
        "Terms of service & privacy policy",
        onTap: () => _navigateToTermsPrivacy(),
      ),
    ]);
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
              fontSize: 16,
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

  Widget _buildSection(String title, List<Widget> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 12),
        Container(
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
        ),
      ],
    );
  }

  Widget _buildLogoutButton() {
    return Container(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: handleLogout,
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

  // Navigation methods - implement these based on your existing app structure
  void _navigateToBookService() {
    Navigator.pushNamed(context, '/book-service');
  }

  void _navigateToRepeatBooking() {
    Navigator.pushNamed(context, '/repeat-booking');
  }

  void _navigateToBookingHistory() {
    Navigator.pushNamed(context, '/customer/booking-history');
  }

  void _navigateToOngoingServices() {
    Navigator.pushNamed(context, '/customer/ongoing-services');
  }

  void _navigateToFavoriteWorkers() {
    Navigator.pushNamed(context, '/customer/favorite-workers');
  }

  void _navigateToPaymentMethods() {
    Navigator.pushNamed(context, '/customer/payment-methods');
  }

  void _navigateToWalletCredits() {
    Navigator.pushNamed(context, '/customer/wallet-credits');
  }

  void _navigateToTransactionHistory() {
    Navigator.pushNamed(context, '/customer/transaction-history');
  }

  void _navigateToMessages() {
    Navigator.pushNamed(context, '/customer/messages');
  }

  void _navigateToMyReviews() {
    Navigator.pushNamed(context, '/customer/my-reviews');
  }

  void _navigateToHelpSupport() {
    Navigator.pushNamed(context, '/customer/help-support');
  }

  void _navigateToPersonalInformation() {
    Navigator.pushNamed(context, '/customer/personal-information');
  }

  void _navigateToAddressManagement() {
    Navigator.pushNamed(context, '/customer/address-management');
  }

  void _navigateToIdentityVerification() {
    Navigator.pushNamed(context, '/customer/identity-verification');
  }

  void _navigateToAppSettings() {
    Navigator.pushNamed(context, '/customer/app-settings');
  }

  void _navigateToReferralProgram() {
    Navigator.pushNamed(context, '/customer/referral-program');
  }

  void _navigateToBecomeWorker() {
    Navigator.pushNamed(context, '/become-worker');
  }

  void _navigateToTermsPrivacy() {
    Navigator.pushNamed(context, '/terms-privacy');
  }
}
