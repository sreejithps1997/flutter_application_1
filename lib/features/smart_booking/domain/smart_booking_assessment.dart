class SmartBookingAssessment {
  const SmartBookingAssessment({
    required this.query,
    required this.category,
    required this.urgency,
    required this.recommendedPath,
    required this.summary,
    required this.questions,
    required this.workers,
    this.demandSignalId,
    this.city,
  });

  final String query;
  final String category;
  final String urgency;
  final String recommendedPath;
  final String summary;
  final List<String> questions;
  final List<Map<String, dynamic>> workers;
  final String? demandSignalId;
  final String? city;

  bool get hasWorkers => workers.isNotEmpty;
  bool get isUrgent => urgency == 'Urgent';
  bool get shouldCreateHelpRequest {
    return recommendedPath == 'help_request' || !hasWorkers;
  }
}
