import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../domain/workable_notification.dart';

class NotificationRepository {
  NotificationRepository({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  String? get currentUserId => _auth.currentUser?.uid;

  CollectionReference<Map<String, dynamic>> _collection(String uid) {
    return _firestore.collection('users').doc(uid).collection('notifications');
  }

  Stream<List<WorkableNotification>> watchCurrentUserNotifications() {
    final uid = currentUserId;
    if (uid == null) return Stream.value(const []);

    return _collection(uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.map(_notificationFromSnapshot).toList(),
        );
  }

  Future<void> markRead(String notificationId) async {
    final uid = currentUserId;
    if (uid == null) return;

    await _collection(uid).doc(notificationId).update({
      'isRead': true,
      'readAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> markAllRead() async {
    final uid = currentUserId;
    if (uid == null) return;

    final unread = await _collection(
      uid,
    ).where('isRead', isEqualTo: false).get();
    if (unread.docs.isEmpty) return;

    final batch = _firestore.batch();
    for (final doc in unread.docs) {
      batch.update(doc.reference, {
        'isRead': true,
        'readAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }

  WorkableNotification _notificationFromSnapshot(
    QueryDocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data();
    final createdAt = data['createdAt'];
    final metadata = data['metadata'] is Map
        ? Map<String, dynamic>.from(data['metadata'] as Map)
        : <String, dynamic>{};

    return WorkableNotification(
      id: snapshot.id,
      title: data['title']?.toString() ?? 'Notification',
      message: data['message']?.toString() ?? '',
      status: data['status']?.toString() ?? 'update',
      type: data['type']?.toString() ?? 'general',
      isRead: data['isRead'] == true,
      requiresAction: data['requiresAction'] == true,
      createdAt: createdAt is Timestamp ? createdAt.toDate() : null,
      routingData: {
        ...metadata,
        'notificationId': snapshot.id,
        'type': data['type']?.toString() ?? 'general',
        'status': data['status']?.toString() ?? 'update',
        'notificationCategory': data['notificationCategory']?.toString() ?? '',
        'category': data['notificationCategory']?.toString() ?? '',
        'bookingId': data['bookingId']?.toString() ?? metadata['bookingId'],
        'documentId': data['documentId']?.toString() ?? metadata['documentId'],
        'chatId': metadata['chatId'],
        'chatWithId': metadata['chatWithId'],
        'chatWithName': metadata['chatWithName'],
        'userRole': metadata['userRole'],
        'reviewId': metadata['reviewId'],
        'workerId': metadata['workerId'],
      },
    );
  }
}
