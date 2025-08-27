import 'package:flutter/material.dart';

class ViewEarningsScreen extends StatelessWidget {
  static const routeName = '/view-earnings';

  const ViewEarningsScreen({super.key});

  final double totalEarnings = 12450.00;
  final int completedJobs = 18;

  final List<Map<String, dynamic>> dummyTransactions = const [
    {
      "date": "05 Jul 2025",
      "amount": 750.0,
      "service": "Electrician",
      "status": "Paid",
    },
    {
      "date": "03 Jul 2025",
      "amount": 1200.0,
      "service": "Plumber",
      "status": "Paid",
    },
    {
      "date": "01 Jul 2025",
      "amount": 550.0,
      "service": "Cleaner",
      "status": "Pending",
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Earnings"),
        backgroundColor: Colors.deepPurple,
        automaticallyImplyLeading: false, // ✅ Fixes the double back arrow issue
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _summaryCard(
              icon: Icons.attach_money,
              label: "Total Earnings",
              value: "₹${totalEarnings.toStringAsFixed(2)}",
              color: Colors.green,
            ),
            const SizedBox(height: 12),
            _summaryCard(
              icon: Icons.check_circle_outline,
              label: "Completed Jobs",
              value: "$completedJobs",
              color: Colors.deepPurple,
            ),
            const SizedBox(height: 24),
            const Text(
              "Transaction History",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: dummyTransactions.isEmpty
                  ? const Center(child: Text("No transactions yet"))
                  : ListView.separated(
                      itemCount: dummyTransactions.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final txn = dummyTransactions[index];
                        return _transactionTile(txn);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        border: Border.all(color: color.withOpacity(0.2)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 28, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _transactionTile(Map<String, dynamic> txn) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: const Icon(
          Icons.account_balance_wallet,
          color: Colors.deepPurple,
        ),
        title: Text(txn['service']),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Date: ${txn['date']}"),
            Text(
              "Status: ${txn['status']}",
              style: TextStyle(
                color: txn['status'] == 'Paid' ? Colors.green : Colors.orange,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        trailing: Text(
          "₹${txn['amount'].toStringAsFixed(2)}",
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.deepPurple,
          ),
        ),
      ),
    );
  }
}
