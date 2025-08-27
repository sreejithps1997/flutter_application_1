import 'package:cloud_firestore/cloud_firestore.dart';

class VerificationTierManager {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Returns the tier string: 'new', 'verified', or 'police_verified'
  // Future<String> getUserVerificationTier(String uid) async {
  //   try {
  //     final snapshot = await _firestore
  //         .collection('users')
  //         .doc(uid)
  //         .collection('identityVerification')
  //         .get();

  //     final statusMap = <String, String>{};
  //     for (final doc in snapshot.docs) {
  //       statusMap[doc.id] = doc['status'] ?? 'pending';
  //     }

  //     return _determineTierFromStatus(statusMap);
  //   } catch (e) {
  //     print('❌ Failed to load verification status: $e');
  //     return 'new';
  //   }
  // }

  Future<String> getUserVerificationTier(String uid) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(uid)
          .collection('identityVerification')
          .get();

      final statusMap = <String, String>{};
      for (final doc in snapshot.docs) {
        statusMap[doc.id] = doc['status'] ?? 'pending';
      }

      final tier = determineTierFromStatus(statusMap);

      // ✅ Cache the tier under users/{uid}/verification.tier
      await _firestore.collection('users').doc(uid).set({
        'verification': {'tier': tier},
      }, SetOptions(merge: true));

      return tier;
    } catch (e) {
      print('❌ Failed to load verification status: $e');
      return 'new';
    }
  }

  /// Accepts a map of document keys and their verification statuses
  String determineTierFromStatus(Map<String, String> status) {
    final selfie = status['selfie'] == 'verified';
    final phone = status['phone'] == 'verified';
    final pan = status['pan'] == 'verified';
    final address =
        status['addressProof'] == 'verified' || status['address'] == 'verified';

    final govtId = [
      'aadhaar',
      'passport',
      'voter',
      'driving_license',
    ].any((idType) => status[idType] == 'verified');

    final police = status['backgroundCheck'] == 'verified';

    if (selfie && govtId && pan && address && police) {
      return 'police_verified';
    } else if (selfie && govtId && pan && address) {
      return 'verified';
    } else {
      return 'new';
    }
  }

  Future<bool> hasUploadedPanAndAadhaar(String uid) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('identityVerification')
        .get();

    bool hasPan = false;
    bool hasAadhaar = false;

    for (final doc in snapshot.docs) {
      if (doc.id == 'pan' && doc['status'] == 'verified') hasPan = true;
      if (doc.id == 'aadhaar' && doc['status'] == 'verified') hasAadhaar = true;
    }

    return hasPan && hasAadhaar;
  }

  Future<void> maybeStartVerificationTimer(String uid) async {
    final userRef = FirebaseFirestore.instance.collection('users').doc(uid);
    final verificationSnapshot = await userRef
        .collection('identityVerification')
        .get();

    final statusMap = <String, String>{};
    for (final doc in verificationSnapshot.docs) {
      statusMap[doc.id] = doc['status'] ?? 'pending';
    }

    final hasPan = statusMap['pan'] == 'verified';
    final hasAadhaar = statusMap['aadhaar'] == 'verified';

    if (hasPan && hasAadhaar) {
      final mainDoc = await userRef.get();
      final existingStart = mainDoc.data()?['verification']?['startAt'];

      if (existingStart == null) {
        await userRef.set({
          'verification': {'startAt': FieldValue.serverTimestamp()},
        }, SetOptions(merge: true));
      }
    }
  }
}
