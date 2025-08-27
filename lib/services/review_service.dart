import 'package:cloud_firestore/cloud_firestore.dart';

Future<void> submitReviewToFirestore({
  required String workerId,
  required String bookingId,
  required int rating,
  required String comment,
}) async {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  // Save the review to a 'reviews' subcollection
  await firestore
      .collection('workers')
      .doc(workerId)
      .collection('reviews')
      .add({
        'bookingId': bookingId,
        'rating': rating,
        'comment': comment,
        'createdAt': FieldValue.serverTimestamp(),
      });

  // Recalculate average rating
  final reviewSnapshot = await firestore
      .collection('workers')
      .doc(workerId)
      .collection('reviews')
      .get();

  double totalRating = 0;
  for (var doc in reviewSnapshot.docs) {
    totalRating += (doc['rating'] as num).toDouble();
  }

  final double averageRating = reviewSnapshot.docs.isNotEmpty
      ? totalRating / reviewSnapshot.docs.length
      : 0.0;

  // Count completed bookings
  final completedJobsSnapshot = await firestore
      .collection('bookings')
      .where('workerId', isEqualTo: workerId)
      .where('status', isEqualTo: 'completed')
      .get();

  final int completedJobsCount = completedJobsSnapshot.size;

  // Update worker's profile
  await firestore.collection('workers').doc(workerId).update({
    'averageRating': averageRating,
    'completedJobsCount': completedJobsCount,
  });
}
