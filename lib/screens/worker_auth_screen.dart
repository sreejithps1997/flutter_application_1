import 'package:flutter/material.dart';
import 'worker_login_screen.dart';
import 'worker_signup_screen.dart';

class WorkerAuthScreen extends StatelessWidget {
  static const routeName = '/worker-auth';

  const WorkerAuthScreen({super.key});

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
              const Spacer(),
              const Icon(Icons.handyman, size: 90, color: Colors.deepPurple),
              const SizedBox(height: 24),
              Text(
                "Welcome, Worker",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.deepPurple.shade800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Sign up or log in to get jobs and grow your business.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey[700]),
              ),
              const Spacer(),

              // 🔐 Login Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pushNamed(context, WorkerLoginScreen.routeName);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text("Log In"),
                ),
              ),
              const SizedBox(height: 12),

              // 🆕 Sign Up Button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.pushNamed(context, WorkerSignupScreen.routeName);
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: Colors.deepPurple),
                  ),
                  child: const Text(
                    "Sign Up",
                    style: TextStyle(color: Colors.deepPurple),
                  ),
                ),
              ),
              const Spacer(),

              const Text(
                "By continuing, you agree to our Terms & Privacy Policy.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
