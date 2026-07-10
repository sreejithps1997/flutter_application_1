import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';

import '../domain/booking_draft.dart';

class BookingRepository {
  BookingRepository({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  Future<String> createBooking(BookingDraft draft) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      throw StateError('You must be logged in to book a service.');
    }

    final hasWorker = draft.workerId?.trim().isNotEmpty ?? false;
    String status = 'pending_assignment';
    String? workerId;
    String? workerName;
    Map<String, dynamic>? selectedWorker;

    if (hasWorker) {
      final worker = await _getWorker(draft.workerId!.trim());
      if (!isWorkerEligible(worker)) {
        throw StateError(
          'That worker is no longer available or not eligible. Please choose another professional.',
        );
      }

      final scheduleError = _validateWorkerSchedule(worker!, draft.scheduledAt);
      final radiusError = _validateServiceRadius(worker, draft.selectedAddress);
      final validationError = scheduleError ?? radiusError;
      if (validationError != null) {
        throw StateError(validationError);
      }

      workerId = draft.workerId!.trim();
      selectedWorker = worker;
      workerName =
          (worker['name'] ?? worker['fullName'] ?? draft.workerName ?? '')
              .toString()
              .trim();
      status = 'pending';
    }

    final customerProfile = await _getCustomerProfile(currentUser.uid);
    final issueText = draft.issue.trim();
    final serviceName = _serviceName(selectedWorker, issueText);
    final price = _priceFromWorker(selectedWorker);
    final now = FieldValue.serverTimestamp();

    final bookingData = <String, dynamic>{
      'customerId': currentUser.uid,
      'customerName':
          customerProfile['name'] ??
          customerProfile['fullName'] ??
          currentUser.displayName ??
          'Customer',
      'customerPhone':
          customerProfile['phone'] ??
          customerProfile['phoneNumber'] ??
          currentUser.phoneNumber,
      'service': serviceName,
      'serviceType': serviceName,
      'issue': issueText,
      'issueDescription': issueText,
      'address': draft.address.trim(),
      'preferredDate': draft.preferredDate.trim(),
      'preferredTime': draft.preferredTime.trim(),
      if (draft.scheduledAt != null)
        'scheduledAt': Timestamp.fromDate(draft.scheduledAt!),
      'payment': 'Cash',
      'paymentMethod': 'Cash',
      'paymentStatus': 'not_started',
      if (price != null) 'price': price,
      if (price != null) 'estimatedPrice': price,
      'rating': null,
      'source': draft.source,
      'createdAt': now,
      'updatedAt': now,
      'status': status,
      'workerId': workerId,
      'workerName': workerName,
    };

    final selectedAddress = draft.selectedAddress;
    if (selectedAddress != null) {
      bookingData.addAll({
        'addressId': selectedAddress['id'],
        'addressLabel': selectedAddress['label'],
        'addressArea': selectedAddress['area'],
        'addressPincode': selectedAddress['pincode'],
        'addressLandmark': selectedAddress['landmark'],
        'addressContact': selectedAddress['contact'],
        'addressLatitude': selectedAddress['latitude'],
        'addressLongitude': selectedAddress['longitude'],
        if (selectedAddress['location'] != null)
          'addressLocation': selectedAddress['location'],
      });
    }

    final bookingRef = await _firestore.collection('bookings').add(bookingData);
    return bookingRef.id;
  }

  Future<Map<String, dynamic>?> _getWorker(String id) async {
    final snapshot = await _firestore.collection('workers').doc(id).get();
    return snapshot.data();
  }

  Future<Map<String, dynamic>> _getCustomerProfile(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    return doc.data() ?? {};
  }

  static bool isWorkerEligible(Map<String, dynamic>? worker) {
    if (worker == null) return false;
    final visible = (worker['visibleToUsers'] ?? false) == true;
    final image = (worker['imageUrl'] ?? '').toString().trim().isNotEmpty;
    final selfieOk = (worker['verification']?['selfie'] ?? '') == 'verified';
    final hasLocation = worker['location'] != null;
    final disabled = (worker['accountDisabled'] ?? false) == true;

    return visible && !disabled && image && selfieOk && hasLocation;
  }

  String _serviceName(Map<String, dynamic>? worker, String issueText) {
    final skills = worker?['skills'];
    if (skills is List && skills.isNotEmpty) {
      final firstSkill = skills.first.toString().trim();
      if (firstSkill.isNotEmpty) return firstSkill;
    }
    final serviceType = worker?['serviceType']?.toString().trim();
    if (serviceType != null && serviceType.isNotEmpty) return serviceType;
    return issueText.length > 32
        ? '${issueText.substring(0, 32)}...'
        : issueText;
  }

  num? _priceFromWorker(Map<String, dynamic>? worker) {
    final pricing = worker?['pricing'];
    if (pricing is num) return pricing;
    final text = pricing?.toString() ?? '';
    final match = RegExp(r'\d+(\.\d+)?').firstMatch(text);
    if (match == null) return null;
    return num.tryParse(match.group(0) ?? '');
  }

  String? _validateWorkerSchedule(
    Map<String, dynamic> worker,
    DateTime? scheduledAt,
  ) {
    if (worker['isAvailable'] == false) {
      return 'This worker is currently not accepting new jobs.';
    }

    if (scheduledAt == null) {
      return 'Please select a valid date and time.';
    }
    if (scheduledAt.isBefore(DateTime.now())) {
      return 'Please select a future date and time.';
    }

    final schedule = Map<String, dynamic>.from(worker['schedule'] ?? {});
    final workingDays = List<int>.from(schedule['workingDays'] ?? const []);
    if (workingDays.isNotEmpty && !workingDays.contains(scheduledAt.weekday)) {
      return 'This worker is not available on the selected day.';
    }

    if (schedule['isFlexible'] == true) return null;

    final start = _parseMinutes(schedule['startTime']);
    final end = _parseMinutes(schedule['endTime']);
    if (start == null || end == null) return null;

    final selectedMinutes = scheduledAt.hour * 60 + scheduledAt.minute;
    if (selectedMinutes < start || selectedMinutes > end) {
      return 'Please choose a time between ${schedule['startTime']} and ${schedule['endTime']}.';
    }

    return null;
  }

  int? _parseMinutes(dynamic value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty) return null;

    final match = RegExp(
      r'^(\d{1,2})(?::(\d{2}))?\s*(AM|PM)?$',
      caseSensitive: false,
    ).firstMatch(text);
    if (match == null) return null;

    var hour = int.tryParse(match.group(1) ?? '');
    final minute = int.tryParse(match.group(2) ?? '0') ?? 0;
    final period = match.group(3)?.toUpperCase();
    if (hour == null || hour > 23 || minute > 59) return null;
    if (period == 'PM' && hour < 12) hour += 12;
    if (period == 'AM' && hour == 12) hour = 0;
    return hour * 60 + minute;
  }

  String? _validateServiceRadius(
    Map<String, dynamic> worker,
    Map<String, dynamic>? selectedAddress,
  ) {
    final addressLocation = _addressGeoPoint(selectedAddress);
    final workerLocation = worker['location'];
    if (addressLocation == null || workerLocation is! GeoPoint) return null;

    final radiusKm = _asDouble(worker['serviceRadius']) ?? 2;
    final distanceKm =
        Geolocator.distanceBetween(
          workerLocation.latitude,
          workerLocation.longitude,
          addressLocation.latitude,
          addressLocation.longitude,
        ) /
        1000;

    if (distanceKm > radiusKm) {
      return 'This address is ${distanceKm.toStringAsFixed(1)} km away, outside the worker service radius of ${radiusKm.toStringAsFixed(0)} km.';
    }
    return null;
  }

  GeoPoint? _addressGeoPoint(Map<String, dynamic>? address) {
    if (address == null) return null;
    final location = address['location'];
    if (location is GeoPoint) return location;
    final lat = _asDouble(address['latitude'] ?? address['addressLatitude']);
    final lng = _asDouble(address['longitude'] ?? address['addressLongitude']);
    if (lat == null || lng == null) return null;
    return GeoPoint(lat, lng);
  }

  double? _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }
}
