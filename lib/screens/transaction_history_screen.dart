import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../core/theme/workable_design.dart';
import '../widgets/workable_ui.dart';

class TransactionHistoryScreen extends StatefulWidget {
  static const routeName = '/transaction-history';

  final String ownerField;
  final String title;
  final bool isWorkerView;

  const TransactionHistoryScreen({
    super.key,
    this.ownerField = 'customerId',
    this.title = 'Transaction History',
    this.isWorkerView = false,
  });

  @override
  State<TransactionHistoryScreen> createState() =>
      _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState extends State<TransactionHistoryScreen> {
  final _currency = NumberFormat.currency(locale: 'en_IN', symbol: 'Rs. ');
  final _dateFormat = DateFormat('dd MMM yyyy, h:mm a');

  String activeFilter = 'all';
  String searchQuery = '';

  Stream<QuerySnapshot<Map<String, dynamic>>> _transactionStream(String uid) {
    return FirebaseFirestore.instance
        .collection('transactions')
        .where(widget.ownerField, isEqualTo: uid)
        .snapshots();
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _sortedDocs(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    final docs = snapshot.docs.toList();
    docs.sort((a, b) => _createdAt(b.data()).compareTo(_createdAt(a.data())));
    return docs;
  }

  DateTime _createdAt(Map<String, dynamic> data) {
    final timestamp = data['createdAt'] ?? data['updatedAt'];
    if (timestamp is Timestamp) return timestamp.toDate();
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  double _amount(Map<String, dynamic> data, String key) {
    final value = data[key];
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0;
    return 0;
  }

  bool _isCredit(Map<String, dynamic> data) {
    final type = data['type']?.toString() ?? '';
    return type == 'refund' || type == 'cashback' || type == 'wallet_credit';
  }

  bool _matchesFilter(Map<String, dynamic> data) {
    final type = data['type']?.toString() ?? '';
    if (activeFilter == 'all') return true;
    if (activeFilter == 'payment') {
      return type == 'payment' || type == 'upi_payment';
    }
    return type == activeFilter;
  }

  bool _matchesSearch(String id, Map<String, dynamic> data) {
    final query = searchQuery.trim().toLowerCase();
    if (query.isEmpty) return true;

    final values = [
      id,
      data['bookingId'],
      data['workerName'],
      data['service'],
      data['paymentMethod'],
      data['status'],
    ].whereType<Object>().map((value) => value.toString().toLowerCase());

    return values.any((value) => value.contains(query));
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: WorkableDesign.canvas,
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.download),
            onPressed: () => _showSnack('Export will be added after reports'),
          ),
        ],
      ),
      body: user == null
          ? _buildEmptyState('Sign in to view transactions')
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _transactionStream(user.uid),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return _buildEmptyState('Unable to load transactions');
                }

                final allDocs = _sortedDocs(snapshot.data!);
                final visibleDocs = allDocs.where((doc) {
                  final data = doc.data();
                  return _matchesFilter(data) && _matchesSearch(doc.id, data);
                }).toList();

                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    WorkablePageHeader(
                      title: widget.isWorkerView
                          ? 'Earnings ledger'
                          : 'Transaction ledger',
                      subtitle:
                          'Review payments, refunds, credits, and booking-linked money movement.',
                      icon: LucideIcons.receipt,
                    ),
                    const SizedBox(height: 16),
                    _buildSummaryCard(allDocs),
                    const SizedBox(height: 16),
                    _buildSearchField(),
                    const SizedBox(height: 12),
                    _buildFilters(),
                    const SizedBox(height: 16),
                    if (visibleDocs.isEmpty)
                      _buildEmptyState('No matching transactions')
                    else
                      ...visibleDocs.map(_buildTransactionCard),
                  ],
                );
              },
            ),
    );
  }

  Widget _buildSummaryCard(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final now = DateTime.now();
    final monthDocs = docs.where((doc) {
      final date = _createdAt(doc.data());
      return date.year == now.year && date.month == now.month;
    }).toList();

    final outgoing = monthDocs.fold<double>(0, (total, doc) {
      final data = doc.data();
      return _isCredit(data) ? total : total + _amount(data, 'total');
    });
    final incoming = monthDocs.fold<double>(0, (total, doc) {
      final data = doc.data();
      return _isCredit(data) ? total + _amount(data, 'total') : total;
    });
    final average = monthDocs.isEmpty ? 0 : outgoing / monthDocs.length;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text(
              'This Month Summary',
              style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _summaryMetric(
                  widget.isWorkerView ? 'Collected' : 'Total Spent',
                  _currency.format(outgoing),
                ),
                _summaryMetric(
                  widget.isWorkerView ? 'Adjustments' : 'Credits/Refunds',
                  _currency.format(incoming),
                  alignEnd: true,
                  color: Colors.green,
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _summaryMetric('Transactions', monthDocs.length.toString()),
                _summaryMetric(
                  'Avg. Amount',
                  _currency.format(average),
                  alignEnd: true,
                  color: Colors.purple,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryMetric(
    String label,
    String value, {
    bool alignEnd = false,
    Color? color,
  }) {
    return Column(
      crossAxisAlignment: alignEnd
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(label, style: const TextStyle(color: Colors.grey)),
      ],
    );
  }

  Widget _buildSearchField() {
    return TextField(
      decoration: InputDecoration(
        hintText: 'Search worker, booking, method, or status',
        prefixIcon: const Icon(Icons.search),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
      onChanged: (value) => setState(() => searchQuery = value),
    );
  }

  Widget _buildFilters() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildFilterChip('All', 'all'),
          _buildFilterChip('Payments', 'payment'),
          _buildFilterChip('Refunds', 'refund'),
          _buildFilterChip('Wallet', 'wallet_credit'),
          _buildFilterChip('Cashback', 'cashback'),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isActive = activeFilter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: isActive,
        onSelected: (_) => setState(() => activeFilter = value),
      ),
    );
  }

  Widget _buildTransactionCard(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    final isCredit = _isCredit(data);
    final total = _amount(data, 'total');
    final amount = _amount(data, 'amount');
    final platformFee = _amount(data, 'platformFee');
    final date = _createdAt(data);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: _typeColor(data).withValues(alpha: 0.12),
              child: Icon(_typeIcon(data), color: _typeColor(data), size: 20),
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
                          _titleFor(data),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      _statusPill(data['status']?.toString() ?? 'pending'),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    data['service']?.toString() ??
                        data['reason']?.toString() ??
                        'Workable transaction',
                    style: const TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_dateFormat.format(date)} • ID: ${data['id'] ?? doc.id}',
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${isCredit ? '+' : '-'}${_currency.format(total)}',
                  style: TextStyle(
                    color: isCredit ? Colors.green : Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (platformFee > 0)
                  Text(
                    '${_currency.format(amount)} + ${_currency.format(platformFee)} fee',
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                Text(
                  data['paymentMethod']?.toString() ?? '',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusPill(String status) {
    final color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        status.replaceAll('_', ' '),
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  IconData _typeIcon(Map<String, dynamic> data) {
    switch (data['type']?.toString()) {
      case 'refund':
        return LucideIcons.rotateCcw;
      case 'wallet_credit':
        return LucideIcons.wallet;
      case 'cashback':
        return LucideIcons.trendingUp;
      default:
        return LucideIcons.creditCard;
    }
  }

  Color _typeColor(Map<String, dynamic> data) {
    switch (data['type']?.toString()) {
      case 'refund':
      case 'cashback':
        return Colors.green;
      case 'wallet_credit':
        return Colors.purple;
      default:
        return Colors.blue;
    }
  }

  Color _statusColor(String status) {
    if (status.contains('paid') || status.contains('completed')) {
      return Colors.green;
    }
    if (status.contains('failed')) return Colors.red;
    return Colors.orange;
  }

  String _titleFor(Map<String, dynamic> data) {
    final type = data['type']?.toString() ?? '';
    switch (type) {
      case 'refund':
        return 'Refund';
      case 'wallet_credit':
        return 'Wallet Credit';
      case 'cashback':
        return 'Cashback';
      default:
        final worker = data['workerName']?.toString();
        return worker == null || worker.isEmpty ? 'Service Payment' : worker;
    }
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.receipt, size: 42, color: Colors.grey.shade500),
            const SizedBox(height: 12),
            Text(message, style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }
}
