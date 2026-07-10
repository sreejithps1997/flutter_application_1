import 'package:cloud_firestore/cloud_firestore.dart';

class BookingPaymentBreakdown {
  const BookingPaymentBreakdown({
    required this.subtotal,
    required this.platformFee,
    required this.discount,
    required this.total,
    this.promoCode,
  });

  final double subtotal;
  final double platformFee;
  final double discount;
  final double total;
  final String? promoCode;
}

class BookingPaymentRepository {
  BookingPaymentRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<void> recordCashPending({
    required String bookingId,
    required String customerId,
    required String transactionId,
    required String paymentMethod,
    required BookingPaymentBreakdown breakdown,
  }) {
    return _recordPaymentState(
      bookingId: bookingId,
      customerId: customerId,
      transactionId: transactionId,
      paymentMethod: paymentMethod,
      breakdown: breakdown,
      paymentStatus: 'cash_pending_confirmation',
      bookingStatus: 'payment_under_review',
      transactionType: 'payment',
    );
  }

  Future<void> recordUpiAttempt({
    required String bookingId,
    required String customerId,
    required String transactionId,
    required String paymentMethod,
    required BookingPaymentBreakdown breakdown,
    required String upiId,
    required String status,
  }) {
    return _recordPaymentState(
      bookingId: bookingId,
      customerId: customerId,
      transactionId: transactionId,
      paymentMethod: paymentMethod,
      breakdown: breakdown,
      paymentStatus: status,
      bookingStatus: status == 'customer_reported_paid'
          ? 'payment_under_review'
          : 'payment_initiated',
      transactionType: 'upi_payment',
      upiId: upiId,
      mergeTransaction: true,
    );
  }

  Future<void> approvePayment({
    required String bookingId,
    required String reviewedBy,
    required String reviewerRole,
    String? note,
  }) async {
    final now = FieldValue.serverTimestamp();

    await _firestore.runTransaction((transaction) async {
      final bookingRef = _firestore.collection('bookings').doc(bookingId);
      final bookingSnap = await transaction.get(bookingRef);
      if (!bookingSnap.exists) {
        throw StateError('Booking not found.');
      }
      final booking = bookingSnap.data() ?? {};

      transaction.update(bookingRef, {
        'status': 'completed',
        'paymentStatus': 'paid',
        'paymentReviewStatus': 'approved',
        'paymentReviewedBy': reviewedBy,
        'paymentReviewerRole': reviewerRole,
        'paymentReviewNote': note,
        'paidAt': now,
        'completedAt': now,
        'timeline.paid': now,
        'timeline.completed': now,
        'updatedAt': now,
      });

      final helpRequestId = booking['sourceHelpRequestId']?.toString();
      if (helpRequestId != null && helpRequestId.isNotEmpty) {
        transaction
            .update(_firestore.collection('helpRequests').doc(helpRequestId), {
              'status': 'completed',
              'paymentStatus': 'paid',
              'paymentReviewStatus': 'approved',
              'paymentReviewedBy': reviewedBy,
              'paymentReviewerRole': reviewerRole,
              'paymentReviewNote': note,
              'paidAt': now,
              'completedAt': now,
              'timeline.paid': now,
              'timeline.completed': now,
              'updatedAt': now,
            });
      }
    });

    await _updateTransactions(
      bookingId: bookingId,
      values: {
        'status': 'paid',
        'paymentReviewStatus': 'approved',
        'paymentReviewedBy': reviewedBy,
        'paymentReviewerRole': reviewerRole,
        'paymentReviewNote': note,
        'paidAt': now,
        'updatedAt': now,
      },
    );

    final booking =
        (await _firestore.collection('bookings').doc(bookingId).get()).data() ??
        const <String, dynamic>{};
    await _notifyPaymentApproved(bookingId: bookingId, booking: booking);
  }

  Future<void> rejectPayment({
    required String bookingId,
    required String reviewedBy,
    required String reviewerRole,
    required String reason,
  }) async {
    final now = FieldValue.serverTimestamp();

    final bookingRef = _firestore.collection('bookings').doc(bookingId);
    final booking = (await bookingRef.get()).data() ?? {};

    await bookingRef.update({
      'status': 'payment_due',
      'paymentStatus': 'payment_rejected',
      'paymentReviewStatus': 'rejected',
      'paymentReviewedBy': reviewedBy,
      'paymentReviewerRole': reviewerRole,
      'paymentRejectionReason': reason,
      'paymentRejectedAt': now,
      'updatedAt': now,
    });

    final helpRequestId = booking['sourceHelpRequestId']?.toString();
    if (helpRequestId != null && helpRequestId.isNotEmpty) {
      await _firestore.collection('helpRequests').doc(helpRequestId).update({
        'status': 'payment_due',
        'paymentStatus': 'payment_rejected',
        'paymentReviewStatus': 'rejected',
        'paymentReviewedBy': reviewedBy,
        'paymentReviewerRole': reviewerRole,
        'paymentRejectionReason': reason,
        'paymentRejectedAt': now,
        'updatedAt': now,
      });
    }

    await _updateTransactions(
      bookingId: bookingId,
      values: {
        'status': 'payment_rejected',
        'paymentReviewStatus': 'rejected',
        'paymentReviewedBy': reviewedBy,
        'paymentReviewerRole': reviewerRole,
        'paymentRejectionReason': reason,
        'updatedAt': now,
      },
    );

    await _notifyPaymentRejected(
      bookingId: bookingId,
      booking: booking,
      reason: reason,
    );
  }

  Future<void> _recordPaymentState({
    required String bookingId,
    required String customerId,
    required String transactionId,
    required String paymentMethod,
    required BookingPaymentBreakdown breakdown,
    required String paymentStatus,
    required String bookingStatus,
    required String transactionType,
    String? upiId,
    bool mergeTransaction = false,
  }) async {
    final now = FieldValue.serverTimestamp();
    final bookingRef = _firestore.collection('bookings').doc(bookingId);
    final transactionRef = _firestore
        .collection('transactions')
        .doc(transactionId);

    await _firestore.runTransaction((transaction) async {
      final freshBooking = await transaction.get(bookingRef);
      if (!freshBooking.exists) {
        throw StateError('Booking was not found.');
      }
      final booking = freshBooking.data() ?? {};

      transaction.update(bookingRef, {
        'payment': paymentMethod,
        'paymentMethod': paymentMethod,
        'paymentStatus': paymentStatus,
        'paymentReference': transactionId,
        'paymentSubtotal': breakdown.subtotal,
        'platformFee': breakdown.platformFee,
        'discount': breakdown.discount,
        'totalAmount': breakdown.total,
        if (upiId != null) 'paymentUpiId': upiId,
        'promoCode': breakdown.promoCode,
        'status': bookingStatus,
        'updatedAt': now,
      });

      final helpRequestId = booking['sourceHelpRequestId']?.toString();
      if (helpRequestId != null && helpRequestId.isNotEmpty) {
        transaction
            .update(_firestore.collection('helpRequests').doc(helpRequestId), {
              'status': bookingStatus,
              'paymentMethod': paymentMethod,
              'paymentStatus': paymentStatus,
              'paymentReference': transactionId,
              'paymentSubtotal': breakdown.subtotal,
              'platformFee': breakdown.platformFee,
              'discount': breakdown.discount,
              'totalAmount': breakdown.total,
              if (upiId != null) 'paymentUpiId': upiId,
              'promoCode': breakdown.promoCode,
              'updatedAt': now,
            });
      }

      final transactionData = {
        'id': transactionId,
        'bookingId': bookingId,
        'customerId': customerId,
        'workerId': booking['workerId'],
        'workerName': booking['workerName'],
        'service': booking['issue'] ?? 'Service booking',
        'type': transactionType,
        'status': paymentStatus,
        'paymentMethod': paymentMethod,
        if (upiId != null) 'upiId': upiId,
        'amount': breakdown.subtotal,
        'platformFee': breakdown.platformFee,
        'discount': breakdown.discount,
        'total': breakdown.total,
        'promoCode': breakdown.promoCode,
        'createdAt': now,
        'updatedAt': now,
      };

      if (mergeTransaction) {
        transaction.set(
          transactionRef,
          transactionData,
          SetOptions(merge: true),
        );
      } else {
        transaction.set(transactionRef, transactionData);
      }
    });

    await _notifyPaymentReported(
      bookingId: bookingId,
      paymentStatus: paymentStatus,
      bookingStatus: bookingStatus,
    );
  }

  Future<void> _updateTransactions({
    required String bookingId,
    required Map<String, Object?> values,
  }) async {
    final snapshot = await _firestore
        .collection('transactions')
        .where('bookingId', isEqualTo: bookingId)
        .get();

    if (snapshot.docs.isEmpty) return;

    final batch = _firestore.batch();
    for (final doc in snapshot.docs) {
      batch.update(doc.reference, values);
    }
    await batch.commit();
  }

  Future<void> _notifyPaymentReported({
    required String bookingId,
    required String paymentStatus,
    required String bookingStatus,
  }) async {
    final booking =
        (await _firestore.collection('bookings').doc(bookingId).get()).data() ??
        const <String, dynamic>{};
    final helpRequestId = booking['sourceHelpRequestId']?.toString();
    if (helpRequestId == null || helpRequestId.isEmpty) return;

    final workerId = booking['workerId']?.toString() ?? '';
    if (workerId.isEmpty) return;

    final service = _text(booking, ['service', 'serviceType'], 'help request');
    final isCash = paymentStatus == 'cash_pending_confirmation';
    final isReportedPaid = paymentStatus == 'customer_reported_paid';
    if (!isCash && !isReportedPaid) return;

    await _createNotification(
      uid: workerId,
      title: isCash ? 'Customer selected cash' : 'Customer reported payment',
      message: isCash
          ? 'The customer selected cash for $service. Confirm only after receiving it.'
          : 'The customer reported UPI payment for $service. It is under review.',
      type: isCash
          ? 'help_request_cash_pending'
          : 'help_request_payment_reported',
      status: bookingStatus,
      requiresAction: isCash,
      helpRequestId: helpRequestId,
      bookingId: bookingId,
      userRole: 'worker',
    );
  }

  Future<void> _notifyPaymentApproved({
    required String bookingId,
    required Map<String, dynamic> booking,
  }) async {
    final helpRequestId = booking['sourceHelpRequestId']?.toString();
    if (helpRequestId == null || helpRequestId.isEmpty) return;

    final customerId = booking['customerId']?.toString() ?? '';
    final workerId = booking['workerId']?.toString() ?? '';
    final service = _text(booking, ['service', 'serviceType'], 'help request');

    if (customerId.isNotEmpty) {
      await _createNotification(
        uid: customerId,
        title: 'Help request completed',
        message:
            'Payment for $service was confirmed. Your request is completed.',
        type: 'help_request_payment_approved',
        status: 'completed',
        requiresAction: false,
        helpRequestId: helpRequestId,
        bookingId: bookingId,
        userRole: 'customer',
      );
    }
    if (workerId.isNotEmpty) {
      await _createNotification(
        uid: workerId,
        title: 'Payment confirmed',
        message: 'Payment for $service was approved and marked completed.',
        type: 'help_request_payment_approved',
        status: 'completed',
        requiresAction: false,
        helpRequestId: helpRequestId,
        bookingId: bookingId,
        userRole: 'worker',
      );
    }
  }

  Future<void> _notifyPaymentRejected({
    required String bookingId,
    required Map<String, dynamic> booking,
    required String reason,
  }) async {
    final helpRequestId = booking['sourceHelpRequestId']?.toString();
    if (helpRequestId == null || helpRequestId.isEmpty) return;

    final customerId = booking['customerId']?.toString() ?? '';
    if (customerId.isEmpty) return;

    final service = _text(booking, ['service', 'serviceType'], 'help request');
    await _createNotification(
      uid: customerId,
      title: 'Payment needs attention',
      message: 'Payment for $service was rejected: $reason',
      type: 'help_request_payment_rejected',
      status: 'payment_rejected',
      requiresAction: true,
      helpRequestId: helpRequestId,
      bookingId: bookingId,
      userRole: 'customer',
    );
  }

  Future<void> _createNotification({
    required String uid,
    required String title,
    required String message,
    required String type,
    required String status,
    required bool requiresAction,
    required String helpRequestId,
    required String bookingId,
    required String userRole,
  }) {
    // Cross-user notifications are created by Cloud Functions from booking
    // state changes. Keep this compatibility hook as a no-op to avoid
    // client-side notification writes.
    return Future.value();
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
}
