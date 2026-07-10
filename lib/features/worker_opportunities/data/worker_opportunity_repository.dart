import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../domain/worker_opportunity.dart';

class WorkerOpportunityRepository {
  WorkerOpportunityRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    FirebaseFunctions? functions,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance,
       _functions =
           functions ?? FirebaseFunctions.instanceFor(region: 'us-central1');

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final FirebaseFunctions _functions;

  String? get currentWorkerId => _auth.currentUser?.uid;

  Stream<List<WorkerOpportunity>> watchOpenOpportunities() {
    return _firestore
        .collection('demandSignals')
        .where('status', isEqualTo: 'open')
        .orderBy('lastSearchedAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) {
          final items = snapshot.docs.map(_fromSnapshot).toList();
          items.sort((a, b) {
            final countCompare = b.searchCount.compareTo(a.searchCount);
            if (countCompare != 0) return countCompare;
            final aDate = a.lastSearchedAt ?? DateTime(1970);
            final bDate = b.lastSearchedAt ?? DateTime(1970);
            return bDate.compareTo(aDate);
          });
          return items;
        });
  }

  Future<void> claimOpportunity(WorkerOpportunity opportunity) async {
    final workerId = currentWorkerId;
    if (workerId == null) {
      throw StateError('No signed-in worker found.');
    }

    final skill = opportunity.guessedCategory.trim().isEmpty
        ? opportunity.searchPhrase
        : opportunity.guessedCategory;

    final callable = _functions.httpsCallable('claimDemandOpportunity');
    await callable.call<Map<String, dynamic>>({
      'signalId': opportunity.id,
      'skill': skill,
    });
  }

  WorkerOpportunity _fromSnapshot(
    QueryDocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data();
    return WorkerOpportunity(
      id: snapshot.id,
      searchPhrase: _text(data, ['lastSearchPhrase', 'searchPhrase'], 'Help'),
      normalizedPhrase: _text(data, ['normalizedPhrase'], ''),
      guessedCategory: _text(data, ['guessedCategory'], 'General Help'),
      city: _text(data, ['city'], 'Unknown'),
      status: _text(data, ['status'], 'open'),
      searchCount: _int(data['searchCount']),
      claimedWorkerIds: _list(data['claimedWorkerIds']),
      createdAt: _date(data['createdAt']),
      lastSearchedAt: _date(data['lastSearchedAt']),
    );
  }

  DateTime? _date(dynamic value) {
    if (value is Timestamp) return value.toDate();
    return null;
  }

  List<String> _list(dynamic value) {
    if (value is List) return value.map((item) => item.toString()).toList();
    return const [];
  }

  String _text(Map<String, dynamic> data, List<String> keys, String fallback) {
    for (final key in keys) {
      final value = data[key]?.toString().trim();
      if (value != null && value.isNotEmpty && value.toLowerCase() != 'null') {
        return value;
      }
    }
    return fallback;
  }

  int _int(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}
