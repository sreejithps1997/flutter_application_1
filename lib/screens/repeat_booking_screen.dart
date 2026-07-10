import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../core/theme/workable_design.dart';
import '../widgets/workable_ui.dart';

class RepeatBookingScreen extends StatefulWidget {
  static const routeName = '/repeat-booking';

  const RepeatBookingScreen({super.key});

  @override
  State<RepeatBookingScreen> createState() => _RepeatBookingScreenState();
}

class _RepeatBookingScreenState extends State<RepeatBookingScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<BookingHistory> _recentBookings = [];
  List<BookingHistory> _frequentServices = [];
  bool _isLoading = true;
  String _selectedFilter = 'All';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchBookingData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchBookingData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Fetch recent completed bookings
      final recentQuery = await FirebaseFirestore.instance
          .collection('bookings')
          .where('customerId', isEqualTo: user.uid)
          .where('status', isEqualTo: 'completed')
          .orderBy('completedAt', descending: true)
          .limit(20)
          .get();

      List<BookingHistory> recentBookings = [];
      for (var doc in recentQuery.docs) {
        final data = doc.data();
        recentBookings.add(BookingHistory.fromFirestore(doc.id, data));
      }

      // Calculate frequent services based on service type frequency
      Map<String, List<BookingHistory>> serviceGroups = {};
      for (var booking in recentBookings) {
        if (!serviceGroups.containsKey(booking.serviceType)) {
          serviceGroups[booking.serviceType] = [];
        }
        serviceGroups[booking.serviceType]!.add(booking);
      }

      List<BookingHistory> frequentServices = [];
      serviceGroups.forEach((serviceType, bookings) {
        if (bookings.length >= 2) {
          // Consider frequent if booked 2 or more times
          frequentServices.add(bookings.first); // Add the most recent one
        }
      });

      // Sort frequent services by frequency (most frequent first)
      frequentServices.sort((a, b) {
        int aCount = serviceGroups[a.serviceType]!.length;
        int bCount = serviceGroups[b.serviceType]!.length;
        return bCount.compareTo(aCount);
      });

      if (!mounted) return;
      setState(() {
        _recentBookings = recentBookings;
        _frequentServices = frequentServices;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      _showErrorSnackBar('Failed to load booking history: $e');
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: WorkableDesign.danger,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  List<BookingHistory> _getFilteredBookings(List<BookingHistory> bookings) {
    if (_selectedFilter == 'All') return bookings;
    return bookings
        .where((booking) => booking.serviceType == _selectedFilter)
        .toList();
  }

  Set<String> _getAvailableServices(List<BookingHistory> bookings) {
    Set<String> services = {'All'};
    services.addAll(bookings.map((booking) => booking.serviceType));
    return services;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WorkableDesign.canvas,
      appBar: AppBar(
        title: const Text("Repeat Booking"),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          labelColor: WorkableDesign.primary,
          unselectedLabelColor: WorkableDesign.muted,
          indicatorColor: WorkableDesign.primary,
          tabs: const [
            Tab(icon: Icon(Icons.history), text: "Recent"),
            Tab(icon: Icon(Icons.repeat), text: "Frequent"),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
                  child: WorkablePageHeader(
                    title: 'Book trusted help again',
                    subtitle:
                        'Repeat completed services with the same worker or the same service details.',
                    icon: Icons.repeat,
                  ),
                ),
                _buildFilterChips(),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildRecentBookingsTab(),
                      _buildFrequentServicesTab(),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildFilterChips() {
    final availableServices = _tabController.index == 0
        ? _getAvailableServices(_recentBookings)
        : _getAvailableServices(_frequentServices);

    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: availableServices.length,
        itemBuilder: (context, index) {
          final service = availableServices.elementAt(index);
          final isSelected = _selectedFilter == service;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(service),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  _selectedFilter = service;
                });
              },
              selectedColor: WorkableDesign.primary.withValues(alpha: 0.12),
              checkmarkColor: WorkableDesign.primary,
              labelStyle: TextStyle(
                color: isSelected
                    ? WorkableDesign.primary
                    : WorkableDesign.muted,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildRecentBookingsTab() {
    final filteredBookings = _getFilteredBookings(_recentBookings);

    if (filteredBookings.isEmpty) {
      return _buildEmptyState(
        "No Recent Bookings",
        "You haven't completed any bookings yet.\nStart by booking a service!",
        Icons.history,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filteredBookings.length,
      itemBuilder: (context, index) {
        return _buildBookingCard(filteredBookings[index]);
      },
    );
  }

  Widget _buildFrequentServicesTab() {
    final filteredBookings = _getFilteredBookings(_frequentServices);

    if (filteredBookings.isEmpty) {
      return _buildEmptyState(
        "No Frequent Services",
        "Book the same service multiple times\nto see it here for quick rebooking.",
        Icons.repeat,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filteredBookings.length,
      itemBuilder: (context, index) {
        return _buildBookingCard(filteredBookings[index], isFrequent: true);
      },
    );
  }

  Widget _buildEmptyState(String title, String description, IconData icon) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 76, color: WorkableDesign.muted),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: WorkableDesign.ink,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: WorkableDesign.muted),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                Navigator.pushNamed(context, '/book-service');
              },
              child: const Text("Book a Service"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBookingCard(BookingHistory booking, {bool isFrequent = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: WorkableSectionCard(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _getServiceColor(
                            booking.serviceType,
                          ).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          _getServiceIcon(booking.serviceType),
                          color: _getServiceColor(booking.serviceType),
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    booking.serviceType,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (isFrequent) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: WorkableDesign.warning.withValues(
                                        alpha: 0.12,
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Text(
                                      "FREQUENT",
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: WorkableDesign.warning,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              booking.workerName,
                              style: const TextStyle(
                                fontSize: 14,
                                color: WorkableDesign.muted,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            "Rs ${booking.totalAmount.toInt()}",
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: WorkableDesign.success,
                            ),
                          ),
                          const SizedBox(height: 4),
                          if (booking.rating > 0)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.star,
                                  size: 14,
                                  color: Colors.amber,
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  booking.rating.toStringAsFixed(1),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: WorkableDesign.muted,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(
                        Icons.location_on_outlined,
                        size: 16,
                        color: WorkableDesign.muted,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          booking.address,
                          style: const TextStyle(
                            fontSize: 12,
                            color: WorkableDesign.muted,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(
                        Icons.access_time,
                        size: 16,
                        color: WorkableDesign.muted,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _formatDate(booking.completedAt),
                        style: const TextStyle(
                          fontSize: 12,
                          color: WorkableDesign.muted,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: WorkableDesign.canvas,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _rebookWithSameWorker(booking),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: WorkableDesign.primary),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.person, size: 16),
                          SizedBox(width: 4),
                          Text("Same Worker", style: TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _rebookService(booking),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: WorkableDesign.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.refresh, size: 16, color: Colors.white),
                          SizedBox(width: 4),
                          Text(
                            "Book Again",
                            style: TextStyle(fontSize: 12, color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getServiceIcon(String serviceType) {
    switch (serviceType.toLowerCase()) {
      case 'plumbing':
        return Icons.plumbing;
      case 'electrical':
        return Icons.electrical_services;
      case 'carpentry':
        return Icons.handyman;
      case 'child care':
        return Icons.child_care;
      case 'maid':
        return Icons.cleaning_services;
      case 'cooking':
        return Icons.restaurant;
      case 'laundry':
        return Icons.local_laundry_service;
      default:
        return Icons.home_repair_service;
    }
  }

  Color _getServiceColor(String serviceType) {
    switch (serviceType.toLowerCase()) {
      case 'plumbing':
        return Colors.blue;
      case 'electrical':
        return Colors.amber;
      case 'carpentry':
        return Colors.brown;
      case 'child care':
        return Colors.pink;
      case 'maid':
        return Colors.purple;
      case 'cooking':
        return Colors.orange;
      case 'laundry':
        return Colors.cyan;
      default:
        return Colors.grey;
    }
  }

  String _formatDate(DateTime date) {
    return "${date.day}/${date.month}/${date.year}";
  }

  void _rebookWithSameWorker(BookingHistory booking) {
    // Navigate to booking screen with pre-filled data including same worker
    Navigator.pushNamed(
      context,
      '/book-service',
      arguments: {
        'serviceType': booking.serviceType,
        'workerId': booking.workerId,
        'workerName': booking.workerName,
        'address': booking.address,
        'isRepeatBooking': true,
      },
    );
  }

  void _rebookService(BookingHistory booking) {
    // Navigate to booking screen with pre-filled service type only
    Navigator.pushNamed(
      context,
      '/book-service',
      arguments: {
        'serviceType': booking.serviceType,
        'address': booking.address,
        'isRepeatBooking': true,
      },
    );
  }
}

// Model class for booking history
class BookingHistory {
  final String id;
  final String serviceType;
  final String workerId;
  final String workerName;
  final String address;
  final double totalAmount;
  final double rating;
  final DateTime completedAt;

  BookingHistory({
    required this.id,
    required this.serviceType,
    required this.workerId,
    required this.workerName,
    required this.address,
    required this.totalAmount,
    required this.rating,
    required this.completedAt,
  });

  factory BookingHistory.fromFirestore(String id, Map<String, dynamic> data) {
    return BookingHistory(
      id: id,
      serviceType: data['serviceType'] ?? '',
      workerId: data['workerId'] ?? '',
      workerName: data['workerName'] ?? 'Unknown Worker',
      address: data['address'] ?? 'Address not available',
      totalAmount: (data['totalAmount'] ?? 0.0).toDouble(),
      rating: (data['rating'] ?? 0.0).toDouble(),
      completedAt:
          (data['completedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
