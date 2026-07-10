import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'app_preferences_service.dart';

class NotificationService {
  static Future<NotificationSettings> requestNotificationPermission() {
    return FirebaseMessaging.instance.requestPermission();
  }

  static Future<void> setPushNotificationsEnabled(bool enabled) async {
    await AppPreferencesService.setNotifications(enabled);

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'notificationsEnabled': enabled,
        'notificationsUpdatedAt': FieldValue.serverTimestamp(),
        if (!enabled) 'fcmToken': FieldValue.delete(),
      }, SetOptions(merge: true));
    }

    if (enabled) {
      await requestNotificationPermission();
      await saveFcmTokenToFirestore();
    } else {
      await removeCurrentDeviceToken();
      await FirebaseMessaging.instance.deleteToken();
    }
  }

  static Future<void> removeCurrentDeviceToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) return;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('fcmTokens')
          .doc(token)
          .delete();
    } catch (e) {
      debugPrint('Failed to remove FCM token: $e');
    }
  }

  /// Save the FCM token to Firestore for the logged-in user
  static Future<void> saveFcmTokenToFirestore() async {
    if (!AppPreferencesService.notifications) return;

    final user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      try {
        final token = await FirebaseMessaging.instance.getToken();
        if (token != null) {
          await _saveTokenForUser(uid: user.uid, token: token);
        }
      } catch (e) {
        debugPrint('Failed to save FCM token: $e');
      }
    }
  }

  // 🔁 Start listening for token refresh and update Firestore
  static void startTokenRefreshListener() {
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      if (!AppPreferencesService.notifications) return;

      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await _saveTokenForUser(uid: user.uid, token: newToken);
      }
    });
  }

  static Future<void> _saveTokenForUser({
    required String uid,
    required String token,
  }) async {
    final firestore = FirebaseFirestore.instance;
    final userRef = firestore.collection('users').doc(uid);

    final batch = firestore.batch();
    batch.set(userRef, {
      'fcmToken': token,
      'notificationsEnabled': true,
      'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    batch.set(userRef.collection('fcmTokens').doc(token), {
      'token': token,
      'platform': defaultTargetPlatform.name,
      'enabled': true,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await batch.commit();
  }

  /// Create in-app notification
  static Future<void> createNotification({
    required String uid,

    required String title,

    required String message,

    required String type,

    String? documentId,

    String? status,
  }) async {
    try {
      int newVersion = 1;

      debugPrint('Creating notification for UID: $uid');
      // 🔁 Move old notification to history before creating new one
      if (documentId != null) {
        final oldNotifications = await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('notifications')
            .where('documentId', isEqualTo: documentId)
            .get();
        debugPrint('Found old notifications: ${oldNotifications.docs.length}');

        for (final oldDoc in oldNotifications.docs) {
          try {
            final oldData = oldDoc.data();

            debugPrint('===== MOVING TO HISTORY =====');
            debugPrint('Old notification version: ${oldData['version']}');

            // Keep same version lineage
            final previousVersion = oldData['version'] ?? 1;
            newVersion = previousVersion + 1;

            // Create clean mutable map
            final historyData = Map<String, dynamic>.from(oldData);

            // Add migration timestamp
            historyData['movedAt'] = FieldValue.serverTimestamp();

            debugPrint('Writing history document...');

            // Write into history collection
            await FirebaseFirestore.instance
                .collection('users')
                .doc(uid)
                .collection('verificationNotificationHistory')
                .add(historyData);

            debugPrint('History write successful');

            // Delete old active notification
            await oldDoc.reference.delete();

            debugPrint('Old active notification deleted');
          } catch (e) {
            debugPrint('History migration error: $e');
          }
        }
      }

      final notificationRef = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('notifications')
          .doc();

      await notificationRef.set({
        'version': newVersion,
        'title': title,

        'message': message,

        'type': type,

        'documentId': documentId,

        'status': status,

        'requiresAction': status == 'rejected',

        'notificationCategory': 'verification_workflow',

        'isRead': false,

        'createdAt': FieldValue.serverTimestamp(),
      });
      debugPrint('Notification created successfully');
    } catch (e) {
      debugPrint('Failed to create notification: $e');
    }
  }

  static Future<void> createMarketplaceNotification({
    required String uid,
    required String title,
    required String message,
    required String type,
    String? status,
    bool requiresAction = false,
    String notificationCategory = 'marketplace_update',
    Map<String, dynamic>? metadata,
  }) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('notifications')
          .add({
            'title': title,
            'message': message,
            'type': type,
            'status': status ?? 'update',
            'requiresAction': requiresAction,
            'notificationCategory': notificationCategory,
            'metadata': metadata ?? const <String, dynamic>{},
            'isRead': false,
            'createdAt': FieldValue.serverTimestamp(),
          });
    } catch (e) {
      debugPrint('Failed to create marketplace notification: $e');
    }
  }

  /// Resolve rejected notifications after reupload
  static Future<void> resolveRejectedNotifications({
    required String uid,
    required String documentId,
  }) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('notifications')
          .where('documentId', isEqualTo: documentId)
          .where('requiresAction', isEqualTo: true)
          .get();

      for (final doc in snapshot.docs) {
        await doc.reference.update({'requiresAction': false});
      }

      debugPrint('Rejection notifications resolved');
    } catch (e) {
      debugPrint('Failed to resolve rejection notifications: $e');
    }
  }

  /// Mark informational notifications as read
  static Future<void> markSuccessNotificationsAsRead({
    required String uid,
  }) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('notifications')
          .where('isRead', isEqualTo: false)
          .where('requiresAction', isEqualTo: false)
          .get();

      for (final doc in snapshot.docs) {
        await doc.reference.update({'isRead': true});
      }
    } catch (e) {
      debugPrint('Failed to mark success notifications');
    }
  }
}
