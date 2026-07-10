import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/worker_match_query.dart';
import '../domain/worker_match_result.dart';

class WorkerMatchingRepository {
  WorkerMatchingRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<List<WorkerMatchResult>> findMatches(WorkerMatchQuery query) async {
    if (query.normalizedSearchText.isEmpty &&
        query.normalizedCategory.isEmpty) {
      return const [];
    }

    final visibleSnapshot = await _firestore
        .collection('workers')
        .where('visibleToUsers', isEqualTo: true)
        .limit(query.maxResults * 2)
        .get();

    var matches = visibleSnapshot.docs
        .map((doc) => _resultFor(doc.id, doc.data(), query))
        .where((result) => result.score > 0)
        .toList();

    if (matches.isEmpty) {
      final fallback = await _firestore
          .collection('workers')
          .limit(query.maxResults * 2)
          .get();
      matches = fallback.docs
          .map((doc) => _resultFor(doc.id, doc.data(), query))
          .where((result) {
            final visible =
                result.worker['visibleToUsers'] == true ||
                result.worker['profileVisibility'] == true;
            return visible && result.score > 0;
          })
          .toList();
    }

    matches.sort((a, b) => b.score.compareTo(a.score));
    return matches.take(query.maxResults).toList();
  }

  WorkerMatchResult _resultFor(
    String id,
    Map<String, dynamic> data,
    WorkerMatchQuery query,
  ) {
    final worker = _workerResult(id, data);
    final reasons = <String>[];
    var score = 0;

    final serviceText = _normalize('${worker['service'] ?? ''}');
    final haystack = [
      worker['name'],
      worker['service'],
      worker['location'],
      ..._list(worker['services']),
      ..._list(worker['skills']),
      ..._list(worker['serviceCategories']),
    ].whereType<Object>().map((value) => _normalize(value.toString())).toList();

    if (_hasTextMatch(haystack, query.normalizedSearchText)) {
      score += 40;
      reasons.add('Skill match');
    }

    if (_hasTextMatch(haystack, query.normalizedCategory)) {
      score += 30;
      reasons.add('Category match');
    }

    if (serviceText.contains(query.normalizedSearchText) ||
        serviceText.contains(query.normalizedCategory)) {
      score += 12;
      reasons.add('Service fit');
    }

    if (worker['isAvailable'] == true) {
      score += query.urgency.toLowerCase() == 'urgent' ? 22 : 10;
      reasons.add('Available');
    }

    if (_isVerified(worker)) {
      score += query.urgency.toLowerCase() == 'urgent' ? 18 : 10;
      reasons.add('Verified');
    }

    final rating = _double(worker['rating']);
    if (rating > 0) {
      score += (rating * 5).round();
      if (rating >= 4) reasons.add('High rating');
    }

    final completedJobs = _int(worker['completedJobsCount']);
    if (completedJobs > 0) {
      score += (completedJobs / 10).clamp(0, 20).round();
      reasons.add('Completed jobs');
    }

    if (_hasPrice(worker)) {
      score += 5;
      reasons.add('Pricing available');
    }

    return WorkerMatchResult(
      workerId: id,
      worker: worker,
      score: score,
      reasons: reasons.toSet().toList(),
    );
  }

  bool _hasTextMatch(List<String> haystack, String needle) {
    if (needle.isEmpty) return false;
    return haystack.any((value) {
      if (value.contains(needle)) return true;
      return needle.contains(value) && value.length > 2;
    });
  }

  Map<String, dynamic> _workerResult(String id, Map<String, dynamic> data) {
    final services = _list(data['services']);
    final skills = _list(data['skills']);
    final categories = _list(data['serviceCategories']);
    final combinedServices = [
      ...services,
      ...skills,
      ...categories,
    ].where((item) => item.trim().isNotEmpty).toSet().toList();

    return {
      ...data,
      'id': id,
      'name': _text(data, ['name', 'fullName'], 'Worker'),
      'services': combinedServices,
      'skills': skills,
      'serviceCategories': categories,
      'service': combinedServices.join(', '),
      'rating': _double(data['averageRating'] ?? data['rating']),
      'imageUrl': _text(data, ['imageUrl', 'profileImageUrl', 'photoUrl'], ''),
      'location': _text(data, ['location', 'city', 'address'], ''),
      'pricing': data['pricing'] ?? data['startingPrice'] ?? data['rate'] ?? '',
      'completedJobsCount': _int(
        data['completedJobsCount'] ??
            data['completedJobs'] ??
            data['totalJobs'],
      ),
    };
  }

  bool _isVerified(Map<String, dynamic> worker) {
    final verification = worker['verification'];
    if (verification is Map) {
      return verification['tier'] == 'verified' ||
          verification['tier'] == 'premium' ||
          verification['selfie'] == 'verified';
    }
    return worker['verificationStatus'] == 'verified' ||
        worker['isVerified'] == true;
  }

  bool _hasPrice(Map<String, dynamic> worker) {
    final value =
        worker['pricing'] ?? worker['startingPrice'] ?? worker['rate'];
    if (value is num) return value > 0;
    if (value is Map) return value.isNotEmpty;
    return value?.toString().trim().isNotEmpty == true;
  }

  String _normalize(String value) {
    return value.toLowerCase().trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  List<String> _list(dynamic value) {
    if (value is List) return value.map((item) => item.toString()).toList();
    if (value is String && value.trim().isNotEmpty) {
      return value.split(',').map((item) => item.trim()).toList();
    }
    return [];
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

  double _double(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  int _int(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}
