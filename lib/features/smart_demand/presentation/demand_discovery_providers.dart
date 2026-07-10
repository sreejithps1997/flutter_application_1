import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/demand_discovery_repository.dart';

final demandDiscoveryRepositoryProvider = Provider<DemandDiscoveryRepository>((
  ref,
) {
  return DemandDiscoveryRepository();
});
