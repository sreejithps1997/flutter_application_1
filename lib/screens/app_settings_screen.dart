import 'package:flutter/material.dart';

class AppSettingsScreen extends StatefulWidget {
  static const routeName = '/app-settings';

  const AppSettingsScreen({super.key});

  @override
  State<AppSettingsScreen> createState() => _AppSettingsScreenState();
}

class _AppSettingsScreenState extends State<AppSettingsScreen> {
  bool darkMode = false;
  bool notifications = true;
  bool soundEnabled = true;
  bool locationServices = true;
  bool biometricLogin = true;
  bool autoLock = true;
  String dataUsage = 'WiFi Only';
  bool offlineMode = false;
  bool highContrast = false;
  bool autoUpdate = true;

  Widget buildSettingItem({
    required IconData icon,
    required String title,
    String? subtitle,
    bool isToggle = true,
    bool value = false,
    Function()? onTap,
    Function(bool)? onToggle,
    String? trailingValue,
    Color? color,
    Widget? trailingWidget,
  }) {
    return InkWell(
      onTap: isToggle ? null : onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: (color ?? Colors.blue).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color ?? Colors.blue, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (subtitle != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (isToggle)
              Switch(
                value: value,
                onChanged: onToggle,
                activeColor: Colors.blue,
              )
            else if (trailingWidget != null)
              trailingWidget
            else
              Row(
                children: [
                  if (trailingValue != null)
                    Text(
                      trailingValue,
                      style: const TextStyle(color: Colors.grey),
                    ),
                  const Icon(Icons.chevron_right, color: Colors.grey),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget buildSection(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(subtitle, style: const TextStyle(color: Colors.grey)),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget buildStorageUsageCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Storage Usage",
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
          ),
          const SizedBox(height: 8),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [Text("App Cache"), Text("45 MB")],
          ),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [Text("Images"), Text("67 MB")],
          ),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [Text("Documents"), Text("16 MB")],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: 0.32,
              backgroundColor: Colors.grey.shade300,
              color: Colors.blue,
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 4),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("128 MB used", style: TextStyle(fontSize: 12)),
              Text("400 MB available", style: TextStyle(fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }

  Widget buildResetOptions() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Reset Options",
            style: TextStyle(fontSize: 16, color: Colors.red),
          ),
          const SizedBox(height: 4),
          const Text(
            "These actions cannot be undone",
            style: TextStyle(color: Colors.redAccent, fontSize: 13),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.red,
              side: BorderSide(color: Colors.red.shade200),
            ),
            child: const Text("Reset App Settings"),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text("Clear All Data"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('App Settings'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // Display & Interface
          buildSection("Display & Interface", "Customize your app appearance"),
          buildSettingItem(
            icon: darkMode ? Icons.dark_mode : Icons.light_mode,
            title: "Dark Mode",
            subtitle: "Switch between light and dark theme",
            value: darkMode,
            onToggle: (val) => setState(() => darkMode = val),
          ),
          const SizedBox(height: 10),
          buildSettingItem(
            icon: Icons.language,
            title: "Language",
            subtitle: "English (India)",
            isToggle: false,
            trailingValue: "English",
            onTap: () {},
          ),
          const SizedBox(height: 10),
          buildSettingItem(
            icon: Icons.text_fields,
            title: "Font Size",
            subtitle: "Medium",
            isToggle: false,
            trailingValue: "Medium",
            onTap: () {},
          ),

          const SizedBox(height: 24),

          // Notifications & Sounds
          buildSection(
            "Notifications & Sounds",
            "Manage how you receive alerts",
          ),
          buildSettingItem(
            icon: Icons.notifications,
            title: "Push Notifications",
            subtitle: "Receive booking and message alerts",
            value: notifications,
            onToggle: (val) => setState(() => notifications = val),
          ),
          const SizedBox(height: 10),
          buildSettingItem(
            icon: soundEnabled ? Icons.volume_up : Icons.volume_off,
            title: "Sound & Vibration",
            subtitle: "Enable notification sounds",
            value: soundEnabled,
            onToggle: (val) => setState(() => soundEnabled = val),
          ),
          const SizedBox(height: 10),
          buildSettingItem(
            icon: Icons.notifications_active,
            title: "Notification Categories",
            subtitle: "Customize notification types",
            isToggle: false,
            onTap: () {},
          ),

          const SizedBox(height: 24),

          // Privacy & Security
          buildSection("Privacy & Security", "Control your data and security"),
          buildSettingItem(
            icon: Icons.location_on,
            title: "Location Services",
            subtitle: "Allow location access for nearby workers",
            value: locationServices,
            onToggle: (val) => setState(() => locationServices = val),
            color: Colors.green,
          ),
          const SizedBox(height: 10),
          buildSettingItem(
            icon: Icons.fingerprint,
            title: "Biometric Login",
            subtitle: "Use fingerprint or face unlock",
            value: biometricLogin,
            onToggle: (val) => setState(() => biometricLogin = val),
            color: Colors.green,
          ),
          const SizedBox(height: 10),
          buildSettingItem(
            icon: Icons.lock,
            title: "Auto-Lock",
            subtitle: "Lock app when inactive for 5 minutes",
            value: autoLock,
            onToggle: (val) => setState(() => autoLock = val),
            color: Colors.green,
          ),
          const SizedBox(height: 10),
          buildSettingItem(
            icon: Icons.privacy_tip,
            title: "Privacy Policy",
            subtitle: "View our privacy practices",
            isToggle: false,
            onTap: () {},
            color: Colors.green,
          ),

          const SizedBox(height: 24),

          // Data & Storage
          buildSection("Data & Storage", "Manage app data and downloads"),
          buildSettingItem(
            icon: Icons.wifi,
            title: "Data Usage",
            subtitle: "Download images on WiFi only",
            isToggle: false,
            trailingValue: "WiFi Only",
            onTap: () {},
            color: Colors.purple,
          ),
          const SizedBox(height: 10),
          buildSettingItem(
            icon: Icons.download,
            title: "Offline Mode",
            subtitle: "Save data for offline access",
            value: offlineMode,
            onToggle: (val) => setState(() => offlineMode = val),
            color: Colors.purple,
          ),
          const SizedBox(height: 10),
          buildStorageUsageCard(),
          const SizedBox(height: 10),
          buildSettingItem(
            icon: Icons.delete,
            title: "Clear Cache",
            subtitle: "Free up 45 MB of storage space",
            isToggle: false,
            onTap: () {},
            color: Colors.red,
          ),

          const SizedBox(height: 24),

          // Accessibility
          buildSection("Accessibility", "Make the app easier to use"),
          buildSettingItem(
            icon: Icons.contrast,
            title: "High Contrast",
            subtitle: "Improve text readability",
            value: highContrast,
            onToggle: (val) => setState(() => highContrast = val),
            color: Colors.orange,
          ),
          const SizedBox(height: 10),
          buildSettingItem(
            icon: Icons.accessibility,
            title: "Screen Reader Support",
            subtitle: "Enable voice accessibility features",
            isToggle: false,
            onTap: () {},
            color: Colors.orange,
          ),

          const SizedBox(height: 24),

          // App Info
          buildSection("App Information", "Version and support details"),
          buildSettingItem(
            icon: Icons.update,
            title: "Auto Update",
            subtitle: "Automatically install app updates",
            value: autoUpdate,
            onToggle: (val) => setState(() => autoUpdate = val),
            color: Colors.grey,
          ),
          const SizedBox(height: 10),
          buildSettingItem(
            icon: Icons.info,
            title: "App Version",
            subtitle: "Workable v2.1.0 (Latest)",
            isToggle: false,
            onTap: () {},
            color: Colors.grey,
          ),
          const SizedBox(height: 10),
          buildSettingItem(
            icon: Icons.feedback,
            title: "Send Feedback",
            subtitle: "Help us improve the app",
            isToggle: false,
            onTap: () {},
            color: Colors.grey,
          ),

          const SizedBox(height: 24),

          // Reset
          buildResetOptions(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
