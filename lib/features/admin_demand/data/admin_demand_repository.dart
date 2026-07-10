import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../domain/admin_demand_signal.dart';

class AdminDemandRepository {
  AdminDemandRepository({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  Stream<List<AdminDemandSignal>> watchDemandSignals() {
    return _firestore.collection('demandSignals').limit(150).snapshots().map((
      snapshot,
    ) {
      final items = snapshot.docs.map(_fromSnapshot).toList();
      items.sort((a, b) {
        final statusCompare = _statusRank(a).compareTo(_statusRank(b));
        if (statusCompare != 0) return statusCompare;

        final countCompare = b.searchCount.compareTo(a.searchCount);
        if (countCompare != 0) return countCompare;

        final aDate = a.lastSearchedAt ?? DateTime(1970);
        final bDate = b.lastSearchedAt ?? DateTime(1970);
        return bDate.compareTo(aDate);
      });
      return items;
    });
  }

  Future<void> approveCategory({
    required AdminDemandSignal signal,
    required String categoryName,
    String? note,
  }) async {
    final adminId = _auth.currentUser?.uid ?? 'admin';
    final cleanCategory = categoryName.trim();
    if (cleanCategory.isEmpty) {
      throw ArgumentError('Category name is required.');
    }

    final signalRef = _firestore.collection('demandSignals').doc(signal.id);
    final skillRef = _firestore.collection('skills').doc(cleanCategory);

    await _firestore.runTransaction((transaction) async {
      final now = FieldValue.serverTimestamp();

      transaction.set(skillRef, {
        'name': cleanCategory,
        'status': 'approved',
        'source': 'admin_demand_review',
        'fromDemandSignalId': signal.id,
        'searchPhrase': signal.searchPhrase,
        'searchCount': signal.searchCount,
        'city': signal.city,
        'approvedBy': adminId,
        'approvedAt': now,
        'updatedAt': now,
      }, SetOptions(merge: true));

      transaction.update(signalRef, {
        'status': 'approved',
        'adminAction': 'approved_category',
        'approvedCategory': cleanCategory,
        'adminNote': note?.trim(),
        'reviewedBy': adminId,
        'reviewedAt': now,
        'updatedAt': now,
      });
    });
  }

  Future<void> mergeIntoCategory({
    required AdminDemandSignal signal,
    required String categoryName,
    String? note,
  }) async {
    final adminId = _auth.currentUser?.uid ?? 'admin';
    final cleanCategory = categoryName.trim();
    if (cleanCategory.isEmpty) {
      throw ArgumentError('Category name is required.');
    }

    await _firestore.collection('demandSignals').doc(signal.id).update({
      'status': 'merged',
      'adminAction': 'merged_into_category',
      'approvedCategory': cleanCategory,
      'mergedIntoCategory': cleanCategory,
      'adminNote': note?.trim(),
      'reviewedBy': adminId,
      'reviewedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> rejectSignal({
    required AdminDemandSignal signal,
    required String reason,
  }) async {
    final adminId = _auth.currentUser?.uid ?? 'admin';
    await _firestore.collection('demandSignals').doc(signal.id).update({
      'status': 'rejected',
      'adminAction': 'rejected',
      'rejectionReason': reason.trim().isEmpty
          ? 'Demand is not suitable for marketplace category creation.'
          : reason.trim(),
      'reviewedBy': adminId,
      'reviewedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  int _statusRank(AdminDemandSignal signal) {
    switch (signal.status) {
      case 'open':
        return 0;
      case 'merged':
        return 1;
      case 'approved':
        return 2;
      case 'rejected':
        return 3;
      default:
        return 4;
    }
  }

  AdminDemandSignal _fromSnapshot(
    QueryDocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data();
    return AdminDemandSignal(
      id: snapshot.id,
      searchPhrase: _text(data, ['lastSearchPhrase', 'searchPhrase'], 'Help'),
      normalizedPhrase: _text(data, ['normalizedPhrase'], ''),
      guessedCategory: _text(data, ['guessedCategory'], 'General Help'),
      city: _text(data, ['city'], 'Unknown'),
      status: _text(data, ['status'], 'open'),
      searchCount: _int(data['searchCount']),
      customerIds: _list(data['customerIds']),
      claimedWorkerIds: _list(data['claimedWorkerIds']),
      adminAction: _optionalText(data['adminAction']),
      approvedCategory: _optionalText(data['approvedCategory']),
      createdAt: _date(data['createdAt']),
      lastSearchedAt: _date(data['lastSearchedAt']),
      updatedAt: _date(data['updatedAt']),
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

  String? _optionalText(dynamic value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty || text.toLowerCase() == 'null') {
      return null;
    }
    return text;
  }

  int _int(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}
