import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../core/theme/workable_design.dart';
import '../services/app_preferences_service.dart';
import '../widgets/workable_ui.dart';

class LocationPermissionScreen extends StatefulWidget {
  static const routeName = '/location-permission';

  const LocationPermissionScreen({super.key});

  @override
  State<LocationPermissionScreen> createState() =>
      _LocationPermissionScreenState();
}

class _LocationPermissionScreenState extends State<LocationPermissionScreen> {
  bool _isLoading = false;

  Future<void> _requestPermission() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        await AppPreferencesService.setLocationServices(false);
        if (!mounted) return;
        _showSnack('Turn on device location services first.');
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      final granted =
          permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse;
      await AppPreferencesService.setLocationServices(granted);

      if (!mounted) return;
      if (granted) {
        Navigator.pop(context, true);
      } else {
        _showSnack('Location permission was not granted.');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WorkableDesign.canvas,
      appBar: AppBar(title: const Text('Enable Location')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(WorkableDesign.pagePadding),
          children: [
            const WorkablePageHeader(
              title: 'Find nearby help faster',
              subtitle:
                  'Location helps Workable show nearby workers, saved addresses, service areas, and urgent help options.',
              icon: LucideIcons.mapPin,
            ),
            const SizedBox(height: 16),
            const WorkableSectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  WorkableInfoRow(
                    icon: LucideIcons.shield,
                    text:
                        'Your exact location is used only for relevant booking and service matching flows.',
                  ),
                  SizedBox(height: 10),
                  WorkableInfoRow(
                    icon: LucideIcons.settings,
                    text:
                        'You can turn location features off later from App Settings.',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _isLoading ? null : _requestPermission,
              icon: _isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(LucideIcons.mapPin),
              label: Text(_isLoading ? 'Checking...' : 'Allow Location Access'),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: _isLoading
                  ? null
                  : () => Navigator.pop(context, false),
              child: const Text('Not Now'),
            ),
          ],
        ),
      ),
    );
  }
}
