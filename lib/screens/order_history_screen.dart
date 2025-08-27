import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class OrderHistoryScreen extends StatelessWidget {
  static const routeName = '/order-history';

  const OrderHistoryScreen({super.key});

  Future<List<Map<String, dynamic>>> _fetchOrderHistory() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return [];

    final snapshot = await FirebaseFirestore.instance
        .collection('bookings')
        .where('customerId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      return {
        'service': data['issue'] ?? 'Service',
        'worker': data['workerName'] ?? 'Unknown',
        'date': data['preferredDate'] ?? '--',
        'time': data['preferredTime'] ?? '--',
        'status': data['status'] ?? 'Pending',
        'amount': data['amount'] ?? 0,
      };
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Order History"),
        backgroundColor: Colors.deepPurple,
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _fetchOrderHistory(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final orders = snapshot.data ?? [];

          if (orders.isEmpty) {
            return const Center(
              child: Text(
                "You have no order history yet.",
                style: TextStyle(fontSize: 16),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: orders.length,
            itemBuilder: (context, index) {
              final order = orders[index];
              return _orderCard(order);
            },
          );
        },
      ),
    );
  }

  Widget _orderCard(Map<String, dynamic> order) {
    final Color statusColor = _getStatusColor(order['status']);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              order['service'],
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text("Worker: ${order['worker']}"),
            Text("Date: ${order['date']} at ${order['time']}"),
            Text("Amount Paid: ₹${order['amount']}"),
            const SizedBox(height: 8),
            Chip(
              label: Text(
                order['status'].toString().toUpperCase(),
                style: const TextStyle(color: Colors.white),
              ),
              backgroundColor: statusColor,
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      case 'pending':
        return Colors.orange;
      case 'confirmed':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }
}
