// keep your imports unchanged
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';

import '../widgets/custom_button.dart';
import '../widgets/star_rating.dart';
import 'worker_profile_screen.dart';
import '../services/notification_service.dart';
import '../widgets/verification_tier_badge.dart';

import '../services/user_type_service.dart';
import 'account/account_screen_factory.dart';
import '../core/theme/workable_design.dart';
import '../features/community_campaigns/presentation/customer_campaign_strip.dart';
import '../features/help_requests/presentation/customer_help_requests_screen.dart';
import '../features/smart_booking/presentation/smart_booking_assistant_screen.dart';
import 'generic_help_request_screen.dart';

class CustomerDashboardScreen extends StatefulWidget {
  static const routeName = '/customer-dashboard';

  const CustomerDashboardScreen({super.key});

  @override
  State<CustomerDashboardScreen> createState() =>
      _CustomerDashboardScreenState();
}

class _CustomerDashboardScreenState extends State<CustomerDashboardScreen> {
  String userName = '';
  String selectedService = '';
  String searchQuery = '';
  double minRating = 0;
  double maxHourlyRate = 10000;
  double maxDistance = 10000;
  Position? currentPosition;

  int _selectedIndex = 0;

  // final List<String> skills = [
  //   'Plumbing',
  //   'Electrical',
  //   'Cooking',
  //   'Carpentry',
  //   'Cleaning',
  //   'Painting',
  // ];

  List<String> availableSkills = [];

  @override
  void initState() {
    super.initState();

    // ✅ Save current FCM token and start refresh listener
    NotificationService.saveFcmTokenToFirestore(); // ✅ Now available
    NotificationService.startTokenRefreshListener();

    // Initialize customer dashboard features
    _initializeDashboard(); // 🔁 Run async loading
    _fetchSkills(); // 🆕
  }

  Future<void> _initializeDashboard() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();

    final data = doc.data();

    if (data != null) {
      setState(() {
        userName = data['name'] ?? 'Customer';

        final loc = data['location'];
        if (loc is GeoPoint) {
          currentPosition = Position(
            latitude: loc.latitude,
            longitude: loc.longitude,
            timestamp: DateTime.now(),
            accuracy: 1.0,
            altitude: 0.0,
            altitudeAccuracy: 1.0,
            heading: 0.0,
            headingAccuracy: 1.0,
            speed: 0.0,
            speedAccuracy: 1.0,
            floor: null,
            isMocked: false,
          );
          debugPrint(
            "📍 Loaded location: ${currentPosition?.latitude}, ${currentPosition?.longitude}",
          );
        }
      });
    }
  }

  Future<void> _fetchSkills() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('skills')
          .get();
      setState(() {
        availableSkills = snapshot.docs.map((doc) => doc.id).toList();
      });
    } catch (e) {
      debugPrint('Error fetching skills: $e');
    }
  }

  void _openAdvancedFilter() {
    showModalBottomSheet(
      context: context,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "Advanced Filters",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Text("Min Rating"),
                      Expanded(
                        child: Slider(
                          value: minRating,
                          min: 0,
                          max: 5,
                          divisions: 5,
                          label: "$minRating",
                          onChanged: (value) {
                            setModalState(() => minRating = value);
                            setState(() {});
                          },
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      const Text("Max Hourly Rate"),
                      Expanded(
                        child: Slider(
                          value: maxHourlyRate,
                          min: 100,
                          max: 10000,
                          divisions: 100,
                          label: "₹${maxHourlyRate.toInt()}",
                          onChanged: (value) {
                            setModalState(() => maxHourlyRate = value);
                            setState(() {});
                          },
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      const Text("Max Distance (km)"),
                      Expanded(
                        child: Slider(
                          value: maxDistance,
                          min: 1,
                          max: 10000,
                          divisions: 20,
                          label: "${maxDistance.toInt()} km",
                          onChanged: (value) {
                            setModalState(() => maxDistance = value);
                            setState(() {});
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  CustomButton(
                    text: 'Apply Filters',
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Stream<QuerySnapshot> getFilteredWorkers() {
    // Query query = FirebaseFirestore.instance
    //     .collection('workers')
    //     .where(
    //       'visibleToUsers',
    //       isEqualTo: true,
    //     ); // ✅ Always filter hidden workers

    Query query = FirebaseFirestore.instance
        .collection('workers')
        .where('visibleToUsers', isEqualTo: true)
        .where('imageUrl', isGreaterThan: '') // Profile photo uploaded
        .where('verification.selfie', isEqualTo: 'verified') // Selfie verified
        .where('location', isGreaterThan: null); // Has location

    if (selectedService.isNotEmpty) {
      query = query.where('skills', arrayContains: selectedService);
    }
    return query.snapshots();
  }

  // Stream<QuerySnapshot> getFilteredWorkers() {
  //   Query query = FirebaseFirestore.instance.collection('workers');

  //   if (selectedService.isNotEmpty) {
  //     query = query.where('skills', arrayContains: selectedService);
  //   }

  //   return query.snapshots();
  // }

  double? _calculateDistance(Map<String, dynamic> workerData) {
    if (currentPosition == null) return null;
    final loc = workerData['location'];
    if (loc is! GeoPoint) return null;
    return Geolocator.distanceBetween(
          currentPosition!.latitude,
          currentPosition!.longitude,
          loc.latitude,
          loc.longitude,
        ) /
        1000;
  }

  void _onTabTapped(int index) {
    setState(() => _selectedIndex = index);
    switch (index) {
      case 0:
        break; // Home
      case 1:
        Navigator.pushNamed(context, '/search');
        break;
      case 2:
        Navigator.pushNamed(context, '/customer-bookings');
        break;
      case 3:
        Navigator.pushNamed(
          context,
          '/recent-chats',
          arguments: {'userRole': 'customer'},
        );
        break;
      // case 4:
      //   // Navigator.pushNamed(context, '/edit-profile');
      //   // Navigator.pushNamed(context, MyAccountScreen.routeName);
      //   Navigator.pushNamed(context, '/account');
      //   break;
      case 4:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => FutureBuilder<String>(
              future: UserTypeService.getCurrentUserType(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  );
                }
                if (snapshot.hasError || !snapshot.hasData) {
                  return const Scaffold(
                    body: Center(child: Text("Error loading account")),
                  );
                }
                return AccountScreenFactory.createAccountScreen(snapshot.data!);
              },
            ),
          ),
        );
        break;
    }
  }

  void handleBookingAttemptQuick(
    BuildContext context,
    String _,
    String workerId,
    String workerName,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            WorkerProfileScreen(workerId: workerId, name: workerName),
      ),
    );
  }

  List<String> _workerSkills(Map<String, dynamic> data) {
    return (data['skills'] as List<dynamic>?)
            ?.map((skill) => skill.toString().trim())
            .where((skill) => skill.isNotEmpty)
            .toList() ??
        [];
  }

  String _pricingLabel(dynamic pricing) {
    final text = pricing?.toString().trim();
    if (text == null || text.isEmpty || text.toLowerCase() == 'null') {
      return 'Rate not set';
    }
    return text.contains('Rs') || text.contains('/hr') || text.contains('hour')
        ? text
        : 'Rs $text / hr';
  }

  String _locationLabel(Map<String, dynamic> data) {
    final parts = [data['area'], data['city'], data['addressArea']]
        .where((part) {
          final text = part?.toString().trim();
          return text != null &&
              text.isNotEmpty &&
              text.toLowerCase() != 'null';
        })
        .map((part) => part.toString().trim())
        .toList();

    if (parts.isEmpty) return 'Service location added';
    return parts.toSet().take(2).join(', ');
  }

  int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  Widget _buildWorkerCard(Map<String, dynamic> data, String id, String tier) {
    final name = data['name']?.toString().trim().isNotEmpty == true
        ? data['name'].toString().trim()
        : 'Worker';
    final imageUrl = data['imageUrl']?.toString().trim();
    final skills = _workerSkills(data);
    final visibleSkills = skills.take(3).toList();
    final extraSkillCount = skills.length - visibleSkills.length;
    final rating = (data['averageRating'] as num?)?.toDouble() ?? 0.0;
    final reviewCount = _asInt(data['totalReviews'] ?? data['reviewCount']);
    final distance = _calculateDistance(data);

    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: WorkableDesign.pagePadding,
        vertical: 8,
      ),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(WorkableDesign.radius),
        side: const BorderSide(color: WorkableDesign.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(WorkableDesign.radius),
        onTap: () => handleBookingAttemptQuick(context, tier, id, name),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      width: 76,
                      height: 76,
                      color: WorkableDesign.canvas,
                      child: imageUrl != null && imageUrl.isNotEmpty
                          ? Image.network(
                              imageUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  const Icon(Icons.person, size: 34),
                            )
                          : const Icon(Icons.person, size: 34),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            VerificationTierBadge(tier: tier),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            StarRating(rating: rating),
                            const SizedBox(width: 6),
                            Text(
                              reviewCount > 0
                                  ? '${rating.toStringAsFixed(1)} ($reviewCount)'
                                  : rating > 0
                                  ? rating.toStringAsFixed(1)
                                  : 'New',
                              style: TextStyle(
                                color: WorkableDesign.muted,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              Icons.location_on_outlined,
                              size: 15,
                              color: WorkableDesign.muted,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                distance != null
                                    ? '${distance.toStringAsFixed(1)} km away'
                                    : _locationLabel(data),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: WorkableDesign.muted,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (visibleSkills.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final skill in visibleSkills)
                      Chip(
                        label: Text(skill),
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        backgroundColor: WorkableDesign.primary.withValues(
                          alpha: 0.08,
                        ),
                        labelStyle: const TextStyle(
                          color: WorkableDesign.primaryDark,
                          fontSize: 12,
                        ),
                        side: BorderSide(
                          color: WorkableDesign.primary.withValues(alpha: 0.16),
                        ),
                      ),
                    if (extraSkillCount > 0)
                      Chip(
                        label: Text('+$extraSkillCount'),
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _pricingLabel(data['pricing']),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () =>
                        handleBookingAttemptQuick(context, tier, id, name),
                    icon: const Icon(Icons.arrow_forward, size: 18),
                    label: const Text('Profile'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WorkableDesign.canvas,
      appBar: AppBar(
        title: Text('Hi, $userName'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_alt_outlined),
            onPressed: _openAdvancedFilter,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(WorkableDesign.pagePadding),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search worker by name or category...',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) =>
                  setState(() => searchQuery = value.trim().toLowerCase()),
            ),
          ),
          const CustomerCampaignStrip(),
          const SizedBox(height: 10),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: availableSkills.map((skill) {
                final isSelected = selectedService == skill;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: ChoiceChip(
                    label: Text(skill),
                    selected: isSelected,

                    // onSelected: (_) => setState(() {
                    //   selectedService = isSelected ? '' : skill;
                    // }),
                    onSelected: (_) => setState(() {
                      selectedService = isSelected ? '' : skill;
                      searchQuery = ''; // Reset search to avoid conflict
                    }),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: getFilteredWorkers(),

              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (currentPosition == null) {
                  return const Center(child: CircularProgressIndicator());
                }

                final workers = snapshot.data!.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final name = data['name']?.toString().toLowerCase() ?? '';
                  final skillsList =
                      (data['skills'] as List<dynamic>?)
                          ?.map((e) => e.toString().toLowerCase())
                          .toList() ??
                      [];

                  final rating = (data['averageRating'] ?? 0).toDouble();
                  final pricingString = data['pricing']?.toString() ?? '';
                  final rate =
                      double.tryParse(
                        RegExp(r'\d+').firstMatch(pricingString)?.group(0) ??
                            '0',
                      ) ??
                      0.0;
                  final distance = _calculateDistance(data);
                  final isNotDisabled =
                      data['accountDisabled'] != true &&
                      data['accountStatus'] != 'disabled';
                  final passesDistanceFilter =
                      distance != null && distance <= maxDistance;

                  final matchesSearch =
                      searchQuery.isEmpty ||
                      name.contains(searchQuery) ||
                      skillsList.any((skill) => skill.contains(searchQuery));

                  final matchesSelectedService =
                      selectedService.isEmpty ||
                      skillsList.contains(selectedService.toLowerCase());

                  return matchesSearch &&
                      matchesSelectedService &&
                      isNotDisabled &&
                      rating >= minRating &&
                      rate <= maxHourlyRate &&
                      passesDistanceFilter;
                }).toList();

                if (workers.isEmpty) {
                  return const Center(
                    child: Text('No matching workers found.'),
                  );
                }

                return ListView.builder(
                  itemCount: workers.length,
                  itemBuilder: (context, index) {
                    final data = workers[index].data() as Map<String, dynamic>;
                    final id = workers[index].id;
                    final tier = data['verification']?['tier'] ?? 'new';

                    return _buildWorkerCard(data, id, tier);
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            heroTag: 'smart_booking',
            onPressed: () => Navigator.pushNamed(
              context,
              SmartBookingAssistantScreen.routeName,
            ),
            icon: const Icon(Icons.auto_awesome),
            label: const Text('Smart book'),
          ),
          const SizedBox(height: 10),
          FloatingActionButton.extended(
            heroTag: 'my_help_requests',
            onPressed: () => Navigator.pushNamed(
              context,
              CustomerHelpRequestsScreen.routeName,
            ),
            icon: const Icon(Icons.list_alt_outlined),
            label: const Text('My help'),
          ),
          const SizedBox(height: 10),
          FloatingActionButton.extended(
            heroTag: 'request_help',
            onPressed: () => Navigator.pushNamed(
              context,
              GenericHelpRequestScreen.routeName,
            ),
            icon: const Icon(Icons.front_hand_outlined),
            label: const Text('Request help'),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onTabTapped,
        selectedItemColor: WorkableDesign.primary,
        unselectedItemColor: WorkableDesign.muted,
        backgroundColor: WorkableDesign.surface,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Search'),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today),
            label: 'Bookings',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_outline),
            label: 'Chats',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}
