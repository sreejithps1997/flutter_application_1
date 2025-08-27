import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../widgets/star_rating.dart';

class CustomerReviewsScreen extends StatelessWidget {
  static const routeName = '/customer-reviews';

  const CustomerReviewsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text("My Reviews"),
        backgroundColor: Colors.deepPurple,
      ),
      body: userId == null
          ? const Center(child: Text("Please log in to view your reviews."))
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('reviews')
                  .where('customerId', isEqualTo: userId)
                  .orderBy(
                    'timestamp',
                    descending: true,
                  ) // 🔁 Ensure correct field
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final reviews = snapshot.data?.docs ?? [];

                if (reviews.isEmpty) {
                  return const Center(
                    child: Text(
                      "No reviews submitted yet.",
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: reviews.length,
                  itemBuilder: (context, index) {
                    final data = reviews[index].data() as Map<String, dynamic>;
                    return _reviewCard(data);
                  },
                );
              },
            ),
    );
  }

  Widget _reviewCard(Map<String, dynamic> review) {
    final Timestamp timestamp = review['timestamp'] ?? Timestamp.now();
    final date = timestamp.toDate();
    final formattedDate =
        "${date.day.toString().padLeft(2, '0')} ${_monthName(date.month)} ${date.year}";

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              review['workerName'] ?? 'Worker',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            if (review['service'] != null)
              Text(
                review['service'],
                style: TextStyle(
                  color: Colors.grey[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
            const SizedBox(height: 10),
            StarRating(rating: (review['rating'] ?? 0).toDouble()),
            const SizedBox(height: 10),
            if ((review['review'] ?? '').toString().isNotEmpty)
              Text(review['review'], style: const TextStyle(fontSize: 15)),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.bottomRight,
              child: Text(
                formattedDate,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[500],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _monthName(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return months[month - 1];
  }
}
