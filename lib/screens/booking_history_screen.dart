import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/booking_flow.dart';

class BookingHistoryScreen extends StatefulWidget {
  static const routeName = '/booking-history';

  const BookingHistoryScreen({Key? key}) : super(key: key);

  @override
  State<BookingHistoryScreen> createState() => _BookingHistoryScreenState();
}

class _BookingHistoryScreenState extends State<BookingHistoryScreen> {
  String searchQuery = '';
  String selectedFilter = 'all';
  bool showFilters = false;
  final int _pageSize = 10;

  DocumentSnapshot? _lastDocument;
  bool _isLoadingMore = false;
  List<DocumentSnapshot> _bookings = [];

  @override
  void initState() {
    super.initState();
    _fetchInitialBookings();
  }

  Future<void> _fetchInitialBookings() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    final query = FirebaseFirestore.instance
        .collection('bookings')
        .where('customerId', isEqualTo: userId)
        .where('status', whereIn: ['completed', 'cancelled'])
        .orderBy('createdAt', descending: true)
        .limit(_pageSize);

    final snapshot = await query.get();
    setState(() {
      _bookings = snapshot.docs;
      _lastDocument = snapshot.docs.isNotEmpty ? snapshot.docs.last : null;
    });
  }

  Future<void> _loadMoreBookings() async {
    if (_lastDocument == null || _isLoadingMore) return;

    setState(() => _isLoadingMore = true);

    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      setState(() => _isLoadingMore = false);
      return;
    }

    final query = FirebaseFirestore.instance
        .collection('bookings')
        .where('customerId', isEqualTo: userId)
        .where('status', whereIn: ['completed', 'cancelled'])
        .orderBy('createdAt', descending: true)
        .startAfterDocument(_lastDocument!)
        .limit(_pageSize);

    final snapshot = await query.get();
    setState(() {
      _bookings.addAll(snapshot.docs);
      _lastDocument = snapshot.docs.isNotEmpty ? snapshot.docs.last : null;
      _isLoadingMore = false;
    });
  }

  String formatAmount(num amount) {
    final formatter = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
    return formatter.format(amount);
  }

  Color getStatusColor(String status) {
    switch (status) {
      case 'completed':
        return Colors.green.shade600;
      case 'cancelled':
        return Colors.red.shade600;
      default:
        return Colors.grey.shade600;
    }
  }

  Widget buildFilterChip(String label, String value) {
    final isActive = selectedFilter == value;
    return ChoiceChip(
      label: Text(label),
      selected: isActive,
      onSelected: (_) => setState(() => selectedFilter = value),
      selectedColor: Colors.blue.shade600,
      backgroundColor: Colors.grey.shade200,
      labelStyle: TextStyle(color: isActive ? Colors.white : Colors.black87),
    );
  }

  List<DocumentSnapshot> get filteredBookings {
    return _bookings.where((doc) {
      final booking = doc.data() as Map<String, dynamic>;
      final matchesQuery =
          (booking['workerName']?.toString().toLowerCase().contains(
                searchQuery.toLowerCase(),
              ) ??
              false) ||
          (booking['serviceType']?.toString().toLowerCase().contains(
                searchQuery.toLowerCase(),
              ) ??
              false);

      final matchesFilter =
          selectedFilter == 'all' ||
          booking['status'] == selectedFilter ||
          (selectedFilter == 'month' &&
              booking['createdAt'] != null &&
              (booking['createdAt'] as Timestamp).toDate().month ==
                  DateTime.now().month);

      return matchesQuery && matchesFilter;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final total = _bookings.length;
    final completed = _bookings
        .where((doc) => (doc.data() as Map)['status'] == 'completed')
        .length;
    final cancelled = _bookings
        .where((doc) => (doc.data() as Map)['status'] == 'cancelled')
        .length;

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text('Booking History'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.filter),
            onPressed: () => setState(() => showFilters = !showFilters),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            decoration: InputDecoration(
              hintText: 'Search by worker or service...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
            onChanged: (val) => setState(() => searchQuery = val),
          ),
          const SizedBox(height: 12),

          if (showFilters)
            Wrap(
              spacing: 8,
              children: [
                buildFilterChip('All', 'all'),
                buildFilterChip('Completed', 'completed'),
                buildFilterChip('Cancelled', 'cancelled'),
                buildFilterChip('This Month', 'month'),
              ],
            ),

          const SizedBox(height: 16),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStat('Total', total.toString(), Colors.blue),
                _buildStat('Completed', completed.toString(), Colors.green),
                _buildStat('Cancelled', cancelled.toString(), Colors.red),
              ],
            ),
          ),
          const SizedBox(height: 16),

          if (filteredBookings.isEmpty)
            _buildEmptyState()
          else
            ...filteredBookings.map((doc) => _buildBookingCard(doc)),

          if (_lastDocument != null && !_isLoadingMore)
            Center(
              child: TextButton.icon(
                icon: const Icon(Icons.refresh),
                label: const Text('Load More Bookings'),
                onPressed: _loadMoreBookings,
              ),
            ),
          if (_isLoadingMore)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(8.0),
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Colors.grey)),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: const [
          Icon(LucideIcons.clock, size: 48, color: Colors.grey),
          SizedBox(height: 8),
          Text(
            'No Bookings Yet',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 4),
          Text(
            'Your booking history will appear here.',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  // Safe initials helper (no crashes on empty strings)
  String initials(String? name, {int count = 2}) {
    final s = (name ?? '').trim();
    if (s.isEmpty) return '?';
    final end = s.length < count ? s.length : count;
    return s.substring(0, end).toUpperCase();
  }

  Widget _buildBookingCard(DocumentSnapshot doc) {
    final b = doc.data() as Map<String, dynamic>;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade100),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: Colors.blue.shade600,
                foregroundColor: Colors.white,
                child: Text(initials(b['workerName'])),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (b['workerName'] as String?)?.trim().isNotEmpty == true
                          ? b['workerName']
                          : 'Unknown',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      b['serviceType'] ?? 'Service',
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
              Chip(
                avatar: Icon(
                  LucideIcons.checkCircle,
                  size: 16,
                  color: getStatusColor(b['status'] ?? ''),
                ),
                label: Text(
                  (b['status'] ?? '').toString().toUpperCase(),
                  style: TextStyle(color: getStatusColor(b['status'] ?? '')),
                ),
                backgroundColor: getStatusColor(
                  b['status'] ?? '',
                ).withOpacity(0.1),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
              const SizedBox(width: 6),
              Text(_formatDate(b['createdAt'])),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.location_on, size: 16, color: Colors.grey),
              const SizedBox(width: 6),
              Text(b['address'] ?? 'No address'),
            ],
          ),
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.currency_rupee, size: 16),
                  Text(formatAmount(b['totalAmount'] ?? 0)),
                ],
              ),
              if (b['rating'] != null)
                Row(
                  children: [
                    const Icon(Icons.star, color: Colors.amber, size: 16),
                    const SizedBox(width: 2),
                    Text(b['rating'].toString()),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ElevatedButton.icon(
                onPressed: () => BookingFlow.rebook(context, b),
                icon: const Icon(Icons.replay, size: 18),
                label: const Text('Rebook'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade50,
                  foregroundColor: Colors.blue.shade700,
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => _callWorker(b['workerPhone']),
                icon: const Icon(Icons.call, size: 18),
                label: const Text('Call'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade50,
                  foregroundColor: Colors.green.shade700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp is Timestamp) {
      return DateFormat('yyyy-MM-dd • hh:mm a').format(timestamp.toDate());
    }
    return 'N/A';
  }

  void _callWorker(String? phone) async {
    if (phone != null && phone.isNotEmpty) {
      final uri = Uri(scheme: 'tel', path: phone);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
    }
  }
}
