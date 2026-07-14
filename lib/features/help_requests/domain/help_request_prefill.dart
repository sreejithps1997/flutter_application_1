class HelpRequestPrefill {
  const HelpRequestPrefill({
    required this.query,
    required this.category,
    required this.urgency,
    this.demandSignalId,
    this.city,
    this.aiDiagnosis,
    this.source = 'smart_booking',
  });

  final String query;
  final String category;
  final String urgency;
  final String? demandSignalId;
  final String? city;
  final Map<String, dynamic>? aiDiagnosis;
  final String source;

  String get requestType {
    final text = category.toLowerCase();
    final need = query.toLowerCase();

    if (text.contains('pickup') || need.contains('pick up')) return 'Pickup';
    if (text.contains('drop') || need.contains('drop')) return 'Drop';
    if (text.contains('delivery') || need.contains('deliver')) {
      return 'Delivery';
    }
    if (text.contains('elder') || text.contains('family')) {
      return 'Elder support';
    }
    if (urgency == 'Urgent') return 'Urgent help';
    return 'General help';
  }

  String get normalizedUrgency {
    final value = urgency.toLowerCase().trim();
    if (value.contains('urgent') || value.contains('emergency')) {
      return 'Urgent';
    }
    if (value.contains('today') || value.contains('same day')) return 'Today';
    return 'Normal';
  }

  String get title {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return category;
    if (cleanQuery.length <= 54) return cleanQuery;
    return '${cleanQuery.substring(0, 54).trim()}...';
  }

  String get description {
    final parts = <String>[
      query.trim(),
      if (category.trim().isNotEmpty) 'Suggested category: $category',
      if (urgency.trim().isNotEmpty) 'Urgency: $urgency',
      if (_aiSummary.isNotEmpty) 'AI summary: $_aiSummary',
      if (_aiPriceRange.isNotEmpty) 'Estimated range: $_aiPriceRange',
      if (_aiSafetyNote.isNotEmpty) 'Safety note: $_aiSafetyNote',
    ];
    return parts.where((part) => part.trim().isNotEmpty).join('\n');
  }

  String get _aiSummary {
    return aiDiagnosis?['summary']?.toString().trim() ?? '';
  }

  String get _aiPriceRange {
    final text = aiDiagnosis?['priceRange']?.toString().trim() ?? '';
    return text.toLowerCase() == 'unknown' ? '' : text;
  }

  String get _aiSafetyNote {
    return aiDiagnosis?['safetyNote']?.toString().trim() ?? '';
  }

  List<String> get suggestedQuestions {
    final questions = aiDiagnosis?['questions'];
    if (questions is! List) return const [];
    return questions
        .map((question) => question.toString().trim())
        .where((question) => question.isNotEmpty)
        .toList();
  }

  String get aiSummary => _aiSummary;

  String get aiPriceRange => _aiPriceRange;

  String get aiSafetyNote => _aiSafetyNote;

  String get aiConfidence {
    return aiDiagnosis?['confidence']?.toString().trim() ?? '';
  }

  String get aiRecommendedPath {
    return aiDiagnosis?['recommendedPath']?.toString().trim() ?? '';
  }

  Map<String, dynamic> toMetadata() {
    return {
      'source': source,
      'query': query,
      'category': category,
      'urgency': normalizedUrgency,
      if (demandSignalId != null) 'demandSignalId': demandSignalId,
      if (city != null) 'city': city,
      if (aiDiagnosis != null) 'aiDiagnosis': aiDiagnosis,
    };
  }
}
