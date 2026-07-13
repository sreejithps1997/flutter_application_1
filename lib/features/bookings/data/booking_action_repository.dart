import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';

import '../../../utils/location_helper.dart';

class BookingActionRepository {
  BookingActionRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;
  static const double startWorkArrivalRadiusMeters = 120;

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

  Future<void> startWork(String bookingId) async {
    if (bookingId.trim().isEmpty) {
      throw StateError('Booking id is required.');
    }

    final bookingRef = _firestore.collection('bookings').doc(bookingId);
    final precheckBooking = (await bookingRef.get()).data();
    final serviceLocation = _bookingServiceLocation(precheckBooking);
    if (serviceLocation == null) {
      throw StateError(
        'Exact service location is missing. Add or confirm the customer location before starting work.',
      );
    }

    final workerPosition = await LocationHelper.getCurrentLocation();
    if (workerPosition == null) {
      throw StateError(
        'Turn on location permission and GPS to start work at the customer location.',
      );
    }

    final distanceMeters = Geolocator.distanceBetween(
      workerPosition.latitude,
      workerPosition.longitude,
      serviceLocation.latitude,
      serviceLocation.longitude,
    );
    if (distanceMeters > startWorkArrivalRadiusMeters) {
      throw StateError(
        'You are ${distanceMeters.toStringAsFixed(0)} m away from the service location. Start work only after reaching the customer.',
      );
    }

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(bookingRef);
      final booking = snapshot.data();
      final status = booking?['status']?.toString().toLowerCase() ?? '';
      if (!snapshot.exists || (status != 'confirmed' && status != 'accepted')) {
        throw StateError('Only accepted jobs can be started.');
      }
      if (_bookingServiceLocation(booking) == null) {
        throw StateError('Exact service location is missing.');
      }

      final data = {
        'status': 'in_progress',
        'workStartedAt': FieldValue.serverTimestamp(),
        'startLocationVerified': true,
        'startWorkDistanceMeters': distanceMeters,
        'startWorkArrivalRadiusMeters': startWorkArrivalRadiusMeters,
        'workerStartLocation': GeoPoint(
          workerPosition.latitude,
          workerPosition.longitude,
        ),
        'workerStartLocationAccuracy': workerPosition.accuracy,
        'workerStartLocationVerifiedAt': FieldValue.serverTimestamp(),
        'timeline.in_progress': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      transaction.update(bookingRef, data);
    });

    final booking = (await bookingRef.get()).data();
    await _syncSourceHelpRequest(bookingRef, {
      'status': 'in_progress',
      'workStartedAt': FieldValue.serverTimestamp(),
      'startLocationVerified': true,
      'startWorkDistanceMeters': distanceMeters,
      'startWorkArrivalRadiusMeters': startWorkArrivalRadiusMeters,
      'workerStartLocation': GeoPoint(
        workerPosition.latitude,
        workerPosition.longitude,
      ),
      'workerStartLocationAccuracy': workerPosition.accuracy,
      'workerStartLocationVerifiedAt': FieldValue.serverTimestamp(),
      'timeline.in_progress': FieldValue.serverTimestamp(),
    }, booking);
  }

  Future<void> customerConfirmWorkerArrived(String bookingId) {
    return _startWorkWithoutGps(
      bookingId,
      initiatedBy: 'customer',
      reason: 'Customer confirmed worker arrived at service location.',
      extra: {'customerConfirmedWorkerArrivedAt': FieldValue.serverTimestamp()},
    );
  }

  Future<void> adminOverrideStartWork(
    String bookingId, {
    required String adminId,
    required String reason,
    required String customerConfirmationNote,
  }) {
    final cleanReason = reason.trim();
    final cleanNote = customerConfirmationNote.trim();
    if (cleanReason.isEmpty) {
      throw StateError('Admin override reason is required.');
    }
    if (cleanNote.isEmpty) {
      throw StateError('Customer confirmation note is required.');
    }
    return _startWorkWithoutGps(
      bookingId,
      initiatedBy: 'admin',
      reason: cleanReason,
      extra: {
        'adminStartOverride': true,
        'adminStartOverrideBy': adminId,
        'adminStartOverrideReason': cleanReason,
        'adminStartOverrideCustomerConfirmation': cleanNote,
        'adminStartOverrideAt': FieldValue.serverTimestamp(),
      },
    );
  }

  Future<void> _startWorkWithoutGps(
    String bookingId, {
    required String initiatedBy,
    required String reason,
    required Map<String, dynamic> extra,
  }) async {
    if (bookingId.trim().isEmpty) {
      throw StateError('Booking id is required.');
    }

    final bookingRef = _firestore.collection('bookings').doc(bookingId);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(bookingRef);
      final booking = snapshot.data();
      final status = booking?['status']?.toString().toLowerCase() ?? '';
      if (!snapshot.exists || (status != 'confirmed' && status != 'accepted')) {
        throw StateError('Only accepted jobs can be started.');
      }

      transaction.update(bookingRef, {
        'status': 'in_progress',
        'workStartedAt': FieldValue.serverTimestamp(),
        'startLocationVerified': false,
        'startWorkManualOverride': true,
        'startWorkInitiatedBy': initiatedBy,
        'startWorkOverrideReason': reason,
        ...extra,
        'timeline.in_progress': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });

    final booking = (await bookingRef.get()).data();
    await _syncSourceHelpRequest(bookingRef, {
      'status': 'in_progress',
      'workStartedAt': FieldValue.serverTimestamp(),
      'startLocationVerified': false,
      'startWorkManualOverride': true,
      'startWorkInitiatedBy': initiatedBy,
      'startWorkOverrideReason': reason,
      ...extra,
      'timeline.in_progress': FieldValue.serverTimestamp(),
    }, booking);
  }

  Future<void> requestCompletion(String bookingId) async {
    if (bookingId.trim().isEmpty) {
      throw StateError('Booking id is required.');
    }

    final bookingRef = _firestore.collection('bookings').doc(bookingId);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(bookingRef);
      final booking = snapshot.data();
      final status = booking?['status']?.toString().toLowerCase() ?? '';
      final hasStart =
          booking?['workStartedAt'] != null ||
          (booking?['timeline'] is Map &&
              (booking?['timeline'] as Map)['in_progress'] != null);
      if (!snapshot.exists || status != 'in_progress' || !hasStart) {
        throw StateError('Start work before requesting completion.');
      }

      final data = {
        'status': 'completion_requested',
        'paymentStatus': 'not_started',
        'workCompletedAt': FieldValue.serverTimestamp(),
        'completionRequestedAt': FieldValue.serverTimestamp(),
        'timeline.work_completed': FieldValue.serverTimestamp(),
        'timeline.completion_requested': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      transaction.update(bookingRef, data);
    });

    final booking = (await bookingRef.get()).data();
    await _syncSourceHelpRequest(bookingRef, {
      'status': 'completion_requested',
      'paymentStatus': 'not_started',
      'workCompletedAt': FieldValue.serverTimestamp(),
      'completionRequestedAt': FieldValue.serverTimestamp(),
      'timeline.work_completed': FieldValue.serverTimestamp(),
      'timeline.completion_requested': FieldValue.serverTimestamp(),
    }, booking);
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

  GeoPoint? _bookingServiceLocation(Map<String, dynamic>? booking) {
    if (booking == null) return null;
    final location = booking['addressLocation'] ?? booking['serviceLocation'];
    if (location is GeoPoint && _isUsableCoordinate(location)) return location;

    final lat = _asDouble(
      booking['addressLatitude'] ??
          booking['latitude'] ??
          booking['serviceLatitude'],
    );
    final lng = _asDouble(
      booking['addressLongitude'] ??
          booking['longitude'] ??
          booking['serviceLongitude'],
    );
    if (lat == null || lng == null) return null;

    final point = GeoPoint(lat, lng);
    return _isUsableCoordinate(point) ? point : null;
  }

  bool _isUsableCoordinate(GeoPoint point) {
    if (point.latitude == 0 && point.longitude == 0) return false;
    return point.latitude >= -90 &&
        point.latitude <= 90 &&
        point.longitude >= -180 &&
        point.longitude <= 180;
  }

  double? _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }
}
