import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/admin_referral_repository.dart';
import '../domain/admin_referral_reward.dart';

final adminReferralRepositoryProvider = Provider<AdminReferralRepository>((
  ref,
) {
  return AdminReferralRepository();
});

final adminReferralRewardsProvider = StreamProvider<List<AdminReferralReward>>((
  ref,
) {
  return ref.watch(adminReferralRepositoryProvider).watchReferralRewards();
});

final adminReferralFilterProvider = StateProvider<String>((ref) => 'action');

final filteredAdminReferralRewardsProvider =
    Provider<AsyncValue<List<AdminReferralReward>>>((ref) {
      final filter = ref.watch(adminReferralFilterProvider);
      final rewards = ref.watch(adminReferralRewardsProvider);

      return rewards.whenData((items) {
        switch (filter) {
          case 'ready':
            return items.where((item) => item.isRewardReady).toList();
          case 'worker':
            return items.where((item) => item.isWorkerOnboarding).toList();
          case 'credited':
            return items.where((item) => item.isCredited).toList();
          case 'rejected':
            return items.where((item) => item.isRejected).toList();
          case 'action':
            return items
                .where((item) => item.isRewardReady || item.isWorkerOnboarding)
                .toList();
          case 'all':
          default:
            return items;
        }
      });
    });
