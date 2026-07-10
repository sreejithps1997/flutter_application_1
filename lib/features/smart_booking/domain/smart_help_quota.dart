class SmartHelpQuota {
  const SmartHelpQuota({
    required this.dailyAllowance,
    required this.aiCallsUsed,
    required this.localAssessments,
    required this.blockedAiCalls,
    required this.estimatedTokens,
    required this.dateKey,
  });

  final int dailyAllowance;
  final int aiCallsUsed;
  final int localAssessments;
  final int blockedAiCalls;
  final int estimatedTokens;
  final String dateKey;

  int get remainingAiCalls {
    final remaining = dailyAllowance - aiCallsUsed;
    return remaining < 0 ? 0 : remaining;
  }

  bool get canUseAi => remainingAiCalls > 0;

  factory SmartHelpQuota.empty({
    required String dateKey,
    int dailyAllowance = 3,
  }) {
    return SmartHelpQuota(
      dailyAllowance: dailyAllowance,
      aiCallsUsed: 0,
      localAssessments: 0,
      blockedAiCalls: 0,
      estimatedTokens: 0,
      dateKey: dateKey,
    );
  }

  factory SmartHelpQuota.fromMap(
    Map<String, dynamic>? data, {
    required String dateKey,
    int dailyAllowance = 3,
  }) {
    if (data == null) {
      return SmartHelpQuota.empty(
        dateKey: dateKey,
        dailyAllowance: dailyAllowance,
      );
    }

    return SmartHelpQuota(
      dailyAllowance: _asInt(data['dailyAllowance'], dailyAllowance),
      aiCallsUsed: _asInt(data['aiCallsUsed'], 0),
      localAssessments: _asInt(data['localAssessments'], 0),
      blockedAiCalls: _asInt(data['blockedAiCalls'], 0),
      estimatedTokens: _asInt(data['estimatedTokens'], 0),
      dateKey: dateKey,
    );
  }

  static int _asInt(dynamic value, int fallback) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }
}
