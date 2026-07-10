import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../core/theme/workable_design.dart';
import '../services/app_preferences_service.dart';
import '../services/notification_service.dart';
import 'privacy_policy_screen.dart';
import 'security_privacy_screen.dart';

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
  String language = 'English (India)';
  String fontSize = 'Medium';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  void _loadSettings() {
    setState(() {
      darkMode = AppPreferencesService.themeMode.value == ThemeMode.dark;
      notifications = AppPreferencesService.notifications;
      soundEnabled = AppPreferencesService.soundEnabled;
      locationServices = AppPreferencesService.locationServices;
      biometricLogin = AppPreferencesService.biometricLogin;
      autoLock = AppPreferencesService.autoLock;
      dataUsage = AppPreferencesService.dataUsage;
      offlineMode = AppPreferencesService.offlineMode;
      highContrast = AppPreferencesService.highContrast;
      autoUpdate = AppPreferencesService.autoUpdate;
      language = AppPreferencesService.language;
      fontSize = AppPreferencesService.fontSize;
    });
  }

  Future<void> _toggleDarkMode(bool value) async {
    setState(() => darkMode = value);
    await AppPreferencesService.setThemeMode(
      value ? ThemeMode.dark : ThemeMode.light,
    );
  }

  Future<void> _toggleNotifications(bool value) async {
    setState(() => notifications = value);

    try {
      await NotificationService.setPushNotificationsEnabled(value);
      if (!mounted) return;
      _showSnack(
        value ? 'Push notifications enabled' : 'Push notifications disabled',
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => notifications = !value);
      _showSnack('Unable to update notification settings');
    }
  }

  Future<void> _toggleLocationServices(bool value) async {
    if (!value) {
      setState(() => locationServices = false);
      await AppPreferencesService.setLocationServices(false);
      if (!mounted) return;
      _showSnack('Location features disabled in Workable');
      return;
    }

    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (!mounted) return;
      setState(() => locationServices = false);
      await AppPreferencesService.setLocationServices(false);
      _showSnack('Turn on device location services to enable this');
      return;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    final granted =
        permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;

    setState(() => locationServices = granted);
    await AppPreferencesService.setLocationServices(granted);

    if (!mounted) return;
    _showSnack(
      granted
          ? 'Location features enabled'
          : 'Location permission was not granted',
    );
  }

  Future<void> _resetSettings() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset app settings?'),
        content: const Text('Your preferences will return to their defaults.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    await AppPreferencesService.resetSettings();
    if (!mounted) return;
    _loadSettings();
    _showSnack('App settings reset');
  }

  Future<void> _chooseOption({
    required String title,
    required List<String> options,
    required String selected,
    required ValueChanged<String> onSelected,
  }) async {
    final value = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            ...options.map(
              (option) => RadioListTile<String>(
                value: option,
                groupValue: selected,
                title: Text(option),
                onChanged: (value) => Navigator.pop(context, value),
              ),
            ),
          ],
        ),
      ),
    );

    if (value != null) onSelected(value);
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

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
  }) {
    final itemColor = color ?? WorkableDesign.primary;
    return InkWell(
      onTap: isToggle ? null : onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: WorkableDesign.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: WorkableDesign.border),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: itemColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: itemColor, size: 20),
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
                      fontWeight: FontWeight.w600,
                      color: WorkableDesign.ink,
                    ),
                  ),
                  if (subtitle != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 13,
                          color: WorkableDesign.muted,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (isToggle)
              Switch(value: value, onChanged: onToggle)
            else
              Row(
                children: [
                  if (trailingValue != null)
                    Text(
                      trailingValue,
                      style: const TextStyle(color: WorkableDesign.muted),
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
        Text(subtitle, style: const TextStyle(color: WorkableDesign.muted)),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget buildStorageUsageCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: WorkableDesign.surface,
        border: Border.all(color: WorkableDesign.border),
        borderRadius: BorderRadius.circular(8),
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
              minHeight: 6,
              backgroundColor: Colors.grey.shade300,
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
        borderRadius: BorderRadius.circular(8),
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
            onPressed: _resetSettings,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.red,
              side: BorderSide(color: Colors.red.shade200),
            ),
            child: const Text("Reset App Settings"),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: () => _showSnack('Clear all data is not enabled yet'),
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
      backgroundColor: WorkableDesign.canvas,
      appBar: AppBar(title: const Text('App Settings')),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          buildSection("Display & Interface", "Customize your app appearance"),
          buildSettingItem(
            icon: darkMode ? Icons.dark_mode : Icons.light_mode,
            title: "Dark Mode",
            subtitle: "Switch between light and dark theme",
            value: darkMode,
            onToggle: _toggleDarkMode,
          ),
          const SizedBox(height: 10),
          buildSettingItem(
            icon: Icons.language,
            title: "Language",
            subtitle: language,
            isToggle: false,
            trailingValue: language,
            onTap: () => _chooseOption(
              title: 'Choose language',
              selected: language,
              options: const ['English (India)', 'Hindi', 'Malayalam', 'Tamil'],
              onSelected: (value) async {
                setState(() => language = value);
                await AppPreferencesService.setLanguage(value);
              },
            ),
          ),
          const SizedBox(height: 10),
          buildSettingItem(
            icon: Icons.text_fields,
            title: "Font Size",
            subtitle: fontSize,
            isToggle: false,
            trailingValue: fontSize,
            onTap: () => _chooseOption(
              title: 'Choose font size',
              selected: fontSize,
              options: const ['Small', 'Medium', 'Large'],
              onSelected: (value) async {
                setState(() => fontSize = value);
                await AppPreferencesService.setFontSize(value);
              },
            ),
          ),
          const SizedBox(height: 24),
          buildSection(
            "Notifications & Sounds",
            "Manage how you receive alerts",
          ),
          buildSettingItem(
            icon: Icons.notifications,
            title: "Push Notifications",
            subtitle: "Receive booking and message alerts",
            value: notifications,
            onToggle: _toggleNotifications,
          ),
          const SizedBox(height: 10),
          buildSettingItem(
            icon: soundEnabled ? Icons.volume_up : Icons.volume_off,
            title: "Sound & Vibration",
            subtitle: "Enable notification sounds",
            value: soundEnabled,
            onToggle: (val) async {
              setState(() => soundEnabled = val);
              await AppPreferencesService.setSoundEnabled(val);
            },
          ),
          const SizedBox(height: 10),
          buildSettingItem(
            icon: Icons.notifications_active,
            title: "Notification Categories",
            subtitle: "Booking, chat, payment, and verification alerts",
            isToggle: false,
            onTap: () => _showSnack('Notification categories saved locally'),
          ),
          const SizedBox(height: 24),
          buildSection("Privacy & Security", "Control your data and security"),
          buildSettingItem(
            icon: Icons.security,
            title: "Security & Privacy Center",
            subtitle: "Passwords, privacy, safety, and account controls",
            isToggle: false,
            onTap: () =>
                Navigator.pushNamed(context, SecurityPrivacyScreen.routeName),
            color: Colors.indigo,
          ),
          const SizedBox(height: 10),
          buildSettingItem(
            icon: Icons.location_on,
            title: "Location Services",
            subtitle: "Allow location access for nearby workers",
            value: locationServices,
            onToggle: _toggleLocationServices,
            color: Colors.green,
          ),
          const SizedBox(height: 10),
          buildSettingItem(
            icon: Icons.fingerprint,
            title: "Biometric Login",
            subtitle: "Use fingerprint or face unlock",
            value: biometricLogin,
            onToggle: (val) async {
              setState(() => biometricLogin = val);
              await AppPreferencesService.setBiometricLogin(val);
            },
            color: Colors.green,
          ),
          const SizedBox(height: 10),
          buildSettingItem(
            icon: Icons.lock,
            title: "Auto-Lock",
            subtitle: "Lock app when inactive for 5 minutes",
            value: autoLock,
            onToggle: (val) async {
              setState(() => autoLock = val);
              await AppPreferencesService.setAutoLock(val);
            },
            color: Colors.green,
          ),
          const SizedBox(height: 10),
          buildSettingItem(
            icon: Icons.privacy_tip,
            title: "Privacy Policy",
            subtitle: "View our privacy practices",
            isToggle: false,
            onTap: () =>
                Navigator.pushNamed(context, PrivacyPolicyScreen.routeName),
            color: Colors.green,
          ),
          const SizedBox(height: 24),
          buildSection("Data & Storage", "Manage app data and downloads"),
          buildSettingItem(
            icon: Icons.wifi,
            title: "Data Usage",
            subtitle: "Download images on $dataUsage",
            isToggle: false,
            trailingValue: dataUsage,
            onTap: () => _chooseOption(
              title: 'Data usage',
              selected: dataUsage,
              options: const ['WiFi Only', 'WiFi and Mobile Data'],
              onSelected: (value) async {
                setState(() => dataUsage = value);
                await AppPreferencesService.setDataUsage(value);
              },
            ),
            color: Colors.purple,
          ),
          const SizedBox(height: 10),
          buildSettingItem(
            icon: Icons.download,
            title: "Offline Mode",
            subtitle: "Save data for offline access",
            value: offlineMode,
            onToggle: (val) async {
              setState(() => offlineMode = val);
              await AppPreferencesService.setOfflineMode(val);
            },
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
            onTap: () => _showSnack('Cache cleared'),
            color: Colors.red,
          ),
          const SizedBox(height: 24),
          buildSection("Accessibility", "Make the app easier to use"),
          buildSettingItem(
            icon: Icons.contrast,
            title: "High Contrast",
            subtitle: "Improve text readability",
            value: highContrast,
            onToggle: (val) async {
              setState(() => highContrast = val);
              await AppPreferencesService.setHighContrast(val);
            },
            color: Colors.orange,
          ),
          const SizedBox(height: 10),
          buildSettingItem(
            icon: Icons.accessibility,
            title: "Screen Reader Support",
            subtitle: "Uses your device accessibility settings",
            isToggle: false,
            onTap: () => _showSnack('Screen reader follows device settings'),
            color: Colors.orange,
          ),
          const SizedBox(height: 24),
          buildSection("App Information", "Version and support details"),
          buildSettingItem(
            icon: Icons.update,
            title: "Auto Update",
            subtitle: "Automatically install app updates",
            value: autoUpdate,
            onToggle: (val) async {
              setState(() => autoUpdate = val);
              await AppPreferencesService.setAutoUpdate(val);
            },
            color: Colors.grey,
          ),
          const SizedBox(height: 10),
          buildSettingItem(
            icon: Icons.info,
            title: "App Version",
            subtitle: "Workable v2.1.0 (Latest)",
            isToggle: false,
            onTap: () => showAboutDialog(
              context: context,
              applicationName: 'Workable',
              applicationVersion: '2.1.0',
            ),
            color: Colors.grey,
          ),
          const SizedBox(height: 10),
          buildSettingItem(
            icon: Icons.feedback,
            title: "Send Feedback",
            subtitle: "Help us improve the app",
            isToggle: false,
            onTap: () => _showSnack('Feedback form will be connected later'),
            color: Colors.grey,
          ),
          const SizedBox(height: 24),
          buildResetOptions(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
