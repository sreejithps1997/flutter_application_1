import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

Future<void> patchBookingData() async {
  await Firebase.initializeApp();
  final firestore = FirebaseFirestore.instance;

  final snapshot = await firestore.collection('bookings').get();

  for (final doc in snapshot.docs) {
    final data = doc.data();
    final updates = <String, dynamic>{};

    // Only update if the field is missing
    if (!data.containsKey('completedAt')) {
      updates['completedAt'] = null; // or FieldValue.serverTimestamp()
    }

    if (!data.containsKey('rating')) {
      updates['rating'] = null;
    }

    if (!data.containsKey('workerName')) {
      updates['workerName'] = 'Unknown';
    }

    if (!data.containsKey('totalAmount')) {
      updates['totalAmount'] = 0;
    }

    if (updates.isNotEmpty) {
      print('Updating booking: ${doc.id}');
      await doc.reference.update(updates);
    }
  }

  print('✅ Booking patch complete.');
}
