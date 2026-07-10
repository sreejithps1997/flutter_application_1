import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../core/theme/workable_design.dart';
import '../widgets/workable_ui.dart';
import 'chat_screen.dart';

class MessagesScreen extends StatefulWidget {
  static const routeName = '/messages';
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final _searchController = TextEditingController();

  String _activeFilter = 'all';
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String get _currentUserId => _auth.currentUser?.uid ?? '';

  String _roleForRoute(BuildContext context) {
    final routeName = ModalRoute.of(context)?.settings.name ?? '';
    if (routeName.contains('worker')) return 'worker';
    return 'customer';
  }

  String _otherCollection(String role) {
    return role == 'customer' ? 'workers' : 'users';
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _chatStream() {
    return _firestore
        .collection('chats')
        .where('participants', arrayContains: _currentUserId)
        .snapshots();
  }

  Future<Map<String, dynamic>?> _loadPerson(
    String personId,
    String role,
  ) async {
    if (personId.isEmpty) return null;

    final primary = await _firestore
        .collection(_otherCollection(role))
        .doc(personId)
        .get();
    if (primary.exists) return primary.data();

    final fallback = await _firestore.collection('users').doc(personId).get();
    return fallback.data();
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _sortedDocs(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final copy = [...docs];
    copy.sort((a, b) {
      final aTime = _timestampFrom(a.data())?.toDate() ?? DateTime(1970);
      final bTime = _timestampFrom(b.data())?.toDate() ?? DateTime(1970);
      return bTime.compareTo(aTime);
    });
    return copy;
  }

  Timestamp? _timestampFrom(Map<String, dynamic> data) {
    return data['timestamp'] as Timestamp? ??
        data['lastMessageTime'] as Timestamp? ??
        data['updatedAt'] as Timestamp? ??
        data['createdAt'] as Timestamp?;
  }

  String _chatPartnerId(Map<String, dynamic> data) {
    final participants = List<String>.from(data['participants'] ?? const []);
    return participants.firstWhere(
      (id) => id != _currentUserId,
      orElse: () => '',
    );
  }

  String _lastMessage(Map<String, dynamic> data) {
    final last = (data['lastMessage'] ?? data['lastMessageText'] ?? '')
        .toString()
        .trim();
    if (last.isNotEmpty) return last;
    if (data['lastMessageType'] == 'image') return 'Photo';
    if (data['lastMessageType'] == 'location') return 'Location shared';
    return 'No messages yet';
  }

  int _unreadForMe(Map<String, dynamic> data) {
    final counts = data['unreadCounts'];
    if (counts is Map && counts[_currentUserId] is num) {
      return (counts[_currentUserId] as num).toInt();
    }
    return 0;
  }

  String _formatTime(Timestamp? timestamp) {
    if (timestamp == null) return '';

    final dt = timestamp.toDate();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDay = DateTime(dt.year, dt.month, dt.day);
    final days = today.difference(messageDay).inDays;

    if (days == 0) return DateFormat('h:mm a').format(dt);
    if (days == 1) return 'Yesterday';
    if (days < 7) return DateFormat('EEE').format(dt);
    return DateFormat('MMM d').format(dt);
  }

  bool _matchesFilter(Map<String, dynamic> data, String role) {
    if (_activeFilter == 'all') return true;
    if (_activeFilter == 'unread') return _unreadForMe(data) > 0;

    final bookingId = (data['bookingId'] ?? '').toString();
    if (_activeFilter == 'bookings') return bookingId.isNotEmpty;

    return role == _activeFilter;
  }

  bool _matchesSearch({
    required String name,
    required String subtitle,
    required String bookingId,
  }) {
    if (_searchQuery.isEmpty) return true;
    final q = _searchQuery.toLowerCase();
    return name.toLowerCase().contains(q) ||
        subtitle.toLowerCase().contains(q) ||
        bookingId.toLowerCase().contains(q);
  }

  String _initials(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  void _openChat({
    required String chatWithId,
    required String chatWithName,
    required String role,
    required String bookingId,
    required String service,
  }) {
    Navigator.pushNamed(
      context,
      ChatScreen.routeName,
      arguments: {
        'chatWithId': chatWithId,
        'chatWithName': chatWithName,
        'userRole': role,
        'bookingId': bookingId.isEmpty ? null : bookingId,
        'workerService': service.isEmpty ? null : service,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final role = _roleForRoute(context);
    if (_currentUserId.isEmpty) {
      return const Scaffold(
        backgroundColor: WorkableDesign.canvas,
        body: WorkableEmptyState(
          icon: LucideIcons.messageCircle,
          title: 'Please sign in first',
          message: 'Your booking and support conversations will appear here.',
        ),
      );
    }

    return Scaffold(
      backgroundColor: WorkableDesign.canvas,
      appBar: AppBar(
        title: const Text('Messages'),
        backgroundColor: WorkableDesign.surface,
        foregroundColor: WorkableDesign.ink,
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(LucideIcons.refreshCw),
            onPressed: () => setState(() {}),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                setState(() => _searchQuery = value.trim());
              },
              decoration: InputDecoration(
                hintText: 'Search conversations',
                prefixIcon: const Icon(LucideIcons.search),
                suffixIcon: _searchQuery.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear search',
                        icon: const Icon(LucideIcons.x),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      ),
                filled: true,
                fillColor: WorkableDesign.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(WorkableDesign.radius),
                  borderSide: const BorderSide(color: WorkableDesign.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(WorkableDesign.radius),
                  borderSide: const BorderSide(color: WorkableDesign.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(WorkableDesign.radius),
                  borderSide: const BorderSide(color: WorkableDesign.primary),
                ),
              ),
            ),
          ),
          _FilterBar(
            activeFilter: _activeFilter,
            onChanged: (value) => setState(() => _activeFilter = value),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _chatStream(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return _EmptyState(
                    icon: LucideIcons.messageCircle,
                    title: 'Messages could not load',
                    message: snapshot.error.toString(),
                  );
                }

                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = _sortedDocs(snapshot.data!.docs).where((doc) {
                  final chat = doc.data();
                  final chatWithId = _chatPartnerId(chat);
                  final fallbackName = (chat['chatWithName'] ?? '').toString();
                  final lastMessage = _lastMessage(chat);
                  final bookingId = (chat['bookingId'] ?? '').toString();
                  return chatWithId.isNotEmpty &&
                      _matchesFilter(chat, role) &&
                      _matchesSearch(
                        name: fallbackName,
                        subtitle: lastMessage,
                        bookingId: bookingId,
                      );
                }).toList();

                if (docs.isEmpty) {
                  return const _EmptyState(
                    icon: LucideIcons.messagesSquare,
                    title: 'No conversations yet',
                    message:
                        'Chats with workers will appear here after you send or receive a message.',
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final chat = docs[index].data();
                    final chatWithId = _chatPartnerId(chat);
                    final lastMessage = _lastMessage(chat);
                    final bookingId = (chat['bookingId'] ?? '').toString();

                    return FutureBuilder<Map<String, dynamic>?>(
                      future: _loadPerson(chatWithId, role),
                      builder: (context, personSnapshot) {
                        final person = personSnapshot.data;
                        final name =
                            (person?['name'] ??
                                    person?['fullName'] ??
                                    chat['chatWithName'] ??
                                    'Workable User')
                                .toString();
                        final service =
                            (person?['service'] ??
                                    person?['profession'] ??
                                    chat['service'] ??
                                    '')
                                .toString();

                        return _ConversationTile(
                          name: name,
                          subtitle: lastMessage,
                          service: service,
                          bookingId: bookingId,
                          time: _formatTime(_timestampFrom(chat)),
                          initials: _initials(name),
                          imageUrl:
                              (person?['imageUrl'] ??
                                      person?['profileImageUrl'] ??
                                      person?['photoUrl'])
                                  ?.toString(),
                          unreadCount: _unreadForMe(chat),
                          onTap: () => _openChat(
                            chatWithId: chatWithId,
                            chatWithName: name,
                            role: role,
                            bookingId: bookingId,
                            service: service,
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.activeFilter, required this.onChanged});

  final String activeFilter;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final filters = const [
      ('all', 'All'),
      ('unread', 'Unread'),
      ('bookings', 'Bookings'),
    ];

    return SizedBox(
      height: 44,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final (key, label) = filters[index];
          final selected = key == activeFilter;
          return ChoiceChip(
            label: Text(label),
            selected: selected,
            onSelected: (_) => onChanged(key),
            selectedColor: WorkableDesign.primary.withValues(alpha: 0.1),
            backgroundColor: WorkableDesign.surface,
            checkmarkColor: WorkableDesign.primary,
            side: BorderSide(
              color: selected
                  ? WorkableDesign.primary.withValues(alpha: 0.28)
                  : WorkableDesign.border,
            ),
            labelStyle: TextStyle(
              color: selected ? WorkableDesign.primary : WorkableDesign.ink,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            ),
          );
        },
      ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({
    required this.name,
    required this.subtitle,
    required this.service,
    required this.bookingId,
    required this.time,
    required this.initials,
    required this.imageUrl,
    required this.unreadCount,
    required this.onTap,
  });

  final String name;
  final String subtitle;
  final String service;
  final String bookingId;
  final String time;
  final String initials;
  final String? imageUrl;
  final int unreadCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasUnread = unreadCount > 0;

    return Container(
      decoration: WorkableDesign.cardDecoration(
        borderColor: hasUnread
            ? WorkableDesign.primary.withValues(alpha: 0.26)
            : WorkableDesign.border,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(WorkableDesign.radius),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: WorkableDesign.primary,
                backgroundImage: imageUrl == null || imageUrl!.isEmpty
                    ? null
                    : NetworkImage(imageUrl!),
                child: imageUrl == null || imageUrl!.isEmpty
                    ? Text(
                        initials,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      )
                    : null,
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
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: WorkableDesign.ink,
                              fontWeight: hasUnread
                                  ? FontWeight.w800
                                  : FontWeight.w600,
                            ),
                          ),
                        ),
                        if (time.isNotEmpty)
                          Text(
                            time,
                            style: TextStyle(
                              fontSize: 12,
                              color: hasUnread
                                  ? WorkableDesign.primary
                                  : WorkableDesign.muted,
                              fontWeight: hasUnread
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    if (service.isNotEmpty)
                      Text(
                        service,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: WorkableDesign.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: hasUnread
                            ? WorkableDesign.ink
                            : WorkableDesign.muted,
                        fontWeight: hasUnread
                            ? FontWeight.w700
                            : FontWeight.w400,
                      ),
                    ),
                    if (bookingId.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Text(
                          'Booking: $bookingId',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: WorkableDesign.muted,
                            fontSize: 11,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (hasUnread) ...[
                const SizedBox(width: 10),
                CircleAvatar(
                  radius: 11,
                  backgroundColor: WorkableDesign.primary,
                  child: Text(
                    unreadCount > 9 ? '9+' : '$unreadCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return WorkableEmptyState(icon: icon, title: title, message: message);
  }
}
