import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../utils/location_helper.dart'; // Update this path as needed

class MapPickerScreen extends StatefulWidget {
  static const routeName = '/map-picker';

  final LatLng? initialLocation;

  const MapPickerScreen({super.key, this.initialLocation});

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  GoogleMapController? _mapController;
  LatLng? _selectedLatLng;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeMap();
  }

  Future<void> _initializeMap() async {
    if (widget.initialLocation != null) {
      setState(() {
        _selectedLatLng = widget.initialLocation!;
        _isLoading = false;
      });
      return;
    }

    final position = await LocationHelper.getCurrentLocation();
    if (position != null) {
      setState(() {
        _selectedLatLng = LatLng(position.latitude, position.longitude);
      });
    }
    setState(() => _isLoading = false);
  }

  void _onMapTap(LatLng latLng) {
    setState(() {
      _selectedLatLng = latLng;
    });
  }

  void _confirmLocation() {
    if (_selectedLatLng != null) {
      Navigator.pop(context, _selectedLatLng);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Pick Location")),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: _selectedLatLng!,
                    zoom: 16,
                  ),
                  onTap: _onMapTap,
                  markers: {
                    if (_selectedLatLng != null)
                      Marker(
                        markerId: const MarkerId('picked_location'),
                        position: _selectedLatLng!,
                      ),
                  },
                  onMapCreated: (controller) => _mapController = controller,
                ),
                Positioned(
                  bottom: 20,
                  left: 20,
                  right: 20,
                  child: ElevatedButton.icon(
                    onPressed: _confirmLocation,
                    icon: const Icon(Icons.check),
                    label: const Text("Use This Location"),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
