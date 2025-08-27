import 'package:flutter/material.dart';
import '../services/auth_service.dart';

import 'worker_profile_update_screen.dart';
import 'worker_change_password_screen.dart';
import 'withdrawal_screen.dart';
import 'ratings_reviews_screen.dart';
import 'help_support_screen.dart';
import 'terms_conditions_screen.dart';
import 'privacy_policy_screen.dart';
import 'user_type_selection_screen.dart';

class WorkerSettingsScreen extends StatefulWidget {
  static const routeName = '/worker-settings';

  const WorkerSettingsScreen({super.key});

  @override
  State<WorkerSettingsScreen> createState() => _WorkerSettingsScreenState();
}

class _WorkerSettingsScreenState extends State<WorkerSettingsScreen> {
  bool _notificationsEnabled = true;
  String _selectedLanguage = 'English';

  void _changeLanguage() {
    showModalBottomSheet(
      context: context,
      builder: (_) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Wrap(
            children: ['English', 'हिन्दी', 'മലയാളം', 'தமிழ்'].map((lang) {
              return ListTile(
                title: Text(lang),
                onTap: () {
                  if (mounted) {
                    setState(() {
                      _selectedLanguage = lang;
                    });
                  }
                  Navigator.pop(context);
                },
              );
            }).toList(),
          ),
        );
      },
    );
  }

  void _logout() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Log Out"),
        content: const Text("Are you sure you want to log out?"),
        actions: [
          TextButton(
            child: const Text("Cancel"),
            onPressed: () => Navigator.pop(context),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple),
            child: const Text("Log Out"),
            onPressed: () async {
              Navigator.pop(context); // Close dialog first
              await AuthService().signOut();
              if (mounted) {
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  UserTypeSelectionScreen.routeName,
                  (route) => false,
                );
              }
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Worker Settings"),
        backgroundColor: Colors.deepPurple,
      ),
      body: ListView(
        children: [
          SwitchListTile(
            title: const Text("Enable Notifications"),
            value: _notificationsEnabled,
            activeColor: Colors.deepPurple,
            onChanged: (val) => setState(() => _notificationsEnabled = val),
          ),
          ListTile(
            title: const Text("Language"),
            subtitle: Text(_selectedLanguage),
            trailing: const Icon(Icons.chevron_right),
            onTap: _changeLanguage,
          ),
          const Divider(),

          ListTile(
            title: const Text("Edit Profile"),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.pushNamed(
              context,
              WorkerProfileUpdateScreen.routeName,
            ),
          ),
          ListTile(
            title: const Text("Change Password"),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.pushNamed(
              context,
              WorkerChangePasswordScreen.routeName,
            ),
          ),
          ListTile(
            title: const Text("Withdraw Earnings"),
            trailing: const Icon(Icons.chevron_right),
            onTap: () =>
                Navigator.pushNamed(context, WithdrawalScreen.routeName),
          ),
          ListTile(
            title: const Text("Ratings & Reviews"),
            trailing: const Icon(Icons.chevron_right),
            onTap: () =>
                Navigator.pushNamed(context, RatingsReviewsScreen.routeName),
          ),
          const Divider(),

          ListTile(
            title: const Text("Help & Support"),
            trailing: const Icon(Icons.chevron_right),
            onTap: () =>
                Navigator.pushNamed(context, HelpSupportScreen.routeName),
          ),
          ListTile(
            title: const Text("Terms & Conditions"),
            trailing: const Icon(Icons.chevron_right),
            onTap: () =>
                Navigator.pushNamed(context, TermsConditionsScreen.routeName),
          ),
          ListTile(
            title: const Text("Privacy Policy"),
            trailing: const Icon(Icons.chevron_right),
            onTap: () =>
                Navigator.pushNamed(context, PrivacyPolicyScreen.routeName),
          ),
          const Divider(),

          ListTile(
            title: const Text("Log Out", style: TextStyle(color: Colors.red)),
            trailing: const Icon(Icons.logout, color: Colors.red),
            onTap: _logout,
          ),
        ],
      ),
    );
  }
}
