import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/notification_repository.dart';
import '../domain/workable_notification.dart';

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return NotificationRepository();
});

final showUnreadOnlyProvider = StateProvider<bool>((ref) => false);

final notificationsProvider = StreamProvider<List<WorkableNotification>>((ref) {
  return ref
      .watch(notificationRepositoryProvider)
      .watchCurrentUserNotifications();
});

final visibleNotificationsProvider =
    Provider<AsyncValue<List<WorkableNotification>>>((ref) {
      final showUnreadOnly = ref.watch(showUnreadOnlyProvider);
      final notifications = ref.watch(notificationsProvider);

      return notifications.whenData((items) {
        if (!showUnreadOnly) return items;
        return items.where((notification) => !notification.isRead).toList();
      });
    });

final unreadNotificationCountProvider = Provider<int>((ref) {
  final notifications =
      ref.watch(notificationsProvider).valueOrNull ?? const [];
  return notifications.where((notification) => !notification.isRead).length;
});
