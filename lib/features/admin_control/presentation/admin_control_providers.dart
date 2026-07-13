import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/admin_control_repository.dart';
import '../data/dispute_evidence_repository.dart';
import '../domain/admin_control_summary.dart';
import '../domain/admin_dispute_item.dart';
import '../domain/admin_permission_set.dart';
import '../domain/dispute_evidence_case.dart';

final adminControlRepositoryProvider = Provider<AdminControlRepository>((ref) {
  return AdminControlRepository();
});

final adminControlSummaryProvider = FutureProvider<AdminControlSummary>((ref) {
  return ref.watch(adminControlRepositoryProvider).loadSummary();
});

final adminDisputesProvider = StreamProvider<List<AdminDisputeItem>>((ref) {
  return ref.watch(adminControlRepositoryProvider).watchDisputes();
});

final adminPermissionProvider = FutureProvider<AdminPermissionSet>((ref) {
  return ref.watch(adminControlRepositoryProvider).loadPermissions();
});

final adminAuditLogsProvider =
    StreamProvider.family<List<Map<String, dynamic>>, AdminDisputeItem>((
      ref,
      item,
    ) {
      return ref.watch(adminControlRepositoryProvider).watchAuditLogs(item);
    });

final disputeEvidenceRepositoryProvider = Provider<DisputeEvidenceRepository>((
  ref,
) {
  return DisputeEvidenceRepository();
});

final disputeEvidenceCaseProvider =
    FutureProvider.family<
      DisputeEvidenceCase,
      ({String collection, String id})
    >((ref, target) {
      return ref
          .watch(disputeEvidenceRepositoryProvider)
          .loadCase(collection: target.collection, id: target.id);
    });
