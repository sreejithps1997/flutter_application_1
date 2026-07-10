import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/theme/workable_design.dart';
import '../../../services/notification_navigation_service.dart';
import '../../../widgets/workable_ui.dart';
import '../domain/workable_notification.dart';
import 'notification_providers.dart';

class NotificationsScreen extends ConsumerWidget {
  static const routeName = '/notifications';

  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showUnreadOnly = ref.watch(showUnreadOnlyProvider);
    final unreadCount = ref.watch(unreadNotificationCountProvider);
    final visibleNotifications = ref.watch(visibleNotificationsProvider);

    return Scaffold(
      backgroundColor: WorkableDesign.canvas,
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: WorkableDesign.surface,
        foregroundColor: WorkableDesign.ink,
        actions: [
          IconButton(
            tooltip: showUnreadOnly ? 'Show all' : 'Show unread',
            icon: Icon(
              showUnreadOnly ? LucideIcons.listFilter : LucideIcons.badgeCheck,
            ),
            onPressed: () {
              ref.read(showUnreadOnlyProvider.notifier).state = !showUnreadOnly;
            },
          ),
          IconButton(
            tooltip: 'Mark all read',
            icon: const Icon(LucideIcons.checkCheck),
            onPressed: unreadCount == 0
                ? null
                : () => ref.read(notificationRepositoryProvider).markAllRead(),
          ),
        ],
      ),
      body: visibleNotifications.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => const _NotificationEmptyState(
          title: 'Unable to load notifications',
        ),
        data: (notifications) {
          if (notifications.isEmpty) {
            return _NotificationEmptyState(
              title: showUnreadOnly
                  ? 'No unread notifications'
                  : 'No notifications yet',
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final notification = notifications[index];
              return _NotificationCard(
                notification: notification,
                onMarkRead: () async => ref
                    .read(notificationRepositoryProvider)
                    .markRead(notification.id),
              );
            },
          );
        },
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.notification,
    required this.onMarkRead,
  });

  final WorkableNotification notification;
  final Future<void> Function() onMarkRead;

  static final DateFormat _dateFormat = DateFormat('dd MMM, h:mm a');

  @override
  Widget build(BuildContext context) {
    final date = notification.createdAt == null
        ? 'Just now'
        : _dateFormat.format(notification.createdAt!);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: WorkableDesign.cardDecoration(
        borderColor: notification.isRead
            ? WorkableDesign.border
            : WorkableDesign.primary.withValues(alpha: 0.3),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(WorkableDesign.radius),
        onTap: () async {
          if (!notification.isRead) {
            await onMarkRead();
          }
          await NotificationNavigationService.handleData(
            notification.routingData,
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: notification.color.withValues(alpha: 0.12),
                child: Icon(
                  notification.icon,
                  color: notification.color,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
                            style: TextStyle(
                              fontWeight: notification.isRead
                                  ? FontWeight.w600
                                  : FontWeight.w800,
                            ),
                          ),
                        ),
                        if (!notification.isRead)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: WorkableDesign.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      notification.message,
                      style: const TextStyle(
                        color: WorkableDesign.muted,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        WorkableStatusPill(
                          label: notification.statusLabel,
                          color: notification.color,
                        ),
                        if (notification.requiresAction)
                          const WorkableStatusPill(
                            label: 'action needed',
                            color: WorkableDesign.warning,
                          ),
                        Text(
                          date,
                          style: const TextStyle(
                            color: WorkableDesign.muted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NotificationEmptyState extends StatelessWidget {
  const _NotificationEmptyState({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return WorkableEmptyState(
      icon: LucideIcons.bell,
      title: title,
      message:
          'Important booking, payment, verification, and support updates will appear here.',
    );
  }
}
