import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'base_account_screen.dart';

class WorkerAccountScreen extends BaseAccountScreen {
  static const routeName = '/worker-account';

  const WorkerAccountScreen({Key? key}) : super(key: key);

  @override
  State<WorkerAccountScreen> createState() => _WorkerAccountScreenState();
}

class _WorkerAccountScreenState
    extends BaseAccountScreenState<WorkerAccountScreen> {
  // Worker-specific data
  int completedJobs = 0;
  double workerRating = 0.0;
  double totalEarnings = 0.0;
  int activeServices = 0;
  bool isAvailable = true;
  String workingHours = '';
  List<String> serviceCategories = [];
  int totalReviews = 0;

  @override
  Future<void> fetchTypeSpecificData(String uid, String userType) async {
    try {
      // Fetch worker-specific data
      final workerDoc = await FirebaseFirestore.instance
          .collection('workers')
          .doc(uid)
          .get();

      if (workerDoc.exists) {
        final data = workerDoc.data()!;
        setState(() {
          completedJobs = data['completedJobs'] ?? 0;
          workerRating = (data['rating'] ?? 0.0).toDouble();
          totalEarnings = (data['totalEarnings'] ?? 0.0).toDouble();
          activeServices = data['activeServices'] ?? 0;
          isAvailable = data['isAvailable'] ?? true;
          workingHours = data['workingHours'] ?? '9 AM - 6 PM';
          serviceCategories = List<String>.from(
            data['serviceCategories'] ?? [],
          );
          totalReviews = data['totalReviews'] ?? 0;
        });
      }
    } catch (e) {
      print('Error fetching worker data: $e');
      // Handle error gracefully
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load worker data: $e'),
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
        title: const Text("Worker Dashboard"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
        actions: [
          // Availability Toggle
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Switch(
                value: isAvailable,
                onChanged: (value) => _toggleAvailability(value),
                activeColor: Colors.green,
                inactiveThumbColor: Colors.grey,
              ),
            ],
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile Card with Availability Status
            _buildWorkerProfileCard(),
            const SizedBox(height: 24),

            // Worker Stats
            _buildWorkerStats(),
            const SizedBox(height: 24),

            // Business Management Section
            _buildBusinessSection(),
            const SizedBox(height: 24),

            // Earnings Section
            _buildEarningsSection(),
            const SizedBox(height: 24),

            // Worker Tools Section
            _buildWorkerToolsSection(),
            const SizedBox(height: 24),

            // Settings Section
            _buildSettingsSection(),
            const SizedBox(height: 32),

            // Logout Button
            _buildLogoutButton(),

            const SizedBox(height: 16),

            // App Version
            Center(
              child: Text(
                "Workable Worker App v2.1.0",
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkerProfileCard() {
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
                                : 'W',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          )
                        : null,
                  ),
                  // Availability indicator
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: isAvailable ? Colors.green : Colors.grey,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: Icon(
                        isAvailable ? Icons.check : Icons.pause,
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
                            userName.isNotEmpty ? userName : 'Worker Name',
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
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isAvailable
                            ? Colors.green.shade100
                            : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        isAvailable ? 'Available' : 'Unavailable',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isAvailable
                              ? Colors.green.shade700
                              : Colors.grey.shade700,
                        ),
                      ),
                    ),
                    if (serviceCategories.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        serviceCategories.join(', '),
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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

  Widget _buildWorkerStats() {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            completedJobs.toString(),
            "Completed",
            Icons.check_circle_outline,
            Colors.green,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            workerRating > 0 ? "${workerRating.toStringAsFixed(1)}★" : "0.0★",
            "Rating",
            Icons.star_outline,
            Colors.orange,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            "₹${totalEarnings.toStringAsFixed(0)}",
            "Earned",
            Icons.monetization_on_outlined,
            Colors.blue,
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

  Widget _buildBusinessSection() {
    return _buildSection("Business Management", [
      buildMenuItem(
        Icons.work_outline,
        "Active Jobs",
        "$activeServices ongoing jobs",
        badge: activeServices,
        onTap: () => _navigateToActiveJobs(),
      ),
      buildMenuItem(
        Icons.history,
        "Job History",
        "$completedJobs completed jobs",
        onTap: () => _navigateToJobHistory(),
      ),
      buildMenuItem(
        Icons.schedule,
        "Schedule Management",
        "Working hours: $workingHours",
        onTap: () => _navigateToSchedule(),
      ),
      buildMenuItem(
        Icons.location_on_outlined,
        "Service Areas",
        "Manage coverage areas",
        onTap: () => _navigateToServiceAreas(),
      ),
    ]);
  }

  Widget _buildEarningsSection() {
    return _buildSection("Earnings & Payments", [
      buildMenuItem(
        Icons.account_balance_wallet_outlined,
        "Earnings Overview",
        "Total: ₹${totalEarnings.toStringAsFixed(0)}",
        onTap: () => _navigateToEarningsOverview(),
      ),
      buildMenuItem(
        Icons.payment,
        "Payout Methods",
        "Bank account, UPI",
        onTap: () => _navigateToPayoutMethods(),
      ),
      buildMenuItem(
        Icons.receipt_long,
        "Transaction History",
        "Payment records",
        onTap: () => _navigateToTransactionHistory(),
      ),
      buildMenuItem(
        Icons.assessment,
        "Earnings Analytics",
        "Performance insights",
        onTap: () => _navigateToEarningsAnalytics(),
      ),
    ]);
  }

  Widget _buildWorkerToolsSection() {
    return _buildSection("Worker Tools", [
      buildMenuItem(
        Icons.rate_review,
        "Customer Reviews",
        "$totalReviews reviews received",
        onTap: () => _navigateToCustomerReviews(),
      ),
      buildMenuItem(
        Icons.chat_bubble_outline,
        "Messages",
        "Chat with customers",
        onTap: () => _navigateToMessages(),
      ),
      buildMenuItem(
        Icons.photo_library,
        "Portfolio",
        "Showcase your work",
        onTap: () => _navigateToPortfolio(),
      ),
      buildMenuItem(
        Icons.school,
        "Training Center",
        "Improve your skills",
        onTap: () => _navigateToTrainingCenter(),
      ),
    ]);
  }

  Widget _buildSettingsSection() {
    return _buildSection("Settings", [
      buildMenuItem(
        Icons.person_outline,
        "Professional Profile",
        "Edit business details",
        onTap: () => _navigateToProfessionalProfile(),
      ),
      buildMenuItem(
        Icons.verified_user_outlined,
        "Verification Status",
        isVerified ? "Verified" : "Complete verification",
        isVerified: isVerified,
        onTap: () => _navigateToVerificationStatus(),
      ),
      buildMenuItem(
        Icons.notifications_outlined,
        "Notification Settings",
        "Job alerts, messages",
        onTap: () => _navigateToNotificationSettings(),
      ),
      buildMenuItem(
        Icons.settings_outlined,
        "App Settings",
        "Preferences",
        onTap: () => _navigateToAppSettings(),
      ),
    ]);
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

  void _toggleAvailability(bool value) async {
    setState(() {
      isAvailable = value;
    });

    try {
      // Update in Firestore
      await FirebaseFirestore.instance
          .collection('workers')
          .doc(FirebaseAuth.instance.currentUser!.uid)
          .update({'isAvailable': value});

      // Show confirmation
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            value
                ? 'You are now available for jobs'
                : 'You are now unavailable',
          ),
          backgroundColor: value ? Colors.green : Colors.orange,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      // Revert the state if update fails
      setState(() {
        isAvailable = !value;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update availability: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Navigation methods - implement these based on your app structure
  void _navigateToActiveJobs() {
    Navigator.pushNamed(context, '/worker/active-jobs');
  }

  void _navigateToJobHistory() {
    Navigator.pushNamed(context, '/worker/job-history');
  }

  void _navigateToSchedule() {
    Navigator.pushNamed(context, '/worker/schedule');
  }

  void _navigateToServiceAreas() {
    Navigator.pushNamed(context, '/worker/service-areas');
  }

  void _navigateToEarningsOverview() {
    Navigator.pushNamed(context, '/worker/earnings-overview');
  }

  void _navigateToPayoutMethods() {
    Navigator.pushNamed(context, '/worker/payout-methods');
  }

  void _navigateToTransactionHistory() {
    Navigator.pushNamed(context, '/worker/transaction-history');
  }

  void _navigateToEarningsAnalytics() {
    Navigator.pushNamed(context, '/worker/earnings-analytics');
  }

  void _navigateToCustomerReviews() {
    Navigator.pushNamed(context, '/worker/customer-reviews');
  }

  void _navigateToMessages() {
    Navigator.pushNamed(context, '/worker/messages');
  }

  void _navigateToPortfolio() {
    Navigator.pushNamed(context, '/worker/portfolio');
  }

  void _navigateToTrainingCenter() {
    Navigator.pushNamed(context, '/worker/training-center');
  }

  void _navigateToProfessionalProfile() {
    Navigator.pushNamed(context, '/worker/professional-profile');
  }

  void _navigateToVerificationStatus() {
    Navigator.pushNamed(context, '/worker/verification-status');
  }

  void _navigateToNotificationSettings() {
    Navigator.pushNamed(context, '/worker/notification-settings');
  }

  void _navigateToAppSettings() {
    Navigator.pushNamed(context, '/worker/app-settings');
  }
}
