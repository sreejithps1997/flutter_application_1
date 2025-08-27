import 'package:flutter/material.dart';

class SecurityTab extends StatelessWidget {
  const SecurityTab({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Icon(Icons.lock, size: 80, color: Colors.deepPurple),
        const SizedBox(height: 16),
        const Text(
          "Secure Your Account",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 24),

        ListTile(
          leading: const Icon(Icons.password),
          title: const Text("Change Password"),
          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
          onTap: () {
            // TODO: Navigate to change password screen
          },
        ),
        const Divider(),

        ListTile(
          leading: const Icon(Icons.security),
          title: const Text("2-Step Verification"),
          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
          onTap: () {
            // TODO: Navigate to 2FA setup
          },
        ),
        const Divider(),

        ListTile(
          leading: const Icon(Icons.qr_code),
          title: const Text("Authenticator App"),
          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
          onTap: () {
            // TODO: Future feature
          },
        ),
      ],
    );
  }
}
