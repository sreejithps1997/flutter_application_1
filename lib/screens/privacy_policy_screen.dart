import 'package:flutter/material.dart';
import '../widgets/custom_button.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  static const routeName = '/privacy-policy';

  const PrivacyPolicyScreen({super.key});

  void _close(BuildContext context) {
    Navigator.pop(context); // Close the screen and return
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy Policy'),
        backgroundColor: Colors.deepPurple,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Expanded(
              child: SingleChildScrollView(
                child: Text('''
**Privacy Policy - Workable**

Effective Date: July 10, 2025

Workable ("we", "us", or "our") values your privacy. This Privacy Policy explains how we collect, use, and protect your personal information.

**1. Information We Collect**
- Personal Details: name, phone number, email
- Location Data: used to find nearby services
- Booking and Payment Info

**2. How We Use Your Information**
- To enable bookings between customers and workers
- To improve app functionality and safety
- To communicate support or updates

**3. Sharing**
- We do not sell your data.
- We may share with service providers or as required by law.

**4. Security**
- We use secure servers and encryption.
- You are responsible for securing your account.

**5. Your Rights**
- You may update or delete your account at any time.
- Contact us at support@workableapp.com for questions.

**6. Changes to This Policy**
We may update this Privacy Policy. Continued use means acceptance.

Thank you for trusting Workable.
                  ''', style: TextStyle(fontSize: 14, height: 1.5)),
              ),
            ),
            const SizedBox(height: 20),
            CustomButton(text: 'Close', onPressed: () => _close(context)),
          ],
        ),
      ),
    );
  }
}
