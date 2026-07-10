import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../core/theme/workable_design.dart';
import '../widgets/workable_ui.dart';
import 'customer_booking_review_screen.dart';

class MyReviewsScreen extends StatefulWidget {
  static const routeName = '/my-reviews';

  const MyReviewsScreen({super.key});

  @override
  State<MyReviewsScreen> createState() => _MyReviewsScreenState();
}

class _MyReviewsScreenState extends State<MyReviewsScreen> {
  final _dateFormat = DateFormat('dd MMM yyyy');

  String activeFilter = 'all';
  String searchQuery = '';

  Stream<QuerySnapshot<Map<String, dynamic>>> _reviewsStream(String uid) {
    return FirebaseFirestore.instance
        .collection('reviews')
        .where('customerId', isEqualTo: uid)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _bookingsStream(String uid) {
    return FirebaseFirestore.instance
        .collection('bookings')
        .where('customerId', isEqualTo: uid)
        .snapshots();
  }

  DateTime _dateFrom(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value) ?? DateTime(1970);
    return DateTime(1970);
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _sortedReviews(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    final docs = snapshot.docs.toList();
    docs.sort((a, b) {
      final ad = _dateFrom(a.data()['timestamp'] ?? a.data()['createdAt']);
      final bd = _dateFrom(b.data()['timestamp'] ?? b.data()['createdAt']);
      return bd.compareTo(ad);
    });
    return docs;
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _pendingBookings(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    final docs = snapshot.docs.where((doc) {
      final data = doc.data();
      final status = data['status']?.toString().toLowerCase();
      final hasReview = data['hasReview'] == true || data['rating'] != null;
      return status == 'completed' && !hasReview;
    }).toList();

    docs.sort((a, b) {
      final ad = _dateFrom(a.data()['completedAt'] ?? a.data()['updatedAt']);
      final bd = _dateFrom(b.data()['completedAt'] ?? b.data()['updatedAt']);
      return bd.compareTo(ad);
    });
    return docs;
  }

  bool _matchesSearch(Map<String, dynamic> data, String id) {
    final query = searchQuery.trim().toLowerCase();
    if (query.isEmpty) return true;

    final values = [
      id,
      data['workerName'],
      data['service'],
      data['issue'],
      data['review'],
      data['bookingId'],
    ].whereType<Object>().map((value) => value.toString().toLowerCase());

    return values.any((value) => value.contains(query));
  }

  bool _matchesFilter(Map<String, dynamic> data) {
    final rating = (data['rating'] as num?)?.round() ?? 0;
    final createdAt = _dateFrom(data['timestamp'] ?? data['createdAt']);

    switch (activeFilter) {
      case 'recent':
        return DateTime.now().difference(createdAt).inDays <= 30;
      case '5star':
        return rating == 5;
      case '4star':
        return rating == 4;
      case '3star':
        return rating == 3;
      case 'pending':
        return false;
      default:
        return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: WorkableDesign.canvas,
      appBar: AppBar(title: const Text("My Reviews"), leading: BackButton()),
      body: user == null
          ? _emptyState('Sign in to view your reviews')
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _reviewsStream(user.uid),
              builder: (context, reviewSnapshot) {
                if (reviewSnapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (reviewSnapshot.hasError) {
                  return _emptyState('Unable to load reviews');
                }

                return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _bookingsStream(user.uid),
                  builder: (context, bookingSnapshot) {
                    if (!bookingSnapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final reviews = _sortedReviews(reviewSnapshot.data!);
                    final pending = _pendingBookings(bookingSnapshot.data!);
                    final visibleReviews = reviews.where((doc) {
                      final data = doc.data();
                      return _matchesFilter(data) &&
                          _matchesSearch(data, doc.id);
                    }).toList();

                    return ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        const WorkablePageHeader(
                          title: 'Your service feedback',
                          subtitle:
                              'Track reviews you gave, edit feedback, and complete pending ratings after finished jobs.',
                          icon: LucideIcons.star,
                        ),
                        const SizedBox(height: 16),
                        _buildStats(reviews, pending),
                        const SizedBox(height: 20),
                        _buildSearch(),
                        const SizedBox(height: 12),
                        _buildFilters(reviews, pending),
                        const SizedBox(height: 20),
                        if (activeFilter == 'all' && pending.isNotEmpty) ...[
                          const Text(
                            "Pending Reviews",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ...pending.take(3).map(_buildPendingReview),
                          const SizedBox(height: 20),
                        ],
                        Text(
                          activeFilter == 'pending'
                              ? "Pending Reviews"
                              : "Your Reviews",
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (activeFilter == 'pending')
                          pending.isEmpty
                              ? _emptyState('No pending reviews')
                              : Column(
                                  children: pending
                                      .map(_buildPendingReview)
                                      .toList(),
                                )
                        else
                          visibleReviews.isEmpty
                              ? _emptyState('No reviews found')
                              : Column(
                                  children: visibleReviews
                                      .map(_buildReviewCard)
                                      .toList(),
                                ),
                        const SizedBox(height: 20),
                        _buildGuidelines(),
                      ],
                    );
                  },
                );
              },
            ),
    );
  }

  Widget _buildStats(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> reviews,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> pending,
  ) {
    final ratings = reviews
        .map((doc) => doc.data()['rating'])
        .whereType<num>()
        .map((rating) => rating.toDouble())
        .toList();
    final average = ratings.isEmpty
        ? 0.0
        : ratings.reduce((a, b) => a + b) / ratings.length;
    final recentCount = reviews.where((doc) {
      final createdAt = _dateFrom(doc.data()['timestamp']);
      return DateTime.now().difference(createdAt).inDays <= 30;
    }).length;

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _buildStatsCard(
          reviews.length,
          'Total Reviews',
          WorkableDesign.primary,
          LucideIcons.star,
        ),
        _buildStatsCard(
          average.toStringAsFixed(1),
          'Avg Rating',
          WorkableDesign.warning,
          LucideIcons.star,
        ),
        _buildStatsCard(
          pending.length,
          'Pending',
          WorkableDesign.success,
          LucideIcons.clock,
        ),
        _buildStatsCard(
          recentCount,
          'This Month',
          WorkableDesign.accent,
          LucideIcons.calendar,
        ),
      ],
    );
  }

  Widget _buildStatsCard(
    Object number,
    String label,
    Color color,
    IconData icon,
  ) {
    return Container(
      width: (MediaQuery.of(context).size.width / 2) - 26,
      height: 90,
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: WorkableDesign.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: WorkableDesign.border),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 6),
          Text(
            '$number',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: color,
            ),
          ),
          Text(label, style: const TextStyle(fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildSearch() {
    return TextField(
      decoration: InputDecoration(
        hintText: 'Search reviews...',
        prefixIcon: const Icon(Icons.search, color: Colors.grey),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
      onChanged: (value) => setState(() => searchQuery = value),
    );
  }

  Widget _buildFilters(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> reviews,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> pending,
  ) {
    final options = [
      ('all', 'All Reviews', reviews.length),
      (
        'recent',
        'Recent',
        reviews.where((doc) {
          final createdAt = _dateFrom(doc.data()['timestamp']);
          return DateTime.now().difference(createdAt).inDays <= 30;
        }).length,
      ),
      (
        '5star',
        '5 Star',
        reviews.where((doc) => (doc.data()['rating'] as num?) == 5).length,
      ),
      (
        '4star',
        '4 Star',
        reviews.where((doc) => (doc.data()['rating'] as num?) == 4).length,
      ),
      (
        '3star',
        '3 Star',
        reviews.where((doc) => (doc.data()['rating'] as num?) == 3).length,
      ),
      ('pending', 'Pending', pending.length),
    ];

    return SizedBox(
      height: 38,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: options
            .map(
              (filter) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text("${filter.$2} (${filter.$3})"),
                  selected: activeFilter == filter.$1,
                  onSelected: (_) => setState(() => activeFilter = filter.$1),
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildReviewCard(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final review = doc.data();
    final rating = (review['rating'] as num?)?.round() ?? 0;
    final bookingId = review['bookingId']?.toString() ?? doc.id;
    final workerId = review['workerId']?.toString() ?? '';
    final createdAt = _dateFrom(review['timestamp']);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: WorkableDesign.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: WorkableDesign.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: WorkableDesign.primary,
                child: Text(
                  _initials(review['workerName']),
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      review['workerName']?.toString() ?? 'Worker',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      review['service']?.toString() ?? 'Service booking',
                      style: const TextStyle(
                        fontSize: 12,
                        color: WorkableDesign.muted,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'edit') _openReview(bookingId, workerId);
                  if (value == 'delete') _deleteReview(bookingId);
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'edit', child: Text('Edit')),
                  PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: List.generate(5, (i) {
                  return Icon(
                    Icons.star,
                    color: i < rating ? Colors.amber : Colors.grey[300],
                    size: 18,
                  );
                }),
              ),
              Text(
                createdAt.year == 1970 ? '' : _dateFormat.format(createdAt),
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if ((review['review']?.toString() ?? '').isNotEmpty)
            Text(review['review'].toString()),
          if (review['tags'] is List && (review['tags'] as List).isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Wrap(
                spacing: 8,
                runSpacing: 6,
                children: (review['tags'] as List)
                    .map((tag) => Chip(label: Text(tag.toString())))
                    .toList(),
              ),
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              TextButton.icon(
                onPressed: () => _openReview(bookingId, workerId),
                icon: const Icon(LucideIcons.edit3, size: 16),
                label: const Text("Edit", style: TextStyle(fontSize: 12)),
              ),
              TextButton.icon(
                onPressed: () => _deleteReview(bookingId),
                icon: const Icon(LucideIcons.trash2, size: 16),
                label: const Text("Delete", style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPendingReview(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final booking = doc.data();
    final workerId = booking['workerId']?.toString() ?? '';
    final updatedAt = _dateFrom(
      booking['completedAt'] ?? booking['updatedAt'] ?? booking['createdAt'],
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: WorkableDesign.warning.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: WorkableDesign.warning.withValues(alpha: 0.30),
        ),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            backgroundColor: WorkableDesign.warning,
            child: Icon(LucideIcons.clock, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  booking['workerName']?.toString() ?? 'Worker',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  booking['serviceType']?.toString() ??
                      booking['issue']?.toString() ??
                      'Service booking',
                  style: const TextStyle(
                    fontSize: 12,
                    color: WorkableDesign.muted,
                  ),
                ),
                if (updatedAt.year != 1970)
                  Text(
                    'Completed on ${_dateFormat.format(updatedAt)}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: WorkableDesign.muted,
                    ),
                  ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: workerId.isEmpty
                ? null
                : () => _openReview(doc.id, workerId),
            style: ElevatedButton.styleFrom(
              backgroundColor: WorkableDesign.warning,
            ),
            child: const Text("Write"),
          ),
        ],
      ),
    );
  }

  Widget buildLegacyGuidelines() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.withValues(alpha: 0.20)),
      ),
      padding: const EdgeInsets.all(16),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Review Guidelines",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.blueAccent,
            ),
          ),
          SizedBox(height: 8),
          Text("• Be honest and constructive in your feedback"),
          Text("• Focus on service quality and professionalism"),
          Text("• You can edit or delete your submitted reviews"),
        ],
      ),
    );
  }

  Widget _buildGuidelines() {
    return Container(
      decoration: BoxDecoration(
        color: WorkableDesign.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: WorkableDesign.primary.withValues(alpha: 0.20),
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Review Guidelines',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: WorkableDesign.primary,
            ),
          ),
          SizedBox(height: 8),
          Text('- Be honest and constructive in your feedback'),
          Text('- Focus on service quality and professionalism'),
          Text('- You can edit or delete your submitted reviews'),
        ],
      ),
    );
  }

  Future<void> _deleteReview(String bookingId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete review?'),
        content: const Text('This will remove your review from the booking.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await FirebaseFirestore.instance
          .collection('reviews')
          .doc(bookingId)
          .delete();
      await FirebaseFirestore.instance
          .collection('bookings')
          .doc(bookingId)
          .set({
            'hasReview': false,
            'rating': FieldValue.delete(),
            'reviewTags': FieldValue.delete(),
          }, SetOptions(merge: true));

      if (!mounted) return;
      _showSnack('Review deleted');
    } catch (_) {
      if (!mounted) return;
      _showSnack('Unable to delete review');
    }
  }

  void _openReview(String bookingId, String workerId) {
    if (bookingId.isEmpty || workerId.isEmpty) {
      _showSnack('Missing booking or worker details');
      return;
    }

    Navigator.pushNamed(
      context,
      CustomerBookingReviewScreen.routeName,
      arguments: {'bookingId': bookingId, 'workerId': workerId},
    );
  }

  Widget _emptyState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.star, color: Colors.grey.shade500, size: 38),
            const SizedBox(height: 10),
            Text(message, style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  String _initials(dynamic value) {
    final name = value?.toString().trim() ?? '';
    if (name.isEmpty) return 'W';
    final parts = name.split(RegExp(r'\s+'));
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }
}
