import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/worker_matching_repository.dart';

final workerMatchingRepositoryProvider = Provider<WorkerMatchingRepository>((
  ref,
) {
  return WorkerMatchingRepository();
});
