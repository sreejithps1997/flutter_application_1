import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/referral_share_audit.dart';

class ReferralGrowthRepository {
  ReferralGrowthRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Stream<ReferralShareAudit> watchShareAudit(String uid) {
    return _firestore
        .collection('referralShareEvents')
        .where('referrerId', isEqualTo: uid)
        .snapshots()
        .map((snapshot) => ReferralShareAudit.fromDocs(snapshot.docs));
  }

  Future<void> trackShare({
    required String uid,
    required String code,
    required String channel,
    required String inviteLink,
  }) async {
    final now = FieldValue.serverTimestamp();
    final eventRef = _firestore.collection('referralShareEvents').doc();
    final userRef = _firestore.collection('users').doc(uid);

    await _firestore.runTransaction((transaction) async {
      transaction.set(eventRef, {
        'referrerId': uid,
        'referralCode': code,
        'channel': channel,
        'inviteLink': inviteLink,
        'status': 'shared',
        'createdAt': now,
        'updatedAt': now,
      });
      transaction.set(userRef, {
        'referralShareCount': FieldValue.increment(1),
        'lastReferralShareAt': now,
        'lastReferralShareChannel': channel,
        'updatedAt': now,
      }, SetOptions(merge: true));
    });
  }
}
