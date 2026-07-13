import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/theme/workable_design.dart';
import '../../services/worker_visibility_service.dart';
import '../../widgets/worker_visibility_status_panel.dart';
import 'base_account_screen.dart';

class WorkerAccountScreen extends BaseAccountScreen {
  static const routeName = '/worker-account';

  const WorkerAccountScreen({super.key});

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
      await WorkerVisibilityService().syncWorkerVisibility(uid);

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
      debugPrint('Error fetching worker data: $e');
      // Handle error gracefully
      if (!mounted) return;
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
      backgroundColor: WorkableDesign.canvas,
      appBar: AppBar(
        title: const Text("Worker Dashboard"),
        backgroundColor: WorkableDesign.surface,
        foregroundColor: WorkableDesign.ink,
        actions: [
          // Availability Toggle
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Switch(
                value: isAvailable,
                onChanged: (value) => _toggleAvailability(value),
                activeColor: WorkableDesign.success,
                inactiveThumbColor: WorkableDesign.muted,
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
            const SizedBox(height: 16),

            _buildVisibilityStatusCard(),
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

  Widget _buildVisibilityStatusCard() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return WorkerVisibilityStatusPanel(
      workerId: uid ?? '',
      margin: EdgeInsets.zero,
    );
  }

  Widget _buildWorkerProfileCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: WorkableDesign.cardDecoration(),
      child: Column(
        children: [
          Row(
            children: [
              Stack(
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: WorkableDesign.accent.withValues(
                      alpha: 0.1,
                    ),
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
                              color: WorkableDesign.accent,
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
                        color: isAvailable
                            ? WorkableDesign.success
                            : WorkableDesign.muted,
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
                            color: WorkableDesign.success,
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
                            ? WorkableDesign.success.withValues(alpha: 0.1)
                            : WorkableDesign.muted.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        isAvailable ? 'Available' : 'Unavailable',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isAvailable
                              ? WorkableDesign.success
                              : WorkableDesign.muted,
                        ),
                      ),
                    ),
                    if (serviceCategories.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        serviceCategories.join(', '),
                        style: const TextStyle(
                          fontSize: 12,
                          color: WorkableDesign.muted,
                        ),
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
            WorkableDesign.success,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            workerRating > 0
                ? "${workerRating.toStringAsFixed(1)} star"
                : "0.0 star",
            "Rating",
            Icons.star_outline,
            WorkableDesign.warning,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            "Rs ${totalEarnings.toStringAsFixed(0)}",
            "Earned",
            Icons.monetization_on_outlined,
            WorkableDesign.primary,
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
      decoration: WorkableDesign.cardDecoration(),
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
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: WorkableDesign.muted),
          ),
        ],
      ),
    );
  }

  Widget _buildBusinessSection() {
    return _buildSection("Work", [
      buildMenuItem(
        Icons.work_outline,
        "Active Jobs",
        "$activeServices ongoing jobs",
        badge: activeServices,
        onTap: () => _navigateToActiveJobs(),
      ),
      buildMenuItem(
        Icons.volunteer_activism_outlined,
        "Help Requests",
        "Pickup, delivery, urgent help",
        onTap: () => _navigateToHelpRequests(),
      ),
      buildMenuItem(
        Icons.history,
        "Job History",
        "$completedJobs completed jobs",
        onTap: () => _navigateToJobHistory(),
      ),
      buildMenuItem(
        Icons.chat_bubble_outline,
        "Messages",
        "Chat with customers",
        onTap: () => _navigateToMessages(),
      ),
    ]);
  }

  Widget _buildEarningsSection() {
    return _buildSection("Money", [
      buildMenuItem(
        Icons.account_balance_wallet_outlined,
        "Earnings",
        "Total: Rs ${totalEarnings.toStringAsFixed(0)}",
        onTap: () => _navigateToEarnings(),
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
    ]);
  }

  Widget _buildWorkerToolsSection() {
    return _buildSection("Business", [
      buildMenuItem(
        Icons.person_outline,
        "Professional Profile",
        "Profile, schedule, service area",
        onTap: () => _navigateToProfessionalProfile(),
      ),
      buildMenuItem(
        Icons.photo_library,
        "Portfolio",
        "Showcase your work",
        onTap: () => _navigateToPortfolio(),
      ),
      buildMenuItem(
        Icons.radar_outlined,
        "Opportunity Feed",
        "Customer demand near you",
        onTap: () => _navigateToOpportunities(),
      ),
      buildMenuItem(
        Icons.workspace_premium_outlined,
        "Achievements & Badges",
        "Verified hours and milestone history",
        onTap: () => _navigateToAchievements(),
      ),
      buildMenuItem(
        Icons.description_outlined,
        "Experience Certificate",
        "Share your verified Workable record",
        onTap: () => _navigateToExperienceCertificate(),
      ),
      buildMenuItem(
        Icons.rule_outlined,
        "Badge Criteria",
        "How Workable trust levels are calculated",
        onTap: () => _navigateToBadgeCriteria(),
      ),
      buildMenuItem(
        Icons.card_giftcard_outlined,
        "Referral Programme",
        "People joined through you",
        onTap: () => _navigateToReferralProgram(),
      ),
      buildMenuItem(
        Icons.rate_review,
        "Reviews & Ratings",
        "$totalReviews reviews received",
        onTap: () => _navigateToCustomerReviews(),
      ),
      buildMenuItem(
        Icons.verified_user_outlined,
        "Verification Status",
        isVerified ? "Verified" : "Complete verification",
        isVerified: isVerified,
        onTap: () => _navigateToVerificationStatus(),
      ),
    ]);
  }

  Widget _buildSettingsSection() {
    return _buildSection("Settings", [
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
            color: WorkableDesign.ink,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: WorkableDesign.cardDecoration(),
          child: Column(children: items),
        ),
      ],
    );
  }

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
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        throw StateError('No signed-in worker found');
      }

      // Update in Firestore
      await FirebaseFirestore.instance.collection('workers').doc(uid).update({
        'isAvailable': value,
      });

      if (!mounted) return;

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
      if (!mounted) return;

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

  void _navigateToHelpRequests() {
    Navigator.pushNamed(context, '/worker/help-requests');
  }

  void _navigateToJobHistory() {
    Navigator.pushNamed(context, '/worker/job-history');
  }

  void _navigateToEarnings() {
    Navigator.pushNamed(context, '/worker/earnings');
  }

  void _navigateToPayoutMethods() {
    Navigator.pushNamed(context, '/worker/payout-methods');
  }

  void _navigateToTransactionHistory() {
    Navigator.pushNamed(context, '/worker/transaction-history');
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

  void _navigateToProfessionalProfile() {
    Navigator.pushNamed(context, '/worker/professional-profile');
  }

  void _navigateToOpportunities() {
    Navigator.pushNamed(context, '/worker/opportunities');
  }

  void _navigateToAchievements() {
    Navigator.pushNamed(context, '/worker/achievements');
  }

  void _navigateToExperienceCertificate() {
    Navigator.pushNamed(context, '/worker/experience-certificate');
  }

  void _navigateToBadgeCriteria() {
    Navigator.pushNamed(context, '/worker/badge-criteria');
  }

  void _navigateToReferralProgram() {
    Navigator.pushNamed(context, '/referral-programme');
  }

  void _navigateToVerificationStatus() {
    Navigator.pushNamed(context, '/worker/verification-status');
  }

  void _navigateToAppSettings() {
    Navigator.pushNamed(context, '/worker/app-settings');
  }
}
