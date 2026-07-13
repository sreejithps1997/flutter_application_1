class SignupReferralAttribution {
  const SignupReferralAttribution({required this.code, required this.source});

  final String code;
  final String source;

  bool get hasCode => code.isNotEmpty;

  Map<String, dynamic> toUserFields() {
    if (!hasCode) return const {};
    return {
      'referredByCode': code,
      'referralStatus': 'pending_backend_check',
      'referralSource': source,
      'referralCapturedAtClient': DateTime.now().toIso8601String(),
    };
  }
}
