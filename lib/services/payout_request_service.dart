import 'package:cloud_firestore/cloud_firestore.dart';

class PayoutSummary {
  const PayoutSummary({
    required this.availableAmount,
    required this.availableBookingIds,
    required this.payoutMethod,
    required this.payoutDetails,
  });

  final num availableAmount;
  final List<String> availableBookingIds;
  final String payoutMethod;
  final Map<String, dynamic> payoutDetails;

  bool get hasPayoutMethod {
    if (payoutMethod == 'bank') {
      return (payoutDetails['bankAccountNumber'] ?? '').toString().isNotEmpty &&
          (payoutDetails['ifsc'] ?? '').toString().isNotEmpty;
    }
    return (payoutDetails['upiId'] ?? '').toString().contains('@');
  }
}

class PayoutRequestService {
  PayoutRequestService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<PayoutSummary> loadSummary(String workerId) async {
    final workerDoc = await _firestore
        .collection('workers')
        .doc(workerId)
        .get();
    final worker = workerDoc.data() ?? {};
    final payout = Map<String, dynamic>.from(worker['payout'] ?? {});
    final topLevelMethod = worker['paymentMethod']?.toString().toLowerCase();
    final method =
        payout['defaultMethod']?.toString() == 'bank' ||
            topLevelMethod == 'bank'
        ? 'bank'
        : 'upi';
    final payoutDetails = <String, dynamic>{
      ...payout,
      if ((payout['upiId'] ?? '').toString().isEmpty) 'upiId': worker['upiId'],
      if ((payout['bankAccountNumber'] ?? '').toString().isEmpty)
        'bankAccountNumber': worker['bankAccountNumber'],
      if ((payout['ifsc'] ?? '').toString().isEmpty) 'ifsc': worker['ifscCode'],
    };

    final bookings = await _firestore
        .collection('bookings')
        .where('workerId', isEqualTo: workerId)
        .get();

    final eligible = bookings.docs.where((doc) {
      final data = doc.data();
      final status = (data['status'] ?? '').toString().toLowerCase();
      final paymentStatus = (data['paymentStatus'] ?? '')
          .toString()
          .toLowerCase();
      final payoutStatus = (data['payoutStatus'] ?? '')
          .toString()
          .toLowerCase();
      final earned =
          status == 'completed' || status == 'paid' || paymentStatus == 'paid';
      final alreadyRequested = {
        'requested',
        'processing',
        'paid',
        'rejected',
      }.contains(payoutStatus);
      return earned && !alreadyRequested;
    }).toList();

    final amount = eligible.fold<num>(
      0,
      (total, doc) => total + _amountForWorker(doc.data()),
    );

    return PayoutSummary(
      availableAmount: amount,
      availableBookingIds: eligible.map((doc) => doc.id).toList(),
      payoutMethod: method,
      payoutDetails: payoutDetails,
    );
  }

  Future<String> createRequest({
    required String workerId,
    required PayoutSummary summary,
  }) async {
    if (!summary.hasPayoutMethod) {
      throw StateError('Add a valid payout method before requesting payout.');
    }
    if (summary.availableAmount <= 0 || summary.availableBookingIds.isEmpty) {
      throw StateError('No completed paid jobs are available for payout.');
    }

    final now = FieldValue.serverTimestamp();
    final requestRef = _firestore.collection('payoutRequests').doc();
    final batch = _firestore.batch();

    batch.set(requestRef, {
      'workerId': workerId,
      'amount': summary.availableAmount,
      'bookingIds': summary.availableBookingIds,
      'status': 'pending',
      'payoutMethod': summary.payoutMethod,
      'payoutDetails': summary.payoutDetails,
      'requestedAt': now,
      'updatedAt': now,
    });

    for (final bookingId in summary.availableBookingIds) {
      final bookingRef = _firestore.collection('bookings').doc(bookingId);
      batch.update(bookingRef, {
        'payoutStatus': 'requested',
        'payoutRequestId': requestRef.id,
        'payoutRequestedAt': now,
        'updatedAt': now,
      });
    }

    await batch.commit();
    return requestRef.id;
  }

  num _amountForWorker(Map<String, dynamic> data) {
    final raw =
        data['price'] ??
        data['estimatedPrice'] ??
        data['amount'] ??
        data['totalAmount'];
    if (raw is num) return raw;
    final match = RegExp(r'\d+(\.\d+)?').firstMatch(raw?.toString() ?? '');
    return num.tryParse(match?.group(0) ?? '') ?? 0;
  }
}
