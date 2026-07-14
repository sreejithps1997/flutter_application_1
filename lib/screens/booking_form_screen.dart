import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import '../core/theme/workable_design.dart';
import '../features/bookings/data/booking_repository.dart';
import '../features/bookings/domain/booking_draft.dart';
import 'address_management_screen.dart';
import 'add_new_address_screen.dart';
import 'customer_booking_confirmation_screen.dart';
import 'package:intl/intl.dart'; // ⬅️ Add at top if not already

class BookingFormScreen extends StatefulWidget {
  static const routeName = '/booking-form';

  final String? workerId;
  final String? workerName;

  const BookingFormScreen({super.key, this.workerId, this.workerName});

  @override
  State<BookingFormScreen> createState() => _BookingFormScreenState();
}

class _BookingFormScreenState extends State<BookingFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _issueController = TextEditingController();
  final _dateController = TextEditingController();
  final _timeController = TextEditingController();
  final _addressController = TextEditingController();

  bool _isLoading = false;
  bool _isLocating = false;
  bool _didApplyRouteAddress = false;
  bool _didLoadDefaultAddress = false;
  Map<String, dynamic>? _selectedAddress;
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didApplyRouteAddress) return;

    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map && args['selectedAddress'] is Map) {
      final address = Map<String, dynamic>.from(args['selectedAddress'] as Map);
      _applySelectedAddress(address);
    } else {
      _loadDefaultAddressPrompt();
    }

    _didApplyRouteAddress = true;
  }

  void _applySelectedAddress(Map<String, dynamic> address) {
    _selectedAddress = address;
    _addressController.text = _formatSelectedAddress(address);
  }

  String _formatSelectedAddress(Map<String, dynamic> address) {
    final parts =
        [
              address['address'],
              address['area'],
              address['landmark'],
              address['pincode'],
            ]
            .where((part) => part != null && part.toString().trim().isNotEmpty)
            .map((part) => part.toString().trim())
            .toList();

    return parts.join(', ');
  }

  Future<void> _openAddressSelector() async {
    final selectedAddress = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => AddressManagementScreen(
          isSelectionMode: true,
          selectedAddressId: _selectedAddress?['id']?.toString(),
        ),
      ),
    );

    if (selectedAddress == null || !mounted) return;

    setState(() => _applySelectedAddress(selectedAddress));
  }

  Future<void> _openSelectedAddressDetails() async {
    final selectedAddress = _selectedAddress;

    if (selectedAddress == null) {
      await _openAddressSelector();
      return;
    }

    final updatedAddress = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            AddNewAddressScreen(isEdit: true, addressData: selectedAddress),
      ),
    );

    if (updatedAddress == null || !mounted) return;

    setState(() => _applySelectedAddress(updatedAddress));
  }

  Future<void> _loadDefaultAddressPrompt() async {
    if (_didLoadDefaultAddress) return;
    _didLoadDefaultAddress = true;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('addresses')
        .where('isDefault', isEqualTo: true)
        .limit(1)
        .get();
    if (!mounted || snapshot.docs.isEmpty) return;

    final address = {
      ...snapshot.docs.first.data(),
      'id': snapshot.docs.first.id,
    };
    setState(() => _applySelectedAddress(address));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _askUseDefaultAddress();
    });
  }

  Future<void> _askUseDefaultAddress() async {
    final address = _selectedAddress;
    if (address == null) return;

    final action = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Use this service location?'),
          content: Text(
            _formatSelectedAddress(address).isEmpty
                ? 'Use your saved default location for this booking?'
                : _formatSelectedAddress(address),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, 'different'),
              child: const Text('Different Address'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, 'edit'),
              child: const Text('Add Details'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, 'same'),
              child: const Text('Yes, Continue'),
            ),
          ],
        );
      },
    );

    if (!mounted) return;
    if (action == 'different') {
      await _openAddressSelector();
    } else if (action == 'edit') {
      await _openSelectedAddressDetails();
    }
  }

  Future<void> _useCurrentLocation() async {
    if (_isLocating) return;
    setState(() => _isLocating = true);
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!mounted) return;
      if (!serviceEnabled) {
        _showMessage('Please enable location services.');
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (!mounted) return;
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _showMessage('Location permission denied.');
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      final place = placemarks.isNotEmpty ? placemarks.first : null;
      final addressText = [
        place?.street,
        place?.locality,
        place?.administrativeArea,
        place?.postalCode,
      ].where((part) => (part ?? '').trim().isNotEmpty).join(', ');

      final address = <String, dynamic>{
        'id': 'current_location',
        'label': 'Current location',
        'type': 'Current',
        'address': addressText.isEmpty ? 'Current GPS location' : addressText,
        'area': place?.locality ?? '',
        'landmark': '',
        'pincode': place?.postalCode ?? '',
        'contact': '',
        'latitude': position.latitude,
        'longitude': position.longitude,
        'location': GeoPoint(position.latitude, position.longitude),
        'isVerified': true,
      };
      if (!mounted) return;
      setState(() => _applySelectedAddress(address));
      _showMessage('Current location added for this booking.');
    } catch (error) {
      if (!mounted) return;
      _showMessage('Unable to get location. Choose a saved address instead.');
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  Future<void> _submitBooking() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await BookingRepository().createBooking(
        BookingDraft(
          issue: _issueController.text.trim(),
          address: _addressController.text.trim(),
          preferredDate: _dateController.text.trim(),
          preferredTime: _timeController.text.trim(),
          scheduledAt: _selectedScheduledAt(),
          workerId: widget.workerId,
          workerName: widget.workerName,
          selectedAddress: _selectedAddress,
        ),
      );

      if (mounted) {
        Navigator.pushReplacementNamed(
          context,
          CustomerBookingConfirmationScreen.routeName,
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_bookingErrorMessage(e))));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  DateTime? _selectedScheduledAt() {
    final date = _selectedDate;
    final time = _selectedTime;
    if (date == null || time == null) return null;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  String _bookingErrorMessage(Object error) {
    final message = error.toString().replaceFirst('Bad state: ', '').trim();
    if (message.isEmpty) {
      return 'Failed to submit booking. Please try again.';
    }
    return message;
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    _issueController.dispose();
    _dateController.dispose();
    _timeController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasWorker =
        widget.workerId?.isNotEmpty == true &&
        widget.workerName?.isNotEmpty == true;
    final workerDisplay = hasWorker ? "Book Service" : "New Booking";
    final hasSelectedAddress = _addressController.text.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: WorkableDesign.canvas,
      appBar: AppBar(
        title: Text(
          workerDisplay,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 20),
        ),
        backgroundColor: WorkableDesign.surface,
        foregroundColor: WorkableDesign.ink,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: WorkableDesign.canvas,
              borderRadius: BorderRadius.circular(WorkableDesign.radius),
            ),
            child: const Icon(Icons.arrow_back_ios, size: 16),
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header Section
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: WorkableDesign.surface,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  // Service Icon
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [WorkableDesign.primary, WorkableDesign.accent],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(25),
                      boxShadow: [
                        BoxShadow(
                          color: WorkableDesign.primary.withValues(alpha: 0.18),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.build_circle,
                      color: Colors.white,
                      size: 40,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "Book Your Service",
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: WorkableDesign.ink,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Fill in the details below to book your service",
                    style: const TextStyle(
                      fontSize: 16,
                      color: WorkableDesign.muted,
                    ),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),

            // Form Section
            Padding(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                child: Column(
                  children: [
                    // Worker Info Card
                    // if (widget.workerName != null)
                    //   Container(
                    //     width: double.infinity,
                    //     margin: const EdgeInsets.only(bottom: 24),
                    //     padding: const EdgeInsets.all(20),
                    //     decoration: BoxDecoration(
                    //       color: Colors.white,
                    //       borderRadius: BorderRadius.circular(20),
                    //       boxShadow: [
                    //         BoxShadow(
                    //           color: Colors.grey.withOpacity(0.1),
                    //           blurRadius: 10,
                    //           offset: const Offset(0, 5),
                    //         ),
                    //       ],
                    //     ),
                    //     child: Row(
                    //       children: [
                    //         Container(
                    //           width: 50,
                    //           height: 50,
                    //           decoration: BoxDecoration(
                    //             color: Colors.deepPurple.shade50,
                    //             borderRadius: BorderRadius.circular(15),
                    //           ),
                    //           child: Icon(
                    //             Icons.person,
                    //             color: Colors.deepPurple.shade400,
                    //             size: 28,
                    //           ),
                    //         ),
                    //         const SizedBox(width: 16),
                    //         Expanded(
                    //           child: Column(
                    //             crossAxisAlignment: CrossAxisAlignment.start,
                    //             children: [
                    //               Text(
                    //                 "Assigned Worker",
                    //                 style: TextStyle(
                    //                   fontSize: 12,
                    //                   color: Colors.grey[600],
                    //                   fontWeight: FontWeight.w500,
                    //                 ),
                    //               ),
                    //               const SizedBox(height: 4),
                    //               Text(
                    //                 widget.workerName!,
                    //                 style: const TextStyle(
                    //                   fontSize: 16,
                    //                   fontWeight: FontWeight.w600,
                    //                   color: Colors.black87,
                    //                 ),
                    //               ),
                    //             ],
                    //           ),
                    //         ),
                    //         Container(
                    //           padding: const EdgeInsets.symmetric(
                    //             horizontal: 12,
                    //             vertical: 6,
                    //           ),
                    //           decoration: BoxDecoration(
                    //             color: Colors.green.shade50,
                    //             borderRadius: BorderRadius.circular(20),
                    //           ),
                    //           child: Text(
                    //             "Available",
                    //             style: TextStyle(
                    //               fontSize: 12,
                    //               color: Colors.green.shade700,
                    //               fontWeight: FontWeight.w500,
                    //             ),
                    //           ),
                    //         ),
                    //       ],
                    //     ),
                    //   ),
                    if (hasWorker)
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 24),
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: WorkableDesign.surface,
                          borderRadius: BorderRadius.circular(
                            WorkableDesign.radius,
                          ),
                          border: Border.all(color: WorkableDesign.border),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                color: WorkableDesign.primary.withValues(
                                  alpha: 0.1,
                                ),
                                borderRadius: BorderRadius.circular(
                                  WorkableDesign.radius,
                                ),
                              ),
                              child: Icon(
                                Icons.person,
                                color: WorkableDesign.primary,
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Assigned Worker",
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: WorkableDesign.muted,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    widget.workerName!,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: WorkableDesign.ink,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: WorkableDesign.success.withValues(
                                  alpha: 0.1,
                                ),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                "Available",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: WorkableDesign.success,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Issue Description Card
                    Container(
                      margin: const EdgeInsets.only(bottom: 20),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: WorkableDesign.surface,
                        borderRadius: BorderRadius.circular(
                          WorkableDesign.radius,
                        ),
                        border: Border.all(color: WorkableDesign.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: WorkableDesign.warning.withValues(
                                    alpha: 0.1,
                                  ),
                                  borderRadius: BorderRadius.circular(
                                    WorkableDesign.radius,
                                  ),
                                ),
                                child: Icon(
                                  Icons.description,
                                  color: WorkableDesign.warning,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Text(
                                "Issue Description",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: WorkableDesign.ink,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _issueController,
                            decoration: InputDecoration(
                              labelText: "Describe your issue in detail",
                              hintText:
                                  "e.g., Kitchen tap is leaking, need urgent repair...",
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(
                                  WorkableDesign.radius,
                                ),
                                borderSide: BorderSide(
                                  color: WorkableDesign.border,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(
                                  WorkableDesign.radius,
                                ),
                                borderSide: BorderSide(
                                  color: WorkableDesign.border,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(
                                  WorkableDesign.radius,
                                ),
                                borderSide: BorderSide(
                                  color: WorkableDesign.primary,
                                  width: 2,
                                ),
                              ),
                              filled: true,
                              fillColor: WorkableDesign.canvas,
                              contentPadding: const EdgeInsets.all(16),
                            ),
                            maxLines: 4,
                            validator: (val) =>
                                val == null || val.trim().isEmpty
                                ? "Please describe the issue"
                                : null,
                          ),
                        ],
                      ),
                    ),

                    // Address Card
                    Container(
                      margin: const EdgeInsets.only(bottom: 20),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: WorkableDesign.surface,
                        borderRadius: BorderRadius.circular(
                          WorkableDesign.radius,
                        ),
                        border: Border.all(color: WorkableDesign.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: WorkableDesign.danger.withValues(
                                    alpha: 0.1,
                                  ),
                                  borderRadius: BorderRadius.circular(
                                    WorkableDesign.radius,
                                  ),
                                ),
                                child: Icon(
                                  Icons.location_on,
                                  color: WorkableDesign.danger,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Text(
                                  "Service Address",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: WorkableDesign.ink,
                                  ),
                                ),
                              ),
                              TextButton.icon(
                                onPressed: _openAddressSelector,
                                icon: Icon(
                                  hasSelectedAddress
                                      ? Icons.swap_horiz
                                      : Icons.add_location_alt,
                                  size: 18,
                                ),
                                label: Text(
                                  hasSelectedAddress
                                      ? "Change Address"
                                      : "Add Address",
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _addressController,
                            readOnly: true,
                            onTap: _openAddressSelector,
                            decoration: InputDecoration(
                              labelText: "Complete Address",
                              hintText: "Add a saved address for this booking",
                              suffixIcon: IconButton(
                                onPressed: hasSelectedAddress
                                    ? _openSelectedAddressDetails
                                    : _openAddressSelector,
                                icon: Icon(
                                  hasSelectedAddress
                                      ? Icons.visibility_outlined
                                      : Icons.add_circle_outline,
                                ),
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(
                                  WorkableDesign.radius,
                                ),
                                borderSide: BorderSide(
                                  color: WorkableDesign.border,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(
                                  WorkableDesign.radius,
                                ),
                                borderSide: BorderSide(
                                  color: WorkableDesign.border,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(
                                  WorkableDesign.radius,
                                ),
                                borderSide: BorderSide(
                                  color: WorkableDesign.primary,
                                  width: 2,
                                ),
                              ),
                              filled: true,
                              fillColor: WorkableDesign.canvas,
                              contentPadding: const EdgeInsets.all(16),
                            ),
                            validator: (val) =>
                                val == null || val.trim().isEmpty
                                ? "Address is required"
                                : null,
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _isLocating
                                      ? null
                                      : _useCurrentLocation,
                                  icon: _isLocating
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(Icons.my_location_outlined),
                                  label: Text(
                                    _isLocating
                                        ? 'Getting location...'
                                        : 'Use current location',
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _openAddressSelector,
                                  icon: const Icon(Icons.bookmark_outline),
                                  label: const Text('Saved addresses'),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.info_outline,
                                size: 16,
                                color: WorkableDesign.muted,
                              ),
                              const SizedBox(width: 6),
                              const Expanded(
                                child: Text(
                                  'A map location helps workers start work only after reaching the service place.',
                                  style: TextStyle(
                                    color: WorkableDesign.muted,
                                    fontSize: 12,
                                    height: 1.35,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (_selectedAddress != null) ...[
                            const SizedBox(height: 12),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: WorkableDesign.danger.withValues(
                                  alpha: 0.08,
                                ),
                                borderRadius: BorderRadius.circular(
                                  WorkableDesign.radius,
                                ),
                                border: Border.all(
                                  color: WorkableDesign.danger.withValues(
                                    alpha: 0.18,
                                  ),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.location_searching,
                                    color: WorkableDesign.danger,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      [
                                            _selectedAddress!['label'],
                                            _selectedAddress!['contact'],
                                          ]
                                          .where(
                                            (part) =>
                                                part != null &&
                                                part
                                                    .toString()
                                                    .trim()
                                                    .isNotEmpty,
                                          )
                                          .join(' - '),
                                      style: TextStyle(
                                        color: WorkableDesign.danger,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    // Date & Time Card
                    Container(
                      margin: const EdgeInsets.only(bottom: 30),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: WorkableDesign.surface,
                        borderRadius: BorderRadius.circular(
                          WorkableDesign.radius,
                        ),
                        border: Border.all(color: WorkableDesign.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: WorkableDesign.primary.withValues(
                                    alpha: 0.1,
                                  ),
                                  borderRadius: BorderRadius.circular(
                                    WorkableDesign.radius,
                                  ),
                                ),
                                child: Icon(
                                  Icons.schedule,
                                  color: WorkableDesign.primary,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Text(
                                "Preferred Schedule",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: WorkableDesign.ink,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _dateController,
                                  decoration: InputDecoration(
                                    labelText: "Preferred Date",
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(
                                        WorkableDesign.radius,
                                      ),
                                      borderSide: BorderSide(
                                        color: WorkableDesign.border,
                                      ),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(
                                        WorkableDesign.radius,
                                      ),
                                      borderSide: BorderSide(
                                        color: WorkableDesign.border,
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(
                                        WorkableDesign.radius,
                                      ),
                                      borderSide: BorderSide(
                                        color: WorkableDesign.primary,
                                        width: 2,
                                      ),
                                    ),
                                    filled: true,
                                    fillColor: WorkableDesign.canvas,
                                    suffixIcon: Container(
                                      margin: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: WorkableDesign.primary
                                            .withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(
                                          WorkableDesign.radius,
                                        ),
                                      ),
                                      child: Icon(
                                        Icons.calendar_today,
                                        color: WorkableDesign.primary,
                                        size: 20,
                                      ),
                                    ),
                                    contentPadding: const EdgeInsets.all(16),
                                  ),
                                  readOnly: true,
                                  onTap: () async {
                                    DateTime? pickedDate = await showDatePicker(
                                      context: context,
                                      initialDate: DateTime.now().add(
                                        const Duration(days: 1),
                                      ),
                                      firstDate: DateTime.now(),
                                      lastDate: DateTime.now().add(
                                        const Duration(days: 60),
                                      ),
                                    );
                                    if (pickedDate != null) {
                                      setState(() {
                                        _selectedDate = pickedDate;
                                        _dateController.text = DateFormat(
                                          'yyyy-MM-dd',
                                        ).format(pickedDate);
                                      });
                                    }
                                  },
                                  validator: (value) =>
                                      value == null || value.trim().isEmpty
                                      ? "Date is required"
                                      : null,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  controller: _timeController,
                                  decoration: InputDecoration(
                                    labelText: "Preferred Time",
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(
                                        WorkableDesign.radius,
                                      ),
                                      borderSide: BorderSide(
                                        color: WorkableDesign.border,
                                      ),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(
                                        WorkableDesign.radius,
                                      ),
                                      borderSide: BorderSide(
                                        color: WorkableDesign.border,
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(
                                        WorkableDesign.radius,
                                      ),
                                      borderSide: BorderSide(
                                        color: WorkableDesign.primary,
                                        width: 2,
                                      ),
                                    ),
                                    filled: true,
                                    fillColor: WorkableDesign.canvas,
                                    suffixIcon: Container(
                                      margin: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: WorkableDesign.primary
                                            .withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(
                                          WorkableDesign.radius,
                                        ),
                                      ),
                                      child: Icon(
                                        Icons.access_time,
                                        color: WorkableDesign.primary,
                                        size: 20,
                                      ),
                                    ),
                                    contentPadding: const EdgeInsets.all(16),
                                  ),
                                  readOnly: true,
                                  onTap: () async {
                                    TimeOfDay? pickedTime =
                                        await showTimePicker(
                                          context: context,
                                          initialTime: TimeOfDay.now(),
                                        );
                                    if (pickedTime != null) {
                                      if (!context.mounted) return;
                                      setState(() {
                                        _selectedTime = pickedTime;
                                        _timeController.text = pickedTime
                                            .format(context);
                                      });
                                    }
                                  },
                                  validator: (value) =>
                                      value == null || value.trim().isEmpty
                                      ? "Time is required"
                                      : null,
                                ),
                              ),
                            ],
                          ),
                          if (hasWorker) ...[
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  size: 16,
                                  color: WorkableDesign.primary,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    'This slot will be checked against the worker schedule and service radius before booking.',
                                    style: TextStyle(
                                      color: WorkableDesign.primary,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),

                    // Submit Button
                    _isLoading
                        ? Container(
                            width: double.infinity,
                            height: 56,
                            decoration: BoxDecoration(
                              color: WorkableDesign.primary,
                              borderRadius: BorderRadius.circular(
                                WorkableDesign.radius,
                              ),
                            ),
                            child: const Center(
                              child: CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            ),
                          )
                        : Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: WorkableDesign.primary,
                              borderRadius: BorderRadius.circular(
                                WorkableDesign.radius,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: WorkableDesign.primary.withValues(
                                    alpha: 0.16,
                                  ),
                                  blurRadius: 12,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: _submitBooking,
                                borderRadius: BorderRadius.circular(
                                  WorkableDesign.radius,
                                ),
                                child: const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 16),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.check_circle,
                                        color: Colors.white,
                                        size: 24,
                                      ),
                                      SizedBox(width: 12),
                                      Text(
                                        "Submit Booking",
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
