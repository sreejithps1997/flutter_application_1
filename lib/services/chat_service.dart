import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:geolocator/geolocator.dart';
import 'package:path/path.dart' as path;

import 'app_preferences_service.dart';

class ChatService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Generates a consistent chat ID for two users
  String getChatId(String uid1, String uid2) {
    return uid1.hashCode <= uid2.hashCode ? '${uid1}_$uid2' : '${uid2}_$uid1';
  }

  /// Returns stream of messages for a chat
  Stream<QuerySnapshot> getMessages(String chatId) {
    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp')
        .snapshots();
  }

  Future<void> ensureChatForBooking({
    required String otherUserId,
    required String otherUserName,
    required String userRole,
    String? bookingId,
    String? service,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null || otherUserId.trim().isEmpty) return;

    final chatId = getChatId(uid, otherUserId);
    final participants = chatId.split('_');
    await _firestore.collection('chats').doc(chatId).set({
      'participants': participants,
      'bookingId': bookingId,
      'service': service,
      'chatWithName': otherUserName,
      'createdFrom': 'booking',
      'createdByRole': userRole,
      'updatedAt': FieldValue.serverTimestamp(),
      'unreadCounts.$uid': 0,
    }, SetOptions(merge: true));
  }

  /// Sends a text message
  // Future<void> sendTextMessage(String chatId, String text) async {
  //   if (text.trim().isEmpty) return;

  //   final uid = _auth.currentUser?.uid;
  //   if (uid == null) return;

  //   await _firestore
  //       .collection('chats')
  //       .doc(chatId)
  //       .collection('messages')
  //       .add({
  //     'senderId': uid,
  //     'text': text.trim(),
  //     'timestamp': FieldValue.serverTimestamp(),
  //     'isRead': false,
  //   });
  // }

  Future<void> sendTextMessage(String chatId, String text) async {
    if (text.trim().isEmpty) return;

    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final now = FieldValue.serverTimestamp();

    final messageData = {
      'senderId': uid,
      'text': text.trim(),
      'timestamp': now,
      'isRead': false,
    };

    // 1. Add message to subcollection
    await _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .add(messageData);

    // 2. Update parent chat metadata
    final participants = chatId.split('_');
    final otherUserId = participants.firstWhere((id) => id != uid);
    await _firestore.collection('chats').doc(chatId).set({
      'participants': participants,
      'lastMessage': text.trim(),
      'lastMessageType': 'text',
      'timestamp': now,
      'unreadCounts.$uid': 0,
      'unreadCounts.$otherUserId': FieldValue.increment(1),
    }, SetOptions(merge: true));
  }

  /// Sends an image message
  Future<void> sendImageMessage(String chatId, File imageFile) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    final now = FieldValue.serverTimestamp();

    final imageName = path.basename(imageFile.path);
    final ref = _storage.ref().child('chat_images/$chatId/$imageName');

    await ref.putFile(imageFile);
    final imageUrl = await ref.getDownloadURL();

    await _firestore.collection('chats').doc(chatId).collection('messages').add(
      {
        'senderId': uid,
        'imageUrl': imageUrl,
        'timestamp': now,
        'isRead': false,
      },
    );

    final participants = chatId.split('_');
    final otherUserId = participants.firstWhere((id) => id != uid);
    await _firestore.collection('chats').doc(chatId).set({
      'participants': participants,
      'lastMessage': 'Photo',
      'lastMessageType': 'image',
      'timestamp': now,
      'unreadCounts.$uid': 0,
      'unreadCounts.$otherUserId': FieldValue.increment(1),
    }, SetOptions(merge: true));
  }

  /// Sends current location as message
  Future<void> sendLocationMessage(String chatId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    final now = FieldValue.serverTimestamp();

    if (!AppPreferencesService.locationServices) {
      throw Exception("Location services are disabled in app settings");
    }

    final permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw Exception("Location permission denied");
    }

    final position = await Geolocator.getCurrentPosition();
    final locationUrl =
        'https://www.google.com/maps/search/?api=1&query=${position.latitude},${position.longitude}';

    await _firestore.collection('chats').doc(chatId).collection('messages').add(
      {
        'senderId': uid,
        'locationUrl': locationUrl,
        'timestamp': now,
        'isRead': false,
      },
    );

    final participants = chatId.split('_');
    final otherUserId = participants.firstWhere((id) => id != uid);
    await _firestore.collection('chats').doc(chatId).set({
      'participants': participants,
      'lastMessage': 'Location shared',
      'lastMessageType': 'location',
      'timestamp': now,
      'unreadCounts.$uid': 0,
      'unreadCounts.$otherUserId': FieldValue.increment(1),
    }, SetOptions(merge: true));
  }

  /// Marks all unread messages from other user as read
  Future<void> markMessagesAsRead(String chatId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final query = await _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .where('isRead', isEqualTo: false)
        .where('senderId', isNotEqualTo: uid)
        .get();

    for (final doc in query.docs) {
      await doc.reference.update({'isRead': true});
    }

    await _firestore.collection('chats').doc(chatId).set({
      'unreadCounts.$uid': 0,
    }, SetOptions(merge: true));
  }

  /// Updates typing status (role: 'customer' or 'worker')
  Future<void> updateTypingStatus(
    String chatId,
    String userRole,
    bool isTyping,
  ) async {
    await _firestore
        .collection('chats')
        .doc(chatId)
        .collection('status')
        .doc('typing')
        .set({userRole: isTyping}, SetOptions(merge: true));
  }

  /// Gets typing status stream
  Stream<DocumentSnapshot> getTypingStatusStream(String chatId) {
    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('status')
        .doc('typing')
        .snapshots();
  }
}
