import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../domain/admin_referral_reward.dart';

class AdminReferralRepository {
  AdminReferralRepository({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _functions =
           functions ?? FirebaseFunctions.instanceFor(region: 'us-central1');

  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  Stream<List<AdminReferralReward>> watchReferralRewards() {
    return _firestore.collection('referrals').limit(250).snapshots().map((
      snapshot,
    ) {
      final items = snapshot.docs
          .map(AdminReferralReward.fromSnapshot)
          .toList();
      items.sort((a, b) {
        final statusCompare = _rank(a).compareTo(_rank(b));
        if (statusCompare != 0) return statusCompare;
        final aDate = a.updatedAt ?? a.createdAt ?? DateTime(1970);
        final bDate = b.updatedAt ?? b.createdAt ?? DateTime(1970);
        return bDate.compareTo(aDate);
      });
      return items;
    });
  }

  Future<void> reviewReward({
    required AdminReferralReward referral,
    required String decision,
    required num rewardAmount,
    String? note,
  }) async {
    await _functions.httpsCallable('reviewReferralReward').call({
      'referralId': referral.id,
      'decision': decision,
      'rewardAmount': rewardAmount,
      'note': note?.trim() ?? '',
    });
  }

  int _rank(AdminReferralReward referral) {
    if (referral.rewardStatus == 'ready_for_credit') return 0;
    if (referral.rewardStatus == 'approved') return 1;
    if (referral.status == 'pending_worker_onboarding') return 2;
    if (referral.rewardStatus == 'locked') return 3;
    if (referral.rewardStatus == 'rejected') return 4;
    if (referral.rewardStatus == 'credited') return 5;
    return 6;
  }
}
