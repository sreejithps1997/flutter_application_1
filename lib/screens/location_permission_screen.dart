import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../widgets/custom_button.dart';

class LocationPermissionScreen extends StatefulWidget {
  static const routeName = '/location-permission';

  const LocationPermissionScreen({Key? key}) : super(key: key);

  @override
  State<LocationPermissionScreen> createState() =>
      _LocationPermissionScreenState();
}

class _LocationPermissionScreenState extends State<LocationPermissionScreen> {
  bool isLoading = false;

  Future<void> _requestPermission() async {
    setState(() => isLoading = true);

    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    setState(() => isLoading = false);

    if (permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always) {
      Navigator.pushReplacementNamed(
        context,
        '/',
      ); // Replace with your next screen route
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Location permission is required to proceed.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Enable Location')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.location_on, size: 80, color: Colors.blue),
            const SizedBox(height: 20),
            const Text(
              'We need access to your location to show nearby workers and improve your experience.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 40),
            isLoading
                ? const CircularProgressIndicator()
                : CustomButton(
                    text: 'Allow Location Access',
                    onPressed: _requestPermission,
                  ),
          ],
        ),
      ),
    );
  }
}
