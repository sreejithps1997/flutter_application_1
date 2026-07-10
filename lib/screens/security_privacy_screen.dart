import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../core/theme/workable_design.dart';
import '../services/app_preferences_service.dart';
import '../widgets/workable_ui.dart';
import 'change_password_screen.dart';
import 'privacy_policy_screen.dart';
import 'terms_conditions_screen.dart';

class SecurityPrivacyScreen extends StatefulWidget {
  static const routeName = '/security-privacy';

  const SecurityPrivacyScreen({super.key});

  @override
  State<SecurityPrivacyScreen> createState() => _SecurityPrivacyScreenState();
}

class _SecurityPrivacyScreenState extends State<SecurityPrivacyScreen> {
  late bool _biometricLogin;
  late bool _autoLock;
  late bool _locationServices;

  @override
  void initState() {
    super.initState();
    _biometricLogin = AppPreferencesService.biometricLogin;
    _autoLock = AppPreferencesService.autoLock;
    _locationServices = AppPreferencesService.locationServices;
  }

  Future<void> _setBiometric(bool value) async {
    setState(() => _biometricLogin = value);
    await AppPreferencesService.setBiometricLogin(value);
  }

  Future<void> _setAutoLock(bool value) async {
    setState(() => _autoLock = value);
    await AppPreferencesService.setAutoLock(value);
  }

  Future<void> _setLocation(bool value) async {
    setState(() => _locationServices = value);
    await AppPreferencesService.setLocationServices(value);
  }

  @override
  Widget build(BuildContext context) {
    final enabledCount = [
      _biometricLogin,
      _autoLock,
      _locationServices,
    ].where((enabled) => enabled).length;

    return Scaffold(
      backgroundColor: WorkableDesign.canvas,
      appBar: AppBar(title: const Text('Security & Privacy')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(WorkableDesign.pagePadding),
          children: [
            WorkablePageHeader(
              title: 'Account protection',
              subtitle:
                  '$enabledCount of 3 core protection settings are enabled on this device.',
              icon: LucideIcons.shieldCheck,
            ),
            const SizedBox(height: 16),
            _buildAccountSecurity(),
            const SizedBox(height: 16),
            _buildPrivacyControls(),
            const SizedBox(height: 16),
            _buildDataControls(),
            const SizedBox(height: 16),
            _buildLegalControls(),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountSecurity() {
    return WorkableSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle('Account security'),
          const SizedBox(height: 12),
          _MenuRow(
            icon: LucideIcons.keyRound,
            title: 'Change password',
            subtitle: 'Update your login password securely',
            onTap: () =>
                Navigator.pushNamed(context, ChangePasswordScreen.routeName),
          ),
          _ToggleRow(
            icon: LucideIcons.fingerprint,
            title: 'Biometric login',
            subtitle: 'Use device fingerprint or face unlock',
            value: _biometricLogin,
            onChanged: _setBiometric,
          ),
          _ToggleRow(
            icon: LucideIcons.lock,
            title: 'Auto-lock',
            subtitle: 'Lock Workable after inactivity',
            value: _autoLock,
            onChanged: _setAutoLock,
          ),
        ],
      ),
    );
  }

  Widget _buildPrivacyControls() {
    return WorkableSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle('Privacy controls'),
          const SizedBox(height: 12),
          _ToggleRow(
            icon: LucideIcons.mapPin,
            title: 'Location features',
            subtitle: 'Use location for nearby workers and booking context',
            value: _locationServices,
            onChanged: _setLocation,
          ),
          const WorkableInfoRow(
            icon: LucideIcons.eye,
            text:
                'Profile visibility and worker marketplace visibility are controlled from account verification and worker profile readiness.',
          ),
        ],
      ),
    );
  }

  Widget _buildDataControls() {
    return WorkableSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle('Data controls'),
          const SizedBox(height: 12),
          _PlannedRow(
            icon: LucideIcons.download,
            title: 'Download my data',
            subtitle: 'Requires export backend before launch',
          ),
          _PlannedRow(
            icon: LucideIcons.trash2,
            title: 'Delete account',
            subtitle: 'Requires account deletion workflow and admin audit',
            color: WorkableDesign.danger,
          ),
        ],
      ),
    );
  }

  Widget _buildLegalControls() {
    return WorkableSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle('Legal'),
          const SizedBox(height: 12),
          _MenuRow(
            icon: LucideIcons.fileText,
            title: 'Privacy policy',
            subtitle: 'How Workable handles customer and worker data',
            onTap: () =>
                Navigator.pushNamed(context, PrivacyPolicyScreen.routeName),
          ),
          _MenuRow(
            icon: LucideIcons.scrollText,
            title: 'Terms & conditions',
            subtitle: 'Marketplace rules for bookings, payments, and safety',
            onTap: () =>
                Navigator.pushNamed(context, TermsConditionsScreen.routeName),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: WorkableDesign.ink,
        fontSize: 16,
        fontWeight: FontWeight.w900,
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: _IconBubble(icon: icon),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
      subtitle: Text(subtitle),
      trailing: const Icon(LucideIcons.chevronRight),
      onTap: onTap,
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      secondary: _IconBubble(icon: icon),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
      subtitle: Text(subtitle),
      value: value,
      onChanged: onChanged,
    );
  }
}

class _PlannedRow extends StatelessWidget {
  const _PlannedRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.color = WorkableDesign.primary,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: _IconBubble(icon: icon, color: color),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
      subtitle: Text(subtitle),
      trailing: WorkableStatusPill(label: 'Planned', color: color),
    );
  }
}

class _IconBubble extends StatelessWidget {
  const _IconBubble({required this.icon, this.color = WorkableDesign.primary});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      backgroundColor: color.withValues(alpha: 0.1),
      child: Icon(icon, color: color, size: 18),
    );
  }
}
