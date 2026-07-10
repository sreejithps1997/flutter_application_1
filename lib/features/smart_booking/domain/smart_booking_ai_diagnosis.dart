class SmartBookingAiDiagnosis {
  const SmartBookingAiDiagnosis({
    required this.category,
    required this.urgency,
    required this.summary,
    required this.questions,
    required this.aiUsed,
    required this.providerConfigured,
    required this.quotaReserved,
    required this.priceRange,
    required this.safetyNote,
    required this.recommendedPath,
    required this.confidence,
    required this.cached,
    this.cacheKey,
    this.remainingSmartHelps,
  });

  final String category;
  final String urgency;
  final String summary;
  final List<String> questions;
  final bool aiUsed;
  final bool providerConfigured;
  final bool quotaReserved;
  final String priceRange;
  final String safetyNote;
  final String recommendedPath;
  final String confidence;
  final bool cached;
  final String? cacheKey;
  final int? remainingSmartHelps;

  factory SmartBookingAiDiagnosis.fromCallableData(dynamic value) {
    final data = _asMap(value);
    final diagnosis = _asMap(data['diagnosis']);
    final quota = _asMap(data['quota']);

    return SmartBookingAiDiagnosis(
      category: _asString(diagnosis['category'], 'General Help'),
      urgency: _asString(diagnosis['urgency'], 'Normal'),
      summary: _asString(
        diagnosis['summary'],
        'Workable checked this request and prepared the next questions.',
      ),
      questions: _asStringList(diagnosis['questions']),
      aiUsed: data['aiUsed'] == true,
      providerConfigured: data['providerConfigured'] == true,
      quotaReserved: data['quotaReserved'] == true || quota.isNotEmpty,
      priceRange: _asString(diagnosis['priceRange'], 'Unknown'),
      safetyNote: _asString(diagnosis['safetyNote'], ''),
      recommendedPath: _asString(diagnosis['recommendedPath'], 'help_request'),
      confidence: _asString(diagnosis['confidence'], 'medium'),
      cached: data['cached'] == true,
      cacheKey: _optionalString(data['cacheKey']),
      remainingSmartHelps: quota['remaining'] is num
          ? (quota['remaining'] as num).toInt()
          : null,
    );
  }

  Map<String, dynamic> toMetadata() {
    return {
      'category': category,
      'urgency': urgency,
      'summary': summary,
      'questions': questions,
      'priceRange': priceRange,
      'safetyNote': safetyNote,
      'recommendedPath': recommendedPath,
      'confidence': confidence,
      'aiUsed': aiUsed,
      'providerConfigured': providerConfigured,
      'quotaReserved': quotaReserved,
      'cached': cached,
      if (cacheKey != null) 'cacheKey': cacheKey,
      if (remainingSmartHelps != null)
        'remainingSmartHelps': remainingSmartHelps,
    };
  }

  static Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((key, value) => MapEntry(key.toString(), value));
    }
    return {};
  }

  static String _asString(dynamic value, String fallback) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? fallback : text;
  }

  static String? _optionalString(dynamic value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }

  static List<String> _asStringList(dynamic value) {
    if (value is! List) {
      return const [
        'What is the exact location?',
        'When should this be handled?',
        'Is there any safety risk right now?',
      ];
    }
    return value
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }
}
