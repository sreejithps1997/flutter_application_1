import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/referral_growth_repository.dart';
import '../domain/referral_share_audit.dart';

final referralGrowthRepositoryProvider = Provider<ReferralGrowthRepository>((
  ref,
) {
  return ReferralGrowthRepository();
});

final referralShareAuditProvider =
    StreamProvider.family<ReferralShareAudit, String>((ref, uid) {
      return ref.watch(referralGrowthRepositoryProvider).watchShareAudit(uid);
    });
