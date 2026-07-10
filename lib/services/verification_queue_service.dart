import 'package:cloud_firestore/cloud_firestore.dart';

class VerificationQueueService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static Future<void> createVerificationRequest({
    required String uid,

    required String documentType,

    required Map<String, dynamic> userData,

    required Map<String, dynamic> documentData,
  }) async {
    final requestId = '${uid}_$documentType';

    final queueData = {
      // Core
      'requestId': requestId,
      'uid': uid,
      'documentType': documentType,

      // Status
      'status': 'pending',

      // Timestamps
      'submittedAt': Timestamp.now(),
      'reviewedAt': null,

      // Admin
      'reviewedBy': null,
      'rejectionReason': null,

      // User info
      'userName': userData['name'] ?? '',
      'email': userData['email'] ?? '',
      'phoneNumber': userData['phoneNumber'] ?? '',
      'profileImageUrl': userData['profileImageUrl'] ?? '',

      // Actual document data
      'number': documentData['number'],
      'name': documentData['name'],
      'imageUrl': documentData['imageUrl'],
      'documentId': documentData['documentId'],
      'documentData': documentData,
    };

    await _firestore
        .collection('adminVerificationQueue')
        .doc(requestId)
        .set(queueData);
  }
}
