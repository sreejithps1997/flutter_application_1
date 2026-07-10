import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';

class AdminPayoutReviewScreen extends StatefulWidget {
  static const routeName = '/admin-payout-review';

  const AdminPayoutReviewScreen({super.key});

  @override
  State<AdminPayoutReviewScreen> createState() =>
      _AdminPayoutReviewScreenState();
}

class _AdminPayoutReviewScreenState extends State<AdminPayoutReviewScreen> {
  final _currency = NumberFormat.currency(locale: 'en_IN', symbol: 'Rs ');
  bool _busy = false;

  Stream<QuerySnapshot<Map<String, dynamic>>> _requests() {
    return FirebaseFirestore.instance
        .collection('payoutRequests')
        .where('status', isEqualTo: 'pending')
        .snapshots();
  }

  Future<void> _approve(QueryDocumentSnapshot<Map<String, dynamic>> doc) async {
    final adminId = FirebaseAuth.instance.currentUser?.uid ?? 'admin';
    final data = doc.data();
    final bookingIds = (data['bookingIds'] as List?)?.cast<String>() ?? [];
    final now = FieldValue.serverTimestamp();

    setState(() => _busy = true);
    try {
      final batch = FirebaseFirestore.instance.batch();
      batch.update(doc.reference, {
        'status': 'paid',
        'approvedBy': adminId,
        'approvedAt': now,
        'paidAt': now,
        'updatedAt': now,
      });

      for (final bookingId in bookingIds) {
        batch.update(
          FirebaseFirestore.instance.collection('bookings').doc(bookingId),
          {'payoutStatus': 'paid', 'payoutPaidAt': now, 'updatedAt': now},
        );
      }

      await batch.commit();
      if (!mounted) return;
      _showSnack('Payout marked as paid.');
    } catch (_) {
      if (!mounted) return;
      _showSnack('Unable to approve payout.', isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reject(QueryDocumentSnapshot<Map<String, dynamic>> doc) async {
    final adminId = FirebaseAuth.instance.currentUser?.uid ?? 'admin';
    final data = doc.data();
    final bookingIds = (data['bookingIds'] as List?)?.cast<String>() ?? [];
    final now = FieldValue.serverTimestamp();

    setState(() => _busy = true);
    try {
      final batch = FirebaseFirestore.instance.batch();
      batch.update(doc.reference, {
        'status': 'rejected',
        'rejectedBy': adminId,
        'rejectedAt': now,
        'updatedAt': now,
      });

      for (final bookingId in bookingIds) {
        batch.update(
          FirebaseFirestore.instance.collection('bookings').doc(bookingId),
          {
            'payoutStatus': 'rejected',
            'payoutRequestId': null,
            'updatedAt': now,
          },
        );
      }

      await batch.commit();
      if (!mounted) return;
      _showSnack('Payout rejected.');
    } catch (_) {
      if (!mounted) return;
      _showSnack('Unable to reject payout.', isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F9),
      appBar: AppBar(
        title: const Text('Payout Review'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF111827),
        elevation: 0.4,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _requests(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return _empty('No payout requests waiting');
          }

          docs.sort((a, b) => _date(b.data()).compareTo(_date(a.data())));

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) => _requestCard(docs[index]),
          );
        },
      ),
    );
  }

  Widget _requestCard(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final amount = data['amount'] is num ? data['amount'] as num : 0;
    final bookingIds = data['bookingIds'];
    final count = bookingIds is List ? bookingIds.length : 0;
    final method = data['payoutMethod']?.toString() ?? 'upi';

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
                  backgroundColor: Colors.teal.withValues(alpha: 0.12),
                  child: const Icon(LucideIcons.wallet, color: Colors.teal),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _currency.format(amount),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        '$count jobs • $method • ${data['workerId'] ?? 'worker'}',
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : () => _reject(doc),
                    icon: const Icon(LucideIcons.xCircle, size: 18),
                    label: const Text('Reject'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _busy ? null : () => _approve(doc),
                    icon: const Icon(LucideIcons.checkCircle2, size: 18),
                    label: const Text('Mark Paid'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _empty(String message) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.wallet, size: 44, color: Colors.grey.shade500),
          const SizedBox(height: 12),
          Text(message, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  DateTime _date(Map<String, dynamic> data) {
    final timestamp = data['requestedAt'] ?? data['updatedAt'];
    if (timestamp is Timestamp) return timestamp.toDate();
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
