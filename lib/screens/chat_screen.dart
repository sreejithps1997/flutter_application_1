import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/theme/workable_design.dart';
import '../services/chat_service.dart'; // Adjust path as needed
import '../widgets/workable_ui.dart';
import 'dart:async';
import 'package:intl/intl.dart';

class ChatScreen extends StatefulWidget {
  static const routeName = '/chat';

  final String chatWithId;
  final String chatWithName;
  final String userRole;
  final String? bookingId; // Added for booking context
  final String? workerService; // Added for service type
  final double? workerRating; // Added for rating display

  const ChatScreen({
    super.key,
    required this.chatWithId,
    required this.chatWithName,
    required this.userRole,
    this.bookingId,
    this.workerService,
    this.workerRating,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ChatService _chatService = ChatService();
  final _auth = FirebaseAuth.instance;
  bool _showQuickReplies = false;

  late final String _chatId;
  Timer? _typingTimer;

  // Quick reply templates
  final List<String> _quickReplies = [
    'What time works for you?',
    'Can you send location?',
    'How much will it cost?',
    'When can you start?',
    'Work looks good, thanks!',
    'I\'ll be there in 10 minutes',
  ];

  @override
  void initState() {
    super.initState();
    final user = _auth.currentUser;
    if (user == null) return;
    final myId = user.uid;
    _chatId = _chatService.getChatId(myId, widget.chatWithId);
  }

  Future<void> _sendMessage([String? customText]) async {
    final text = customText ?? _messageController.text.trim();
    if (text.isEmpty) return;
    try {
      await _chatService.sendTextMessage(_chatId, text);
      if (customText == null) _messageController.clear();
      setState(() {
        _showQuickReplies = false;
      });
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  String _formatTimestamp(Timestamp timestamp) {
    final dt = timestamp.toDate();
    final now = DateTime.now();
    final difference = now.difference(dt);

    if (difference.inDays == 0) {
      return DateFormat('h:mm a').format(dt); // Today: 2:30 PM
    } else if (difference.inDays == 1) {
      return 'Yesterday ${DateFormat('h:mm a').format(dt)}';
    } else {
      return DateFormat('MMM d, h:mm a').format(dt); // Jul 19, 12:04 PM
    }
  }

  Future<void> _sendImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;
    try {
      await _chatService.sendImageMessage(_chatId, File(image.path));
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  Future<void> _sendLocation() async {
    try {
      await _chatService.sendLocationMessage(_chatId);
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 300), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _updateTypingStatus(bool isTyping) {
    _chatService.updateTypingStatus(_chatId, widget.userRole, isTyping);
  }

  Future<void> _openBookingDetails() async {
    final bookingId = widget.bookingId;
    if (bookingId == null || bookingId.trim().isEmpty) return;

    if (widget.userRole == 'worker') {
      Navigator.pushNamed(context, '/worker-job-details', arguments: bookingId);
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('bookings')
          .doc(bookingId)
          .get();
      if (!mounted) return;
      if (!doc.exists || doc.data() == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Booking details not found')),
        );
        return;
      }
      Navigator.pushNamed(
        context,
        '/customer-booking-detail',
        arguments: {'id': doc.id, ...doc.data()!},
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Unable to open booking: $e')));
    }
  }

  Widget _buildMessage(Map<String, dynamic> msg, bool isMe) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: isMe
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: WorkableDesign.primary,
              child: Text(
                widget.chatWithName[0].toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isMe ? WorkableDesign.primary : WorkableDesign.surface,
                border: isMe ? null : Border.all(color: WorkableDesign.border),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isMe ? 16 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 16),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (msg['text'] != null)
                    Text(
                      msg['text'],
                      style: TextStyle(
                        fontSize: 14,
                        color: isMe ? Colors.white : WorkableDesign.ink,
                      ),
                    ),
                  if (msg['imageUrl'] != null)
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      clipBehavior: Clip.hardEdge,
                      child: Image.network(
                        msg['imageUrl'],
                        width: 200,
                        fit: BoxFit.cover,
                      ),
                    ),
                  if (msg['locationUrl'] != null)
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isMe
                            ? WorkableDesign.primaryDark
                            : WorkableDesign.canvas,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: InkWell(
                        onTap: () => launchUrl(Uri.parse(msg['locationUrl'])),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.location_on,
                              color: isMe
                                  ? Colors.white
                                  : WorkableDesign.primary,
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              "View Location",
                              style: TextStyle(
                                color: isMe
                                    ? Colors.white
                                    : WorkableDesign.primary,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (msg['timestamp'] != null)
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _formatTimestamp(msg['timestamp']),
                            style: TextStyle(
                              fontSize: 10,
                              color: isMe
                                  ? Colors.white70
                                  : WorkableDesign.muted,
                            ),
                          ),
                          if (isMe) ...[
                            const SizedBox(width: 4),
                            Icon(
                              msg['isRead'] == true
                                  ? Icons.done_all
                                  : Icons.check,
                              size: 12,
                              color: msg['isRead'] == true
                                  ? Colors.white
                                  : Colors.white70,
                            ),
                          ],
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (isMe) const SizedBox(width: 40),
        ],
      ),
    );
  }

  Widget _buildQuickReplies() {
    if (!_showQuickReplies) return const SizedBox.shrink();

    return Container(
      height: 40,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _quickReplies.length,
        itemBuilder: (context, index) {
          return Container(
            margin: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => _sendMessage(_quickReplies[index]),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: WorkableDesign.surface,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: WorkableDesign.border),
                ),
                child: Text(
                  _quickReplies[index],
                  style: TextStyle(fontSize: 12, color: WorkableDesign.ink),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final uid = _auth.currentUser!.uid;

    return Scaffold(
      backgroundColor: WorkableDesign.canvas,
      appBar: AppBar(
        backgroundColor: WorkableDesign.surface,
        foregroundColor: WorkableDesign.ink,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: WorkableDesign.ink),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: WorkableDesign.primary,
              child: Text(
                widget.chatWithName[0].toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.chatWithName,
                    style: const TextStyle(
                      color: WorkableDesign.ink,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (widget.workerService != null)
                    Text(
                      widget.workerService!,
                      style: TextStyle(
                        color: WorkableDesign.muted,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
            if (widget.workerRating != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.star, size: 12, color: Colors.amber.shade600),
                    const SizedBox(width: 2),
                    Text(
                      widget.workerRating!.toStringAsFixed(1),
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.amber.shade800,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.phone, color: WorkableDesign.muted),
            onPressed: () {
              // Add phone call functionality
            },
          ),
          IconButton(
            icon: Icon(Icons.more_vert, color: WorkableDesign.muted),
            onPressed: () {
              // Add more options
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Booking Context Bar
          if (widget.bookingId != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: WorkableDesign.primary.withValues(alpha: 0.08),
              child: Row(
                children: [
                  Icon(
                    Icons.work_outline,
                    size: 16,
                    color: WorkableDesign.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Booking: ${widget.bookingId}',
                    style: TextStyle(
                      fontSize: 12,
                      color: WorkableDesign.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: _openBookingDetails,
                    child: Text(
                      'View Details',
                      style: TextStyle(
                        fontSize: 12,
                        color: WorkableDesign.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Typing Indicator
          StreamBuilder<DocumentSnapshot>(
            stream: _chatService.getTypingStatusStream(_chatId),
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                final data = snapshot.data!.data() as Map<String, dynamic>?;
                final isOtherTyping =
                    data != null &&
                    data[widget.userRole == 'customer'
                            ? 'worker'
                            : 'customer'] ==
                        true;
                return isOtherTyping
                    ? Container(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            const SizedBox(width: 40),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: WorkableDesign.surface,
                                border: Border.all(
                                  color: WorkableDesign.border,
                                ),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        WorkableDesign.muted,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    "typing...",
                                    style: TextStyle(
                                      color: WorkableDesign.muted,
                                      fontSize: 12,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      )
                    : const SizedBox.shrink();
              } else {
                return const SizedBox.shrink();
              }
            },
          ),

          // Messages
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _chatService.getMessages(_chatId),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data!.docs;

                // Mark messages as read
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _chatService.markMessagesAsRead(_chatId);
                });

                if (docs.isEmpty) {
                  return WorkableEmptyState(
                    icon: Icons.chat_bubble_outline,
                    title: 'Start your conversation',
                    message:
                        'Send a message to begin chatting with ${widget.chatWithName}.',
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final msg = docs[index].data() as Map<String, dynamic>;
                    final isMe = msg['senderId'] == uid;
                    return _buildMessage(msg, isMe);
                  },
                );
              },
            ),
          ),

          // Quick Replies
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _buildQuickReplies(),
          ),

          // Message Input
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: WorkableDesign.surface,
              border: const Border(
                top: BorderSide(color: WorkableDesign.border),
              ),
            ),
            child: Row(
              children: [
                // Attachment button
                Container(
                  decoration: BoxDecoration(
                    color: WorkableDesign.canvas,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: PopupMenuButton<String>(
                    icon: Icon(
                      Icons.add,
                      color: WorkableDesign.muted,
                      size: 20,
                    ),
                    onSelected: (value) {
                      switch (value) {
                        case 'image':
                          _sendImage();
                          break;
                        case 'location':
                          _sendLocation();
                          break;
                        case 'quick_replies':
                          setState(() {
                            _showQuickReplies = !_showQuickReplies;
                          });
                          break;
                      }
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'image',
                        child: Row(
                          children: [
                            Icon(Icons.photo, size: 20),
                            SizedBox(width: 8),
                            Text('Photo'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'location',
                        child: Row(
                          children: [
                            Icon(Icons.location_on, size: 20),
                            SizedBox(width: 8),
                            Text('Location'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'quick_replies',
                        child: Row(
                          children: [
                            Icon(Icons.reply_all, size: 20),
                            SizedBox(width: 8),
                            Text('Quick Replies'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),

                // Text input
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: WorkableDesign.canvas,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: TextField(
                      controller: _messageController,
                      decoration: const InputDecoration(
                        hintText: "Type a message...",
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                      ),
                      maxLines: null,
                      onChanged: (value) {
                        _updateTypingStatus(true);
                        _typingTimer?.cancel();
                        _typingTimer = Timer(const Duration(seconds: 2), () {
                          _updateTypingStatus(false);
                        });
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Send button
                GestureDetector(
                  onTap: _sendMessage,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: WorkableDesign.primary,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(
                      Icons.send,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
