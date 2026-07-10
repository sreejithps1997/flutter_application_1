import 'package:cloud_firestore/cloud_firestore.dart';

class BookingActionRepository {
  BookingActionRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<void> acceptBooking(String bookingId) {
    return _updateBooking(bookingId, {
      'status': 'confirmed',
      'acceptedAt': FieldValue.serverTimestamp(),
      'timeline.accepted': FieldValue.serverTimestamp(),
    });
  }

  Future<void> declineBooking(String bookingId, {String by = 'worker'}) {
    return _updateBooking(bookingId, {
      'status': 'cancelled',
      'cancelledBy': by,
      'declinedAt': FieldValue.serverTimestamp(),
      'cancelledAt': FieldValue.serverTimestamp(),
      'timeline.cancelled': FieldValue.serverTimestamp(),
    });
  }

  Future<void> startWork(String bookingId) {
    return _updateBooking(bookingId, {
      'status': 'in_progress',
      'workStartedAt': FieldValue.serverTimestamp(),
      'timeline.in_progress': FieldValue.serverTimestamp(),
    });
  }

  Future<void> requestCompletion(String bookingId) {
    return _updateBooking(bookingId, {
      'status': 'completion_requested',
      'paymentStatus': 'not_started',
      'completionRequestedAt': FieldValue.serverTimestamp(),
      'timeline.completion_requested': FieldValue.serverTimestamp(),
    });
  }

  Future<void> confirmCustomerCompletion(String bookingId) {
    return _updateBooking(bookingId, {
      'status': 'payment_due',
      'paymentStatus': 'payment_due',
      'customerConfirmedCompletionAt': FieldValue.serverTimestamp(),
      'timeline.payment_due': FieldValue.serverTimestamp(),
    });
  }

  Future<void> disputeCompletion(String bookingId, {String? reason}) {
    return _updateBooking(bookingId, {
      'status': 'completion_disputed',
      if (reason != null && reason.trim().isNotEmpty)
        'completionDisputeReason': reason.trim(),
      'completionDisputedAt': FieldValue.serverTimestamp(),
      'timeline.completion_disputed': FieldValue.serverTimestamp(),
    });
  }

  Future<void> cancelBooking(String bookingId, {String by = 'customer'}) {
    return _updateBooking(bookingId, {
      'status': 'cancelled',
      'cancelledBy': by,
      'cancelledAt': FieldValue.serverTimestamp(),
      'timeline.cancelled': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _updateBooking(
    String bookingId,
    Map<String, dynamic> data,
  ) async {
    if (bookingId.trim().isEmpty) {
      throw StateError('Booking id is required.');
    }

    final bookingRef = _firestore.collection('bookings').doc(bookingId);
    await bookingRef.update({
      ...data,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    final booking = (await bookingRef.get()).data();
    await _syncSourceHelpRequest(bookingRef, data, booking);
  }

  Future<void> _syncSourceHelpRequest(
    DocumentReference<Map<String, dynamic>> bookingRef,
    Map<String, dynamic> data,
    Map<String, dynamic>? booking,
  ) async {
    final helpRequestId = booking?['sourceHelpRequestId']?.toString();
    if (helpRequestId == null || helpRequestId.trim().isEmpty) return;

    final status = data['status']?.toString();
    final helpStatus = status == 'confirmed' ? 'accepted' : status;
    await _firestore.collection('helpRequests').doc(helpRequestId).update({
      if (helpStatus != null) 'status': helpStatus,
      if (data.containsKey('paymentStatus'))
        'paymentStatus': data['paymentStatus'],
      for (final entry in data.entries)
        if (entry.key.endsWith('At') || entry.key.startsWith('timeline.'))
          entry.key: entry.value,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
