import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../domain/smart_help_quota.dart';

class SmartHelpQuotaRepository {
  SmartHelpQuotaRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    this.dailyAllowance = 3,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final int dailyAllowance;

  Stream<SmartHelpQuota> watchTodayQuota() {
    final user = _auth.currentUser;
    final dateKey = _todayKey();
    if (user == null) {
      return Stream.value(
        SmartHelpQuota.empty(dateKey: dateKey, dailyAllowance: dailyAllowance),
      );
    }

    return _dayRef(user.uid, dateKey).snapshots().map((snapshot) {
      return SmartHelpQuota.fromMap(
        snapshot.data(),
        dateKey: dateKey,
        dailyAllowance: dailyAllowance,
      );
    });
  }

  Future<void> recordLocalAssessment({
    required String query,
    required String category,
    required String urgency,
    required String recommendedPath,
    required bool foundWorkers,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final dateKey = _todayKey();
    final ref = _dayRef(user.uid, dateKey);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(ref);
      transaction.set(ref, {
        'uid': user.uid,
        'dateKey': dateKey,
        'dailyAllowance': dailyAllowance,
        'localAssessments': FieldValue.increment(1),
        'totalSmartBookingRequests': FieldValue.increment(1),
        'lastLocalAssessment': {
          'queryLength': query.trim().length,
          'category': category,
          'urgency': urgency,
          'recommendedPath': recommendedPath,
          'foundWorkers': foundWorkers,
          'usedAt': FieldValue.serverTimestamp(),
        },
        'updatedAt': FieldValue.serverTimestamp(),
        if (!snapshot.exists) 'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }

  Future<bool> reserveAiHelp({
    required String reason,
    int estimatedTokens = 0,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('Please log in again to use Smart Help.');
    }

    final dateKey = _todayKey();
    final ref = _dayRef(user.uid, dateKey);
    return _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(ref);
      final quota = SmartHelpQuota.fromMap(
        snapshot.data(),
        dateKey: dateKey,
        dailyAllowance: dailyAllowance,
      );

      if (!quota.canUseAi) {
        transaction.set(ref, {
          'uid': user.uid,
          'dateKey': dateKey,
          'dailyAllowance': dailyAllowance,
          'blockedAiCalls': FieldValue.increment(1),
          'lastBlockedReason': reason,
          'updatedAt': FieldValue.serverTimestamp(),
          if (!snapshot.exists) 'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        return false;
      }

      transaction.set(ref, {
        'uid': user.uid,
        'dateKey': dateKey,
        'dailyAllowance': dailyAllowance,
        'aiCallsUsed': FieldValue.increment(1),
        'estimatedTokens': FieldValue.increment(estimatedTokens),
        'lastAiReason': reason,
        'lastAiReservedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        if (!snapshot.exists) 'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      return true;
    });
  }

  DocumentReference<Map<String, dynamic>> _dayRef(String uid, String dateKey) {
    return _firestore
        .collection('aiUsage')
        .doc(uid)
        .collection('days')
        .doc(dateKey);
  }

  String _todayKey() {
    final now = DateTime.now();
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    return '${now.year}-$month-$day';
  }
}
