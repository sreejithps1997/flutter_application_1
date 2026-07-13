import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../domain/admin_control_summary.dart';
import '../domain/admin_dispute_item.dart';
import '../domain/admin_permission_set.dart';

class AdminControlRepository {
  AdminControlRepository({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  Future<AdminControlSummary> loadSummary() async {
    final results = await Future.wait<int>([
      _countBookings(status: 'payment_under_review'),
      _countPayoutReviews(),
      _countVerificationReviews(),
      _countDisputedBookings(),
      _countBookings(statuses: const ['confirmed', 'accepted', 'in_progress']),
      _countHelpIssues(),
      _countDemandSignals(),
      _countReferralRewards(),
      _countActiveCampaigns(),
    ]);

    return AdminControlSummary(
      paymentReviews: results[0],
      payoutReviews: results[1],
      verificationReviews: results[2],
      disputedBookings: results[3],
      workStartOverrides: results[4],
      helpIssues: results[5],
      openDemandSignals: results[6],
      referralRewards: results[7],
      activeCampaigns: results[8],
    );
  }

  Stream<List<AdminDisputeItem>> watchDisputes() {
    return _firestore.collection('bookings').snapshots().asyncMap((
      bookingSnapshot,
    ) async {
      final helpSnapshot = await _firestore
          .collection('helpRequests')
          .where(
            'status',
            whereIn: const [
              'completion_disputed',
              'payment_under_review',
              'disputed',
            ],
          )
          .get();
      final bookingDisputes = bookingSnapshot.docs
          .where((doc) => _isDisputedBooking(doc.data()))
          .map(AdminDisputeItem.booking);
      final helpDisputes = helpSnapshot.docs.map(AdminDisputeItem.helpRequest);
      final items = [...bookingDisputes, ...helpDisputes];
      items.sort((a, b) {
        final aDate = a.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bDate = b.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bDate.compareTo(aDate);
      });
      return items;
    });
  }

  Future<AdminPermissionSet> loadPermissions() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      return const AdminPermissionSet(isAdmin: false, roles: {});
    }
    final snapshot = await _firestore.collection('users').doc(uid).get();
    return AdminPermissionSet.fromData(snapshot.data());
  }

  Stream<List<Map<String, dynamic>>> watchAuditLogs(AdminDisputeItem item) {
    return _firestore
        .collection('adminAuditLogs')
        .where(
          'targetCollection',
          isEqualTo: item.isHelpRequest ? 'helpRequests' : 'bookings',
        )
        .where('targetId', isEqualTo: item.id)
        .limit(20)
        .snapshots()
        .map((snapshot) {
          final logs = snapshot.docs.map((doc) {
            return {'id': doc.id, ...doc.data()};
          }).toList();
          logs.sort((a, b) {
            final aDate = _timestampToDate(a['createdAt']);
            final bDate = _timestampToDate(b['createdAt']);
            return bDate.compareTo(aDate);
          });
          return logs;
        });
  }

  Future<void> markDisputeUnderReview(AdminDisputeItem item) async {
    await _requireSupportAdmin();
    await _updateDispute(item, {
      'adminReviewStatus': 'under_review',
      'adminReviewStartedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await _writeAudit(
      item,
      action: 'mark_under_review',
      note: 'Admin marked dispute under review.',
      newState: const {'adminReviewStatus': 'under_review'},
    );
  }

  Future<void> saveDisputeNote(AdminDisputeItem item, String note) async {
    await _requireSupportAdmin();
    final cleanNote = note.trim();
    if (cleanNote.isEmpty) {
      throw StateError('Admin note is required.');
    }
    await _updateDispute(item, {
      'adminDisputeNote': cleanNote,
      'adminDisputeNoteUpdatedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await _writeAudit(
      item,
      action: 'save_admin_note',
      note: cleanNote,
      newState: {'adminDisputeNote': cleanNote},
    );
  }

  Future<void> requestEvidence({
    required AdminDisputeItem item,
    required String requestedFrom,
    required String requestNote,
  }) async {
    await _requireSupportAdmin();
    final cleanNote = requestNote.trim();
    if (cleanNote.isEmpty) {
      throw StateError('Evidence request note is required.');
    }
    final normalizedParty = requestedFrom.trim().toLowerCase();
    final data = {
      'evidenceStatus': 'requested',
      'evidenceRequestedFrom': normalizedParty,
      'evidenceRequestNote': cleanNote,
      'evidenceRequestedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    await _updateDispute(item, data);
    await _writeAudit(
      item,
      action: 'request_evidence',
      note: cleanNote,
      newState: {
        'evidenceStatus': 'requested',
        'evidenceRequestedFrom': normalizedParty,
      },
    );
  }

  Future<void> flagRisk({
    required AdminDisputeItem item,
    required String riskFlag,
    required String note,
  }) async {
    await _requireSupportAdmin();
    final cleanFlag = riskFlag.trim();
    final cleanNote = note.trim();
    if (cleanFlag.isEmpty || cleanNote.isEmpty) {
      throw StateError('Risk flag and note are required.');
    }
    await _updateDispute(item, {
      'riskFlags': FieldValue.arrayUnion([cleanFlag]),
      'latestRiskNote': cleanNote,
      'latestRiskFlaggedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await _writeAudit(
      item,
      action: 'flag_risk',
      note: cleanNote,
      newState: {'riskFlag': cleanFlag},
    );
  }

  Future<void> resolveDispute({
    required AdminDisputeItem item,
    required String decision,
    required String note,
    double? creditAmount,
  }) async {
    await _requireSupportAdmin();
    final cleanNote = note.trim();
    if (cleanNote.isEmpty) {
      throw StateError('Resolution note is required.');
    }

    final normalizedDecision = decision.trim().toLowerCase();
    if (!{
      'customer_favor',
      'worker_favor',
      'partial_credit',
    }.contains(normalizedDecision)) {
      throw StateError('Unsupported dispute decision.');
    }

    final updateData = <String, dynamic>{
      'adminReviewStatus': 'resolved',
      'resolutionStatus': normalizedDecision,
      'resolutionNote': cleanNote,
      'resolvedAt': FieldValue.serverTimestamp(),
      'resolvedBy': _adminId,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (normalizedDecision == 'customer_favor') {
      updateData.addAll({
        'status': item.isHelpRequest ? 'resolved_customer_favor' : 'completed',
        'paymentStatus': 'customer_favor_resolved',
      });
    } else if (normalizedDecision == 'worker_favor') {
      updateData.addAll({
        'status': item.isHelpRequest ? 'resolved_worker_favor' : 'completed',
        'paymentStatus': 'worker_favor_resolved',
      });
    } else {
      final amount = creditAmount ?? 0;
      if (amount <= 0) {
        throw StateError('Partial credit amount must be greater than zero.');
      }
      updateData.addAll({
        'status': item.isHelpRequest ? 'resolved_partial_credit' : 'completed',
        'paymentStatus': 'partial_credit_resolved',
        'platformCreditAmount': amount,
      });
    }

    await _updateDispute(item, updateData);
    await _writeAudit(
      item,
      action: 'resolve_dispute',
      note: cleanNote,
      newState: {
        'resolutionStatus': normalizedDecision,
        if (creditAmount != null) 'platformCreditAmount': creditAmount,
      },
    );
  }

  Future<void> _updateDispute(
    AdminDisputeItem item,
    Map<String, dynamic> data,
  ) {
    final collection = item.isHelpRequest ? 'helpRequests' : 'bookings';
    return _firestore.collection(collection).doc(item.id).update(data);
  }

  Future<void> _writeAudit(
    AdminDisputeItem item, {
    required String action,
    required String note,
    required Map<String, dynamic> newState,
  }) {
    return _firestore.collection('adminAuditLogs').add({
      'adminId': _adminId,
      'action': action,
      'targetCollection': item.isHelpRequest ? 'helpRequests' : 'bookings',
      'targetId': item.id,
      'targetType': item.typeLabel,
      'note': note,
      'previousState': {
        'status': item.status,
        'paymentStatus': item.paymentStatus,
        'adminReviewStatus': item.data['adminReviewStatus'],
        'evidenceStatus': item.evidenceStatus,
        'resolutionStatus': item.resolutionStatus,
        'riskFlags': item.riskFlags,
      },
      'newState': newState,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  String get _adminId => _auth.currentUser?.uid ?? 'unknown_admin';

  Future<void> _requireSupportAdmin() async {
    final permissions = await loadPermissions();
    if (!permissions.canManageSupport) {
      throw StateError('Support admin permission is required.');
    }
  }

  DateTime _timestampToDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    return DateTime.tryParse(value?.toString() ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0);
  }

  bool _isDisputedBooking(Map<String, dynamic> data) {
    final status = data['status']?.toString().toLowerCase() ?? '';
    final paymentStatus = data['paymentStatus']?.toString().toLowerCase() ?? '';
    return {
          'completion_disputed',
          'disputed',
          'payment_under_review',
        }.contains(status) ||
        {'disputed', 'payment_under_review'}.contains(paymentStatus);
  }

  Future<int> _countBookings({String? status, List<String>? statuses}) async {
    Query<Map<String, dynamic>> query = _firestore.collection('bookings');
    if (status != null) {
      query = query.where('status', isEqualTo: status);
    } else if (statuses != null && statuses.isNotEmpty) {
      query = query.where('status', whereIn: statuses);
    }
    return (await query.count().get()).count ?? 0;
  }

  Future<int> _countPayoutReviews() async {
    final snapshot = await _firestore
        .collection('payoutRequests')
        .where('status', whereIn: const ['requested', 'pending', 'approved'])
        .count()
        .get();
    return snapshot.count ?? 0;
  }

  Future<int> _countVerificationReviews() async {
    final snapshot = await _firestore
        .collection('adminVerificationQueue')
        .where('status', isEqualTo: 'pending')
        .count()
        .get();
    return snapshot.count ?? 0;
  }

  Future<int> _countDisputedBookings() async {
    final statusSnapshot = await _firestore
        .collection('bookings')
        .where('status', whereIn: const ['completion_disputed', 'disputed'])
        .count()
        .get();
    final paymentSnapshot = await _firestore
        .collection('bookings')
        .where('paymentStatus', isEqualTo: 'disputed')
        .count()
        .get();
    return (statusSnapshot.count ?? 0) + (paymentSnapshot.count ?? 0);
  }

  Future<int> _countHelpIssues() async {
    final snapshot = await _firestore
        .collection('helpRequests')
        .where(
          'status',
          whereIn: const [
            'completion_disputed',
            'payment_under_review',
            'disputed',
          ],
        )
        .count()
        .get();
    return snapshot.count ?? 0;
  }

  Future<int> _countDemandSignals() async {
    final snapshot = await _firestore
        .collection('demandSignals')
        .where('status', whereIn: const ['open', 'new', 'pending'])
        .count()
        .get();
    return snapshot.count ?? 0;
  }

  Future<int> _countReferralRewards() async {
    final snapshot = await _firestore
        .collection('referralRewards')
        .where('status', whereIn: const ['ready', 'pending', 'approved'])
        .count()
        .get();
    return snapshot.count ?? 0;
  }

  Future<int> _countActiveCampaigns() async {
    final snapshot = await _firestore
        .collection('communityCampaigns')
        .where('status', isEqualTo: 'active')
        .count()
        .get();
    return snapshot.count ?? 0;
  }
}
