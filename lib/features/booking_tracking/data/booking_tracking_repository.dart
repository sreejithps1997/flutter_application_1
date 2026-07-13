import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../utils/location_helper.dart';
import '../domain/booking_tracking_status.dart';

class BookingTrackingRepository {
  BookingTrackingRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Stream<BookingTrackingStatus> watchTrackingStatus(String bookingId) {
    return _firestore.collection('bookings').doc(bookingId).snapshots().map((
      snapshot,
    ) {
      return BookingTrackingStatus.fromBooking(
        bookingId: snapshot.id,
        data: snapshot.data() ?? const <String, dynamic>{},
      );
    });
  }

  Future<void> updateWorkerLiveLocation(String bookingId) async {
    if (bookingId.trim().isEmpty) {
      throw StateError('Booking id is required.');
    }

    final bookingRef = _firestore.collection('bookings').doc(bookingId);
    final booking = (await bookingRef.get()).data();
    final tracking = BookingTrackingStatus.fromBooking(
      bookingId: bookingId,
      data: booking ?? const <String, dynamic>{},
    );
    if (!tracking.canShare) {
      throw StateError('Live location is available only before work starts.');
    }

    final workerPosition = await LocationHelper.getCurrentLocation();
    if (workerPosition == null) {
      throw StateError(
        'Turn on location permission and GPS to share location.',
      );
    }

    final distanceMeters = tracking.serviceLocation == null
        ? null
        : Geolocator.distanceBetween(
            workerPosition.latitude,
            workerPosition.longitude,
            tracking.serviceLocation!.latitude,
            tracking.serviceLocation!.longitude,
          );

    await bookingRef.update({
      'workerLiveLocationSharing': true,
      'workerLiveLocation': GeoPoint(
        workerPosition.latitude,
        workerPosition.longitude,
      ),
      'workerLiveLocationAccuracy': workerPosition.accuracy,
      if (distanceMeters != null)
        'workerLiveDistanceToServiceMeters': distanceMeters,
      'workerLiveLocationUpdatedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> stopWorkerLiveLocation(String bookingId) {
    if (bookingId.trim().isEmpty) {
      throw StateError('Booking id is required.');
    }
    return _firestore.collection('bookings').doc(bookingId).update({
      'workerLiveLocationSharing': false,
      'workerLiveLocationStoppedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> openWorkerLocation(BookingTrackingStatus tracking) async {
    final location = tracking.workerLocation;
    if (location == null) {
      throw StateError('Worker live location is not available yet.');
    }
    await _openMaps(location.latitude, location.longitude);
  }

  Future<void> openServiceLocation(BookingTrackingStatus tracking) async {
    final location = tracking.serviceLocation;
    if (location == null) {
      throw StateError('Service location is not available.');
    }
    await _openMaps(location.latitude, location.longitude);
  }

  Future<void> _openMaps(double latitude, double longitude) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude',
    );
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened) throw StateError('Unable to open maps.');
  }
}
