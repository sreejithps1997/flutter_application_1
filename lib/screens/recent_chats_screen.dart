import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'chat_screen.dart';

class RecentChatsScreen extends StatefulWidget {
  static const routeName = '/recent-chats';

  final String userRole; // 'customer' or 'worker'

  const RecentChatsScreen({super.key, required this.userRole});

  @override
  State<RecentChatsScreen> createState() => _RecentChatsScreenState();
}

class _RecentChatsScreenState extends State<RecentChatsScreen> {
  final _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String get _currentUserId => _auth.currentUser!.uid;

  String _getChatId(String uid1, String uid2) {
    return uid1.hashCode <= uid2.hashCode ? '${uid1}_$uid2' : '${uid2}_$uid1';
  }

  String _formatTimestamp(Timestamp timestamp) {
    final dt = timestamp.toDate();
    final now = DateTime.now();

    if (dt.day == now.day && dt.month == now.month && dt.year == now.year) {
      return "${dt.hour}:${dt.minute.toString().padLeft(2, '0')}";
    }

    return "${dt.day}/${dt.month}";
  }

  // Future<List<Map<String, dynamic>>> _fetchRecentChats() async {
  //   final messagesSnapshots = await _firestore
  //       .collectionGroup('messages')
  //       .orderBy('timestamp', descending: true)
  //       .get();
  //   final Map<String, Map<String, dynamic>> chatMap = {};
  //   final Set<String> chatWithIds = {};
  //   // 1️⃣ Collect chatWithIds
  //   for (var doc in messagesSnapshots.docs) {
  //     final message = doc.data();
  //     final chatId = doc.reference.parent.parent!.id;
  //     final senderId = message['senderId'];
  //     final isMyMessage = senderId == _currentUserId;
  //     final ids = chatId.split('_');
  //     final chatWithId = ids[0] == _currentUserId ? ids[1] : ids[0];
  //     chatWithIds.add(chatWithId);
  //     if (!chatMap.containsKey(chatWithId)) {
  //       chatMap[chatWithId] = {
  //         'chatWithId': chatWithId,
  //         'message': message,
  //         'timestamp': message['timestamp'],
  //         'isRead': message['isRead'] ?? isMyMessage,
  //       };
  //     }
  //   }
  //   // 2️⃣ Fetch user data in a single batch
  //   final userDocs = await _firestore
  //       .collection(widget.userRole == 'customer' ? 'workers' : 'users')
  //       .where(FieldPath.documentId, whereIn: chatWithIds.toList())
  //       .get();
  //   final Map<String, dynamic> userMap = {
  //     for (var doc in userDocs.docs) doc.id: doc.data()
  //   };
  //   // 3️⃣ Combine message data with user info
  //   final List<Map<String, dynamic>> chatList = [];
  //   for (var entry in chatMap.entries) {
  //     final chatWithId = entry.key;
  //     final message = entry.value['message'];
  //     final timestamp = entry.value['timestamp'];
  //     final isRead = entry.value['isRead'];
  //     final userData = userMap[chatWithId];
  //     if (userData == null) continue;
  //     chatList.add({
  //       'chatWithId': chatWithId,
  //       'chatWithName': userData['name'] ?? 'User',
  //       'imageUrl': userData['imageUrl'] ?? null,
  //       'lastMessage': message['text'] ??
  //           (message['imageUrl'] != null
  //               ? "📷 Image"
  //               : (message['locationUrl'] != null ? "📍 Location" : '')),
  //       'timestamp': timestamp,
  //       'isRead': isRead,
  //     });
  //   }
  //   // 4️⃣ Sort by timestamp
  //   chatList.sort((a, b) {
  //     final t1 = a['timestamp'] as Timestamp?;
  //     final t2 = b['timestamp'] as Timestamp?;
  //     return (t2?.toDate() ?? DateTime(0)).compareTo(t1?.toDate() ?? DateTime(0));
  //   });
  //   return chatList;
  // }
  // Future<List<Map<String, dynamic>>> _fetchRecentChats() async {
  //   final chatSnapshots = await _firestore
  //       .collection('chats')
  //       .where('participants', arrayContains: _currentUserId)
  //       .orderBy('timestamp', descending: true)
  //       .get();
  //   final List<Map<String, dynamic>> chatList = [];
  //   final Set<String> chatWithIds = {};
  //   // Step 1: Extract chat partner IDs
  //   for (var doc in chatSnapshots.docs) {
  //     final data = doc.data();
  //     final participants = List<String>.from(data['participants'] ?? []);
  //     final chatWithId = participants.firstWhere(
  //       (id) => id != _currentUserId,
  //       orElse: () => '',
  //     );
  //     if (chatWithId.isNotEmpty) {
  //       chatWithIds.add(chatWithId);
  //     }
  //   }
  //   // Step 2: Batch fetch all user documents
  //   final userDocs = await _firestore
  //       .collection(widget.userRole == 'customer' ? 'workers' : 'users')
  //       .where(FieldPath.documentId, whereIn: chatWithIds.toList())
  //       .get();
  //   final userMap = {for (var doc in userDocs.docs) doc.id: doc.data()};
  //   // Step 3: Merge chat metadata with user info
  //   for (var doc in chatSnapshots.docs) {
  //     final data = doc.data();
  //     final participants = List<String>.from(data['participants'] ?? []);
  //     final chatWithId = participants.firstWhere(
  //       (id) => id != _currentUserId,
  //       orElse: () => '',
  //     );
  //     if (chatWithId.isEmpty || !userMap.containsKey(chatWithId)) continue;
  //     final userData = userMap[chatWithId];
  //     chatList.add({
  //       'chatWithId': chatWithId,
  //       'chatWithName': userData['name'] ?? 'User',
  //       'imageUrl': userData['imageUrl'] ?? null,
  //       'lastMessage': data['lastMessage'] ?? '',
  //       'timestamp': data['timestamp'],
  //       'isRead': false, // You can improve this with actual read status later
  //     });
  //   }
  //   return chatList;
  // }

  Future<List<Map<String, dynamic>>> _fetchRecentChats() async {
    final chatSnapshots = await _firestore
        .collection('chats')
        .where('participants', arrayContains: _currentUserId)
        .orderBy('timestamp', descending: true)
        .get();

    final List<Map<String, dynamic>> chatList = [];
    final Set<String> chatWithIds = {};

    // Step 1: Extract chat partner IDs
    for (var doc in chatSnapshots.docs) {
      final data = doc.data();
      final participants = List<String>.from(data['participants'] ?? []);
      final chatWithId = participants.firstWhere(
        (id) => id != _currentUserId,
        orElse: () => '',
      );
      if (chatWithId.isNotEmpty) {
        chatWithIds.add(chatWithId);
      }
    }

    // ⛔️ Defensive check: Avoid whereIn if no IDs
    if (chatWithIds.isEmpty) return chatList;

    // ⛔️ Defensive check: Firestore only allows 10 items in whereIn
    final limitedIds = chatWithIds.length > 10
        ? chatWithIds.take(10).toList()
        : chatWithIds.toList();

    final userDocs = await _firestore
        .collection(widget.userRole == 'customer' ? 'workers' : 'users')
        .where(FieldPath.documentId, whereIn: limitedIds)
        .get();

    final userMap = {for (var doc in userDocs.docs) doc.id: doc.data()};

    for (var doc in chatSnapshots.docs) {
      final data = doc.data();
      final participants = List<String>.from(data['participants'] ?? []);
      final chatWithId = participants.firstWhere(
        (id) => id != _currentUserId,
        orElse: () => '',
      );

      if (chatWithId.isEmpty || !userMap.containsKey(chatWithId)) continue;

      final userData = userMap[chatWithId];
      if (userData == null) continue; // ✅ This is necessary

      chatList.add({
        'chatWithId': chatWithId,
        'chatWithName': userData['name'] ?? 'User',
        'imageUrl': userData['imageUrl'], // ✅ null is default if missing
        'lastMessage': data['lastMessage'] ?? '',
        'timestamp': data['timestamp'],
        'isRead': false, // You can improve this with actual read status later
      });
    }

    return chatList;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recent Chats'),
        backgroundColor: Colors.deepPurple,
        //automaticallyImplyLeading: false, // ✅ Fixes the double back arrow issue
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _fetchRecentChats(),

        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final chats = snapshot.data ?? [];

          if (chats.isEmpty) {
            return const Center(child: Text("No chats yet."));
          }

          return ListView.builder(
            itemCount: chats.length,
            itemBuilder: (context, index) {
              final chat = chats[index];
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                // leading: CircleAvatar(
                //   backgroundColor: Colors.deepPurple,
                //   child: Text(
                //     chat['chatWithName'].substring(0, 1).toUpperCase(),
                //     style: const TextStyle(color: Colors.white),
                //   ),
                // ),
                leading: chat['imageUrl'] != null
                    ? CircleAvatar(
                        backgroundImage: NetworkImage(chat['imageUrl']),
                      )
                    : CircleAvatar(
                        backgroundColor: Colors.deepPurple,
                        child: Text(
                          chat['chatWithName'].substring(0, 1).toUpperCase(),
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),

                title: Text(
                  chat['chatWithName'],
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  chat['lastMessage'],
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),

                // trailing: chat['isRead'] == false
                //     ? Container(
                //         padding: const EdgeInsets.symmetric(
                //           horizontal: 8,
                //           vertical: 4,
                //         ),
                //         decoration: BoxDecoration(
                //           color: Colors.redAccent,
                //           borderRadius: BorderRadius.circular(12),
                //         ),
                //         child: const Text(
                //           "New",
                //           style: TextStyle(
                //             color: Colors.white,
                //             fontSize: 12,
                //             fontWeight: FontWeight.bold,
                //           ),
                //         ),
                //       )
                //     : null,
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _formatTimestamp(chat['timestamp']),
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    if (chat['isRead'] == false)
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.redAccent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          "New",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),

                onTap: () {
                  Navigator.pushNamed(
                    context,
                    ChatScreen.routeName,
                    arguments: {
                      'chatWithId': chat['chatWithId'],
                      'chatWithName': chat['chatWithName'],
                      'userRole': widget.userRole,
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
