import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'customer_booking_detail_screen.dart';
import 'customer_booking_review_screen.dart';
import '../services/booking_flow.dart';
import '../utils/string_utils.dart';

class CustomerBookingsScreen extends StatefulWidget {
  static const routeName = '/customer-bookings';
  // Also support booking history route
  static const bookingHistoryRoute = '/customer/booking-history';

  const CustomerBookingsScreen({super.key});

  @override
  State<CustomerBookingsScreen> createState() => _CustomerBookingsScreenState();
}

class _CustomerBookingsScreenState extends State<CustomerBookingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedFilter = 'All';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    print("Current UID: ${FirebaseAuth.instance.currentUser?.uid}");

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text("My Bookings"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.deepPurple,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.deepPurple,
          tabs: const [
            Tab(icon: Icon(Icons.access_time), text: "Active"),
            Tab(icon: Icon(Icons.check_circle_outline), text: "Completed"),
            Tab(icon: Icon(Icons.history), text: "All History"),
          ],
        ),
      ),
      body: userId == null
          ? _buildLoginPrompt()
          : Column(
              children: [
                _buildFilterSection(),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildBookingsList(userId, [
                        'pending',
                        'confirmed',
                        'in_progress',
                      ]),
                      _buildBookingsList(userId, ['completed']),
                      _buildBookingsList(userId, null), // All bookings
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildLoginPrompt() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.login, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 16),
            const Text(
              "Please log in",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            const Text(
              "You need to log in to view your bookings.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterSection() {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('bookings')
            .where(
              'customerId',
              isEqualTo: FirebaseAuth.instance.currentUser?.uid,
            )
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const SizedBox.shrink();

          Set<String> serviceTypes = {'All'};
          for (var doc in snapshot.data!.docs) {
            final data = doc.data() as Map<String, dynamic>;
            if (data['serviceType'] != null) {
              serviceTypes.add(data['serviceType']);
            } else if (data['issue'] != null) {
              // Fallback to issue if serviceType not available
              serviceTypes.add(data['issue']);
            }
          }

          return ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: serviceTypes.length,
            itemBuilder: (context, index) {
              final service = serviceTypes.elementAt(index);
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
                  selectedColor: Colors.deepPurple.withOpacity(0.2),
                  checkmarkColor: Colors.deepPurple,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.deepPurple : Colors.grey[700],
                    fontWeight: isSelected
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildBookingsList(String userId, List<String>? statusFilter) {
    return StreamBuilder<QuerySnapshot>(
      stream: _getBookingsStream(userId, statusFilter),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return _buildErrorState();
        }

        final allBookings = snapshot.data?.docs ?? [];

        // Apply filter
        final filteredBookings = _selectedFilter == 'All'
            ? allBookings
            : allBookings.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return data['serviceType'] == _selectedFilter ||
                    data['issue'] == _selectedFilter;
              }).toList();

        if (filteredBookings.isEmpty) {
          return _buildEmptyState(statusFilter);
        }

        return ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: filteredBookings.length,
          itemBuilder: (context, index) {
            final booking =
                filteredBookings[index].data() as Map<String, dynamic>;
            booking['id'] = filteredBookings[index].id;
            return _buildEnhancedBookingTile(context, booking);
          },
        );
      },
    );
  }

  Stream<QuerySnapshot> _getBookingsStream(
    String userId,
    List<String>? statusFilter,
  ) {
    Query query = FirebaseFirestore.instance
        .collection('bookings')
        .where('customerId', isEqualTo: userId)
        .orderBy('createdAt', descending: true);

    if (statusFilter != null) {
      query = query.where('status', whereIn: statusFilter);
    }

    return query.snapshots();
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 16),
            const Text(
              "Something went wrong",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            const Text(
              "Unable to load your bookings.\nPlease try again later.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(List<String>? statusFilter) {
    String title = "No bookings found";
    String description = "You haven't made any bookings yet.";
    IconData icon = Icons.bookmark_border;

    if (statusFilter != null) {
      if (statusFilter.contains('pending') ||
          statusFilter.contains('confirmed')) {
        title = "No active bookings";
        description = "You don't have any ongoing bookings at the moment.";
        icon = Icons.schedule;
      } else if (statusFilter.contains('completed')) {
        title = "No completed bookings";
        description = "You haven't completed any bookings yet.";
        icon = Icons.check_circle_outline;
      }
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                Navigator.pushNamed(context, '/book-service');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
              ),
              child: const Text(
                "Book a Service",
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Widget _buildEnhancedBookingTile(
  //   BuildContext context,
  //   Map<String, dynamic> booking,
  // ) {
  //   final serviceType =
  //       booking['serviceType'] ?? booking['issue'] ?? 'Service Request';
  //   final workerName = booking['workerName'] ?? 'Worker not assigned';
  //   final status = booking['status'] ?? 'Unknown';
  //   final amount = booking['totalAmount'] ?? booking['amount'] ?? 0.0;

  //   return Card(
  //     margin: const EdgeInsets.only(bottom: 16),
  //     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  //     elevation: 2,
  //     child: Column(
  //       children: [
  //         ListTile(
  //           contentPadding: const EdgeInsets.all(16),
  //           leading: Container(
  //             padding: const EdgeInsets.all(12),
  //             decoration: BoxDecoration(
  //               color: _getServiceColor(serviceType).withOpacity(0.1),
  //               borderRadius: BorderRadius.circular(10),
  //             ),
  //             child: Icon(
  //               _getServiceIcon(serviceType),
  //               color: _getServiceColor(serviceType),
  //               size: 24,
  //             ),
  //           ),
  //           title: Text(
  //             serviceType,
  //             style: const TextStyle(fontWeight: FontWeight.bold),
  //           ),
  //           subtitle: Column(
  //             crossAxisAlignment: CrossAxisAlignment.start,
  //             children: [
  //               const SizedBox(height: 6),
  //               if (workerName != 'Worker not assigned')
  //                 Text(
  //                   "Worker: $workerName",
  //                   style: const TextStyle(fontWeight: FontWeight.w500),
  //                 ),
  //               const SizedBox(height: 4),
  //               Text("Date: ${booking['preferredDate'] ?? 'N/A'}"),
  //               Text("Time: ${booking['preferredTime'] ?? 'N/A'}"),
  //               if (amount > 0) ...[
  //                 const SizedBox(height: 4),
  //                 Text(
  //                   "Amount: ₹${amount.toStringAsFixed(0)}",
  //                   style: const TextStyle(
  //                     fontWeight: FontWeight.w600,
  //                     color: Colors.green,
  //                   ),
  //                 ),
  //               ],
  //               const SizedBox(height: 8),
  //               Row(
  //                 children: [
  //                   const Text("Status: "),
  //                   Container(
  //                     padding: const EdgeInsets.symmetric(
  //                       horizontal: 12,
  //                       vertical: 6,
  //                     ),
  //                     decoration: BoxDecoration(
  //                       color: _statusColor(status),
  //                       borderRadius: BorderRadius.circular(16),
  //                     ),
  //                     child: Text(
  //                       _getStatusText(status),
  //                       style: const TextStyle(
  //                         color: Colors.white,
  //                         fontSize: 12,
  //                         fontWeight: FontWeight.w600,
  //                       ),
  //                     ),
  //                   ),
  //                 ],
  //               ),
  //             ],
  //           ),
  //           trailing: const Icon(Icons.arrow_forward_ios, size: 16),
  //           onTap: () {
  //             Navigator.push(
  //               context,
  //               MaterialPageRoute(
  //                 builder: (_) => CustomerBookingDetailScreen(booking: booking),
  //               ),
  //             );
  //           },
  //         ),
  //         // Add quick actions for completed bookings
  //         if (status.toLowerCase() == 'completed') ...[
  //           Container(
  //             padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
  //             decoration: BoxDecoration(
  //               color: Colors.grey[50],
  //               borderRadius: const BorderRadius.only(
  //                 bottomLeft: Radius.circular(12),
  //                 bottomRight: Radius.circular(12),
  //               ),
  //             ),
  //             child: Row(
  //               children: [
  //                 Expanded(
  //                   child: OutlinedButton.icon(
  //                     onPressed: () => BookingFlow.rebook(context, booking),
  //                     icon: const Icon(Icons.refresh, size: 16),
  //                     label: const Text(
  //                       "Book Again",
  //                       style: TextStyle(fontSize: 12),
  //                     ),
  //                     style: OutlinedButton.styleFrom(
  //                       foregroundColor: Colors.deepPurple,
  //                       side: const BorderSide(color: Colors.deepPurple),
  //                     ),
  //                   ),
  //                 ),
  //                 const SizedBox(width: 8),
  //                 Expanded(
  //                   child: OutlinedButton.icon(
  //                     onPressed: () => _rateService(booking),
  //                     icon: const Icon(Icons.star_outline, size: 16),
  //                     label: const Text(
  //                       "Rate Service",
  //                       style: TextStyle(fontSize: 12),
  //                     ),
  //                     style: OutlinedButton.styleFrom(
  //                       foregroundColor: Colors.orange,
  //                       side: const BorderSide(color: Colors.orange),
  //                     ),
  //                   ),
  //                 ),
  //               ],
  //             ),
  //           ),
  //         ],
  //       ],
  //     ),
  //   );
  // }

  Widget _buildEnhancedBookingTile(
    BuildContext context,
    Map<String, dynamic> booking,
  ) {
    final serviceType =
        booking['serviceType'] ?? booking['issue'] ?? 'Service Request';
    final workerName = (booking['workerName'] ?? '').toString().trim();
    final status = (booking['status'] ?? 'Unknown').toString();
    final amount = (booking['totalAmount'] ?? booking['amount'] ?? 0.0) as num;
    Future<void> _precheckThenOpenDetails() async {
      final workerId = (booking['workerId'] as String?)?.trim();

      if (workerId != null && workerId.isNotEmpty) {
        try {
          final snap = await FirebaseFirestore.instance
              .collection('workers')
              .doc(workerId)
              .get();

          if (!mounted) return; // <— guard

          final worker = snap.data();
          final eligible = BookingFlow.isWorkerEligible(worker);

          if (!eligible) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'The assigned worker is not currently available. You can still view booking details.',
                ),
              ),
            );
          }
        } catch (_) {
          if (!mounted) return; // <— guard
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Could not verify worker availability. Opening details…',
              ),
            ),
          );
        }
      }

      if (!mounted) return; // <— guard
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CustomerBookingDetailScreen(booking: booking),
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => BookingFlow.openBookingDetailsStrict(context, booking),
        child: Column(
          children: [
            ListTile(
              contentPadding: const EdgeInsets.all(16),
              leading: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _getServiceColor(serviceType).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  _getServiceIcon(serviceType),
                  color: _getServiceColor(serviceType),
                  size: 24,
                ),
              ),
              title: Text(
                serviceType,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 6),
                  if (workerName.isNotEmpty)
                    Text(
                      "Worker: $workerName",
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  const SizedBox(height: 4),
                  Text("Date: ${booking['preferredDate'] ?? 'N/A'}"),
                  Text("Time: ${booking['preferredTime'] ?? 'N/A'}"),
                  if (amount > 0) ...[
                    const SizedBox(height: 4),
                    Text(
                      "Amount: ₹${amount.toStringAsFixed(0)}",
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.green,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Text("Status: "),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: _statusColor(status),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          _getStatusText(status),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            ),

            // Quick actions for completed bookings (unchanged)
            if (status.toLowerCase() == 'completed') ...[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(12),
                    bottomRight: Radius.circular(12),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => BookingFlow.rebook(context, booking),
                        icon: const Icon(Icons.refresh, size: 16),
                        label: const Text(
                          "Book Again",
                          style: TextStyle(fontSize: 12),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.deepPurple,
                          side: const BorderSide(color: Colors.deepPurple),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _rateService(booking),
                        icon: const Icon(Icons.star_outline, size: 16),
                        label: const Text(
                          "Rate Service",
                          style: TextStyle(fontSize: 12),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.orange,
                          side: const BorderSide(color: Colors.orange),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  IconData _getServiceIcon(String serviceType) {
    final type = serviceType.toLowerCase();
    if (type.contains('plumb')) return Icons.plumbing;
    if (type.contains('electric')) return Icons.electrical_services;
    if (type.contains('carpen') || type.contains('wood')) return Icons.handyman;
    if (type.contains('child') || type.contains('care'))
      return Icons.child_care;
    if (type.contains('maid') || type.contains('clean'))
      return Icons.cleaning_services;
    if (type.contains('cook') || type.contains('food')) return Icons.restaurant;
    if (type.contains('laund') || type.contains('wash'))
      return Icons.local_laundry_service;
    return Icons.home_repair_service;
  }

  Color _getServiceColor(String serviceType) {
    final type = serviceType.toLowerCase();
    if (type.contains('plumb')) return Colors.blue;
    if (type.contains('electric')) return Colors.amber;
    if (type.contains('carpen')) return Colors.brown;
    if (type.contains('child')) return Colors.pink;
    if (type.contains('maid')) return Colors.purple;
    if (type.contains('cook')) return Colors.orange;
    if (type.contains('laund')) return Colors.cyan;
    return Colors.grey;
  }

  String _getStatusText(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'Pending';
      case 'confirmed':
        return 'Confirmed';
      case 'in_progress':
        return 'In Progress';
      case 'completed':
        return 'Completed';
      case 'cancelled':
        return 'Cancelled';
      default:
        return status;
    }
  }

  Color _statusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'confirmed':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'in_progress':
        return Colors.blue;
      case 'completed':
        return Colors.green.shade600;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  void _rateService(Map<String, dynamic> booking) {
    final bookingId = booking['id'];
    final workerId = booking['workerId'];

    if (bookingId != null && workerId != null) {
      Navigator.pushNamed(
        context,
        CustomerBookingReviewScreen.routeName,
        arguments: {'bookingId': bookingId, 'workerId': workerId},
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Missing booking or worker info.")),
      );
    }
  }
}
