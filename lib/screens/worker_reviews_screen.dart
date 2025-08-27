import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../widgets/star_rating.dart';

class WorkerReviewsScreen extends StatefulWidget {
  static const routeName = '/worker-reviews';

  const WorkerReviewsScreen({Key? key}) : super(key: key);

  @override
  State<WorkerReviewsScreen> createState() => _WorkerReviewsScreenState();
}

class _WorkerReviewsScreenState extends State<WorkerReviewsScreen> {
  final String? workerId = FirebaseAuth.instance.currentUser?.uid;
  List<Map<String, dynamic>> reviews = [];

  @override
  void initState() {
    super.initState();
    _loadReviews();
  }

  Future<void> _loadReviews() async {
    if (workerId == null) return;

    final snapshot = await FirebaseFirestore.instance
        .collection('reviews')
        .where('workerId', isEqualTo: workerId)
        .get();

    setState(() {
      reviews = snapshot.docs
          .map((e) => e.data() as Map<String, dynamic>)
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Reviews'),
        backgroundColor: Colors.deepPurple,
        automaticallyImplyLeading: false, // ✅ Fixes the double back arrow issue
      ),
      body: reviews.isEmpty
          ? const Center(child: Text('No reviews yet.'))
          : ListView.builder(
              itemCount: reviews.length,
              itemBuilder: (context, index) {
                final review = reviews[index];
                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  child: ListTile(
                    title: StarRating(
                      rating: (review['rating'] ?? 0).toDouble(),
                    ),
                    subtitle: Text(review['review'] ?? ''),
                  ),
                );
              },
            ),
    );
  }
}
