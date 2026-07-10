import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../core/theme/workable_design.dart';
import '../widgets/workable_ui.dart';

class WalletCreditsScreen extends StatefulWidget {
  static const routeName = '/wallet-credits';

  const WalletCreditsScreen({super.key});

  @override
  State<WalletCreditsScreen> createState() => _WalletCreditsScreenState();
}

class _WalletCreditsScreenState extends State<WalletCreditsScreen> {
  final _currency = NumberFormat.currency(locale: 'en_IN', symbol: 'Rs. ');
  final _dateFormat = DateFormat('dd MMM, h:mm a');

  bool showBalance = true;
  String activeTab = 'wallet';

  Stream<QuerySnapshot<Map<String, dynamic>>> _transactionStream(String uid) {
    return FirebaseFirestore.instance
        .collection('transactions')
        .where('customerId', isEqualTo: uid)
        .snapshots();
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

  bool _isWalletCredit(Map<String, dynamic> data) {
    final type = data['type']?.toString() ?? '';
    return type == 'wallet_credit' || type == 'cashback' || type == 'refund';
  }

  bool _isWalletDebit(Map<String, dynamic> data) {
    return data['type']?.toString() == 'wallet_debit';
  }

  double _walletBalance(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    return docs.fold<double>(0, (balance, doc) {
      final data = doc.data();
      final amount = _amount(data, 'total') != 0
          ? _amount(data, 'total')
          : _amount(data, 'amount');
      if (_isWalletCredit(data)) return balance + amount;
      if (_isWalletDebit(data)) return balance - amount;
      return balance;
    });
  }

  double _creditsEarnedThisMonth(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final now = DateTime.now();
    return docs.fold<double>(0, (total, doc) {
      final data = doc.data();
      final createdAt = _createdAt(data);
      if (createdAt.year != now.year || createdAt.month != now.month) {
        return total;
      }
      if (!_isWalletCredit(data)) return total;
      return total +
          (_amount(data, 'total') != 0
              ? _amount(data, 'total')
              : _amount(data, 'amount'));
    });
  }

  double _spentThisMonth(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final now = DateTime.now();
    return docs.fold<double>(0, (total, doc) {
      final data = doc.data();
      final createdAt = _createdAt(data);
      if (createdAt.year != now.year || createdAt.month != now.month) {
        return total;
      }
      final type = data['type']?.toString() ?? '';
      if (type == 'payment' ||
          type == 'upi_payment' ||
          type == 'wallet_debit') {
        return total + _amount(data, 'total');
      }
      return total;
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: WorkableDesign.canvas,
      appBar: AppBar(
        title: const Text('Wallet & Credits'),
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: user == null
          ? _emptyState('Sign in to view wallet')
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _transactionStream(user.uid),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return _emptyState('Unable to load wallet');
                }

                final docs = snapshot.data!.docs.toList()
                  ..sort(
                    (a, b) =>
                        _createdAt(b.data()).compareTo(_createdAt(a.data())),
                  );
                final balance = _walletBalance(docs);
                final earned = _creditsEarnedThisMonth(docs);
                final spent = _spentThisMonth(docs);
                final walletDocs = docs
                    .where(
                      (doc) =>
                          _isWalletCredit(doc.data()) ||
                          _isWalletDebit(doc.data()),
                    )
                    .toList();

                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    const WorkablePageHeader(
                      title: 'Wallet and credits',
                      subtitle:
                          'Track refunds, cashback, wallet usage, and monthly spending in one place.',
                      icon: LucideIcons.wallet,
                    ),
                    const SizedBox(height: 16),
                    _buildBalanceCard(balance, earned),
                    const SizedBox(height: 24),
                    _buildQuickActions(),
                    const SizedBox(height: 24),
                    _buildCreditsSummary(walletDocs),
                    const SizedBox(height: 24),
                    _buildTabs(),
                    const SizedBox(height: 16),
                    if (activeTab == 'wallet')
                      _buildWalletTransactions(walletDocs)
                    else
                      _buildAnalytics(spent, earned, docs),
                    const SizedBox(height: 24),
                    _buildSecurityInfo(),
                  ],
                );
              },
            ),
    );
  }

  Widget _buildBalanceCard(double balance, double earned) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1D4ED8),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -10,
            right: -10,
            child: Icon(
              LucideIcons.wallet,
              size: 100,
              color: Colors.white.withValues(alpha: 0.10),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(LucideIcons.wallet, size: 20, color: Colors.white),
                  const SizedBox(width: 8),
                  const Text(
                    'Wallet Balance',
                    style: TextStyle(color: Colors.white70),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(
                      showBalance ? LucideIcons.eye : LucideIcons.eyeOff,
                      color: Colors.white,
                      size: 20,
                    ),
                    onPressed: () => setState(() => showBalance = !showBalance),
                  ),
                ],
              ),
              Text(
                showBalance ? _currency.format(balance) : 'Rs. ***.**',
                style: const TextStyle(
                  fontSize: 28,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(
                    LucideIcons.trendingUp,
                    color: Colors.white70,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${_currency.format(earned)} earned this month',
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Actions',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1.45,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          children: [
            _quickAction(
              LucideIcons.plus,
              'Add Money',
              'Available after gateway setup',
              Colors.green,
            ),
            _quickAction(
              LucideIcons.rotateCcw,
              'Refunds',
              'Track returned credits',
              Colors.blue,
            ),
            _quickAction(
              LucideIcons.creditCard,
              'Pay Bill',
              'Use checkout from bookings',
              Colors.purple,
            ),
            _quickAction(
              LucideIcons.settings,
              'Settings',
              'Wallet preferences',
              Colors.grey,
            ),
          ],
        ),
      ],
    );
  }

  Widget _quickAction(
    IconData icon,
    String title,
    String subtitle,
    Color color,
  ) {
    return InkWell(
      onTap: () => _showSnack(subtitle),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          border: Border.all(color: Theme.of(context).dividerColor),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              backgroundColor: color,
              radius: 20,
              child: Icon(icon, size: 18, color: Colors.white),
            ),
            const SizedBox(height: 8),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCreditsSummary(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> walletDocs,
  ) {
    final cashback = walletDocs.fold<double>(0, (total, doc) {
      final data = doc.data();
      if (data['type']?.toString() != 'cashback') return total;
      return total + _amount(data, 'total');
    });
    final refunds = walletDocs.fold<double>(0, (total, doc) {
      final data = doc.data();
      if (data['type']?.toString() != 'refund') return total;
      return total + _amount(data, 'total');
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Available Credits',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _creditCard(
                'Cashback',
                _currency.format(cashback),
                Colors.green,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _creditCard(
                'Refunds',
                _currency.format(refunds),
                Colors.orange,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _creditCard(String title, String amount, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(LucideIcons.coins, color: color, size: 18),
          const SizedBox(height: 8),
          Text(title, style: TextStyle(color: color)),
          const SizedBox(height: 4),
          Text(
            amount,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildTabs() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          _tabButton('Transactions', 'wallet'),
          _tabButton('Analytics', 'analytics'),
        ],
      ),
    );
  }

  Widget _tabButton(String label, String value) {
    final active = activeTab == value;
    return Expanded(
      child: TextButton(
        onPressed: () => setState(() => activeTab = value),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: active ? Colors.blue : Colors.grey,
          ),
        ),
      ),
    );
  }

  Widget _buildWalletTransactions(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> walletDocs,
  ) {
    if (walletDocs.isEmpty) {
      return _emptyState('No wallet credits or refunds yet');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Recent Wallet Activity',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        ...walletDocs.take(8).map(_transactionItem),
      ],
    );
  }

  Widget _transactionItem(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final isCredit = _isWalletCredit(data);
    final amount = _amount(data, 'total') != 0
        ? _amount(data, 'total')
        : _amount(data, 'amount');

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(8),
        color: Theme.of(context).cardColor,
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: isCredit
                ? Colors.green.withValues(alpha: 0.12)
                : Colors.red.withValues(alpha: 0.12),
            child: Icon(
              isCredit ? LucideIcons.arrowDownLeft : LucideIcons.arrowUpRight,
              color: isCredit ? Colors.green : Colors.red,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _walletTitle(data),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  _dateFormat.format(_createdAt(data)),
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${isCredit ? '+' : '-'}${_currency.format(amount)}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isCredit ? Colors.green : Colors.red,
                ),
              ),
              Text(
                data['status']?.toString().replaceAll('_', ' ') ?? 'pending',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAnalytics(
    double spent,
    double earned,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final serviceTotals = <String, double>{};
    for (final doc in docs) {
      final data = doc.data();
      final type = data['type']?.toString() ?? '';
      if (type != 'payment' && type != 'upi_payment') continue;
      final service = data['service']?.toString() ?? 'Services';
      serviceTotals[service] =
          (serviceTotals[service] ?? 0) + _amount(data, 'total');
    }

    final sorted = serviceTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Spending Analytics',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Theme.of(context).dividerColor),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _analyticsMetric('Spent', _currency.format(spent), Colors.red),
              _analyticsMetric(
                'Credits',
                _currency.format(earned),
                Colors.green,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Theme.of(context).dividerColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Category Breakdown',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              if (sorted.isEmpty)
                const Text('No service payments yet')
              else
                ...sorted.take(5).map((entry) {
                  final percent = spent == 0 ? 0 : (entry.value / spent) * 100;
                  return _categoryRow(
                    entry.key,
                    '${_currency.format(entry.value)} (${percent.toStringAsFixed(0)}%)',
                    Colors.blue,
                  );
                }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _analyticsMetric(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(label, style: const TextStyle(color: Colors.grey)),
      ],
    );
  }

  Widget _categoryRow(String label, String amount, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          CircleAvatar(radius: 5, backgroundColor: color),
          const SizedBox(width: 8),
          Expanded(child: Text(label, overflow: TextOverflow.ellipsis)),
          Text(amount),
        ],
      ),
    );
  }

  Widget _buildSecurityInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Row(
        children: [
          CircleAvatar(
            backgroundColor: Colors.blue,
            child: Icon(LucideIcons.shield, color: Colors.white, size: 20),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Wallet values are calculated from verified transaction records.',
              style: TextStyle(color: Colors.blueGrey),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.wallet, color: Colors.grey.shade500, size: 42),
            const SizedBox(height: 12),
            Text(message, style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  String _walletTitle(Map<String, dynamic> data) {
    switch (data['type']?.toString()) {
      case 'cashback':
        return 'Cashback received';
      case 'refund':
        return 'Refund credited';
      case 'wallet_debit':
        return 'Wallet debit';
      default:
        return data['service']?.toString() ?? 'Wallet credit';
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }
}
