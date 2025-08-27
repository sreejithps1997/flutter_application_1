import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../widgets/custom_button.dart';

class WithdrawalScreen extends StatefulWidget {
  static const routeName = '/withdraw';

  const WithdrawalScreen({Key? key}) : super(key: key);

  @override
  State<WithdrawalScreen> createState() => _WithdrawalScreenState();
}

class _WithdrawalScreenState extends State<WithdrawalScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController amountController = TextEditingController();
  final TextEditingController upiController = TextEditingController();

  double currentBalance = 0.0;
  bool isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentEarnings();
  }

  Future<void> _loadCurrentEarnings() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      final doc = await FirebaseFirestore.instance
          .collection('workers')
          .doc(uid)
          .get();
      setState(() {
        currentBalance = (doc.data()?['earnings'] ?? 0).toDouble();
      });
    }
  }

  Future<void> _submitWithdrawal() async {
    if (!_formKey.currentState!.validate()) return;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final amount = double.parse(amountController.text.trim());

    if (amount > currentBalance) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Insufficient balance')));
      return;
    }

    setState(() => isSubmitting = true);

    await FirebaseFirestore.instance.collection('withdrawals').add({
      'workerId': uid,
      'amount': amount,
      'upiId': upiController.text.trim(),
      'status': 'Pending',
      'requestedAt': Timestamp.now(),
    });

    await FirebaseFirestore.instance.collection('workers').doc(uid).update({
      'earnings': FieldValue.increment(-amount),
    });

    setState(() => isSubmitting = false);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Withdrawal request submitted')),
    );

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Withdraw Earnings'),
        backgroundColor: Colors.deepPurple,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              'Current Balance: ₹${currentBalance.toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Amount to withdraw',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.currency_rupee),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Enter amount';
                      final amt = double.tryParse(value);
                      if (amt == null || amt <= 0) return 'Invalid amount';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: upiController,
                    decoration: const InputDecoration(
                      labelText: 'Your UPI ID',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.account_balance_wallet),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Enter UPI ID';
                      if (!value.contains('@')) return 'Invalid UPI ID';
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  isSubmitting
                      ? const CircularProgressIndicator()
                      : CustomButton(
                          text: 'Submit Request',
                          onPressed: _submitWithdrawal,
                        ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
