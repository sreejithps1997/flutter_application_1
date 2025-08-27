import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

class WalletCreditsScreen extends StatefulWidget {
  static const routeName = '/wallet-credits';

  const WalletCreditsScreen({super.key});

  @override
  State<WalletCreditsScreen> createState() => _WalletCreditsScreenState();
}

class _WalletCreditsScreenState extends State<WalletCreditsScreen> {
  bool showBalance = true;
  String activeTab = 'wallet';

  Widget buildQuickAction(
    IconData icon,
    String title,
    String subtitle,
    Color color,
  ) {
    return InkWell(
      onTap: () {},
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          border: Border.all(color: color.withOpacity(0.2)),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
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

  Widget buildTransactionItem({
    required bool isCredit,
    required String title,
    required String date,
    required String category,
    required String amount,
    required String status,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade100),
        borderRadius: BorderRadius.circular(12),
        color: Colors.white,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isCredit ? Colors.green.shade50 : Colors.red.shade50,
              shape: BoxShape.circle,
            ),
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
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      date,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        category,
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${isCredit ? '+' : '-'}₹$amount',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isCredit ? Colors.green : Colors.red,
                ),
              ),
              Text(
                status,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget buildCreditCard({
    required String title,
    required String amount,
    required String expiry,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [color.withOpacity(0.9), color]),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -10,
            right: -10,
            child: Icon(
              LucideIcons.gift,
              size: 80,
              color: Colors.white.withOpacity(0.1),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(LucideIcons.coins, color: Colors.white, size: 16),
                  const SizedBox(width: 6),
                  Text(title, style: const TextStyle(color: Colors.white)),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '$amount Credits',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (expiry.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'Expires: $expiry',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          'Wallet & Credits',
          style: TextStyle(color: Colors.black),
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Wallet Balance
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Colors.blueAccent, Colors.blue],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Stack(
                children: [
                  Positioned(
                    top: -10,
                    right: -10,
                    child: Icon(
                      LucideIcons.wallet,
                      size: 100,
                      color: Colors.white.withOpacity(0.1),
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            LucideIcons.wallet,
                            size: 20,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Wallet Balance',
                            style: TextStyle(color: Colors.white70),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: Icon(
                              showBalance
                                  ? LucideIcons.eye
                                  : LucideIcons.eyeOff,
                              color: Colors.white,
                              size: 20,
                            ),
                            onPressed: () =>
                                setState(() => showBalance = !showBalance),
                          ),
                        ],
                      ),
                      Text(
                        showBalance ? '₹150.00' : '₹***.**',
                        style: const TextStyle(
                          fontSize: 28,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: const [
                          Icon(
                            LucideIcons.trendingUp,
                            color: Colors.white70,
                            size: 16,
                          ),
                          SizedBox(width: 6),
                          Text(
                            '₹75 earned this month',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Quick Actions
            const Text(
              'Quick Actions',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 1.3,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              children: [
                buildQuickAction(
                  LucideIcons.plus,
                  'Add Money',
                  'Top up wallet',
                  Colors.green,
                ),
                buildQuickAction(
                  LucideIcons.refreshCw,
                  'Auto Reload',
                  'Set up auto-reload',
                  Colors.blue,
                ),
                buildQuickAction(
                  LucideIcons.creditCard,
                  'Pay Bill',
                  'Quick payments',
                  Colors.purple,
                ),
                buildQuickAction(
                  LucideIcons.settings,
                  'Settings',
                  'Wallet preferences',
                  Colors.grey,
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Credits
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                Text(
                  'Available Credits',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text('View All', style: TextStyle(color: Colors.blue)),
              ],
            ),
            const SizedBox(height: 12),
            Column(
              children: [
                buildCreditCard(
                  title: 'Referral Bonus',
                  amount: '250',
                  expiry: 'Dec 31, 2025',
                  color: Colors.purple,
                ),
                const SizedBox(height: 12),
                buildCreditCard(
                  title: 'Loyalty Points',
                  amount: '180',
                  expiry: 'No expiry',
                  color: Colors.orange,
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Tabs
            Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => setState(() => activeTab = 'wallet'),
                      child: Text(
                        'Transactions',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: activeTab == 'wallet'
                              ? Colors.blue
                              : Colors.grey,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: TextButton(
                      onPressed: () => setState(() => activeTab = 'analytics'),
                      child: Text(
                        'Analytics',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: activeTab == 'analytics'
                              ? Colors.blue
                              : Colors.grey,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Tab content
            if (activeTab == 'wallet') ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  Text(
                    'Recent Transactions',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  Icon(LucideIcons.filter, size: 20),
                ],
              ),
              const SizedBox(height: 12),
              buildTransactionItem(
                isCredit: false,
                title: 'Plumber Service - Ravi Kumar',
                amount: '450',
                date: 'Today, 2:30 PM',
                status: 'Completed',
                category: 'Service',
              ),
              const SizedBox(height: 10),
              buildTransactionItem(
                isCredit: true,
                title: 'Wallet Top-up',
                amount: '500',
                date: 'Yesterday, 11:20 AM',
                status: 'Success',
                category: 'Add Money',
              ),
              const SizedBox(height: 10),
              buildTransactionItem(
                isCredit: true,
                title: 'Referral Bonus',
                amount: '100',
                date: 'Dec 20, 4:15 PM',
                status: 'Credited',
                category: 'Bonus',
              ),
            ] else ...[
              const Text(
                'Spending Analytics',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: const [
                    Column(
                      children: [
                        Text(
                          '₹1,245',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                          ),
                        ),
                        Text('Spent', style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                    Column(
                      children: [
                        Text(
                          '₹78',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                        Text('Saved', style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Category Breakdown',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    _buildCategoryRow('Plumbing', '₹680 (55%)', Colors.blue),
                    _buildCategoryRow('Electrical', '₹320 (26%)', Colors.green),
                    _buildCategoryRow('Cleaning', '₹245 (19%)', Colors.purple),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),

            // Security Info
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.blue,
                    child: const Icon(
                      LucideIcons.shield,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Wallet Protected',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.blue,
                          ),
                        ),
                        Text(
                          'Your transactions are secured with bank-level encryption',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.blueGrey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Text(label),
            ],
          ),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
