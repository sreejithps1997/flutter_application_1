import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/admin_control_repository.dart';
import '../domain/admin_control_summary.dart';

final adminControlRepositoryProvider = Provider<AdminControlRepository>((ref) {
  return AdminControlRepository();
});

final adminControlSummaryProvider = FutureProvider<AdminControlSummary>((ref) {
  return ref.watch(adminControlRepositoryProvider).loadSummary();
});
