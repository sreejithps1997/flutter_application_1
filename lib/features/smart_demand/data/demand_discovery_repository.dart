import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../worker_matching/data/worker_matching_repository.dart';
import '../../worker_matching/domain/worker_match_query.dart';
import '../domain/demand_discovery_result.dart';

class DemandDiscoveryRepository {
  DemandDiscoveryRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    FirebaseFunctions? functions,
    WorkerMatchingRepository? workerMatchingRepository,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance,
       _functions =
           functions ?? FirebaseFunctions.instanceFor(region: 'us-central1'),
       _workerMatchingRepository =
           workerMatchingRepository ?? WorkerMatchingRepository();

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final FirebaseFunctions _functions;
  final WorkerMatchingRepository _workerMatchingRepository;

  static const Map<String, List<String>> _categoryKeywords = {
    'Plumbing': [
      'pipe',
      'plumber',
      'plumbing',
      'sink',
      'tap',
      'toilet',
      'water leak',
      'leak',
      'drain',
      'bathroom',
    ],
    'Electrical': [
      'electric',
      'electrician',
      'power',
      'switch',
      'fan',
      'light',
      'wiring',
      'short circuit',
      'inverter',
    ],
    'Appliance Repair': [
      'ac',
      'fridge',
      'washing machine',
      'mixer',
      'oven',
      'tv',
      'appliance',
      'cooling',
    ],
    'Cleaning': [
      'clean',
      'cleaning',
      'deep clean',
      'bathroom cleaning',
      'kitchen cleaning',
      'home cleaning',
    ],
    'Carpentry': [
      'carpenter',
      'wood',
      'door',
      'furniture',
      'cupboard',
      'table',
      'chair',
      'lock',
    ],
    'Painting': ['paint', 'painting', 'wall', 'ceiling', 'polish'],
    'Pickup And Delivery': [
      'pickup',
      'pick up',
      'delivery',
      'deliver',
      'drop',
      'parcel',
      'courier',
      'transport',
    ],
    'Elder Or Family Support': [
      'elder',
      'senior',
      'baby',
      'child',
      'care',
      'medicine',
      'hospital',
      'family',
    ],
    'General Help': [
      'help',
      'helper',
      'assistant',
      'arrange',
      'shift',
      'move',
      'setup',
    ],
  };

  Future<DemandDiscoveryResult> discover(String query) async {
    final trimmedQuery = query.trim();
    final normalizedQuery = _normalize(trimmedQuery);
    if (normalizedQuery.isEmpty) {
      return DemandDiscoveryResult(
        query: trimmedQuery,
        normalizedQuery: normalizedQuery,
        guessedCategory: 'General Help',
        workers: const [],
      );
    }

    final guessedCategory = _guessCategory(normalizedQuery);
    final matches = await _workerMatchingRepository.findMatches(
      WorkerMatchQuery(
        searchText: trimmedQuery,
        category: guessedCategory,
        urgency: normalizedQuery.contains('urgent') ? 'Urgent' : 'Normal',
      ),
    );
    final workers = matches.map((match) => match.toWorkerListMap()).toList();

    if (workers.isNotEmpty) {
      return DemandDiscoveryResult(
        query: trimmedQuery,
        normalizedQuery: normalizedQuery,
        guessedCategory: guessedCategory,
        workers: workers,
      );
    }

    final customerContext = await _customerContext();
    final demandSignalId = await _recordDemandSignal(
      query: trimmedQuery,
      normalizedQuery: normalizedQuery,
      guessedCategory: guessedCategory,
      city: customerContext.city,
      customerName: customerContext.name,
    );

    return DemandDiscoveryResult(
      query: trimmedQuery,
      normalizedQuery: normalizedQuery,
      guessedCategory: guessedCategory,
      workers: const [],
      demandSignalId: demandSignalId,
      city: customerContext.city,
    );
  }

  Future<String> _recordDemandSignal({
    required String query,
    required String normalizedQuery,
    required String guessedCategory,
    required String city,
    required String customerName,
  }) async {
    final callable = _functions.httpsCallable('recordSmartDemandSignal');
    final result = await callable.call<Map<String, dynamic>>({
      'query': query,
      'normalizedQuery': normalizedQuery,
      'guessedCategory': guessedCategory,
      'city': city,
      'customerName': customerName,
    });

    return result.data['signalId']?.toString() ??
        _signalId(normalizedQuery, city);
  }

  Future<_CustomerContext> _customerContext() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return const _CustomerContext();

    final doc = await _firestore.collection('users').doc(uid).get();
    final data = doc.data() ?? const <String, dynamic>{};

    return _CustomerContext(
      name: _text(data, ['name', 'fullName', 'displayName'], 'Customer'),
      city: _text(data, ['city', 'area', 'location'], 'Unknown'),
    );
  }

  String _guessCategory(String normalizedQuery) {
    var bestCategory = 'General Help';
    var bestScore = 0;

    for (final entry in _categoryKeywords.entries) {
      final score = entry.value.where((keyword) {
        return normalizedQuery.contains(_normalize(keyword));
      }).length;

      if (score > bestScore) {
        bestCategory = entry.key;
        bestScore = score;
      }
    }

    return bestCategory;
  }

  String _signalId(String normalizedQuery, String city) {
    final base = '${_slug(city)}_${_slug(normalizedQuery)}';
    if (base.length <= 90) return base;
    return base.substring(0, 90);
  }

  String _slug(String value) {
    final slug = _normalize(value)
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    return slug.isEmpty ? 'unknown' : slug;
  }

  String _normalize(String value) {
    return value.toLowerCase().trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  String _text(Map<String, dynamic> data, List<String> keys, String fallback) {
    for (final key in keys) {
      final value = data[key]?.toString().trim();
      if (value != null && value.isNotEmpty && value.toLowerCase() != 'null') {
        return value;
      }
    }
    return fallback;
  }
}

class _CustomerContext {
  const _CustomerContext({this.name = 'Customer', this.city = 'Unknown'});

  final String name;
  final String city;
}
