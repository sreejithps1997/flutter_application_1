import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/worker_opportunity_repository.dart';
import '../domain/worker_opportunity.dart';

final workerOpportunityRepositoryProvider =
    Provider<WorkerOpportunityRepository>((ref) {
      return WorkerOpportunityRepository();
    });

final workerOpportunitiesProvider = StreamProvider<List<WorkerOpportunity>>((
  ref,
) {
  return ref
      .watch(workerOpportunityRepositoryProvider)
      .watchOpenOpportunities();
});

final currentWorkerIdProvider = Provider<String?>((ref) {
  return ref.watch(workerOpportunityRepositoryProvider).currentWorkerId;
});
