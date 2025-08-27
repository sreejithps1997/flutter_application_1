import 'package:flutter/material.dart';
import '../widgets/custom_button.dart';

class TermsConditionsScreen extends StatelessWidget {
  static const routeName = '/terms-conditions';

  const TermsConditionsScreen({super.key});

  void _acceptTerms(BuildContext context) {
    Navigator.pop(
      context,
    ); // Or replace with: Navigator.pushReplacementNamed(...)
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Terms & Conditions'),
        backgroundColor: Colors.deepPurple,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Expanded(
              child: SingleChildScrollView(
                child: Text('''
Welcome to Workable!

Please read these Terms and Conditions carefully before using the Workable app.

1. **Acceptance**
By creating an account or using this app, you agree to be bound by these terms.

2. **Usage**
- You agree to use this app lawfully.
- You are responsible for your content and bookings.

3. **Payments**
- Payments between users are handled securely.
- We are not liable for disputes outside the platform.

4. **Cancellations**
- Workers and Customers may cancel within the rules.
- Repeated abuse may lead to account suspension.

5. **Privacy**
- We protect your data in accordance with our Privacy Policy.

6. **Liability**
- Workable is a platform. We do not guarantee worker performance.

7. **Changes**
- Terms may change. Continued use means acceptance.

By continuing, you acknowledge and accept these terms.

For questions, contact: support@workableapp.com
                  ''', style: TextStyle(fontSize: 14, height: 1.5)),
              ),
            ),
            const SizedBox(height: 20),
            CustomButton(
              text: 'Accept & Continue',
              onPressed: () => _acceptTerms(context),
            ),
          ],
        ),
      ),
    );
  }
}
