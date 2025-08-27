import 'package:flutter/material.dart';
import 'customer_dashboard_screen.dart';

class CustomerBookingConfirmationScreen extends StatelessWidget {
  static const routeName = '/customer-booking-confirmation';

  const CustomerBookingConfirmationScreen({super.key});

  void _goToHome(BuildContext context) {
    Navigator.pushNamedAndRemoveUntil(
      context,
      CustomerDashboardScreen.routeName,
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.deepPurple.shade50,
      appBar: AppBar(
        title: Text("Booking Confirmed"),
        backgroundColor: Colors.deepPurple,
        automaticallyImplyLeading: false,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedScale(
              scale: 1.0,
              duration: Duration(milliseconds: 600),
              curve: Curves.easeOutBack,
              child: Icon(Icons.check_circle, size: 100, color: Colors.green),
            ),
            SizedBox(height: 24),
            Text(
              "Your booking has been successfully submitted!",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.deepPurple.shade800,
              ),
            ),
            SizedBox(height: 20),
            Text(
              "You will receive a notification once it's accepted by the worker.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[700]),
            ),
            SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _goToHome(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  padding: EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text("Back to Home"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
