import 'package:flutter/material.dart';
import 'customer_login_screen.dart';
import 'customer_signup_screen.dart';

class CustomerAuthScreen extends StatelessWidget {
  static const routeName = '/customer-auth';

  const CustomerAuthScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.deepPurple.shade50,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Spacer(),
              Icon(Icons.person_outline, size: 90, color: Colors.deepPurple),
              SizedBox(height: 24),
              Text(
                "Welcome, Customer",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.deepPurple.shade800,
                ),
              ),
              SizedBox(height: 8),
              Text(
                "Log in or sign up to book trusted workers for home services.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey[700]),
              ),
              Spacer(),

              // 🔐 Login Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pushNamed(context, CustomerLoginScreen.routeName);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    padding: EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text("Log In"),
                ),
              ),
              SizedBox(height: 12),

              // 🆕 Sign Up Button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.pushNamed(
                      context,
                      CustomerSignupScreen.routeName,
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 14),
                    side: BorderSide(color: Colors.deepPurple),
                  ),
                  child: Text(
                    "Sign Up",
                    style: TextStyle(color: Colors.deepPurple),
                  ),
                ),
              ),
              Spacer(),

              Text(
                "By continuing, you agree to our Terms & Privacy Policy.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
