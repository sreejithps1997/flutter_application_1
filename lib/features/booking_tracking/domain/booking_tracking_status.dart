import 'package:cloud_firestore/cloud_firestore.dart';

class BookingTrackingStatus {
  const BookingTrackingStatus({
    required this.bookingId,
    required this.status,
    required this.isSharing,
    required this.isStopped,
    required this.workerLocation,
    required this.serviceLocation,
    required this.distanceToServiceMeters,
    required this.accuracyMeters,
    required this.updatedAt,
    required this.stoppedAt,
  });

  final String bookingId;
  final String status;
  final bool isSharing;
  final bool isStopped;
  final GeoPoint? workerLocation;
  final GeoPoint? serviceLocation;
  final double? distanceToServiceMeters;
  final double? accuracyMeters;
  final DateTime? updatedAt;
  final DateTime? stoppedAt;

  bool get canShare => status == 'confirmed' || status == 'accepted';
  bool get isStale {
    if (!isSharing || updatedAt == null) return false;
    return DateTime.now().difference(updatedAt!).inMinutes >= 3;
  }

  String get customerTitle {
    if (isSharing && !isStale) return 'Worker is on the way';
    if (isSharing && isStale) return 'Location update delayed';
    if (isStopped) return 'Arrival sharing stopped';
    return 'Arrival tracking';
  }

  String get customerMessage {
    if (isSharing && !isStale) {
      return 'The worker is sharing live arrival updates.';
    }
    if (isSharing && isStale) {
      return 'The last worker location update is a few minutes old.';
    }
    if (isStopped) {
      return 'Live arrival sharing stopped for this booking.';
    }
    return 'The worker has not started live arrival sharing yet.';
  }

  factory BookingTrackingStatus.fromBooking({
    required String bookingId,
    required Map<String, dynamic> data,
  }) {
    return BookingTrackingStatus(
      bookingId: bookingId,
      status: data['status']?.toString().toLowerCase() ?? '',
      isSharing: data['workerLiveLocationSharing'] == true,
      isStopped:
          data['workerLiveLocationSharing'] == false &&
          data['workerLiveLocationStoppedAt'] != null,
      workerLocation: _geoPoint(data['workerLiveLocation']),
      serviceLocation: _serviceLocation(data),
      distanceToServiceMeters: _double(
        data['workerLiveDistanceToServiceMeters'],
      ),
      accuracyMeters: _double(data['workerLiveLocationAccuracy']),
      updatedAt: _date(data['workerLiveLocationUpdatedAt']),
      stoppedAt: _date(data['workerLiveLocationStoppedAt']),
    );
  }

  static GeoPoint? _serviceLocation(Map<String, dynamic> data) {
    final stored = _geoPoint(
      data['addressLocation'] ?? data['serviceLocation'],
    );
    if (stored != null) return stored;
    final lat = _double(
      data['addressLatitude'] ?? data['latitude'] ?? data['serviceLatitude'],
    );
    final lng = _double(
      data['addressLongitude'] ?? data['longitude'] ?? data['serviceLongitude'],
    );
    if (lat == null || lng == null || (lat == 0 && lng == 0)) return null;
    return GeoPoint(lat, lng);
  }

  static GeoPoint? _geoPoint(dynamic value) {
    if (value is GeoPoint) return value;
    return null;
  }

  static double? _double(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  static DateTime? _date(dynamic value) {
    if (value is Timestamp) return value.toDate();
    return null;
  }
}
