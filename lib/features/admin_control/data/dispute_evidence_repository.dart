import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

import '../domain/dispute_evidence_case.dart';

class DisputeEvidenceRepository {
  DisputeEvidenceRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    FirebaseStorage? storage,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance,
       _storage = storage ?? FirebaseStorage.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final FirebaseStorage _storage;

  Future<DisputeEvidenceCase> loadCase({
    required String collection,
    required String id,
  }) async {
    final targetCollection = _normalizeCollection(collection);
    final snapshot = await _firestore
        .collection(targetCollection)
        .doc(id)
        .get();
    if (!snapshot.exists) {
      throw StateError('Evidence request not found.');
    }
    final item = DisputeEvidenceCase.fromSnapshot(snapshot, targetCollection);
    _assertParticipant(item);
    return item;
  }

  Future<void> submitEvidence({
    required DisputeEvidenceCase item,
    required String note,
    required List<String> proofLinks,
  }) async {
    final cleanNote = note.trim();
    final cleanLinks = proofLinks
        .map((link) => link.trim())
        .where((link) => link.isNotEmpty)
        .toList();
    if (cleanNote.isEmpty && cleanLinks.isEmpty) {
      throw StateError('Add a note or proof link before submitting.');
    }
    _assertParticipant(item);
    await _firestore.collection(item.collection).doc(item.id).update({
      'evidenceStatus': 'submitted',
      'evidenceSubmissionNote': cleanNote,
      'evidenceProofLinks': cleanLinks,
      'evidenceSubmittedBy': _uid,
      'evidenceSubmittedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<List<String>> uploadEvidenceFiles({
    required DisputeEvidenceCase item,
    required List<XFile> files,
  }) async {
    _assertParticipant(item);
    final urls = <String>[];
    for (final file in files) {
      final bytes = await file.readAsBytes();
      final safeName = file.name.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
      final path =
          'disputeEvidence/${item.collection}/${item.id}/$_uid/${DateTime.now().millisecondsSinceEpoch}_$safeName';
      final ref = _storage.ref(path);
      await ref.putData(
        bytes,
        SettableMetadata(
          contentType: file.mimeType ?? 'application/octet-stream',
          customMetadata: {
            'caseCollection': item.collection,
            'caseId': item.id,
            'submittedBy': _uid,
          },
        ),
      );
      urls.add(await ref.getDownloadURL());
    }
    return urls;
  }

  String _normalizeCollection(String collection) {
    final value = collection.trim();
    if (value == 'bookings' || value == 'helpRequests') return value;
    throw StateError('Unsupported evidence target.');
  }

  void _assertParticipant(DisputeEvidenceCase item) {
    if (_uid == item.customerId || _uid == item.workerId) return;
    throw StateError('Only the customer or worker can submit evidence.');
  }

  String get _uid {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw StateError('Sign in required.');
    return uid;
  }
}
