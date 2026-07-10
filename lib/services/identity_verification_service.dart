import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

import '../models/verification_document_config.dart';
import 'notification_service.dart';
import 'verification_queue_service.dart';
import 'worker_visibility_service.dart';

class IdentityVerificationService {
  IdentityVerificationService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _firestore = firestore ?? FirebaseFirestore.instance,
       _storage = storage ?? FirebaseStorage.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  String? get currentUid => _auth.currentUser?.uid;

  CollectionReference<Map<String, dynamic>> _verificationCollection(
    String uid,
  ) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('identityVerification');
  }

  Future<Map<String, dynamic>?> loadVerificationStatus(
    String documentId,
  ) async {
    final uid = currentUid;
    if (uid == null) return null;

    final doc = await _verificationCollection(uid).doc(documentId).get();
    return doc.data();
  }

  Future<Map<String, dynamic>> loadCurrentUserData() async {
    final uid = currentUid;
    if (uid == null) return {};

    final userDoc = await _firestore.collection('users').doc(uid).get();
    return userDoc.data() ?? {};
  }

  Future<File> compressImage(File file) async {
    final targetPath =
        '${file.parent.path}/compressed_${file.uri.pathSegments.last}';

    final result = await FlutterImageCompress.compressAndGetFile(
      file.absolute.path,
      targetPath,
      quality: 85,
      minWidth: 1024,
      minHeight: 1024,
    );

    return result != null ? File(result.path) : file;
  }

  Future<void> deleteImageFromUrl(String? imageUrl) async {
    if (imageUrl == null || imageUrl.isEmpty) return;

    final oldRef = _storage.refFromURL(imageUrl);
    await oldRef.delete();
  }

  Future<String?> uploadVerificationImage({
    required VerificationDocumentConfig config,
    required File? imageFile,
  }) async {
    final uid = currentUid;
    if (uid == null || imageFile == null) return null;

    final storageRef = _storage.ref(
      'users/$uid/identityVerification/${config.storageFolder}/${DateTime.now().millisecondsSinceEpoch}.jpg',
    );

    final uploadTask = await storageRef.putFile(imageFile);
    return uploadTask.ref.getDownloadURL();
  }

  Future<Map<String, dynamic>> submitVerificationDocument({
    required VerificationDocumentConfig config,
    required String? uploadMethod,
    File? imageFile,
    Map<String, dynamic> fields = const {},
    bool replaceExistingImage = false,
    Map<String, dynamic>? existingData,
  }) async {
    final uid = currentUid;
    if (uid == null) {
      throw StateError('You must be signed in to upload.');
    }

    if (replaceExistingImage) {
      await deleteImageFromUrl(existingData?['imageUrl']?.toString());
    }

    final downloadUrl = await uploadVerificationImage(
      config: config,
      imageFile: imageFile,
    );

    final submittedAt = Timestamp.now();
    final documentData = {
      'type': config.type,
      'documentId': config.documentId,
      'documentName': config.documentName,
      ...fields,
      'status': 'pending',
      'submittedAt': submittedAt,
      'updatedAt': submittedAt,
      'verificationMethod': uploadMethod,
      if (downloadUrl != null) 'imageUrl': downloadUrl,
    };

    await _verificationCollection(
      uid,
    ).doc(config.documentId).set(documentData, SetOptions(merge: true));

    final userData = await loadCurrentUserData();

    await VerificationQueueService.createVerificationRequest(
      uid: uid,
      documentType: config.documentId,
      userData: userData,
      documentData: documentData,
    );

    await NotificationService.resolveRejectedNotifications(
      uid: uid,
      documentId: config.documentId,
    );

    await WorkerVisibilityService(
      firestore: _firestore,
    ).syncWorkerVisibility(uid);

    return documentData;
  }
}
