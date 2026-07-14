import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../services/referral_link_service.dart';

class NeighbourhoodDealRepository {
  NeighbourhoodDealRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  Future<String> ensureReferralCode() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('Please sign in to share this deal.');
    }
    final userRef = _firestore.collection('users').doc(user.uid);
    final snapshot = await userRef.get();
    final existing = snapshot.data()?['referralCode']?.toString().trim();
    if (existing != null && existing.isNotEmpty) return existing;

    final code = _generateCode(user.uid);
    await userRef.set({
      'referralCode': code,
      'referralCodeCreatedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    return code;
  }

  Future<String> trackShare({
    required String channel,
    required String bookingId,
    required String service,
    required String area,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('Please sign in to share this deal.');
    }
    final code = await ensureReferralCode();
    final inviteLink = ReferralLinkService.inviteLink(code);
    final eventRef = _firestore.collection('neighbourhoodDealShares').doc();
    final userRef = _firestore.collection('users').doc(user.uid);
    final now = FieldValue.serverTimestamp();

    await _firestore.runTransaction((transaction) async {
      transaction.set(eventRef, {
        'referrerId': user.uid,
        'referralCode': code,
        'bookingId': bookingId,
        'service': service,
        'area': area,
        'channel': channel,
        'inviteLink': inviteLink,
        'status': 'shared',
        'joinedHomes': 1,
        'targetHomes': 4,
        'createdAt': now,
        'updatedAt': now,
      });
      transaction.set(userRef, {
        'neighbourhoodDealShareCount': FieldValue.increment(1),
        'lastNeighbourhoodDealShareAt': now,
        'lastNeighbourhoodDealShareChannel': channel,
        'updatedAt': now,
      }, SetOptions(merge: true));
    });

    return inviteLink;
  }

  String shareText({
    required String code,
    required String service,
    required String area,
  }) {
    final cleanService = service.trim().isEmpty
        ? 'home service'
        : service.trim();
    final cleanArea = area.trim().isEmpty ? 'our nearby area' : area.trim();
    return 'I booked $cleanService on Workable. If 3 nearby homes join near $cleanArea, everyone can unlock a neighbourhood deal after admin review. Join with my code $code: ${ReferralLinkService.inviteLink(code)}';
  }

  String _generateCode(String uid) {
    final base = uid.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toUpperCase();
    final suffix = DateTime.now().millisecondsSinceEpoch
        .toRadixString(36)
        .toUpperCase();
    return 'WB${base.substring(0, base.length < 4 ? base.length : 4)}$suffix';
  }
}
