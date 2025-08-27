import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';

class TransactionHistoryScreen extends StatefulWidget {
  static const routeName = '/transaction-history';

  const TransactionHistoryScreen({Key? key}) : super(key: key);

  @override
  State<TransactionHistoryScreen> createState() =>
      _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState extends State<TransactionHistoryScreen> {
  String activeFilter = 'all';
  String searchQuery = '';

  final List<Map<String, dynamic>> transactions = [
    {
      'id': 'TXN001',
      'type': 'payment',
      'worker': {'name': 'Raj Kumar', 'avatar': 'RK', 'rating': 4.8},
      'service': 'House Cleaning',
      'amount': 350,
      'platformFee': 35,
      'total': 385,
      'status': 'completed',
      'date': '2025-07-23',
      'time': '2:30 PM',
      'paymentMethod': 'UPI',
      'duration': '3 hours',
    },
    {
      'id': 'TXN002',
      'type': 'refund',
      'worker': {'name': 'Priya Singh', 'avatar': 'PS', 'rating': 4.5},
      'service': 'Laundry Service',
      'amount': 150,
      'total': 150,
      'status': 'completed',
      'date': '2025-07-22',
      'time': '11:45 AM',
      'paymentMethod': 'Wallet',
      'reason': 'Service cancelled by worker',
    },
    {
      'id': 'TXN003',
      'type': 'payment',
      'worker': {'name': 'Mohammad Ali', 'avatar': 'MA', 'rating': 4.9},
      'service': 'Plumbing Repair',
      'amount': 500,
      'platformFee': 50,
      'total': 550,
      'status': 'pending',
      'date': '2025-07-22',
      'time': '9:15 AM',
      'paymentMethod': 'Credit Card',
      'duration': '2 hours',
    },
    {
      'id': 'TXN004',
      'type': 'wallet_credit',
      'amount': 200,
      'total': 200,
      'status': 'completed',
      'date': '2025-07-21',
      'time': '6:00 PM',
      'paymentMethod': 'UPI',
      'reason': 'Wallet top-up',
    },
    {
      'id': 'TXN005',
      'type': 'cashback',
      'amount': 25,
      'total': 25,
      'status': 'completed',
      'date': '2025-07-20',
      'time': '3:20 PM',
      'reason': 'First booking cashback',
    },
  ];

  Icon getStatusIcon(String status) {
    switch (status) {
      case 'completed':
        return const Icon(
          LucideIcons.checkCircle,
          color: Colors.green,
          size: 16,
        );
      case 'pending':
        return const Icon(LucideIcons.clock, color: Colors.orange, size: 16);
      case 'failed':
        return const Icon(LucideIcons.xCircle, color: Colors.red, size: 16);
      default:
        return const Icon(
          LucideIcons.alertCircle,
          color: Colors.grey,
          size: 16,
        );
    }
  }

  Icon getTypeIcon(String type) {
    switch (type) {
      case 'payment':
        return const Icon(LucideIcons.creditCard, color: Colors.blue, size: 20);
      case 'refund':
        return const Icon(LucideIcons.rotateCcw, color: Colors.green, size: 20);
      case 'wallet_credit':
        return const Icon(LucideIcons.wallet, color: Colors.purple, size: 20);
      case 'cashback':
        return const Icon(
          LucideIcons.trendingUp,
          color: Colors.green,
          size: 20,
        );
      default:
        return const Icon(LucideIcons.creditCard, color: Colors.grey, size: 20);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredTransactions = transactions
        .where(
          (t) =>
              (activeFilter == 'all' || t['type'] == activeFilter) &&
              (searchQuery.isEmpty ||
                  (t['worker']?['name']?.toLowerCase().contains(
                        searchQuery.toLowerCase(),
                      ) ??
                      false) ||
                  (t['id']?.toLowerCase().contains(searchQuery.toLowerCase()))),
        )
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transaction History'),
        actions: [
          IconButton(icon: const Icon(LucideIcons.download), onPressed: () {}),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Summary Section
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Text(
                      'This Month Summary',
                      style: TextStyle(
                        color: Colors.grey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: const [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '₹1,285',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Total Spent',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '₹175',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                            Text(
                              'Total Saved',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: const [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '8',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            ),
                            Text(
                              'Transactions',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '₹350',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.purple,
                              ),
                            ),
                            Text(
                              'Avg. Amount',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Search Field
            TextField(
              decoration: InputDecoration(
                hintText: 'Search by worker name or booking ID',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (value) => setState(() => searchQuery = value),
            ),
            const SizedBox(height: 12),

            // Filter Chips
            SingleChildScrollView(
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
            ),
            const SizedBox(height: 8),

            // Date Filter
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: const [
                    Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                    SizedBox(width: 6),
                    Text('Last 30 days', style: TextStyle(color: Colors.grey)),
                  ],
                ),
                TextButton(
                  onPressed: () {},
                  child: const Text('Change Period'),
                ),
              ],
            ),

            // Transaction List
            const SizedBox(height: 8),
            ...filteredTransactions.map((tx) => _buildTransactionCard(tx)),

            // Footer
            const SizedBox(height: 20),
            TextButton(
              onPressed: () {},
              child: const Text('Load More Transactions'),
            ),
            const SizedBox(height: 10),
            const Text(
              'Showing transactions from last 30 days',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isActive = activeFilter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: ChoiceChip(
        label: Text(label),
        selected: isActive,
        onSelected: (_) => setState(() => activeFilter = value),
        selectedColor: Colors.blue.shade600,
        backgroundColor: Colors.grey.shade200,
        labelStyle: TextStyle(color: isActive ? Colors.white : Colors.black87),
      ),
    );
  }

  Widget _buildTransactionCard(Map<String, dynamic> tx) {
    final isPositive =
        tx['type'] == 'refund' ||
        tx['type'] == 'cashback' ||
        tx['type'] == 'wallet_credit';
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: Colors.grey.shade100,
              child: getTypeIcon(tx['type']),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        tx['type'] == 'payment'
                            ? 'Payment to'
                            : tx['type'] == 'refund'
                            ? 'Refund from'
                            : tx['type'] == 'wallet_credit'
                            ? 'Wallet Top-up'
                            : 'Cashback Received',
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(width: 6),
                      getStatusIcon(tx['status']),
                    ],
                  ),
                  if (tx['worker'] != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 10,
                            backgroundColor: Colors.blue,
                            child: Text(
                              tx['worker']['avatar'],
                              style: const TextStyle(
                                fontSize: 10,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            tx['worker']['name'],
                            style: const TextStyle(fontSize: 13),
                          ),
                          const SizedBox(width: 6),
                          const Icon(Icons.star, size: 14, color: Colors.amber),
                          Text(
                            '${tx['worker']['rating']}',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  if (tx['service'] != null || tx['reason'] != null)
                    Text(
                      tx['service'] ?? tx['reason'],
                      style: const TextStyle(color: Colors.grey),
                    ),
                  if (tx['duration'] != null)
                    Text(
                      "Duration: ${tx['duration']}",
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  const SizedBox(height: 4),
                  Text(
                    "${tx['date']} • ${tx['time']} • ID: ${tx['id']}",
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
                  '${isPositive ? '+' : '-'}₹${tx['total']}',
                  style: TextStyle(
                    color: isPositive ? Colors.green : Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (tx['platformFee'] != null)
                  Text(
                    '₹${tx['amount']} + ₹${tx['platformFee']} fee',
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                Text(
                  '${tx['paymentMethod'] ?? ''}',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
                const Icon(
                  LucideIcons.moreVertical,
                  size: 16,
                  color: Colors.grey,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
