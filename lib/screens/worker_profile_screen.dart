import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../widgets/star_rating.dart';
import 'booking_form_screen.dart';

class WorkerProfileScreen extends StatefulWidget {
  static const routeName = '/worker-profile';

  final String workerId;
  final String name;

  const WorkerProfileScreen({
    Key? key,
    required this.workerId,
    required this.name,
  }) : super(key: key);

  @override
  State<WorkerProfileScreen> createState() => _WorkerProfileScreenState();
}

class _WorkerProfileScreenState extends State<WorkerProfileScreen> {
  Map<String, dynamic>? workerData;
  List<Map<String, dynamic>> reviews = [];
  bool isFavorited = false;

  @override
  void initState() {
    super.initState();
    _loadWorkerData();
    _loadReviews();
  }

  Future<void> _loadWorkerData() async {
    final doc = await FirebaseFirestore.instance
        .collection('workers')
        .doc(widget.workerId)
        .get();
    if (doc.exists) {
      setState(() {
        workerData = doc.data();
      });
    }
  }

  Future<void> _loadReviews() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('reviews')
        .where('workerId', isEqualTo: widget.workerId)
        .get();

    setState(() {
      reviews = snapshot.docs
          .map((e) => e.data() as Map<String, dynamic>)
          .toList();
    });
  }

  Color _getColorFromName(String name) {
    final hash = name.hashCode;
    final r = (hash & 0xFF0000) >> 16;
    final g = (hash & 0x00FF00) >> 8;
    final b = (hash & 0x0000FF);
    return Color.fromARGB(255, r, g, b);
  }

  @override
  Widget build(BuildContext context) {
    if (workerData == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header with gradient background
            // Simple top bar with back button only
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back, color: Colors.black),
                    ),
                  ],
                ),
              ),
            ),

            // Profile information
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  // Profile image or initials
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: workerData!['imageUrl'] == null
                          ? _getColorFromName(
                              workerData!['name'] ?? widget.name,
                            )
                          : Colors.transparent,

                      // image: workerData!['imageUrl'] != null
                      //     ? DecorationImage(
                      //         image: NetworkImage(workerData!['imageUrl']),
                      //         fit: BoxFit.cover,
                      //       )
                      //     : null,
                    ),
                    alignment: Alignment.center,
                    child: workerData!['imageUrl'] == null
                        ? Text(
                            _getInitials(workerData!['name'] ?? widget.name),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(height: 12),

                  const SizedBox(height: 16),
                  // Name and title
                  Text(
                    workerData!['name'] ?? widget.name,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    workerData!['services'] != null
                        ? "Professional ${(workerData!['services'] as List).first}"
                        : "Service Provider",
                    style: const TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  // Location and experience
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.location_on,
                        size: 16,
                        color: Colors.grey,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        workerData!['location'] != null
                            ? "Downtown Area"
                            : "Location available",
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Icon(Icons.work, size: 16, color: Colors.grey),
                      const SizedBox(width: 4),
                      const Text(
                        "5+ years",
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Stats grid
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildStatCard(
                        icon: Icons.star,
                        iconColor: Colors.amber,
                        value: (workerData!['averageRating'] ?? 0)
                            .toStringAsFixed(1),
                        label: "${reviews.length} reviews",
                      ),
                      _buildStatCard(
                        icon: Icons.check_circle,
                        iconColor: Colors.green,
                        value: "${workerData!['completedJobsCount'] ?? 0}",
                        label: "Jobs completed",
                      ),
                      _buildStatCard(
                        icon: Icons.access_time,
                        iconColor: Colors.blue,
                        value: "2 hours",
                        label: "Response time",
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Badges
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildBadge("Top Rated", Icons.star, Colors.amber),
                      _buildBadge("Verified", Icons.verified, Colors.green),
                      _buildBadge(
                        "Fast Response",
                        Icons.access_time,
                        Colors.blue,
                      ),
                      _buildBadge("Expert", Icons.emoji_events, Colors.purple),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => BookingFormScreen(
                                  workerId: widget.workerId,
                                  workerName:
                                      workerData!['name'] ?? widget.name,
                                ),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            "Book Now",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: IconButton(
                          onPressed: () {
                            // Phone functionality
                          },
                          icon: const Icon(Icons.phone, color: Colors.grey),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: IconButton(
                          onPressed: () {
                            // Message functionality
                          },
                          icon: const Icon(Icons.message, color: Colors.grey),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // About section
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "About",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Professional service provider with years of experience. "
                          "I take pride in delivering exceptional services with attention to detail. "
                          "Fully insured and background checked for your peace of mind.",
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade700,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.currency_rupee,
                                          size: 16,
                                          color: Colors.grey,
                                        ),
                                        const SizedBox(width: 4),
                                        const Text(
                                          "Hourly Rate",
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.black87,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      "₹${workerData!['pricing'] ?? '--'}/hour",
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.calendar_today,
                                          size: 16,
                                          color: Colors.grey,
                                        ),
                                        const SizedBox(width: 4),
                                        const Text(
                                          "Availability",
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.black87,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    const Text(
                                      "Available Today",
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.green,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Services section
                  if (workerData!['services'] != null) ...[
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        "Services",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ...((workerData!['services'] as List).map<Widget>((
                      service,
                    ) {
                      return Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  service.toString(),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87,
                                  ),
                                ),
                                Text(
                                  "₹${workerData!['pricing'] ?? '--'}/hour",
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                            const Icon(Icons.chevron_right, color: Colors.grey),
                          ],
                        ),
                      );
                    }).toList()),
                    const SizedBox(height: 32),
                  ],

                  // Reviews section
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "Customer Reviews",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  reviews.isEmpty
                      ? Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            "No reviews yet.",
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey),
                          ),
                        )
                      : Column(
                          children: reviews.map((review) {
                            return Container(
                              width: double.infinity,
                              margin: const EdgeInsets.only(bottom: 16),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(
                                    color: Colors.grey.shade200,
                                  ),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            "Customer",
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.black87,
                                            ),
                                          ),
                                          Text(
                                            "2 days ago",
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey,
                                            ),
                                          ),
                                        ],
                                      ),
                                      StarRating(
                                        rating: (review['rating'] ?? 0)
                                            .toDouble(),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    review['review'] ?? '',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required Color iconColor,
    required String value,
    required String label,
  }) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: iconColor),
            const SizedBox(width: 4),
            Text(
              value,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }

  Widget _buildBadge(String text, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    } else if (parts.length == 1) {
      final word = parts[0];
      return word.length >= 2
          ? '${word[0]}${word[word.length - 1]}'.toUpperCase()
          : word[0].toUpperCase();
    }
    return 'U';
  }
}
