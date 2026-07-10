import 'package:cloud_functions/cloud_functions.dart';

import '../../smart_demand/data/demand_discovery_repository.dart';
import '../domain/smart_booking_assessment.dart';
import '../domain/smart_booking_ai_diagnosis.dart';

class SmartBookingAssistantRepository {
  SmartBookingAssistantRepository({
    DemandDiscoveryRepository? demandRepository,
    FirebaseFunctions? functions,
  }) : _demandRepository = demandRepository ?? DemandDiscoveryRepository(),
       _functions =
           functions ?? FirebaseFunctions.instanceFor(region: 'us-central1');

  final DemandDiscoveryRepository _demandRepository;
  final FirebaseFunctions _functions;

  Future<SmartBookingAssessment> assess(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      throw StateError('Tell Workable what help you need.');
    }

    final normalized = _normalize(trimmed);
    final demand = await _demandRepository.discover(trimmed);
    final urgency = _detectUrgency(normalized);
    final path = _recommendedPath(
      normalized: normalized,
      category: demand.guessedCategory,
      hasWorkers: demand.hasWorkers,
    );

    return SmartBookingAssessment(
      query: trimmed,
      category: demand.guessedCategory,
      urgency: urgency,
      recommendedPath: path,
      summary: _summary(
        query: trimmed,
        category: demand.guessedCategory,
        urgency: urgency,
        hasWorkers: demand.hasWorkers,
        path: path,
      ),
      questions: _questions(
        category: demand.guessedCategory,
        urgency: urgency,
        path: path,
      ),
      workers: demand.workers,
      demandSignalId: demand.demandSignalId,
      city: demand.city,
    );
  }

  Future<SmartBookingAiDiagnosis> runBackendDiagnosis(String query) async {
    final trimmed = query.trim();
    if (trimmed.length < 8) {
      throw StateError('Please describe the help you need in more detail.');
    }

    try {
      final callable = _functions.httpsCallable('runSmartBookingAiDiagnosis');
      final result = await callable.call<Map<String, dynamic>>({
        'query': trimmed,
        'reason': 'smart_booking_deeper_diagnosis',
      });
      return SmartBookingAiDiagnosis.fromCallableData(result.data);
    } on FirebaseFunctionsException catch (error) {
      throw StateError(error.message ?? 'Smart Help is not available now.');
    }
  }

  String _recommendedPath({
    required String normalized,
    required String category,
    required bool hasWorkers,
  }) {
    if (!hasWorkers) return 'help_request';
    if (category == 'Pickup And Delivery' ||
        category == 'Elder Or Family Support' ||
        normalized.contains('drop') ||
        normalized.contains('deliver') ||
        normalized.contains('urgent help')) {
      return 'help_request';
    }
    return 'worker_booking';
  }

  String _detectUrgency(String normalized) {
    final urgentWords = [
      'urgent',
      'emergency',
      'immediately',
      'now',
      'asap',
      'water leak',
      'short circuit',
      'power issue',
      'locked',
      'hospital',
    ];
    if (urgentWords.any(normalized.contains)) return 'Urgent';
    if (normalized.contains('today') || normalized.contains('tonight')) {
      return 'Today';
    }
    return 'Normal';
  }

  String _summary({
    required String query,
    required String category,
    required String urgency,
    required bool hasWorkers,
    required String path,
  }) {
    final workerText = hasWorkers
        ? 'I found matching workers.'
        : 'I could not find a direct worker match yet.';
    final pathText = path == 'worker_booking'
        ? 'Best next step is to compare workers and book one.'
        : 'Best next step is to create a help request so available helpers can respond.';
    return '$workerText I understood this as $category with $urgency urgency. $pathText';
  }

  List<String> _questions({
    required String category,
    required String urgency,
    required String path,
  }) {
    final questions = <String>[
      'What is the exact location/address?',
      'What time should this be done?',
    ];

    if (urgency == 'Urgent') {
      questions.add('Is there any safety risk right now?');
    }
    if (category == 'Pickup And Delivery') {
      questions.add('What should be picked up and where should it be dropped?');
    } else if (category == 'Plumbing' || category == 'Electrical') {
      questions.add('Can you upload or describe the affected area clearly?');
    } else if (category == 'Elder Or Family Support') {
      questions.add(
        'Does the helper need any special instruction or contact person?',
      );
    } else {
      questions.add('Any budget range or special instruction?');
    }
    if (path == 'worker_booking') {
      questions.add('Do you prefer fastest available or highest rated worker?');
    }

    return questions;
  }

  String _normalize(String value) {
    return value.toLowerCase().trim().replaceAll(RegExp(r'\s+'), ' ');
  }
}
