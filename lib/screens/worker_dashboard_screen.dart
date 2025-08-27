import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'worker_job_details_screen.dart';
import 'view_earnings_screen.dart';
import 'worker_reviews_screen.dart';
import 'worker_profile_update_screen.dart';
import '../services/notification_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'recent_chats_screen.dart';
import '../services/verification_tier_manager.dart';
import 'my_account_screen.dart';
import '../screens/account/worker_account_screen.dart';

class WorkerDashboardScreen extends StatefulWidget {
  static const routeName = '/worker-dashboard';
  const WorkerDashboardScreen({Key? key}) : super(key: key);
  @override
  State<WorkerDashboardScreen> createState() => _WorkerDashboardScreenState();
}

class _WorkerDashboardScreenState extends State<WorkerDashboardScreen> {
  String workerName = 'Worker';
  int _selectedIndex = 0;
  String? _deadlineMessage;
  bool _showVerificationBanner = false;
  bool isOnline = true;

  final String todayDate = DateTime.now().toIso8601String().split('T').first;

  // Mock weekly data - you can replace with real Firebase data
  final List<Map<String, dynamic>> weeklyStats = [
    {'day': 'Mon', 'earnings': 2400, 'jobs': 3},
    {'day': 'Tue', 'earnings': 3200, 'jobs': 4},
    {'day': 'Wed', 'earnings': 1800, 'jobs': 2},
    {'day': 'Thu', 'earnings': 2850, 'jobs': 4}, // Today
    {'day': 'Fri', 'earnings': 0, 'jobs': 0},
    {'day': 'Sat', 'earnings': 0, 'jobs': 0},
    {'day': 'Sun', 'earnings': 0, 'jobs': 0},
  ];

  @override
  void initState() {
    super.initState();

    NotificationService.saveFcmTokenToFirestore();
    NotificationService.startTokenRefreshListener();

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await VerificationTierManager().maybeStartVerificationTimer(uid);
        await VerificationTierManager().getUserVerificationTier(uid);
        await _checkVerificationDeadline(uid);
      });
    }

    _loadWorkerName();
  }

  Future<void> _checkVerificationDeadline(String uid) async {
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();
    final verification = userDoc.data()?['verification'] ?? {};
    final Timestamp? startAt = verification['startAt'];
    if (startAt == null) return;

    final now = DateTime.now();
    final startDate = startAt.toDate();
    final deadline = startDate.add(const Duration(days: 14));

    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('identityVerification')
        .get();

    final statusMap = <String, String>{};
    for (final doc in snapshot.docs) {
      statusMap[doc.id] = doc['status'] ?? 'pending';
    }

    final address =
        statusMap['addressProof'] == 'verified' ||
        statusMap['address'] == 'verified';
    final police = statusMap['backgroundCheck'] == 'verified';

    if (!address || !police) {
      if (now.isBefore(deadline)) {
        setState(() {
          _deadlineMessage =
              "⚠️ ${deadline.difference(now).inDays} day(s) left to complete address and police verification.";
          _showVerificationBanner = true;
        });
      } else {
        await FirebaseFirestore.instance.collection('workers').doc(uid).update({
          'accountStatus': 'disabled',
          'visibleToUsers': false,
        });
      }
    } else {
      setState(() {
        _showVerificationBanner = false;
        _deadlineMessage = null;
      });
    }
  }

  Future<void> _loadWorkerName() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      final doc = await FirebaseFirestore.instance
          .collection('workers')
          .doc(uid)
          .get();
      if (doc.exists) {
        setState(() {
          workerName = doc.data()?['name'] ?? 'Worker';
        });
      }
    }
  }

  void _logout() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
  }

  Widget _buildWelcomeCard() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2563EB), Color(0xFF7C3AED)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Good Morning, $workerName! 👋',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Ready to earn more today?',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: _logout,
                icon: const Icon(Icons.logout, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Work Status',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: isOnline ? Colors.green : Colors.red,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isOnline ? 'Available for jobs' : 'Currently offline',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Switch(
                value: isOnline,
                onChanged: (value) => setState(() => isOnline = value),
                activeColor: Colors.green,
                activeTrackColor: Colors.green.withOpacity(0.3),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTodayStats() {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('bookings')
            .where('workerId', isEqualTo: uid)
            .where('preferredDate', isEqualTo: todayDate)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;
          final completedJobs = docs
              .where((doc) => (doc.data() as Map)['status'] == 'completed')
              .length;
          final scheduledJobs = docs
              .where((doc) => (doc.data() as Map)['status'] == 'confirmed')
              .length;

          // Calculate today's earnings from completed jobs
          double todayEarnings = 0;
          for (final doc in docs) {
            final data = doc.data() as Map<String, dynamic>;
            if (data['status'] == 'completed' && data['price'] != null) {
              todayEarnings += (data['price'] as num).toDouble();
            }
          }

          // Calculate average rating for today (mock data - replace with actual rating calculation)
          double todayRating = 4.9;

          return Column(
            children: [
              // Row 1: Today's Earnings and Jobs Completed
              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      title: "Today's Earnings",
                      value: '₹${todayEarnings.toInt()}',
                      icon: Icons.currency_rupee,
                      gradient: const LinearGradient(
                        colors: [Color(0xFF10B981), Color(0xFF059669)],
                      ),
                      trend: '+12%',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatCard(
                      title: 'Jobs Completed',
                      value: '$completedJobs',
                      icon: Icons.check_circle,
                      gradient: const LinearGradient(
                        colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
                      ),
                      trend: '+2',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Row 2: Scheduled Jobs and Today's Rating
              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      title: 'Scheduled',
                      value: '$scheduledJobs Jobs',
                      icon: Icons.schedule,
                      gradient: const LinearGradient(
                        colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                      ),
                      trend: '$scheduledJobs',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatCard(
                      title: "Today's Rating",
                      value: '$todayRating',
                      icon: Icons.star,
                      gradient: const LinearGradient(
                        colors: [Color(0xFF8B5CF6), Color(0xFF7C3AED)],
                      ),
                      trend: 'Excellent',
                      showStar: true,
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildWeeklyPerformance() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Weekly Performance',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              TextButton(
                onPressed: () {},
                child: const Text(
                  'View Details',
                  style: TextStyle(
                    color: Color(0xFF2563EB),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 120,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: weeklyStats.asMap().entries.map((entry) {
                final index = entry.key;
                final stat = entry.value;
                final isToday = index == 3; // Thursday is today
                final maxEarnings = 4000;
                final height = (stat['earnings'] / maxEarnings * 80).clamp(
                  4.0,
                  80.0,
                );

                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Container(
                          height: height,
                          decoration: BoxDecoration(
                            color: isToday
                                ? const Color(0xFF2563EB)
                                : Colors.grey.shade300,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(4),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          stat['day'],
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isToday
                                ? FontWeight.w600
                                : FontWeight.normal,
                            color: isToday
                                ? const Color(0xFF2563EB)
                                : Colors.grey.shade600,
                          ),
                        ),
                        Text(
                          '₹${stat['earnings']}',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Quick Actions',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _QuickActionButton(
                  title: 'Find Jobs',
                  icon: Icons.work_outline,
                  color: const Color(0xFF2563EB),
                  onTap: () {},
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _QuickActionButton(
                  title: 'Analytics',
                  icon: Icons.trending_up,
                  color: const Color(0xFF10B981),
                  onTap: () {},
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentTab() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    switch (_selectedIndex) {
      case 0:
        return Scaffold(
          backgroundColor: Colors.grey.shade50,
          body: SafeArea(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _buildWelcomeCard(),
                  if (_showVerificationBanner && _deadlineMessage != null) ...[
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.warning, color: Colors.orange.shade600),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _deadlineMessage!,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Colors.orange.shade800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  _buildTodayStats(),
                  const SizedBox(height: 16),
                  _buildWeeklyPerformance(),
                  const SizedBox(height: 16),
                  _buildQuickActions(),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Today's Schedule",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 12),
                        StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('bookings')
                              .where('workerId', isEqualTo: uid)
                              .where('preferredDate', isEqualTo: todayDate)
                              .snapshots(),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData) {
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
                            }

                            final docs = snapshot.data!.docs;

                            if (docs.isEmpty) {
                              return Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.calendar_today,
                                      size: 64,
                                      color: Colors.grey.shade400,
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      "No jobs scheduled for today.",
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }

                            return Column(
                              children: docs.map((doc) {
                                final data = doc.data() as Map<String, dynamic>;
                                return _JobCard(data: data, bookingId: doc.id);
                              }).toList(),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 100), // Bottom padding for navigation
                ],
              ),
            ),
          ),
        );

      case 1:
        return const ViewEarningsScreen();
      case 2:
        return const WorkerReviewsScreen();
      case 3:
        return RecentChatsScreen(userRole: 'worker');
      // case 4:
      //   return const MyAccountScreen();

      // case 4:
      //   return FutureBuilder<String>(
      //     future: UserTypeService.getCurrentUserType(),
      //     builder: (context, snapshot) {
      //       if (snapshot.connectionState == ConnectionState.waiting) {
      //         return const Center(child: CircularProgressIndicator());
      //       }
      //       if (snapshot.hasError || !snapshot.hasData) {
      //         return const Center(child: Text('Failed to load account'));
      //       }
      //       return AccountScreenFactory.createAccountScreen(snapshot.data!);
      //     },
      //   );
      case 4:
        return const WorkerAccountScreen();
      default:
        return const Center(child: Text("Tab not found"));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _buildCurrentTab(),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (int index) {
            setState(() => _selectedIndex = index);
            if (index == 0) {
              final uid = FirebaseAuth.instance.currentUser?.uid;
              if (uid != null) _checkVerificationDeadline(uid);
            }
          },
          selectedItemColor: const Color(0xFF2563EB),
          unselectedItemColor: Colors.grey.shade600,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500),
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          elevation: 0,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: 'Overview',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.attach_money_outlined),
              activeIcon: Icon(Icons.attach_money),
              label: 'Earnings',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.star_border_outlined),
              activeIcon: Icon(Icons.star),
              label: 'Reviews',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.chat_bubble_outline),
              activeIcon: Icon(Icons.chat_bubble),
              label: 'Chats',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Gradient gradient;
  final String trend;
  final bool showStar;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.gradient,
    required this.trend,
    this.showStar = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: Colors.white, size: 20),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  trend,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (showStar) ...[
                const SizedBox(width: 4),
                const Icon(Icons.star, color: Colors.yellow, size: 16),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.title,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
            Icon(Icons.chevron_right, color: color, size: 16),
          ],
        ),
      ),
    );
  }
}

class _JobCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final String bookingId;

  const _JobCard({required this.data, required this.bookingId});

  @override
  Widget build(BuildContext context) {
    final status = data['status'] ?? 'pending';
    final statusColor = _statusColor(status);

    final preferredTime = data['preferredTime'] ?? 'Time not set';
    final serviceName = data['service'] ?? 'Service not specified';
    final customerName = data['customerName'] ?? 'Customer';
    final address = data['address'] ?? 'Address not available';
    final duration = data['duration'] ?? 'Duration not specified';
    final price = data['price'] != null
        ? "₹${data['price']}"
        : 'Price not available';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.access_time, size: 16),
              const SizedBox(width: 6),
              Text(preferredTime),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  status.toLowerCase(),
                  style: TextStyle(fontSize: 12, color: statusColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            serviceName,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          Text(
            customerName,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          Row(
            children: [
              const Icon(Icons.location_on_outlined, size: 16),
              const SizedBox(width: 4),
              Expanded(child: Text(address)),
            ],
          ),
          Text(duration),
          const SizedBox(height: 6),
          Text(
            price,
            style: const TextStyle(
              color: Colors.green,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            WorkerJobDetailsScreen(bookingId: bookingId),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text("View Details"),
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Call feature not implemented"),
                    ),
                  );
                },
                icon: const Icon(Icons.phone_outlined),
              ),
              IconButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Chat feature not implemented"),
                    ),
                  );
                },
                icon: const Icon(Icons.chat_bubble_outline),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'confirmed':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'cancelled':
        return Colors.red;
      case 'completed':
        return Colors.blueGrey;
      default:
        return Colors.grey;
    }
  }
}
