import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

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
  PayoutRequestService({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _functions =
           functions ?? FirebaseFunctions.instanceFor(region: 'us-central1');

  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

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

    final result = await _functions.httpsCallable('createPayoutRequest').call({
      'bookingIds': summary.availableBookingIds,
    });
    final data = Map<String, dynamic>.from(result.data as Map);
    return data['payoutRequestId']?.toString() ?? '';
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
