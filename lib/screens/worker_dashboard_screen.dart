import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'worker_job_details_screen.dart';
import 'worker_earnings_screen.dart';
import 'worker_reviews_screen.dart';
import '../services/notification_service.dart';
import 'chat_screen.dart';
import 'recent_chats_screen.dart';
import '../services/chat_service.dart';
import '../services/verification_tier_manager.dart';
import '../screens/account/worker_account_screen.dart';
import '../core/theme/workable_design.dart';
import '../widgets/worker_visibility_status_panel.dart';

class WorkerDashboardScreen extends StatefulWidget {
  static const routeName = '/worker-dashboard';
  const WorkerDashboardScreen({super.key});
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
              "${deadline.difference(now).inDays} day(s) left to complete address and police verification.";
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
          isOnline = doc.data()?['isAvailable'] ?? true;
        });
      }
    }
  }

  Future<void> _toggleAvailability(bool value) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final previous = isOnline;
    setState(() => isOnline = value);

    try {
      await FirebaseFirestore.instance.collection('workers').doc(uid).update({
        'isAvailable': value,
        'availabilityUpdatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => isOnline = previous);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to update availability: $e')),
      );
    }
  }

  void _logout() async {
    await NotificationService.removeCurrentDeviceToken();
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
  }

  double? _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  String _weekdayLabel(int weekday) {
    const labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return labels[(weekday - 1).clamp(0, 6)];
  }

  Widget _buildWelcomeCard() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [WorkableDesign.primary, WorkableDesign.accent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(WorkableDesign.radius),
        boxShadow: [
          BoxShadow(
            color: WorkableDesign.primary.withValues(alpha: 0.18),
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
                      'Good Morning, $workerName!',
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
                onChanged: _toggleAvailability,
                activeColor: Colors.green,
                activeTrackColor: Colors.green.withValues(alpha: 0.3),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardMetrics(String workerId) {
    if (workerId.isEmpty) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('bookings')
          .where('workerId', isEqualTo: workerId)
          .snapshots(),
      builder: (context, bookingSnapshot) {
        if (!bookingSnapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: LinearProgressIndicator(minHeight: 3),
          );
        }

        final bookings = bookingSnapshot.data!.docs
            .map((doc) => doc.data())
            .toList();
        final stats = _DashboardStats.fromBookings(bookings);

        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('workers')
              .doc(workerId)
              .snapshots(),
          builder: (context, workerSnapshot) {
            final worker = workerSnapshot.data?.data() ?? {};
            final rating = _asDouble(
              worker['averageRating'] ?? worker['rating'],
            );
            final reviewCount =
                _asInt(worker['totalReviews'] ?? worker['reviewsCount']) ?? 0;

            return Column(
              children: [
                _buildTodayStats(stats, rating, reviewCount),
                const SizedBox(height: 16),
                _buildWeeklyPerformance(stats.weeklyStats),
                const SizedBox(height: 16),
                _buildQuickActions(),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildTodayStats(
    _DashboardStats stats,
    double? rating,
    int reviewCount,
  ) {
    final ratingLabel = rating == null || rating <= 0
        ? 'No ratings'
        : rating.toStringAsFixed(1);
    final reviewTrend = reviewCount == 0
        ? 'New'
        : '$reviewCount ${reviewCount == 1 ? 'review' : 'reviews'}';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  title: "Today's Earnings",
                  value: 'Rs ${stats.todayEarnings.toInt()}',
                  icon: Icons.currency_rupee,
                  gradient: const LinearGradient(
                    colors: [Color(0xFF16A34A), Color(0xFF0F766E)],
                  ),
                  trend: '${stats.todayCompletedJobs} paid',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  title: 'Jobs Completed',
                  value: '${stats.todayCompletedJobs}',
                  icon: Icons.check_circle,
                  gradient: const LinearGradient(
                    colors: [
                      WorkableDesign.primary,
                      WorkableDesign.primaryDark,
                    ],
                  ),
                  trend: 'Today',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  title: 'Scheduled',
                  value: '${stats.todayScheduledJobs}',
                  icon: Icons.schedule,
                  gradient: const LinearGradient(
                    colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                  ),
                  trend: 'Today',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  title: 'Rating',
                  value: ratingLabel,
                  icon: Icons.star,
                  gradient: const LinearGradient(
                    colors: [Color(0xFF7C3AED), Color(0xFF4338CA)],
                  ),
                  trend: reviewTrend,
                  showStar: rating != null && rating > 0,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyPerformance(List<_WeeklyStat> weeklyStats) {
    final maxEarnings = weeklyStats.fold<double>(
      0,
      (max, stat) => stat.earnings > max ? stat.earnings : max,
    );
    final todayLabel = _weekdayLabel(DateTime.now().weekday);

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: WorkableDesign.surface,
        borderRadius: BorderRadius.circular(WorkableDesign.radius),
        border: Border.all(color: WorkableDesign.border),
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
                  color: WorkableDesign.ink,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              TextButton(
                onPressed: () => setState(() => _selectedIndex = 1),
                child: const Text('Earnings'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Completed jobs and earnings from the last 7 days.',
            style: TextStyle(
              color: WorkableDesign.muted,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 120,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: weeklyStats.map((stat) {
                final isToday = stat.day == todayLabel;
                final height = maxEarnings <= 0
                    ? 4.0
                    : (stat.earnings / maxEarnings * 80).clamp(4.0, 80.0);

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
                                ? WorkableDesign.primary
                                : WorkableDesign.border,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(4),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          stat.day,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isToday
                                ? FontWeight.w600
                                : FontWeight.normal,
                            color: isToday
                                ? WorkableDesign.primary
                                : WorkableDesign.muted,
                          ),
                        ),
                        Text(
                          stat.jobs == 0 ? '-' : 'Rs ${stat.earnings.toInt()}',
                          style: const TextStyle(
                            fontSize: 10,
                            color: WorkableDesign.muted,
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
      decoration: WorkableDesign.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Quick Actions',
            style: TextStyle(
              color: WorkableDesign.ink,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _QuickActionButton(
                  title: 'Active Jobs',
                  icon: Icons.work_outline,
                  color: WorkableDesign.primary,
                  onTap: () =>
                      Navigator.pushNamed(context, '/worker/active-jobs'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _QuickActionButton(
                  title: 'Payouts',
                  icon: Icons.account_balance_wallet_outlined,
                  color: WorkableDesign.accent,
                  onTap: () => Navigator.pushNamed(context, '/worker/earnings'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _QuickActionButton(
                  title: 'Opportunities',
                  icon: Icons.radar_outlined,
                  color: WorkableDesign.warning,
                  onTap: () =>
                      Navigator.pushNamed(context, '/worker/opportunities'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _QuickActionButton(
                  title: 'Help Requests',
                  icon: Icons.volunteer_activism_outlined,
                  color: WorkableDesign.success,
                  onTap: () =>
                      Navigator.pushNamed(context, '/worker/help-requests'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _QuickActionButton(
                  title: 'Verification',
                  icon: Icons.verified_outlined,
                  color: WorkableDesign.success,
                  onTap: () => Navigator.pushNamed(
                    context,
                    '/worker/verification-status',
                  ),
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(child: SizedBox.shrink()),
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
                  WorkerVisibilityStatusPanel(workerId: uid ?? ''),
                  const SizedBox(height: 16),
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
                  _buildDashboardMetrics(uid ?? ''),
                  const SizedBox(height: 16),
                  _WorkerBookingsSection(workerId: uid ?? ''),
                  const SizedBox(height: 100), // Bottom padding for navigation
                ],
              ),
            ),
          ),
        );

      case 1:
        return const WorkerEarningsScreen();
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
      backgroundColor: WorkableDesign.canvas,
      body: _buildCurrentTab(),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: WorkableDesign.ink.withValues(alpha: 0.08),
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
          selectedItemColor: WorkableDesign.primary,
          unselectedItemColor: WorkableDesign.muted,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500),
          type: BottomNavigationBarType.fixed,
          backgroundColor: WorkableDesign.surface,
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

class _DashboardStats {
  final int todayCompletedJobs;
  final int todayScheduledJobs;
  final double todayEarnings;
  final List<_WeeklyStat> weeklyStats;

  const _DashboardStats({
    required this.todayCompletedJobs,
    required this.todayScheduledJobs,
    required this.todayEarnings,
    required this.weeklyStats,
  });

  factory _DashboardStats.fromBookings(List<Map<String, dynamic>> bookings) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekStart = today.subtract(const Duration(days: 6));

    final weekly = <DateTime, _WeeklyStatBuilder>{
      for (var i = 0; i < 7; i++)
        weekStart.add(Duration(days: i)): _WeeklyStatBuilder(
          day: _weekdayLabel(weekStart.add(Duration(days: i)).weekday),
        ),
    };

    var todayCompleted = 0;
    var todayScheduled = 0;
    var todayEarnings = 0.0;

    for (final booking in bookings) {
      final status = (booking['status'] ?? '').toString().toLowerCase();
      final scheduledAt = _bookingDate(booking);
      final amount = _bookingAmount(booking);
      final isToday = scheduledAt != null && _isSameDay(scheduledAt, today);

      if (isToday && status == 'completed') {
        todayCompleted++;
        todayEarnings += amount;
      }
      if (isToday && (status == 'confirmed' || status == 'in_progress')) {
        todayScheduled++;
      }

      if (scheduledAt != null &&
          !scheduledAt.isBefore(weekStart) &&
          !scheduledAt.isAfter(today.add(const Duration(days: 1)))) {
        final dayKey = DateTime(
          scheduledAt.year,
          scheduledAt.month,
          scheduledAt.day,
        );
        final builder = weekly[dayKey];
        if (builder != null && status == 'completed') {
          builder.jobs++;
          builder.earnings += amount;
        }
      }
    }

    return _DashboardStats(
      todayCompletedJobs: todayCompleted,
      todayScheduledJobs: todayScheduled,
      todayEarnings: todayEarnings,
      weeklyStats: weekly.values.map((item) => item.toStat()).toList(),
    );
  }

  static bool _isSameDay(DateTime date, DateTime other) {
    return date.year == other.year &&
        date.month == other.month &&
        date.day == other.day;
  }

  static DateTime? _bookingDate(Map<String, dynamic> data) {
    final scheduledAt = data['scheduledAt'];
    if (scheduledAt is Timestamp) return scheduledAt.toDate();

    final preferredDate = data['preferredDate']?.toString().trim();
    if (preferredDate != null && preferredDate.isNotEmpty) {
      return DateTime.tryParse(preferredDate);
    }

    final createdAt = data['createdAt'];
    if (createdAt is Timestamp) return createdAt.toDate();
    return null;
  }

  static double _bookingAmount(Map<String, dynamic> data) {
    final raw =
        data['price'] ??
        data['estimatedPrice'] ??
        data['amount'] ??
        data['totalAmount'] ??
        data['total'];
    if (raw is num) return raw.toDouble();
    return double.tryParse(raw?.toString() ?? '') ?? 0;
  }

  static String _weekdayLabel(int weekday) {
    const labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return labels[(weekday - 1).clamp(0, 6)];
  }
}

class _WeeklyStat {
  final String day;
  final int jobs;
  final double earnings;

  const _WeeklyStat({
    required this.day,
    required this.jobs,
    required this.earnings,
  });
}

class _WeeklyStatBuilder {
  final String day;
  int jobs = 0;
  double earnings = 0;

  _WeeklyStatBuilder({required this.day});

  _WeeklyStat toStat() {
    return _WeeklyStat(day: day, jobs: jobs, earnings: earnings);
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
            color: Colors.black.withValues(alpha: 0.1),
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
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: Colors.white, size: 20),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
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
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
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

class _WorkerBookingsSection extends StatelessWidget {
  final String workerId;

  const _WorkerBookingsSection({required this.workerId});

  @override
  Widget build(BuildContext context) {
    if (workerId.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('bookings')
            .where('workerId', isEqualTo: workerId)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final bookings = snapshot.data!.docs.map((doc) {
            return _BookingListItem(
              id: doc.id,
              data: doc.data() as Map<String, dynamic>,
            );
          }).toList()..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));

          final newRequests = bookings
              .where((item) => item.status == 'pending')
              .toList();
          final upcoming = bookings.where((item) {
            return item.status == 'confirmed' || item.status == 'in_progress';
          }).toList();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _BookingGroup(
                title: 'New Requests',
                subtitle: 'Accept or decline customer bookings',
                emptyText: 'No new booking requests.',
                bookings: newRequests,
              ),
              const SizedBox(height: 18),
              _BookingGroup(
                title: 'Upcoming Jobs',
                subtitle: 'Confirmed work you need to complete',
                emptyText: 'No upcoming jobs scheduled.',
                bookings: upcoming,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _BookingGroup extends StatelessWidget {
  final String title;
  final String subtitle;
  final String emptyText;
  final List<_BookingListItem> bookings;

  const _BookingGroup({
    required this.title,
    required this.subtitle,
    required this.emptyText,
    required this.bookings,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
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
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${bookings.length}',
                style: TextStyle(
                  color: Colors.blue.shade700,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (bookings.isEmpty)
          _EmptyBookingsCard(message: emptyText)
        else
          Column(
            children: bookings
                .map((item) => _JobCard(data: item.data, bookingId: item.id))
                .toList(),
          ),
      ],
    );
  }
}

class _EmptyBookingsCard extends StatelessWidget {
  final String message;

  const _EmptyBookingsCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.event_available_outlined, color: Colors.grey.shade500),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message, style: TextStyle(color: Colors.grey.shade700)),
          ),
        ],
      ),
    );
  }
}

class _BookingListItem {
  final String id;
  final Map<String, dynamic> data;

  const _BookingListItem({required this.id, required this.data});

  String get status => (data['status'] ?? 'pending').toString().toLowerCase();

  DateTime get scheduledAt {
    final scheduled = data['scheduledAt'];
    if (scheduled is Timestamp) return scheduled.toDate();
    final date = data['preferredDate']?.toString() ?? '';
    final time = data['preferredTime']?.toString() ?? '';
    return DateTime.tryParse('$date ${_normalizeTime(time)}') ??
        DateTime.tryParse(date) ??
        DateTime.fromMillisecondsSinceEpoch(0);
  }

  String _normalizeTime(String time) {
    final match = RegExp(
      r'^(\d{1,2})(?::(\d{2}))?\s*(AM|PM)?$',
      caseSensitive: false,
    ).firstMatch(time.trim());
    if (match == null) return '00:00';
    var hour = int.tryParse(match.group(1) ?? '0') ?? 0;
    final minute = int.tryParse(match.group(2) ?? '0') ?? 0;
    final period = match.group(3)?.toUpperCase();
    if (period == 'PM' && hour < 12) hour += 12;
    if (period == 'AM' && hour == 12) hour = 0;
    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  }
}

class _JobCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final String bookingId;

  const _JobCard({required this.data, required this.bookingId});

  @override
  Widget build(BuildContext context) {
    final status = (data['status'] ?? 'pending').toString();
    final statusColor = _statusColor(status);
    final preferredDate = data['preferredDate'] ?? 'Date not set';
    final preferredTime = data['preferredTime'] ?? 'Time not set';
    final serviceName =
        data['service'] ?? data['serviceType'] ?? 'Service not specified';
    final customerName = data['customerName'] ?? 'Customer';
    final address = data['address'] ?? 'Address not available';
    final issue = data['issueDescription'] ?? data['issue'] ?? '';
    final price = data['price'] != null
        ? 'Rs ${data['price']}'
        : 'Price not set';
    final isPending = status.toLowerCase() == 'pending';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.access_time, size: 16),
              const SizedBox(width: 6),
              Expanded(child: Text('$preferredDate • $preferredTime')),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
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
            serviceName.toString(),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          Text(
            customerName.toString(),
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          if (issue.toString().trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              issue.toString(),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Colors.grey.shade700),
            ),
          ],
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.location_on_outlined, size: 16),
              const SizedBox(width: 4),
              Expanded(child: Text(address.toString())),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            price,
            style: const TextStyle(
              color: Colors.green,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          if (isPending) ...[
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _updateStatus(context, 'cancelled'),
                    child: const Text('Decline'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _updateStatus(context, 'confirmed'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Accept'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],
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
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text('View Details'),
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Call feature not implemented'),
                    ),
                  );
                },
                icon: const Icon(Icons.phone_outlined),
              ),
              IconButton(
                onPressed: () => _openChat(context, customerName, serviceName),
                icon: const Icon(Icons.chat_bubble_outline),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _updateStatus(BuildContext context, String nextStatus) async {
    await FirebaseFirestore.instance
        .collection('bookings')
        .doc(bookingId)
        .update({
          'status': nextStatus,
          if (nextStatus == 'confirmed')
            'acceptedAt': FieldValue.serverTimestamp(),
          if (nextStatus == 'cancelled')
            'declinedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          nextStatus == 'confirmed' ? 'Job accepted' : 'Job declined',
        ),
      ),
    );
  }

  Future<void> _openChat(
    BuildContext context,
    Object customerName,
    Object serviceName,
  ) async {
    final customerId = data['customerId']?.toString();
    if (customerId == null || customerId.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Customer details not found')),
      );
      return;
    }

    try {
      await ChatService().ensureChatForBooking(
        otherUserId: customerId,
        otherUserName: customerName.toString(),
        userRole: 'worker',
        bookingId: bookingId,
        service: serviceName.toString(),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to start chat right now')),
      );
      return;
    }
    if (!context.mounted) return;

    Navigator.pushNamed(
      context,
      ChatScreen.routeName,
      arguments: {
        'chatWithId': customerId,
        'chatWithName': customerName.toString(),
        'userRole': 'worker',
        'bookingId': bookingId,
        'workerService': serviceName.toString(),
      },
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
