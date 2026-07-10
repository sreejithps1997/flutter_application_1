import 'package:cloud_firestore/cloud_firestore.dart';

import '../features/bookings/data/booking_payment_repository.dart';

class PaymentReconciliationService {
  PaymentReconciliationService({FirebaseFirestore? firestore})
    : _repository = BookingPaymentRepository(firestore: firestore);

  final BookingPaymentRepository _repository;

  Future<void> approvePayment({
    required String bookingId,
    required String reviewedBy,
    required String reviewerRole,
    String? note,
  }) {
    return _repository.approvePayment(
      bookingId: bookingId,
      reviewedBy: reviewedBy,
      reviewerRole: reviewerRole,
      note: note,
    );
  }

  Future<void> rejectPayment({
    required String bookingId,
    required String reviewedBy,
    required String reviewerRole,
    required String reason,
  }) {
    return _repository.rejectPayment(
      bookingId: bookingId,
      reviewedBy: reviewedBy,
      reviewerRole: reviewerRole,
      reason: reason,
    );
  }
}
