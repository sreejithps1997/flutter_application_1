import 'package:workable/services/referral_link_service.dart';

import '../domain/signup_referral_attribution.dart';

class SignupReferralRepository {
  String normalizeCode(String? value) {
    return ReferralLinkService.normalizeCode(value);
  }

  Future<String?> loadPendingCode() {
    return ReferralLinkService.loadPendingReferralCode();
  }

  Future<void> savePendingCode(String? code) {
    return ReferralLinkService.savePendingReferralCode(code);
  }

  Future<void> consumePendingCodeIfMatches(String? code) async {
    final clean = normalizeCode(code);
    if (clean.isEmpty) return;
    final pending = await loadPendingCode();
    if (pending == clean) {
      await ReferralLinkService.consumePendingReferralCode();
    }
  }

  SignupReferralAttribution attributionFromInput(
    String? input, {
    String source = 'signup_form',
  }) {
    final clean = normalizeCode(input);
    return SignupReferralAttribution(code: clean, source: source);
  }
}
