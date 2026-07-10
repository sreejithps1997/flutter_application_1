import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/admin_demand_repository.dart';
import '../domain/admin_demand_signal.dart';

final adminDemandRepositoryProvider = Provider<AdminDemandRepository>((ref) {
  return AdminDemandRepository();
});

final adminDemandSignalsProvider = StreamProvider<List<AdminDemandSignal>>((
  ref,
) {
  return ref.watch(adminDemandRepositoryProvider).watchDemandSignals();
});

final adminDemandStatusFilterProvider = StateProvider<String>((ref) => 'open');

final filteredAdminDemandSignalsProvider =
    Provider<AsyncValue<List<AdminDemandSignal>>>((ref) {
      final filter = ref.watch(adminDemandStatusFilterProvider);
      final signals = ref.watch(adminDemandSignalsProvider);

      return signals.whenData((items) {
        if (filter == 'all') return items;
        return items.where((item) => item.status == filter).toList();
      });
    });
