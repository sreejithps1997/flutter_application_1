import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
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
  String? _resolvedAddress;
  bool _isLoading = true;
  bool _isResolvingAddress = false;
  bool _isMovingMap = false;
  int _addressRequestId = 0;

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
      _resolveSelectedAddress(widget.initialLocation!);
      return;
    }

    final position = await LocationHelper.getCurrentLocation();
    final initialLatLng = position != null
        ? LatLng(position.latitude, position.longitude)
        : const LatLng(20.5937, 78.9629);

    if (!mounted) return;
    setState(() {
      _selectedLatLng = initialLatLng;
      _isLoading = false;
    });
    _resolveSelectedAddress(initialLatLng);
  }

  Future<void> _resolveSelectedAddress(LatLng latLng) async {
    final requestId = ++_addressRequestId;
    if (!mounted) return;

    setState(() {
      _isResolvingAddress = true;
      _resolvedAddress = null;
    });

    try {
      final placemarks = await placemarkFromCoordinates(
        latLng.latitude,
        latLng.longitude,
      );

      if (!mounted || requestId != _addressRequestId) return;

      if (placemarks.isEmpty) {
        setState(() => _resolvedAddress = 'Address not found for this point');
        return;
      }

      final place = placemarks.first;
      final addressParts = [
        place.name,
        place.street,
        place.subLocality,
        place.locality,
        place.administrativeArea,
        place.postalCode,
      ].where((part) => part != null && part.trim().isNotEmpty).toList();

      setState(() {
        _resolvedAddress = addressParts.isEmpty
            ? 'Address not found for this point'
            : addressParts.join(', ');
      });
    } catch (_) {
      if (!mounted || requestId != _addressRequestId) return;
      setState(() => _resolvedAddress = 'Move the map to refine this point');
    } finally {
      if (mounted && requestId == _addressRequestId) {
        setState(() => _isResolvingAddress = false);
      }
    }
  }

  void _onCameraMove(CameraPosition position) {
    _selectedLatLng = position.target;
    if (!_isMovingMap) {
      setState(() => _isMovingMap = true);
    }
  }

  void _onCameraIdle() {
    final selectedLatLng = _selectedLatLng;
    if (selectedLatLng == null) return;

    setState(() => _isMovingMap = false);
    _resolveSelectedAddress(selectedLatLng);
  }

  void _onMapTap(LatLng latLng) {
    _mapController?.animateCamera(CameraUpdate.newLatLng(latLng));
  }

  Future<void> _moveToCurrentLocation() async {
    final position = await LocationHelper.getCurrentLocation();
    if (position == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to get current location')),
      );
      return;
    }

    final latLng = LatLng(position.latitude, position.longitude);
    await _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(CameraPosition(target: latLng, zoom: 17)),
    );
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
                  onCameraMove: _onCameraMove,
                  onCameraIdle: _onCameraIdle,
                  onMapCreated: (controller) => _mapController = controller,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                ),
                const Center(
                  child: Padding(
                    padding: EdgeInsets.only(bottom: 36),
                    child: Icon(
                      Icons.location_pin,
                      color: Colors.red,
                      size: 46,
                    ),
                  ),
                ),
                Center(
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: Colors.blue,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
                Positioned(
                  right: 16,
                  bottom: 152,
                  child: FloatingActionButton.small(
                    heroTag: 'current-location',
                    onPressed: _moveToCurrentLocation,
                    child: const Icon(Icons.my_location),
                  ),
                ),
                Positioned(
                  bottom: 20,
                  left: 20,
                  right: 20,
                  child: Card(
                    elevation: 8,
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.location_on, color: Colors.red),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _isMovingMap
                                      ? 'Move pin to exact location'
                                      : 'Selected location',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _isResolvingAddress
                                ? 'Finding nearest address...'
                                : _resolvedAddress ??
                                      'Move the map to select a point',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: Colors.grey.shade700),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _confirmLocation,
                              icon: const Icon(Icons.check),
                              label: const Text("Use This Location"),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
