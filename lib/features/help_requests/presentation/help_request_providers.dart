import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/help_request_repository.dart';
import '../domain/help_request.dart';

final helpRequestRepositoryProvider = Provider<HelpRequestRepository>((ref) {
  return HelpRequestRepository();
});

final openHelpRequestsProvider = StreamProvider<List<HelpRequest>>((ref) {
  return ref.watch(helpRequestRepositoryProvider).watchOpenHelpRequests();
});

final workerHelpRequestsProvider = StreamProvider<List<HelpRequest>>((ref) {
  return ref.watch(helpRequestRepositoryProvider).watchWorkerHelpRequests();
});

final customerHelpRequestsProvider = StreamProvider<List<HelpRequest>>((ref) {
  return ref.watch(helpRequestRepositoryProvider).watchCustomerHelpRequests();
});

final helpRequestProvider = StreamProvider.family<HelpRequest?, String>((
  ref,
  requestId,
) {
  return ref.watch(helpRequestRepositoryProvider).watchHelpRequest(requestId);
});
