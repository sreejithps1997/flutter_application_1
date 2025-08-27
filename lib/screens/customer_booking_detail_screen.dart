import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../widgets/custom_button.dart';
import '../widgets/star_rating.dart';
import 'customer_reschedule_screen.dart';
import 'chat_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import '../utils/string_utils.dart'; // for safeInitials()
import '../services/booking_flow.dart'; // you already have this elsewhere

class CustomerBookingDetailScreen extends StatelessWidget {
  static const routeName = '/customer-booking-detail';

  final Map<String, dynamic> booking;

  const CustomerBookingDetailScreen({super.key, required this.booking});

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
      await FirebaseFirestore.instance
          .collection('bookings')
          .doc(bookingId)
          .update({'status': 'cancelled'});

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

  @override
  Widget build(BuildContext context) {
    final status = booking['status'] ?? 'pending';
    final bookingId = booking['id'] ?? '';
    final bool isCompleted = status.toLowerCase() == 'completed';

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          "Booking Details",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Booking Overview Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
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
                          color: _statusColor(status).withOpacity(0.1),
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
                    color: Colors.grey.withOpacity(0.1),
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
                onPressed: () {
                  final workerId = booking['workerId'];
                  final workerName = booking['workerName'];
                  if (workerId != null && workerName != null) {
                    Navigator.pushNamed(
                      context,
                      ChatScreen.routeName,
                      arguments: {
                        'chatWithId': workerId,
                        'chatWithName': workerName,
                        'userRole': 'customer',
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
                    color: Colors.grey.withOpacity(0.1),
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

            // Payment Details - Only show if completed
            if (isCompleted) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
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
                          color: Colors.grey.withOpacity(0.1),
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
      case 'completed':
        return Icons.check_circle_outline;
      case 'reschedule_requested':
        return Icons.schedule_outlined;
      default:
        return Icons.help_outline;
    }
  }
}
