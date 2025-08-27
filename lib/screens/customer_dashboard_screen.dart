// keep your imports unchanged
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';

import '../widgets/custom_button.dart';
import '../widgets/star_rating.dart';
import '../utils/location_helper.dart';
import 'worker_profile_screen.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../services/notification_service.dart';
import 'my_account_screen.dart';

import '../widgets/verification_tier_badge.dart';
import '../services/verification_tier_manager.dart';

import '../services/user_type_service.dart';
import 'account/customer_account_screen.dart';
import 'account/worker_account_screen.dart';
import 'account/account_screen_factory.dart';

class CustomerDashboardScreen extends StatefulWidget {
  static const routeName = '/customer-dashboard';

  const CustomerDashboardScreen({Key? key}) : super(key: key);

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
          print(
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
      print('Error fetching skills: $e');
    }
  }

  Future<void> _loadUserName() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      setState(() {
        userName = doc.data()?['name'] ?? 'Customer';
      });
    }
  }

  Future<void> _getCurrentLocation() async {
    currentPosition = await LocationHelper.getCurrentLocation();
    setState(() {});
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

  void handleBookingAttempt(
    BuildContext context,
    String tier,
    String workerId,
    String workerName,
  ) {
    if (tier == 'new') {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text("Verification Required"),
          content: const Text(
            "This worker has not yet completed their identity verification. Please choose a verified worker for booking.",
          ),
          actions: [
            TextButton(
              child: const Text("OK"),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      );
      return;
    }

    // ✅ Allow booking / profile view
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            WorkerProfileScreen(workerId: workerId, name: workerName),
      ),
    );
  }

  // Future<void> handleBookingAttemptQuick(
  //   BuildContext context,
  //   String cachedTier,
  //   String workerId,
  //   String workerName,
  // ) async {
  //   String effectiveTier = cachedTier;

  //   // 🧠 Only fetch fresh tier if cached says "new"
  //   if (cachedTier == 'new') {
  //     effectiveTier = await VerificationTierManager().getUserVerificationTier(
  //       workerId,
  //     );
  //   }

  //   if (effectiveTier == 'new') {
  //     _showBlockedDialog(context);
  //     return;
  //   }

  //   // ✅ Tier is verified or police_verified, allow booking
  //   Navigator.push(
  //     context,
  //     MaterialPageRoute(
  //       builder: (_) =>
  //           WorkerProfileScreen(workerId: workerId, name: workerName),
  //     ),
  //   );
  // }

  Future<void> handleBookingAttemptQuick(
    BuildContext context,
    String cachedTier,
    String workerId,
    String workerName,
  ) async {
    String effectiveTier = cachedTier;

    // 🔄 Still fetch fresh tier if it's marked as 'new'
    if (cachedTier == 'new') {
      effectiveTier = await VerificationTierManager().getUserVerificationTier(
        workerId,
      );
    }

    // ✅ Regardless of tier (even 'new'), allow viewing/booking
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            WorkerProfileScreen(workerId: workerId, name: workerName),
      ),
    );
  }

  void _showBlockedDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Verification Required"),
        content: const Text(
          "This worker has not yet completed their identity verification. Please choose a verified worker for booking.",
        ),
        actions: [
          TextButton(
            child: const Text("OK"),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search worker by name or category...',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) =>
                  setState(() => searchQuery = value.trim().toLowerCase()),
            ),
          ),
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
                  final passesDistanceFilter =
                      distance == null || distance <= maxDistance;

                  final matchesSearch =
                      searchQuery.isEmpty ||
                      name.contains(searchQuery) ||
                      skillsList.any((skill) => skill.contains(searchQuery));

                  final matchesSelectedService =
                      selectedService.isEmpty ||
                      skillsList.contains(selectedService.toLowerCase());

                  return matchesSearch &&
                      matchesSelectedService &&
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

                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundImage: data['imageUrl'] != null
                              ? NetworkImage(data['imageUrl'])
                              : null,
                          child: data['imageUrl'] == null
                              ? const Icon(Icons.person)
                              : null,
                        ),
                        title: Text(data['name'] ?? ''),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (data['skills'] != null)
                              Text((data['skills'] as List).join(', ')),

                            VerificationTierBadge(
                              tier: tier,
                            ), // 👈 Add badge here

                            StarRating(
                              rating:
                                  (data['averageRating'] as num?)?.toDouble() ??
                                  0.0,
                            ),

                            Text('₹${data['pricing'] ?? '--'} / hr'),
                            Text(
                              _calculateDistance(data) != null
                                  ? 'Distance: ${_calculateDistance(data)!.toStringAsFixed(1)} km'
                                  : 'Distance: N/A',
                            ),
                          ],
                        ),
                        trailing: ElevatedButton(
                          child: const Text('View Profile'),
                          // onPressed: () {
                          //   Navigator.push(
                          //     context,
                          //     MaterialPageRoute(
                          //       builder: (_) => WorkerProfileScreen(
                          //         workerId: id,
                          //         name: data['name'] ?? '',
                          //       ),
                          //     ),
                          //   );
                          // },
                          onPressed: () => handleBookingAttemptQuick(
                            context,
                            tier,
                            id,
                            data['name'] ?? '',
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onTabTapped,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
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
