import 'package:cloud_firestore/cloud_firestore.dart';

import 'verification_tier_manager.dart';

class WorkerVisibilityService {
  WorkerVisibilityService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<void> syncWorkerVisibility(String uid) async {
    if (uid.trim().isEmpty) return;

    final workerRef = _firestore.collection('workers').doc(uid);
    final workerDoc = await workerRef.get();
    if (!workerDoc.exists) return;

    final userDoc = await _firestore.collection('users').doc(uid).get();
    final userData = userDoc.data() ?? {};
    final workerData = workerDoc.data() ?? {};
    final statuses = await _loadVerificationStatuses(uid);
    final tier = VerificationTierManager().determineTierFromStatus(statuses);

    final imageUrl = _firstNonEmpty([
      workerData['imageUrl'],
      workerData['profileImageUrl'],
      userData['imageUrl'],
      userData['profileImageUrl'],
      userData['profileImage'],
      userData['photoUrl'],
    ]);
    final location = _resolveLocation(workerData);
    final hasLocation = location != null;
    final hasProfileImage = imageUrl != null && imageUrl.isNotEmpty;
    final selfieVerified = statuses['selfie'] == 'verified';
    final disabled =
        workerData['accountDisabled'] == true ||
        workerData['accountStatus'] == 'disabled';
    final visibleToUsers =
        hasProfileImage && selfieVerified && hasLocation && !disabled;

    await workerRef.set({
      if (hasProfileImage) ...{
        'imageUrl': imageUrl,
        'profileImageUrl': imageUrl,
      },
      if (hasLocation) 'location': location,
      'visibleToUsers': visibleToUsers,
      'visibilityUpdatedAt': FieldValue.serverTimestamp(),
      'verification': {
        ...statuses,
        'tier': tier,
        'selfie': statuses['selfie'] ?? 'incomplete',
        'updatedAt': FieldValue.serverTimestamp(),
      },
    }, SetOptions(merge: true));

    await _firestore.collection('users').doc(uid).set({
      'verification': {'tier': tier},
    }, SetOptions(merge: true));
  }

  Future<Map<String, String>> _loadVerificationStatuses(String uid) async {
    final snapshot = await _firestore
        .collection('users')
        .doc(uid)
        .collection('identityVerification')
        .get();

    final statuses = <String, String>{};
    for (final doc in snapshot.docs) {
      statuses[doc.id] = doc.data()['status']?.toString() ?? 'incomplete';
    }
    return statuses;
  }

  String? _firstNonEmpty(List<dynamic> values) {
    for (final value in values) {
      final text = value?.toString().trim();
      if (text != null && text.isNotEmpty && text.toLowerCase() != 'null') {
        return text;
      }
    }
    return null;
  }

  GeoPoint? _resolveLocation(Map<String, dynamic> workerData) {
    final location = workerData['location'];
    if (location is GeoPoint) return location;

    if (location is String) {
      final parts = location.split(',');
      if (parts.length == 2) {
        final lat = double.tryParse(parts[0].trim());
        final lng = double.tryParse(parts[1].trim());
        if (_isUsableCoordinate(lat, lng)) return GeoPoint(lat!, lng!);
      }
    }

    final lat = _asDouble(workerData['latitude']);
    final lng = _asDouble(workerData['longitude']);
    if (_isUsableCoordinate(lat, lng)) return GeoPoint(lat!, lng!);

    return null;
  }

  double? _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  bool _isUsableCoordinate(double? lat, double? lng) {
    if (lat == null || lng == null) return false;
    if (lat == 0.0 && lng == 0.0) return false;
    return lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180;
  }
}
