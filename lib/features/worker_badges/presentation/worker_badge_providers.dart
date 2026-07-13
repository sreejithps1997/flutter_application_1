import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/worker_badge_repository.dart';
import '../domain/worker_badge_summary.dart';

final workerBadgeRepositoryProvider = Provider<WorkerBadgeRepository>((ref) {
  return WorkerBadgeRepository();
});

final workerBadgeSummaryProvider =
    StreamProvider.family<WorkerBadgeSummary, String>((ref, workerId) {
      return ref
          .watch(workerBadgeRepositoryProvider)
          .watchWorkerBadge(workerId);
    });
