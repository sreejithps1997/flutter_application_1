import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../core/theme/workable_design.dart';
import 'customer_booking_detail_screen.dart';
import 'customer_booking_review_screen.dart';
import '../services/booking_flow.dart';
import '../widgets/booking_status_timeline.dart';
import '../widgets/workable_ui.dart';

class CustomerBookingsScreen extends StatefulWidget {
  static const routeName = '/customer-bookings';
  // Also support booking history route
  static const bookingHistoryRoute = '/customer/booking-history';

  //const CustomerBookingsScreen({super.key});
  final int initialTab;
  const CustomerBookingsScreen({super.key, this.initialTab = 0});

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
    // _tabController = TabController(length: 3, vsync: this);
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTab,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: WorkableDesign.canvas,
      appBar: AppBar(
        title: const Text("My Bookings"),
        backgroundColor: WorkableDesign.surface,
        foregroundColor: WorkableDesign.ink,
        bottom: TabBar(
          controller: _tabController,
          labelColor: WorkableDesign.primary,
          unselectedLabelColor: WorkableDesign.muted,
          indicatorColor: WorkableDesign.primary,
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
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: WorkablePageHeader(
                    title: 'Track every job',
                    subtitle:
                        'Review active work, payment progress, completed services, and past booking history.',
                    icon: Icons.event_note_outlined,
                    trailing: IconButton.filledTonal(
                      tooltip: 'Refresh',
                      onPressed: () => setState(() {}),
                      icon: const Icon(Icons.refresh),
                    ),
                  ),
                ),
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
    return WorkableEmptyState(
      icon: Icons.login,
      title: 'Please log in',
      message: 'You need to log in to view your bookings.',
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
                  selectedColor: WorkableDesign.primary.withValues(alpha: 0.1),
                  checkmarkColor: WorkableDesign.primary,
                  backgroundColor: WorkableDesign.surface,
                  side: BorderSide(
                    color: isSelected
                        ? WorkableDesign.primary.withValues(alpha: 0.35)
                        : WorkableDesign.border,
                  ),
                  labelStyle: TextStyle(
                    color: isSelected
                        ? WorkableDesign.primary
                        : WorkableDesign.ink,
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
    return const WorkableEmptyState(
      icon: Icons.error_outline,
      title: 'Something went wrong',
      message: 'Unable to load your bookings. Please try again later.',
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

    return WorkableEmptyState(
      icon: icon,
      title: title,
      message: description,
      actionLabel: 'Book a Service',
      onAction: () => Navigator.pushNamed(context, '/book-service'),
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
    final amount = _readAmount(booking['totalAmount'] ?? booking['amount']);
    Future<void> precheckThenOpenDetails() async {
      final workerId = (booking['workerId'] as String?)?.trim();

      if (workerId != null && workerId.isNotEmpty) {
        try {
          final snap = await FirebaseFirestore.instance
              .collection('workers')
              .doc(workerId)
              .get();

          if (!context.mounted) return;

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
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Could not verify worker availability. Opening details...',
              ),
            ),
          );
        }
      }

      if (!context.mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CustomerBookingDetailScreen(booking: booking),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: WorkableDesign.cardDecoration(),
      child: InkWell(
        borderRadius: BorderRadius.circular(WorkableDesign.radius),
        onTap: precheckThenOpenDetails,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: _getServiceColor(
                            serviceType,
                          ).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(
                            WorkableDesign.radius,
                          ),
                        ),
                        child: Icon(
                          _getServiceIcon(serviceType),
                          color: _getServiceColor(serviceType),
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              serviceType,
                              style: const TextStyle(
                                color: WorkableDesign.ink,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 6),
                            WorkableStatusPill(
                              label: _getStatusText(status),
                              color: _statusColor(status),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right,
                        color: WorkableDesign.muted,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (workerName.isNotEmpty)
                    WorkableInfoRow(
                      icon: Icons.engineering_outlined,
                      text: 'Worker: $workerName',
                    ),
                  WorkableInfoRow(
                    icon: Icons.calendar_today_outlined,
                    text: 'Date: ${booking['preferredDate'] ?? 'N/A'}',
                  ),
                  WorkableInfoRow(
                    icon: Icons.schedule_outlined,
                    text: 'Time: ${booking['preferredTime'] ?? 'N/A'}',
                  ),
                  if (amount > 0)
                    WorkableInfoRow(
                      icon: Icons.payments_outlined,
                      text: 'Amount: Rs ${amount.toStringAsFixed(0)}',
                    ),
                  const SizedBox(height: 12),
                  BookingStatusTimeline(status: status, compact: true),
                ],
              ),
            ),

            // Quick actions for completed bookings (unchanged)
            if (status.toLowerCase() == 'completed') ...[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: WorkableDesign.canvas,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(WorkableDesign.radius),
                    bottomRight: Radius.circular(WorkableDesign.radius),
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
                          foregroundColor: WorkableDesign.primary,
                          side: const BorderSide(color: WorkableDesign.border),
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
                          foregroundColor: WorkableDesign.warning,
                          side: const BorderSide(color: WorkableDesign.border),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (status.toLowerCase() == 'completion_requested') ...[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: WorkableDesign.warning.withValues(alpha: 0.08),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(WorkableDesign.radius),
                    bottomRight: Radius.circular(WorkableDesign.radius),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.help_outline,
                      color: WorkableDesign.warning,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        "Confirm if the work is completed",
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                CustomerBookingDetailScreen(booking: booking),
                          ),
                        );
                      },
                      child: const Text("Review"),
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
    if (type.contains('child') || type.contains('care')) {
      return Icons.child_care;
    }
    if (type.contains('maid') || type.contains('clean')) {
      return Icons.cleaning_services;
    }
    if (type.contains('cook') || type.contains('food')) return Icons.restaurant;
    if (type.contains('laund') || type.contains('wash')) {
      return Icons.local_laundry_service;
    }
    return Icons.home_repair_service;
  }

  Color _getServiceColor(String serviceType) {
    final type = serviceType.toLowerCase();
    if (type.contains('plumb')) return WorkableDesign.primary;
    if (type.contains('electric')) return WorkableDesign.warning;
    if (type.contains('carpen')) return WorkableDesign.accent;
    if (type.contains('child')) return const Color(0xFFDB2777);
    if (type.contains('maid') || type.contains('clean')) {
      return WorkableDesign.success;
    }
    if (type.contains('cook')) return const Color(0xFFEA580C);
    if (type.contains('laund')) return const Color(0xFF0891B2);
    return WorkableDesign.muted;
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
      case 'completion_requested':
        return 'Confirm Work?';
      case 'payment_due':
        return 'Payment Due';
      case 'payment_initiated':
        return 'Payment Started';
      case 'payment_under_review':
        return 'Payment Review';
      case 'completion_disputed':
        return 'Issue Reported';
      case 'cancelled':
        return 'Cancelled';
      default:
        return status;
    }
  }

  Color _statusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'confirmed':
        return WorkableDesign.success;
      case 'pending':
        return WorkableDesign.warning;
      case 'in_progress':
        return WorkableDesign.primary;
      case 'completed':
        return WorkableDesign.success;
      case 'completion_requested':
        return WorkableDesign.warning;
      case 'payment_due':
      case 'payment_initiated':
      case 'payment_under_review':
        return WorkableDesign.primary;
      case 'completion_disputed':
        return WorkableDesign.danger;
      case 'cancelled':
        return WorkableDesign.danger;
      default:
        return WorkableDesign.muted;
    }
  }

  num _readAmount(dynamic value) {
    if (value is num) return value;
    if (value is String) return num.tryParse(value) ?? 0;
    return 0;
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
