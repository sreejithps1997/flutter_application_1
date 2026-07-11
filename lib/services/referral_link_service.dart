import 'package:shared_preferences/shared_preferences.dart';

class ReferralLinkService {
  static const _pendingReferralCodeKey = 'pending_referral_code';
  static const inviteHost = 'workable.app';

  static String normalizeCode(String? value) {
    return (value ?? '')
        .trim()
        .replaceAll(RegExp(r'[^a-zA-Z0-9]'), '')
        .toUpperCase();
  }

  static String inviteLink(String code) {
    return 'https://$inviteHost/invite?ref=${Uri.encodeComponent(code)}';
  }

  static String appInviteLink(String code) {
    return 'workable://invite?ref=${Uri.encodeComponent(code)}';
  }

  static Future<void> savePendingReferralCode(String? code) async {
    final clean = normalizeCode(code);
    if (clean.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pendingReferralCodeKey, clean);
  }

  static Future<String?> loadPendingReferralCode() async {
    final prefs = await SharedPreferences.getInstance();
    final clean = normalizeCode(prefs.getString(_pendingReferralCodeKey));
    return clean.isEmpty ? null : clean;
  }

  static Future<String?> consumePendingReferralCode() async {
    final prefs = await SharedPreferences.getInstance();
    final clean = normalizeCode(prefs.getString(_pendingReferralCodeKey));
    if (clean.isEmpty) return null;
    await prefs.remove(_pendingReferralCodeKey);
    return clean;
  }
}
