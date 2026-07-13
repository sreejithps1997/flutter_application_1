import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../widgets/custom_button.dart';
import '../widgets/star_rating.dart';
import 'customer_reschedule_screen.dart';
import 'chat_screen.dart';
import '../utils/string_utils.dart'; // for safeInitials()
import '../services/booking_flow.dart'; // you already have this elsewhere
import '../services/chat_service.dart';
import '../widgets/booking_status_timeline.dart';
import '../core/theme/workable_design.dart';
import '../features/bookings/data/booking_action_repository.dart';
import 'customer_payment_screen.dart';

class CustomerBookingDetailScreen extends StatelessWidget {
  static const routeName = '/customer-booking-detail';

  final Map<String, dynamic> booking;

  const CustomerBookingDetailScreen({super.key, required this.booking});

  String? _firstTextValue(List<String> keys) {
    for (final key in keys) {
      final value = booking[key]?.toString().trim();
      if (value != null && value.isNotEmpty && value.toLowerCase() != 'null') {
        return value;
      }
    }
    return null;
  }

  double? _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  DateTime? _timestampToDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    return null;
  }

  String _formatDateTime(DateTime value) {
    final hour = value.hour > 12
        ? value.hour - 12
        : value.hour == 0
        ? 12
        : value.hour;
    final minute = value.minute.toString().padLeft(2, '0');
    final period = value.hour >= 12 ? 'PM' : 'AM';
    return '${value.day}/${value.month}/${value.year} $hour:$minute $period';
  }

  String _formatDistance(double meters) {
    if (meters < 1000) return '${meters.toStringAsFixed(0)} m';
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }

  Future<Map<String, dynamic>?> _loadWorker(String workerId) async {
    final doc = await FirebaseFirestore.instance
        .collection('workers')
        .doc(workerId)
        .get();
    return doc.data();
  }

  void _confirmCancel(BuildContext context, String bookingId) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          "Cancel Booking?",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        content: const Text(
          "Are you sure you want to cancel this booking?",
          style: TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("No", style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _cancelBooking(context, bookingId);
            },
            child: const Text("Yes", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _cancelBooking(BuildContext context, String bookingId) async {
    try {
      await BookingActionRepository().cancelBooking(bookingId);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("Booking has been cancelled."),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("Error cancelling booking."),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    }
  }

  Future<void> _confirmWorkCompleted(
    BuildContext context,
    String bookingId,
  ) async {
    try {
      await BookingActionRepository().confirmCustomerCompletion(bookingId);

      if (!context.mounted) return;
      Navigator.pushNamed(
        context,
        CustomerPaymentScreen.routeName,
        arguments: bookingId,
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Unable to confirm completion.")),
      );
    }
  }

  Future<void> _confirmWorkerArrivedAndStart(
    BuildContext context,
    String bookingId,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Start Work?"),
        content: const Text(
          "Use this only when the worker is physically at your service location but cannot start from their phone because of GPS, network, or device issues. This starts verified work time.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text("Cancel"),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text("Worker Arrived"),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await BookingActionRepository().customerConfirmWorkerArrived(bookingId);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Work started after your confirmation."),
          backgroundColor: WorkableDesign.success,
        ),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Unable to start work right now.")),
      );
    }
  }

  Future<void> _reportCompletionIssue(
    BuildContext context,
    String bookingId,
  ) async {
    final reasonController = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Report an Issue"),
        content: TextField(
          controller: reasonController,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: "Tell us what is not completed or what went wrong",
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () =>
                Navigator.pop(dialogContext, reasonController.text.trim()),
            child: const Text("Submit"),
          ),
        ],
      ),
    );
    reasonController.dispose();

    if (reason == null || reason.isEmpty) return;

    try {
      await BookingActionRepository().disputeCompletion(
        bookingId,
        reason: reason,
      );

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Issue reported to support.")),
      );
      Navigator.pop(context);
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Unable to report issue.")));
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = booking['status'] ?? 'pending';
    final bookingId = booking['id'] ?? '';
    final statusText = status.toString().toLowerCase();
    final paymentStatus = (booking['paymentStatus'] ?? '')
        .toString()
        .toLowerCase();
    final bool isCompleted =
        statusText == 'completed' ||
        statusText == 'paid' ||
        paymentStatus == 'paid';
    final bool needsCompletionConfirmation =
        statusText == 'completion_requested';
    final bool hasPaymentState =
        {
          'payment_due',
          'payment_initiated',
          'payment_under_review',
          'completed',
          'paid',
        }.contains(statusText) ||
        {
          'customer_reported_paid',
          'cash_pending_confirmation',
          'payment_under_review',
          'payment_rejected',
          'paid',
        }.contains(paymentStatus);

    return Scaffold(
      backgroundColor: WorkableDesign.canvas,
      appBar: AppBar(
        title: const Text(
          "Booking Details",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(WorkableDesign.pagePadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Booking Overview Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: WorkableDesign.surface,
                borderRadius: BorderRadius.circular(WorkableDesign.radius),
                border: Border.all(color: WorkableDesign.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header with Service Name and Status
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Service Request",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: _statusColor(status).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _statusIcon(status),
                              size: 16,
                              color: _statusColor(status),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              status.toUpperCase(),
                              style: TextStyle(
                                color: _statusColor(status),
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Date and Time in Grid
                  Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Icon(
                              Icons.calendar_today_outlined,
                              size: 20,
                              color: Colors.blue[600],
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Date",
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                Text(
                                  booking['preferredDate'] ?? "N/A",
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Row(
                          children: [
                            Icon(
                              Icons.access_time_outlined,
                              size: 20,
                              color: Colors.blue[600],
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Time",
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                Text(
                                  booking['preferredTime'] ?? "N/A",
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Address
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.location_on_outlined,
                        size: 20,
                        color: Colors.blue[600],
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Address",
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                            Text(
                              booking['address'] ?? "N/A",
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Service Provider Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Service Provider",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 16),

                  // Row(
                  //   mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  //   children: [
                  //     Row(
                  //       children: [
                  //         // ✅ Clickable profile avatar
                  //         InkWell(
                  //           onTap: () {
                  //             final workerId = booking['workerId'];
                  //             if (workerId != null) {
                  //               Navigator.pushNamed(
                  //                 context,
                  //                 '/worker-profile',
                  //                 arguments: {'workerId': workerId},
                  //               );
                  //             }
                  //           },
                  //           child: CircleAvatar(
                  //             radius: 24,
                  //             backgroundColor: Colors.blue[600],
                  //             child: Text(
                  //               (booking['workerName'] ?? 'N/A')
                  //                   .substring(0, 2)
                  //                   .toUpperCase(),
                  //               style: const TextStyle(
                  //                 color: Colors.white,
                  //                 fontWeight: FontWeight.w600,
                  //               ),
                  //             ),
                  //           ),
                  //         ),
                  //         const SizedBox(width: 16),
                  //         Column(
                  //           crossAxisAlignment: CrossAxisAlignment.start,
                  //           children: [
                  //             Text(
                  //               booking['workerName'] ?? "N/A",
                  //               style: const TextStyle(
                  //                 fontSize: 16,
                  //                 fontWeight: FontWeight.w600,
                  //               ),
                  //             ),
                  //             Row(
                  //               children: [
                  //                 Icon(
                  //                   Icons.star,
                  //                   size: 16,
                  //                   color: Colors.yellow[600],
                  //                 ),
                  //                 const SizedBox(width: 4),
                  //                 // Text(
                  //                 //   "4.8 (127 reviews)",
                  //                 //   style: TextStyle(
                  //                 //     fontSize: 14,
                  //                 //     color: Colors.grey[600],
                  //                 //   ),
                  //                 // ),
                  //                 FutureBuilder<DocumentSnapshot>(
                  //                   future: FirebaseFirestore.instance
                  //                       .collection('workers')
                  //                       .doc(booking['workerId'])
                  //                       .get(),
                  //                   builder: (context, snapshot) {
                  //                     if (snapshot.connectionState ==
                  //                         ConnectionState.waiting) {
                  //                       return const Text("Loading...");
                  //                     }

                  //                     if (!snapshot.hasData ||
                  //                         !snapshot.data!.exists) {
                  //                       return const Text(
                  //                         "No rating yet",
                  //                         style: TextStyle(
                  //                           fontSize: 14,
                  //                           color: Colors.grey,
                  //                         ),
                  //                       );
                  //                     }

                  //                     final data =
                  //                         snapshot.data!.data()
                  //                             as Map<String, dynamic>;
                  //                     final double rating =
                  //                         (data['averageRating'] ?? 0)
                  //                             .toDouble();
                  //                     final int reviews =
                  //                         (data['reviewCount'] ?? 0);

                  //                     return Text(
                  //                       "${rating.toStringAsFixed(1)} ($reviews reviews)",
                  //                       style: TextStyle(
                  //                         fontSize: 14,
                  //                         color: Colors.grey[600],
                  //                       ),
                  //                     );
                  //                   },
                  //                 ),
                  //               ],
                  //             ),
                  //           ],
                  //         ),
                  //       ],
                  //     ),
                  //     // ✅ Clickable call icon
                  //     // InkWell(
                  //     //   onTap: () async {
                  //     //     final workerId = booking['workerId'];
                  //     //     if (workerId == null) {
                  //     //       ScaffoldMessenger.of(context).showSnackBar(
                  //     //         const SnackBar(
                  //     //           content: Text("Worker ID not available."),
                  //     //         ),
                  //     //       );
                  //     //       return;
                  //     //     }
                  //     //     try {
                  //     //       final workerDoc = await FirebaseFirestore.instance
                  //     //           .collection('workers')
                  //     //           .doc(workerId)
                  //     //           .get();
                  //     //       if (!workerDoc.exists) {
                  //     //         ScaffoldMessenger.of(context).showSnackBar(
                  //     //           const SnackBar(
                  //     //             content: Text("Worker not found."),
                  //     //           ),
                  //     //         );
                  //     //         return;
                  //     //       }
                  //     //       final workerData = workerDoc.data();
                  //     //       final phone =
                  //     //           workerData?['phone'] ??
                  //     //           workerData?['phoneNumber'];
                  //     //       if (phone != null &&
                  //     //           phone.toString().trim().isNotEmpty) {
                  //     //         final Uri callUri = Uri(
                  //     //           scheme: 'tel',
                  //     //           path: phone,
                  //     //         );
                  //     //         if (await canLaunchUrl(callUri)) {
                  //     //           await launchUrl(callUri);
                  //     //         } else {
                  //     //           ScaffoldMessenger.of(context).showSnackBar(
                  //     //             const SnackBar(
                  //     //               content: Text("Cannot place call."),
                  //     //             ),
                  //     //           );
                  //     //         }
                  //     //       } else {
                  //     //         ScaffoldMessenger.of(context).showSnackBar(
                  //     //           const SnackBar(
                  //     //             content: Text("Phone number not available."),
                  //     //           ),
                  //     //         );
                  //     //       }
                  //     //     } catch (e) {
                  //     //       ScaffoldMessenger.of(context).showSnackBar(
                  //     //         const SnackBar(
                  //     //           content: Text("Error fetching worker info."),
                  //     //         ),
                  //     //       );
                  //     //     }
                  //     //   },
                  //     //   child: Container(
                  //     //     padding: const EdgeInsets.all(12),
                  //     //     decoration: BoxDecoration(
                  //     //       color: Colors.blue[50],
                  //     //       borderRadius: BorderRadius.circular(24),
                  //     //     ),
                  //     //     child: Icon(
                  //     //       Icons.phone_outlined,
                  //     //       size: 20,
                  //     //       color: Colors.blue[600],
                  //     //     ),
                  //     //   ),
                  //     // ),
                  //   ],
                  // ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          // ✅ Avatar + profile open with gating
                          InkWell(
                            onTap: () => BookingFlow.openWorkerProfile(
                              context,
                              booking['workerId'],
                            ),
                            child: CircleAvatar(
                              radius: 24,
                              backgroundColor: Colors.blue[600],
                              child: Text(
                                safeInitials(
                                  booking['workerName'],
                                ), // <-- no substring crash
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // show a friendly fallback when name is missing
                              Text(
                                (booking['workerName'] ?? '')
                                        .toString()
                                        .trim()
                                        .isEmpty
                                    ? 'Worker not assigned'
                                    : booking['workerName'],
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Row(
                                children: [
                                  Icon(
                                    Icons.star,
                                    size: 16,
                                    color: Colors.yellow[600],
                                  ),
                                  const SizedBox(width: 4),
                                  // rating lookup (safe for null workerId)
                                  FutureBuilder<DocumentSnapshot>(
                                    future:
                                        (booking['workerId'] != null &&
                                            (booking['workerId'] as String)
                                                .trim()
                                                .isNotEmpty)
                                        ? FirebaseFirestore.instance
                                              .collection('workers')
                                              .doc(booking['workerId'])
                                              .get()
                                        : null,
                                    builder: (context, snapshot) {
                                      if (snapshot.connectionState ==
                                          ConnectionState.waiting) {
                                        return const Text("Loading...");
                                      }
                                      if (snapshot.data == null ||
                                          !snapshot.hasData ||
                                          !snapshot.data!.exists) {
                                        return const Text(
                                          "No rating yet",
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey,
                                          ),
                                        );
                                      }
                                      final data =
                                          snapshot.data!.data()
                                              as Map<String, dynamic>;
                                      final double rating =
                                          (data['averageRating'] ?? 0)
                                              .toDouble();
                                      final int reviews =
                                          (data['reviewCount'] ?? 0);

                                      return Text(
                                        "${rating.toStringAsFixed(1)} ($reviews reviews)",
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey[600],
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                      // (optional call icon stays commented for now)
                    ],
                  ),
                ],
              ),
            ),

            // Chat Button - show if booking is confirmed or in progress
            if (status.toLowerCase() == 'confirmed' ||
                status.toLowerCase() == 'in_progress') ...[
              const SizedBox(height: 16),
              CustomButton(
                text: "Chat with Worker",
                onPressed: () async {
                  final workerId = booking['workerId']?.toString();
                  final workerName = booking['workerName']?.toString();
                  if (workerId != null &&
                      workerId.trim().isNotEmpty &&
                      workerName != null &&
                      workerName.trim().isNotEmpty) {
                    Map<String, dynamic>? worker;
                    try {
                      worker = await _loadWorker(workerId);
                    } catch (_) {
                      worker = null;
                    }
                    if (!context.mounted) return;

                    final service =
                        _firstTextValue([
                          'service',
                          'serviceName',
                          'category',
                          'subCategory',
                          'workType',
                        ]) ??
                        worker?['service']?.toString() ??
                        worker?['profession']?.toString();
                    final rating =
                        _asDouble(worker?['averageRating']) ??
                        _asDouble(worker?['rating']);

                    try {
                      await ChatService().ensureChatForBooking(
                        otherUserId: workerId,
                        otherUserName: workerName,
                        userRole: 'customer',
                        bookingId: bookingId,
                        service: service,
                      );
                    } catch (_) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Unable to start chat right now"),
                        ),
                      );
                      return;
                    }
                    if (!context.mounted) return;

                    Navigator.pushNamed(
                      context,
                      ChatScreen.routeName,
                      arguments: {
                        'chatWithId': workerId,
                        'chatWithName': workerName,
                        'userRole': 'customer',
                        'bookingId': bookingId,
                        'workerService': service,
                        'workerRating': rating,
                      },
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Worker details not found")),
                    );
                  }
                },
              ),
            ],
            const SizedBox(height: 16),
            // Service Issue Details
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Service Details",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.build_outlined,
                        size: 20,
                        color: Colors.blue[600],
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Issue Description",
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.grey[50],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                booking['issue'] ?? "N/A",
                                style: const TextStyle(
                                  fontSize: 16,
                                  color: Colors.black87,
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
            ),

            const SizedBox(height: 16),
            BookingStatusTimeline(status: status.toString()),
            const SizedBox(height: 16),

            if (status.toLowerCase() == 'confirmed' ||
                status.toLowerCase() == 'accepted') ...[
              _buildWorkerArrivalStatusCard(booking),
              const SizedBox(height: 16),
            ],

            if (status.toLowerCase() == 'confirmed' ||
                status.toLowerCase() == 'accepted') ...[
              _buildCustomerStartWorkCard(context, bookingId),
              const SizedBox(height: 16),
            ],

            if (needsCompletionConfirmation) ...[
              _buildCompletionConfirmationCard(context, bookingId),
              const SizedBox(height: 16),
            ],

            if (status.toLowerCase() == 'payment_due') ...[
              _buildPaymentDueCard(context, bookingId),
              const SizedBox(height: 16),
            ],

            if (hasPaymentState) ...[
              _buildPaymentStatusCard(context, bookingId),
              const SizedBox(height: 16),
            ],

            // Payment Details - Only show if completed
            if (isCompleted ||
                status.toLowerCase() == 'payment_under_review' ||
                status.toLowerCase() == 'payment_initiated') ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withValues(alpha: 0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Payment Details",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Icon(
                          Icons.payment_outlined,
                          size: 20,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              booking['payment'] ?? "Cash",
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              "Payment processed securely",
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            //Show "Leave a Review" button if booking is completed and rating is null
            if (isCompleted && booking['rating'] == null) ...[
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pushNamed(
                      context,
                      '/customer-booking-review',
                      arguments: {
                        'bookingId': booking['id'],
                        'workerId': booking['workerId'],
                      },
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    "Leave a Review",
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            if (isCompleted) ...[
              FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection('reviews')
                    .doc(bookingId)
                    .get(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (!snapshot.hasData || !snapshot.data!.exists) {
                    return const SizedBox(); // No review found
                  }

                  final review = snapshot.data!.data() as Map<String, dynamic>;
                  final double rating = (review['rating'] ?? 0).toDouble();
                  final String description = review['review'] ?? '';
                  final List<dynamic> tags = review['tags'] ?? [];

                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withValues(alpha: 0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // const Text(
                        //   "Your Review",
                        //   style: TextStyle(
                        //     fontSize: 18,
                        //     fontWeight: FontWeight.w600,
                        //   ),
                        // ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              "Your Review",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            IconButton(
                              icon: Icon(
                                Icons.edit,
                                size: 20,
                                color: Colors.deepPurple,
                              ),
                              onPressed: () {
                                Navigator.pushNamed(
                                  context,
                                  '/customer-booking-review',
                                  arguments: {
                                    'bookingId': booking['id'],
                                    'workerId': booking['workerId'],
                                    'editMode': true, // 🔁 Add this flag
                                  },
                                );
                              },
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),
                        StarRating(rating: rating),
                        if (description.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Text(
                            description,
                            style: const TextStyle(fontSize: 16),
                          ),
                        ],
                        if (tags.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            children: tags.map((tag) {
                              return Chip(
                                label: Text(tag),
                                backgroundColor: Colors.grey[200],
                              );
                            }).toList(),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ],

            // Action Buttons
            if ((status.toLowerCase() == 'pending' ||
                    status.toLowerCase() == 'confirmed') &&
                booking['rating'] == null) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            CustomerRescheduleScreen(bookingId: bookingId),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[600],
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    "Reschedule Booking",
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () {
                    // Contact support functionality
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[100],
                    foregroundColor: Colors.grey[700],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    "Contact Support",
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: TextButton(
                  onPressed: () => _confirmCancel(context, bookingId),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    "Cancel Booking",
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCompletionConfirmationCard(
    BuildContext context,
    String bookingId,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFED7AA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFEDD5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.task_alt, color: Color(0xFFEA580C)),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Worker says the job is completed",
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      "Please confirm only after checking the work. Payment starts after your confirmation.",
                      style: TextStyle(color: Color(0xFF9A3412), height: 1.35),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: () => _confirmWorkCompleted(context, bookingId),
              icon: const Icon(Icons.check_circle_outline),
              label: const Text("Confirm Work Completed"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade700,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: OutlinedButton.icon(
              onPressed: () => _reportCompletionIssue(context, bookingId),
              icon: const Icon(Icons.report_problem_outlined),
              label: const Text("Report Issue"),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red.shade700,
                side: BorderSide(color: Colors.red.shade200),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerStartWorkCard(BuildContext context, String bookingId) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFDBEAFE),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.location_on_outlined,
                  color: WorkableDesign.primary,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Worker arrived?",
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      "If the worker is with you but cannot start from their phone, you can confirm arrival and start the work timer.",
                      style: TextStyle(color: Color(0xFF1E3A8A), height: 1.35),
                    ),
                    SizedBox(height: 8),
                    Text(
                      "Use only when the worker is physically present at your service location.",
                      style: TextStyle(
                        color: Color(0xFF1D4ED8),
                        fontWeight: FontWeight.w800,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: () =>
                  _confirmWorkerArrivedAndStart(context, bookingId),
              icon: const Icon(Icons.play_circle_outline),
              label: const Text("Confirm Arrival & Start Work"),
              style: ElevatedButton.styleFrom(
                backgroundColor: WorkableDesign.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkerArrivalStatusCard(Map<String, dynamic> booking) {
    final sharing = booking['workerLiveLocationSharing'] == true;
    final updatedAt = _timestampToDate(booking['workerLiveLocationUpdatedAt']);
    final distance = _asDouble(booking['workerLiveDistanceToServiceMeters']);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: WorkableDesign.accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.near_me_outlined,
                  color: WorkableDesign.accent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sharing ? "Worker is on the way" : "Arrival tracking",
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      sharing
                          ? "The worker is sharing live arrival updates."
                          : "The worker has not started live arrival sharing yet.",
                      style: const TextStyle(
                        color: WorkableDesign.muted,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (updatedAt != null || distance != null) ...[
            const SizedBox(height: 12),
            if (updatedAt != null)
              _arrivalLine(
                Icons.schedule_outlined,
                'Last updated: ${_formatDateTime(updatedAt)}',
              ),
            if (distance != null)
              _arrivalLine(
                Icons.route_outlined,
                'Approx. distance: ${_formatDistance(distance)}',
              ),
          ],
        ],
      ),
    );
  }

  Widget _arrivalLine(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          Icon(icon, size: 17, color: WorkableDesign.muted),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: WorkableDesign.muted),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentDueCard(BuildContext context, String bookingId) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Payment is due",
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          const Text(
            "Choose UPI, PhonePe, Google Pay, Paytm, or cash to finish this booking.",
            style: TextStyle(color: Color(0xFF1E3A8A), height: 1.35),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.pushNamed(
                  context,
                  CustomerPaymentScreen.routeName,
                  arguments: bookingId,
                );
              },
              icon: const Icon(Icons.payment),
              label: const Text("Continue to Payment"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade700,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentStatusCard(BuildContext context, String bookingId) {
    final status = (booking['status'] ?? '').toString().toLowerCase();
    final paymentStatus = (booking['paymentStatus'] ?? '')
        .toString()
        .toLowerCase();
    final state = _BookingPaymentState.from(booking);
    final canContinuePayment =
        status == 'payment_due' || paymentStatus == 'payment_rejected';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: state.color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(WorkableDesign.radius),
        border: Border.all(color: state.color.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(state.icon, color: state.color),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      state.title,
                      style: TextStyle(
                        color: state.color,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      state.message,
                      style: const TextStyle(
                        color: WorkableDesign.ink,
                        height: 1.35,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (canContinuePayment) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () {
                  Navigator.pushNamed(
                    context,
                    CustomerPaymentScreen.routeName,
                    arguments: bookingId,
                  );
                },
                icon: const Icon(Icons.payment),
                label: Text(
                  paymentStatus == 'payment_rejected'
                      ? 'Try Payment Again'
                      : 'Continue to Payment',
                ),
              ),
            ),
          ],
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
      case 'completion_requested':
        return Colors.deepOrange;
      case 'payment_due':
      case 'payment_initiated':
      case 'payment_under_review':
        return Colors.blue;
      case 'completion_disputed':
        return Colors.redAccent;
      case 'completed':
        return Colors.blueGrey;
      case 'reschedule_requested':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  IconData _statusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'confirmed':
        return Icons.check_circle_outline;
      case 'pending':
        return Icons.schedule_outlined;
      case 'cancelled':
        return Icons.cancel_outlined;
      case 'completion_requested':
        return Icons.help_outline;
      case 'payment_due':
      case 'payment_initiated':
      case 'payment_under_review':
        return Icons.payment;
      case 'completion_disputed':
        return Icons.report_problem_outlined;
      case 'completed':
        return Icons.check_circle_outline;
      case 'reschedule_requested':
        return Icons.schedule_outlined;
      default:
        return Icons.help_outline;
    }
  }
}

class _BookingPaymentState {
  const _BookingPaymentState({
    required this.title,
    required this.message,
    required this.color,
    required this.icon,
  });

  final String title;
  final String message;
  final Color color;
  final IconData icon;

  factory _BookingPaymentState.from(Map<String, dynamic> booking) {
    final status = (booking['status'] ?? '').toString().toLowerCase();
    final paymentStatus = (booking['paymentStatus'] ?? '')
        .toString()
        .toLowerCase();

    if (status == 'completed' || status == 'paid' || paymentStatus == 'paid') {
      return const _BookingPaymentState(
        title: 'Payment completed',
        message:
            'This booking is paid and completed. You can leave or edit your review from this page.',
        color: WorkableDesign.success,
        icon: Icons.check_circle_outline,
      );
    }

    if (paymentStatus == 'payment_rejected') {
      final reason = booking['paymentRejectionReason']?.toString().trim();
      return _BookingPaymentState(
        title: 'Payment was rejected',
        message: reason == null || reason.isEmpty
            ? 'The previous payment report could not be approved. Please try payment again or choose cash.'
            : 'The previous payment report could not be approved: $reason',
        color: WorkableDesign.danger,
        icon: Icons.error_outline,
      );
    }

    if (paymentStatus == 'cash_pending_confirmation') {
      return const _BookingPaymentState(
        title: 'Cash confirmation pending',
        message:
            'You selected cash. The worker must confirm receiving cash before this booking is completed.',
        color: WorkableDesign.warning,
        icon: Icons.payments_outlined,
      );
    }

    if (status == 'payment_under_review' ||
        paymentStatus == 'customer_reported_paid' ||
        paymentStatus == 'payment_under_review') {
      return const _BookingPaymentState(
        title: 'Payment under review',
        message:
            'Your UPI payment report is waiting for verification. Once approved, the booking becomes completed.',
        color: WorkableDesign.primary,
        icon: Icons.hourglass_top_outlined,
      );
    }

    if (status == 'payment_initiated' || paymentStatus == 'initiated') {
      return const _BookingPaymentState(
        title: 'Payment started',
        message:
            'Payment was started but not confirmed yet. Continue payment if you still need to finish it.',
        color: WorkableDesign.primary,
        icon: Icons.payment_outlined,
      );
    }

    return const _BookingPaymentState(
      title: 'Payment is due',
      message:
          'The worker completion was confirmed. Choose UPI or cash to finish this booking.',
      color: WorkableDesign.accent,
      icon: Icons.account_balance_wallet_outlined,
    );
  }
}
