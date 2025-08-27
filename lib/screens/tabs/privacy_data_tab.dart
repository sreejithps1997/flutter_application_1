import 'package:flutter/material.dart';

class PrivacyAndDataTab extends StatelessWidget {
  const PrivacyAndDataTab({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Icon(Icons.privacy_tip, size: 80, color: Colors.deepPurple),
        const SizedBox(height: 16),
        const Text(
          "Privacy & Data Controls",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 24),

        ListTile(
          leading: const Icon(Icons.description),
          title: const Text("Privacy Policy"),
          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
          onTap: () {
            Navigator.pushNamed(context, '/privacy-policy');
          },
        ),
        const Divider(),

        ListTile(
          leading: const Icon(Icons.manage_accounts),
          title: const Text("Manage My Data"),
          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
          onTap: () {
            // TODO: Add data download/export feature
          },
        ),
        const Divider(),

        ListTile(
          leading: const Icon(Icons.supervisor_account),
          title: const Text("Third-party App Access"),
          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
          onTap: () {
            // TODO: Future integration with OAuth apps
          },
        ),
      ],
    );
  }
}
