import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'customer_booking_confirmation_screen.dart';

class CustomerPaymentScreen extends StatefulWidget {
  static const routeName = '/customer-payment';

  final String bookingId;

  const CustomerPaymentScreen({super.key, required this.bookingId});

  @override
  State<CustomerPaymentScreen> createState() => _CustomerPaymentScreenState();
}

class _CustomerPaymentScreenState extends State<CustomerPaymentScreen> {
  String selectedMethod = "UPI";
  final TextEditingController _promoCodeController = TextEditingController();

  final List<String> paymentMethods = [
    'UPI',
    'Credit Card',
    'Debit Card',
    'Cash on Delivery',
  ];

  bool _isProcessing = false;

  Future<void> _submitPayment() async {
    final promoCode = _promoCodeController.text.trim();

    setState(() => _isProcessing = true);

    try {
      await FirebaseFirestore.instance
          .collection('bookings')
          .doc(widget.bookingId)
          .update({
            'payment': selectedMethod,
            if (promoCode.isNotEmpty) 'promoCode': promoCode,
            'status': 'confirmed',
            'updatedAt': FieldValue.serverTimestamp(),
          });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Payment successful via $selectedMethod")),
        );

        Navigator.pushReplacementNamed(
          context,
          CustomerBookingConfirmationScreen.routeName,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Payment failed. Please try again.")),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  void dispose() {
    _promoCodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Complete Payment"),
        backgroundColor: Colors.deepPurple,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Select Payment Method",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            ...paymentMethods.map((method) {
              return RadioListTile<String>(
                value: method,
                groupValue: selectedMethod,
                onChanged: (val) => setState(() => selectedMethod = val!),
                title: Text(method),
                activeColor: Colors.deepPurple,
              );
            }),

            const SizedBox(height: 24),
            const Text(
              "Promo Code (Optional)",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _promoCodeController,
              decoration: InputDecoration(
                hintText: "Enter promo code",
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.local_offer),
              ),
            ),

            const Spacer(),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isProcessing ? null : _submitPayment,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                icon: const Icon(Icons.payment),
                label: _isProcessing
                    ? const CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      )
                    : const Text("Pay Now"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
