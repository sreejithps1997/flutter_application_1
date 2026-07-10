import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/smart_booking_assistant_repository.dart';
import '../data/smart_help_quota_repository.dart';
import '../domain/smart_help_quota.dart';

final smartBookingAssistantRepositoryProvider =
    Provider<SmartBookingAssistantRepository>((ref) {
      return SmartBookingAssistantRepository();
    });

final smartHelpQuotaRepositoryProvider = Provider<SmartHelpQuotaRepository>((
  ref,
) {
  return SmartHelpQuotaRepository();
});

final smartHelpQuotaProvider = StreamProvider<SmartHelpQuota>((ref) {
  return ref.watch(smartHelpQuotaRepositoryProvider).watchTodayQuota();
});
