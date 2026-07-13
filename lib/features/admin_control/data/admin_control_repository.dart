import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/admin_control_summary.dart';
import '../domain/admin_dispute_item.dart';

class AdminControlRepository {
  AdminControlRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

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

  Future<void> markDisputeUnderReview(AdminDisputeItem item) {
    return _updateDispute(item, {
      'adminReviewStatus': 'under_review',
      'adminReviewStartedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> saveDisputeNote(AdminDisputeItem item, String note) {
    final cleanNote = note.trim();
    if (cleanNote.isEmpty) {
      throw StateError('Admin note is required.');
    }
    return _updateDispute(item, {
      'adminDisputeNote': cleanNote,
      'adminDisputeNoteUpdatedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _updateDispute(
    AdminDisputeItem item,
    Map<String, dynamic> data,
  ) {
    final collection = item.isHelpRequest ? 'helpRequests' : 'bookings';
    return _firestore.collection(collection).doc(item.id).update(data);
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
