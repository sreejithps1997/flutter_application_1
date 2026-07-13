import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/worker_badge_summary.dart';

class WorkerBadgeRepository {
  WorkerBadgeRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Stream<WorkerBadgeSummary> watchWorkerBadge(String workerId) {
    return _firestore.collection('workers').doc(workerId).snapshots().asyncMap((
      workerSnapshot,
    ) async {
      final worker = workerSnapshot.data() ?? const <String, dynamic>{};
      final bookingSnapshot = await _firestore
          .collection('bookings')
          .where('workerId', isEqualTo: workerId)
          .get();
      final bookings = bookingSnapshot.docs.map((doc) => doc.data()).toList();
      return WorkerBadgeSummary.fromData(
        workerId: workerId,
        worker: worker,
        bookings: bookings,
      );
    });
  }
}
