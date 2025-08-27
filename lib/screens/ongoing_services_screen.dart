import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

class OngoingServicesScreen extends StatefulWidget {
  static const routeName = '/ongoing-services';
  const OngoingServicesScreen({super.key});

  @override
  State<OngoingServicesScreen> createState() => _OngoingServicesScreenState();
}

class _OngoingServicesScreenState extends State<OngoingServicesScreen> {
  String activeFilter = 'All';
  String sortBy = 'time'; // Placeholder for future sort functionality

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        leading: BackButton(color: Colors.black),
        title: const Text(
          'Ongoing Services',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('bookings')
            .where('customerId', isEqualTo: currentUserId)
            .orderBy('preferredDate')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // 🔹 Add here to check snapshot data
          final currentUserId = FirebaseAuth.instance.currentUser!.uid;
          print("Current User ID: $currentUserId");
          print("Snapshot has data? ${snapshot.hasData}");
          print("Docs length: ${snapshot.data?.docs.length}");
          snapshot.data?.docs.forEach((doc) {
            print(doc.data());
          });

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text('No bookings found.', style: TextStyle(fontSize: 16)),
            );
          }

          // Map Firestore data to a list of booking maps
          List<Map<String, dynamic>> bookings = snapshot.data!.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return {
              'id': doc.id,
              'service': data['issue'] ?? 'Service',
              'worker': {
                'name': data['workerName'] ?? 'Worker',
                'rating': (data['rating'] ?? 0).toDouble(),
                'phone': data['workerPhone'] ?? '', // optional
                'image': _getInitials(data['workerName'] ?? 'W'),
                'location': data['workerLocation'] ?? '',
              },
              'status': data['status'] ?? 'confirmed',
              'preferredDate': data['preferredDate'] ?? '',
              'preferredTime': data['preferredTime'] ?? '',
              'address': data['address'] ?? '',
              'progress': data['status'] == 'in_progress'
                  ? 50
                  : 0, // placeholder
              'lastUpdate': data['status'] == 'in_progress'
                  ? 'Service started'
                  : '',
              'canCall': true,
              'canMessage': true,
              'canTrack': data.containsKey('workerLocation'),
              'amount': data['payment'] ?? 'Cash',
            };
          }).toList();
          // 🔹 Add here to check mapped bookings
          print("Mapped bookings: $bookings");

          // Apply filter
          if (activeFilter == 'Today') {
            final today = DateTime.now();
            bookings = bookings.where((b) {
              final date = DateTime.tryParse(b['preferredDate']) ?? today;
              return date.day == today.day &&
                  date.month == today.month &&
                  date.year == today.year;
            }).toList();
          } else if (activeFilter == 'This Week') {
            final now = DateTime.now();
            final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
            final endOfWeek = startOfWeek.add(const Duration(days: 6));
            bookings = bookings.where((b) {
              final date = DateTime.tryParse(b['preferredDate']) ?? now;
              return date.isAfter(
                    startOfWeek.subtract(const Duration(days: 1)),
                  ) &&
                  date.isBefore(endOfWeek.add(const Duration(days: 1)));
            }).toList();
          }

          // Calculate dynamic stats
          final activeCount = bookings.length;
          final inProgressCount = bookings
              .where((b) => b['status'] == 'in_progress')
              .length;
          final upcomingCount = bookings
              .where((b) => b['status'] == 'confirmed')
              .length;

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              children: [
                // Quick Stats
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildStatCard('$activeCount', 'Active', Colors.blue),
                    _buildStatCard(
                      '$inProgressCount',
                      'In Progress',
                      Colors.green,
                    ),
                    _buildStatCard('$upcomingCount', 'Upcoming', Colors.orange),
                  ],
                ),
                const SizedBox(height: 16),
                // Filter bar
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Wrap(
                      spacing: 8,
                      children: [
                        _buildFilterChip('All'),
                        _buildFilterChip('Today'),
                        _buildFilterChip('This Week'),
                      ],
                    ),
                    TextButton(
                      onPressed: () {},
                      child: const Text(
                        'Sort by time',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Booking Cards
                Column(
                  children: bookings
                      .map((booking) => _buildBookingCard(context, booking))
                      .toList(),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _getInitials(String name) {
    final parts = name.split(' ');
    if (parts.length == 1) return parts[0][0];
    return '${parts[0][0]}${parts[1][0]}';
  }

  Widget _buildStatCard(String count, String label, Color color) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade100),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 2)],
        ),
        child: Column(
          children: [
            Text(
              count,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label) {
    final isActive = activeFilter == label;
    return GestureDetector(
      onTap: () {
        setState(() {
          activeFilter = label;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? Colors.blue.shade100 : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isActive ? Colors.blue : Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildBookingCard(BuildContext context, Map<String, dynamic> booking) {
    final worker = booking['worker'];
    final statusColor = _getStatusColor(booking['status']);
    final statusIcon = _getStatusIcon(booking['status']);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 1)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: statusColor,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    statusIcon,
                    const SizedBox(width: 6),
                    Text(
                      _getStatusText(booking['status']),
                      style: const TextStyle(fontSize: 13),
                    ),
                  ],
                ),
                Text(
                  booking['preferredDate'],
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Service Title & Worker
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            booking['service'],
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 16,
                                backgroundColor: Colors.purple,
                                child: Text(
                                  worker['image'],
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    worker['name'],
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      const Icon(
                                        LucideIcons.star,
                                        size: 12,
                                        color: Colors.amber,
                                      ),
                                      const SizedBox(width: 2),
                                      Text(
                                        worker['rating'].toString(),
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                      const Text(
                                        " • ",
                                        style: TextStyle(fontSize: 12),
                                      ),
                                      Text(
                                        worker['location'] ?? '',
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(LucideIcons.moreVertical),
                      onPressed: () {},
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Progress
                if (booking['status'] == 'in_progress') ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Service Progress',
                        style: TextStyle(fontSize: 13),
                      ),
                      Text(
                        '${booking['progress']}%',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: booking['progress'] / 100,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        Colors.green,
                      ),
                      minHeight: 6,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    booking['lastUpdate'],
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                  const SizedBox(height: 12),
                ],
                // Time & Address
                Row(
                  children: [
                    const Icon(LucideIcons.clock, size: 14, color: Colors.grey),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        booking['preferredTime'],
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(
                      LucideIcons.mapPin,
                      size: 14,
                      color: Colors.grey,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        booking['address'],
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(
                      LucideIcons.dollarSign,
                      size: 14,
                      color: Colors.grey,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      booking['amount'],
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.black,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Actions
                Row(
                  children: [
                    if (booking['canCall'])
                      _buildActionBtn(
                        worker['phone'],
                        LucideIcons.phone,
                        "Call",
                        Colors.green,
                      ),
                    if (booking['canMessage'])
                      _buildActionBtn(
                        worker['phone'],
                        LucideIcons.messageCircle,
                        "Message",
                        Colors.blue,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionBtn(
    String phone,
    IconData icon,
    String label,
    Color color,
  ) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        child: OutlinedButton.icon(
          icon: Icon(icon, color: color, size: 16),
          label: Text(label, style: TextStyle(fontSize: 12, color: color)),
          onPressed: () async {
            if (label == 'Call' && phone.isNotEmpty) {
              final uri = Uri(scheme: 'tel', path: phone);
              if (await canLaunchUrl(uri)) launchUrl(uri);
            } else if (label == 'Message' && phone.isNotEmpty) {
              final uri = Uri(scheme: 'sms', path: phone);
              if (await canLaunchUrl(uri)) launchUrl(uri);
            }
          },
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: color.withOpacity(0.4)),
            padding: const EdgeInsets.symmetric(vertical: 8),
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'confirmed':
        return Colors.blue.shade100;
      case 'in_progress':
        return Colors.green.shade100;
      case 'completed':
        return Colors.grey.shade200;
      case 'cancelled':
        return Colors.red.shade100;
      default:
        return Colors.grey.shade200;
    }
  }

  Icon _getStatusIcon(String status) {
    switch (status) {
      case 'confirmed':
        return const Icon(LucideIcons.clock, size: 16);
      case 'in_progress':
        return const Icon(LucideIcons.loader, size: 16);
      case 'completed':
        return const Icon(LucideIcons.checkCircle, size: 16);
      default:
        return const Icon(LucideIcons.alertCircle, size: 16);
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'confirmed':
        return 'Worker Confirmed';
      case 'in_progress':
        return 'Service in Progress';
      case 'completed':
        return 'Completed';
      case 'cancelled':
        return 'Cancelled';
      default:
        return status;
    }
  }
}
