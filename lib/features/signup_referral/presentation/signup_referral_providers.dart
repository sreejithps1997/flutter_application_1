import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/signup_referral_repository.dart';

final signupReferralRepositoryProvider = Provider<SignupReferralRepository>((
  ref,
) {
  return SignupReferralRepository();
});

final pendingSignupReferralCodeProvider = FutureProvider<String?>((ref) {
  return ref.watch(signupReferralRepositoryProvider).loadPendingCode();
});
