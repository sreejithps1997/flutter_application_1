import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

class MessagesScreen extends StatefulWidget {
  static const routeName = '/messages';
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  String activeView = 'list'; // list or chat
  String activeFilter = 'all';
  Map<String, dynamic>? selectedChat;
  String messageText = '';

  final conversations = [
    {
      'id': 1,
      'name': 'Rajesh Kumar',
      'type': 'worker',
      'service': 'Plumber',
      'lastMessage': 'I can start the work tomorrow morning at 9 AM',
      'time': '2m ago',
      'unread': 2,
      'avatar': 'RK',
      'status': 'online',
      'bookingId': '#BK123',
      'rating': 4.8,
    },
    {
      'id': 2,
      'name': 'Workable Support',
      'type': 'support',
      'service': 'Customer Support',
      'lastMessage': 'Your refund has been processed successfully',
      'time': '1h ago',
      'unread': 0,
      'avatar': 'WS',
      'status': 'online',
      'isSupport': true,
    },
    {
      'id': 3,
      'name': 'Priya Sharma',
      'type': 'worker',
      'service': 'House Cleaning',
      'lastMessage': 'Can you please share the house address?',
      'time': '3h ago',
      'unread': 1,
      'avatar': 'PS',
      'status': 'offline',
      'bookingId': '#BK124',
      'rating': 4.9,
    },
    {
      'id': 4,
      'name': 'Amit Singh',
      'type': 'worker',
      'service': 'Electrician',
      'lastMessage': 'Work completed. Please check and confirm',
      'time': '1d ago',
      'unread': 0,
      'avatar': 'AS',
      'status': 'offline',
      'bookingId': '#BK122',
      'rating': 4.7,
    },
  ];

  final chatMessages = [
    {
      'id': 1,
      'sender': 'worker',
      'message': 'Hello! I got your booking request for plumbing work.',
      'time': '10:30 AM',
      'status': 'read',
    },
    {
      'id': 2,
      'sender': 'user',
      'message': 'Hi Rajesh! Yes, I need help with kitchen sink repair.',
      'time': '10:32 AM',
      'status': 'read',
    },
    {
      'id': 3,
      'sender': 'worker',
      'message': 'Can you share some photos of the issue?',
      'time': '10:33 AM',
      'status': 'read',
    },
    {
      'id': 4,
      'sender': 'user',
      'message': 'Sure, let me send the photos',
      'time': '10:35 AM',
      'status': 'read',
      'hasImage': true,
    },
    {
      'id': 5,
      'sender': 'worker',
      'message': 'I can start the work tomorrow morning at 9 AM',
      'time': '10:45 AM',
      'status': 'delivered',
    },
  ];

  final quickReplies = [
    'What time works for you?',
    'Can you send location?',
    'How much will it cost?',
    'When can you start?',
  ];

  Widget buildMessageListItem(Map<String, dynamic> data) {
    final isSupport = data['isSupport'] == true;
    final isOnline = data['status'] == 'online';
    return ListTile(
      onTap: () {
        setState(() {
          selectedChat = data;
          activeView = 'chat';
        });
      },
      leading: Stack(
        children: [
          CircleAvatar(
            backgroundColor: isSupport
                ? Colors.green
                : isOnline
                ? Colors.blue
                : Colors.grey,
            child: Text(
              data['avatar'],
              style: const TextStyle(color: Colors.white),
            ),
          ),
          if (isOnline)
            const Positioned(
              right: 0,
              bottom: 0,
              child: CircleAvatar(backgroundColor: Colors.green, radius: 5),
            ),
        ],
      ),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(data['name'], overflow: TextOverflow.ellipsis)),
          Text(
            data['time'],
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(data['service'], style: const TextStyle(color: Colors.blue)),
          Text(data['lastMessage'], overflow: TextOverflow.ellipsis),
          if (data['bookingId'] != null)
            Text(
              "Booking: ${data['bookingId']}",
              style: const TextStyle(fontSize: 11),
            ),
        ],
      ),
      trailing: data['unread'] > 0
          ? CircleAvatar(
              radius: 10,
              backgroundColor: Colors.blue,
              child: Text(
                "${data['unread']}",
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            )
          : null,
    );
  }

  Widget buildChatMessage(Map<String, dynamic> msg) {
    final isUser = msg['sender'] == 'user';
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(10),
        constraints: const BoxConstraints(maxWidth: 300),
        decoration: BoxDecoration(
          color: isUser ? Colors.blue : Colors.grey[200],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: isUser
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            if (msg['hasImage'] == true)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                width: 100,
                height: 70,
                color: Colors.grey[300],
                child: const Icon(LucideIcons.camera, color: Colors.grey),
              ),
            Text(
              msg['message'],
              style: TextStyle(color: isUser ? Colors.white : Colors.black87),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  msg['time'],
                  style: TextStyle(
                    fontSize: 10,
                    color: isUser ? Colors.white70 : Colors.grey,
                  ),
                ),
                if (isUser)
                  Icon(
                    msg['status'] == 'read'
                        ? LucideIcons.checkCheck
                        : LucideIcons.check,
                    size: 14,
                    color: Colors.white70,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (activeView == 'chat' && selectedChat != null) {
      return Scaffold(
        appBar: AppBar(
          titleSpacing: 0,
          title: Row(
            children: [
              CircleAvatar(
                backgroundColor: Colors.blue,
                child: Text(
                  selectedChat!['avatar'],
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    selectedChat!['name'],
                    style: const TextStyle(fontSize: 16),
                  ),
                  Text(
                    selectedChat!['service'],
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ],
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => setState(() => activeView = 'list'),
          ),
          actions: const [
            IconButton(icon: Icon(LucideIcons.phone), onPressed: null),
            IconButton(icon: Icon(LucideIcons.moreVertical), onPressed: null),
          ],
        ),
        body: Column(
          children: [
            if (selectedChat!['bookingId'] != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                color: Colors.blue.shade50,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Booking: ${selectedChat!['bookingId']}",
                      style: const TextStyle(color: Colors.blue),
                    ),
                    TextButton(
                      onPressed: () {},
                      child: const Text("View Details"),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: chatMessages
                    .map((msg) => buildChatMessage(msg))
                    .toList(),
              ),
            ),
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                children: quickReplies.map((reply) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: OutlinedButton(
                      onPressed: () => setState(() => messageText = reply),
                      child: Text(reply, style: const TextStyle(fontSize: 12)),
                    ),
                  );
                }).toList(),
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(LucideIcons.paperclip),
                    onPressed: () {},
                  ),
                  IconButton(
                    icon: const Icon(LucideIcons.camera),
                    onPressed: () {},
                  ),
                  IconButton(
                    icon: const Icon(LucideIcons.mapPin),
                    onPressed: () {},
                  ),
                  Expanded(
                    child: TextField(
                      controller: TextEditingController(text: messageText),
                      onChanged: (val) => setState(() => messageText = val),
                      decoration: const InputDecoration(
                        hintText: 'Type a message...',
                        filled: true,
                        fillColor: Color(0xFFF3F4F6),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        border: OutlineInputBorder(
                          borderSide: BorderSide.none,
                          borderRadius: BorderRadius.all(Radius.circular(20)),
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(LucideIcons.mic),
                    onPressed: () {},
                  ),
                  IconButton(
                    icon: const Icon(LucideIcons.send),
                    onPressed: () {},
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Messages'),
        actions: const [
          IconButton(icon: Icon(LucideIcons.search), onPressed: null),
          IconButton(icon: Icon(LucideIcons.filter), onPressed: null),
        ],
      ),
      body: Column(
        children: [
          Row(
            children: [
              buildFilterTab('all', 'All', 4),
              buildFilterTab('workers', 'Workers', 3),
              buildFilterTab('support', 'Support', 1),
            ],
          ),
          Expanded(
            child: ListView(
              children: conversations
                  .where(
                    (c) =>
                        activeFilter == 'all' ||
                        c['type'] ==
                            activeFilter.substring(0, activeFilter.length - 1),
                  )
                  .map(buildMessageListItem)
                  .toList(),
            ),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(LucideIcons.headphones),
                    label: const Text("Contact Support"),
                    onPressed: () {
                      // TODO: Implement support
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(LucideIcons.archive),
                    label: const Text("Archived"),
                    onPressed: () {
                      // TODO: Show archived chats
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget buildFilterTab(String key, String label, int count) {
    final isActive = activeFilter == key;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => activeFilter = key),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                width: 2,
                color: isActive ? Colors.blue : Colors.transparent,
              ),
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            '$label ($count)',
            style: TextStyle(color: isActive ? Colors.blue : Colors.grey),
          ),
        ),
      ),
    );
  }
}
