import 'package:cloud_firestore/cloud_firestore.dart';

Future<void> cleanWorkerData() async {
  final firestore = FirebaseFirestore.instance;
  final snapshot = await firestore.collection('workers').get();

  for (var doc in snapshot.docs) {
    final data = doc.data();
    final Map<String, dynamic> updates = {};

    if (!data.containsKey('pricing')) {
      updates['pricing'] = 300;
    }
    if (!data.containsKey('averageRating')) {
      updates['averageRating'] = 0.0;
    }
    if (!data.containsKey('completedJobsCount')) {
      updates['completedJobsCount'] = 0;
    }
    if (!data.containsKey('isAvailable')) {
      updates['isAvailable'] = true;
    }
    if (!data.containsKey('location')) {
      updates['location'] = {'latitude': 0.0, 'longitude': 0.0};
    }

    if (updates.isNotEmpty) {
      await firestore.collection('workers').doc(doc.id).update(updates);
    }
  }

  print("Worker data cleaned successfully.");
}
