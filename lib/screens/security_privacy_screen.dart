import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

class SecurityPrivacyScreen extends StatefulWidget {
  static const routeName = '/security-privacy';

  const SecurityPrivacyScreen({super.key});

  @override
  State<SecurityPrivacyScreen> createState() => _SecurityPrivacyScreenState();
}

class _SecurityPrivacyScreenState extends State<SecurityPrivacyScreen> {
  bool twoFactorEnabled = true;
  bool locationSharing = true;
  bool profileVisible = true;
  bool messageEncryption = true;

  Widget buildToggleItem({
    required IconData icon,
    required String title,
    String? subtitle,
    required bool enabled,
    required Function(bool) onToggle,
    Color color = Colors.blue,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade100),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: color.withOpacity(0.1),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                ],
              ),
            ],
          ),
          Switch(value: enabled, onChanged: onToggle, activeColor: color),
        ],
      ),
    );
  }

  Widget buildMenuItem({
    required IconData icon,
    required String title,
    String? subtitle,
    VoidCallback? onTap,
    Color color = Colors.blue,
    String? badge,
    String? status, // 'verified', 'pending', 'failed'
  }) {
    Icon? statusIcon;
    if (status == 'verified') {
      statusIcon = const Icon(
        Icons.check_circle,
        color: Colors.green,
        size: 16,
      );
    } else if (status == 'pending') {
      statusIcon = const Icon(
        Icons.access_time,
        color: Colors.orange,
        size: 16,
      );
    } else if (status == 'failed') {
      statusIcon = const Icon(Icons.cancel, color: Colors.red, size: 16);
    }

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.grey.shade100),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color.withOpacity(0.1),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      if (statusIcon != null) ...[
                        const SizedBox(width: 6),
                        statusIcon,
                      ],
                      if (badge != null) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            badge,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget buildSecurityStatusCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Colors.green, Colors.greenAccent],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            children: const [
              Icon(Icons.shield, color: Colors.white, size: 32),
              SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Account Security',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    'Strong Protection Active',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: const [
              Column(
                children: [
                  Text(
                    '85%',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Security Score',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
              Column(
                children: [
                  Text(
                    '3',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Active Devices',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
              Column(
                children: [
                  Text(
                    '7d',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Last Login',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget section(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        ...children,
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Security & Privacy'),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Column(
          children: [
            buildSecurityStatusCard(),

            section("Account Security", [
              buildMenuItem(
                icon: LucideIcons.key,
                title: 'Change Password',
                subtitle: 'Last changed 30 days ago',
              ),
              buildToggleItem(
                icon: LucideIcons.shield,
                title: 'Two-Factor Authentication',
                subtitle: 'Extra security for your account',
                enabled: twoFactorEnabled,
                onToggle: (val) => setState(() => twoFactorEnabled = val),
                color: Colors.green,
              ),
              buildMenuItem(
                icon: LucideIcons.smartphone,
                title: 'Login Activity',
                subtitle: '3 active devices',
                color: Colors.purple,
              ),
              buildMenuItem(
                icon: LucideIcons.lock,
                title: 'App Lock Settings',
                subtitle: 'Biometric & PIN protection',
                color: Colors.indigo,
              ),
            ]),

            section("Privacy Controls", [
              buildToggleItem(
                icon: LucideIcons.eye,
                title: 'Profile Visibility',
                subtitle: 'Show profile to workers',
                enabled: profileVisible,
                onToggle: (val) => setState(() => profileVisible = val),
              ),
              buildToggleItem(
                icon: LucideIcons.mapPin,
                title: 'Location Sharing',
                subtitle: 'Share location for bookings',
                enabled: locationSharing,
                onToggle: (val) => setState(() => locationSharing = val),
                color: Colors.red,
              ),
              buildMenuItem(
                icon: LucideIcons.phone,
                title: 'Contact Privacy',
                subtitle: 'Who can see your phone number',
                color: Colors.green,
              ),
              buildMenuItem(
                icon: LucideIcons.camera,
                title: 'Photo Privacy',
                subtitle: 'Control photo sharing',
                color: Colors.purple,
              ),
            ]),

            section("Data Management", [
              buildMenuItem(
                icon: LucideIcons.download,
                title: 'Download My Data',
                subtitle: 'Export your personal data',
              ),
              buildMenuItem(
                icon: LucideIcons.clock,
                title: 'Data Retention',
                subtitle: 'Control how long data is kept',
                color: Colors.orange,
              ),
              buildMenuItem(
                icon: LucideIcons.trash2,
                title: 'Delete Personal Data',
                subtitle: 'Remove specific information',
                color: Colors.red,
              ),
            ]),

            section("Communication", [
              buildToggleItem(
                icon: LucideIcons.messageCircle,
                title: 'Message Encryption',
                subtitle: 'End-to-end encrypted chats',
                enabled: messageEncryption,
                onToggle: (val) => setState(() => messageEncryption = val),
                color: Colors.green,
              ),
              buildMenuItem(
                icon: LucideIcons.phone,
                title: 'Call Recording Settings',
              ),
              buildMenuItem(
                icon: LucideIcons.messageCircle,
                title: 'Chat History',
                subtitle: 'Auto-delete old messages',
                color: Colors.purple,
              ),
            ]),

            section("Safety & Trust", [
              buildMenuItem(
                icon: LucideIcons.users,
                title: 'Emergency Contacts',
                subtitle: '2 contacts added',
                color: Colors.red,
                status: 'verified',
              ),
              buildMenuItem(
                icon: LucideIcons.alertTriangle,
                title: 'Safety Check-in',
                subtitle: 'Auto check-in during bookings',
                color: Colors.orange,
              ),
              buildMenuItem(
                icon: LucideIcons.userX,
                title: 'Block & Report',
                subtitle: 'Manage blocked users',
                color: Colors.red,
              ),
              buildMenuItem(
                icon: LucideIcons.shield,
                title: 'Background Check',
                subtitle: 'Verification status',
                color: Colors.green,
                status: 'verified',
              ),
            ]),

            section("Legal & Policies", [
              buildMenuItem(
                icon: LucideIcons.fileText,
                title: 'Privacy Policy',
                subtitle: 'Last updated: Jan 2025',
                color: Colors.grey,
              ),
              buildMenuItem(
                icon: LucideIcons.fileText,
                title: 'Terms of Service',
                subtitle: 'Review our terms',
                color: Colors.grey,
              ),
              buildMenuItem(
                icon: LucideIcons.globe,
                title: 'Data Processing',
                subtitle: 'How we handle your data',
              ),
            ]),

            section("Danger Zone", [
              buildMenuItem(
                icon: LucideIcons.userX,
                title: 'Deactivate Account',
                subtitle: 'Temporarily disable your account',
                color: Colors.orange,
              ),
              buildMenuItem(
                icon: LucideIcons.trash2,
                title: 'Delete Account',
                subtitle: 'Permanently delete your account',
                color: Colors.red,
              ),
            ]),
          ],
        ),
      ),
    );
  }
}
