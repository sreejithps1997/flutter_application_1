import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class NotificationService {
  /// Save the FCM token to Firestore for the logged-in user
  static Future<void> saveFcmTokenToFirestore() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      try {
        final token = await FirebaseMessaging.instance.getToken();
        if (token != null) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .update({'fcmToken': token});
        }
      } catch (e) {
        print('❌ Failed to save FCM token: $e');
      }
    }
  }

  // 🔁 Start listening for token refresh and update Firestore
  static void startTokenRefreshListener() {
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({'fcmToken': newToken});
      }
    });
  }
}
