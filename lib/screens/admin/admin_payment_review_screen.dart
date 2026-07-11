import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';

class AdminPaymentReviewScreen extends StatefulWidget {
  static const routeName = '/admin-payment-review';

  const AdminPaymentReviewScreen({super.key});

  @override
  State<AdminPaymentReviewScreen> createState() =>
      _AdminPaymentReviewScreenState();
}

class _AdminPaymentReviewScreenState extends State<AdminPaymentReviewScreen> {
  final _currency = NumberFormat.currency(locale: 'en_IN', symbol: 'Rs. ');
  final _dateFormat = DateFormat('dd MMM yyyy, h:mm a');
  final _functions = FirebaseFunctions.instanceFor(region: 'us-central1');
  bool _busy = false;

  Stream<QuerySnapshot<Map<String, dynamic>>> _pendingPayments() {
    return FirebaseFirestore.instance
        .collection('bookings')
        .where('status', isEqualTo: 'payment_under_review')
        .snapshots();
  }

  Future<void> _approve(String bookingId) async {
    setState(() => _busy = true);
    try {
      await _functions.httpsCallable('reviewPaymentRequest').call({
        'bookingId': bookingId,
        'decision': 'approved',
        'note': 'Admin approved payment review.',
      });
      if (!mounted) return;
      _showSnack('Payment approved and booking completed.');
    } catch (_) {
      if (!mounted) return;
      _showSnack('Unable to approve payment.', isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reject(String bookingId) async {
    final reasonController = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Payment?'),
        content: TextField(
          controller: reasonController,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Reason shown in internal payment history',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              context,
              reasonController.text.trim().isEmpty
                  ? 'Payment could not be verified.'
                  : reasonController.text.trim(),
            ),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    reasonController.dispose();
    if (reason == null) return;

    setState(() => _busy = true);
    try {
      await _functions.httpsCallable('reviewPaymentRequest').call({
        'bookingId': bookingId,
        'decision': 'rejected',
        'note': reason,
      });
      if (!mounted) return;
      _showSnack('Payment rejected and returned to payment due.');
    } catch (_) {
      if (!mounted) return;
      _showSnack('Unable to reject payment.', isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F9),
      appBar: AppBar(
        title: const Text('Payment Review'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF111827),
        elevation: 0.4,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _pendingPayments(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _emptyState('Unable to load payment reviews');
          }

          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return _emptyState('No payments waiting for review');
          }

          final sorted = docs.toList()
            ..sort((a, b) => _dateFor(b.data()).compareTo(_dateFor(a.data())));

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: sorted.length,
            itemBuilder: (context, index) {
              return _paymentCard(sorted[index]);
            },
          );
        },
      ),
    );
  }

  Widget _paymentCard(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final amount = _amount(
      data['totalAmount'] ?? data['amount'] ?? data['price'],
    );
    final paymentMethod =
        (data['paymentMethod'] ?? data['payment'] ?? 'Payment').toString();
    final paymentStatus = (data['paymentStatus'] ?? 'under_review').toString();
    final createdAt = _dateFor(data);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.blue.withValues(alpha: 0.12),
                  child: const Icon(LucideIcons.receipt, color: Colors.blue),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data['issue']?.toString() ??
                            data['service']?.toString() ??
                            'Service booking',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        '${data['customerName'] ?? 'Customer'} -> ${data['workerName'] ?? 'Worker'}',
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                    ],
                  ),
                ),
                Text(
                  _currency.format(amount),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _pill(paymentMethod),
                _pill(paymentStatus, color: Colors.orange),
                _pill(_dateFormat.format(createdAt), color: Colors.grey),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : () => _reject(doc.id),
                    icon: const Icon(LucideIcons.xCircle, size: 18),
                    label: const Text('Reject'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _busy ? null : () => _approve(doc.id),
                    icon: const Icon(LucideIcons.checkCircle2, size: 18),
                    label: const Text('Approve'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _pill(String label, {Color color = Colors.deepPurple}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label.replaceAll('_', ' '),
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _emptyState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.receipt, size: 44, color: Colors.grey.shade500),
            const SizedBox(height: 12),
            Text(message, style: const TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }

  double _amount(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0;
    return 0;
  }

  DateTime _dateFor(Map<String, dynamic> data) {
    final value =
        data['updatedAt'] ?? data['createdAt'] ?? data['completionConfirmedAt'];
    if (value is Timestamp) return value.toDate();
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  void _showSnack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
