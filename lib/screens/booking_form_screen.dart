import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../widgets/custom_button.dart';
import '../widgets/form_section.dart';
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

  // Future<void> _submitBooking() async {
  //   if (!_formKey.currentState!.validate()) return;

  //   setState(() => _isLoading = true);

  //   final currentUser = FirebaseAuth.instance.currentUser;
  //   if (currentUser == null) {
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       const SnackBar(
  //         content: Text("You must be logged in to book a service."),
  //       ),
  //     );
  //     setState(() => _isLoading = false);
  //     return;
  //   }

  //   final bookingData = {
  //     'customerId': currentUser.uid,
  //     'workerId': widget.workerId ?? '',
  //     'workerName': widget.workerName ?? '',
  //     'issue': _issueController.text.trim(),
  //     'address': _addressController.text.trim(),
  //     'preferredDate': _dateController.text.trim(),
  //     'preferredTime': _timeController.text.trim(),
  //     'status': 'pending',
  //     'payment': 'Cash', // default method
  //     'rating': null,
  //     'createdAt': Timestamp.now(),
  //   };

  //   try {
  //     await FirebaseFirestore.instance.collection('bookings').add(bookingData);

  //     if (mounted) {
  //       Navigator.pushReplacementNamed(
  //         context,
  //         CustomerBookingConfirmationScreen.routeName,
  //       );
  //     }
  //   } catch (e) {
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       const SnackBar(
  //         content: Text("Failed to submit booking. Please try again."),
  //       ),
  //     );
  //   } finally {
  //     if (mounted) setState(() => _isLoading = false);
  //   }
  // }

  Future<void> _submitBooking() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("You must be logged in to book a service."),
        ),
      );
      setState(() => _isLoading = false);
      return;
    }

    // Determine if we actually have a worker selected
    final hasWorker = (widget.workerId?.trim().isNotEmpty ?? false);

    String status = 'pending_assignment';
    String? workerId;
    String? workerName;

    // If worker was pre-selected (normal booking or rebook), re-validate
    if (hasWorker) {
      final w = await _getWorker(widget.workerId!.trim());
      final ok = _isWorkerEligible(w);

      if (!ok) {
        // Block booking with this worker — show a clear message and stop
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'That worker is no longer available or not eligible. Please choose another professional.',
              ),
            ),
          );
        }
        setState(() => _isLoading = false);
        return;
        // If you prefer to fall back to workerless booking instead of blocking:
        // status = 'pending_assignment'; // keep default
      } else {
        workerId = widget.workerId!.trim();
        // take fresh name from worker doc if present; fallback to passed name
        workerName = (w?['name'] ?? w?['fullName'] ?? widget.workerName ?? '')
            .toString()
            .trim();
        status = 'pending'; // or 'requested' based on your pipeline
      }
    }

    // Build payload
    final Map<String, dynamic> bookingData = {
      'customerId': currentUser.uid,
      'issue': _issueController.text.trim(),
      'address': _addressController.text.trim(),
      'preferredDate': _dateController.text.trim(),
      'preferredTime': _timeController.text.trim(),
      'payment': 'Cash',
      'rating': null,
      'createdAt': FieldValue.serverTimestamp(),
      'status': status,
    };

    // Only include worker fields if we actually have them
    if (workerId != null && workerId.isNotEmpty) {
      bookingData['workerId'] = workerId;
      bookingData['workerName'] = workerName;
    } else {
      bookingData['workerId'] = null;
      bookingData['workerName'] = null;
    }

    try {
      await FirebaseFirestore.instance.collection('bookings').add(bookingData);

      if (mounted) {
        Navigator.pushReplacementNamed(
          context,
          CustomerBookingConfirmationScreen.routeName,
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Failed to submit booking. Please try again."),
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<Map<String, dynamic>?> _getWorker(String id) async {
    final s = await FirebaseFirestore.instance
        .collection('workers')
        .doc(id)
        .get();
    return s.data();
  }

  bool _isWorkerEligible(Map<String, dynamic>? w) {
    if (w == null) return false;
    final visible = (w['visibleToUsers'] ?? false) == true;
    final img = (w['imageUrl'] ?? '').toString().trim().isNotEmpty;
    final selfieOk = (w['verification']?['selfie'] ?? '') == 'verified';
    final tier = (w['verification']?['tier'] ?? 'new') as String;
    final hasLoc = w['location'] != null;
    final disabled = (w['accountDisabled'] ?? false) == true;

    // Align with dashboard logic; tighten if you want
    final tierOk = tier == 'verified' || tier == 'police_verified';
    return visible && !disabled && img && selfieOk && hasLoc && tierOk;
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

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          workerDisplay,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 20),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
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
                color: Colors.white,
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
                        colors: [
                          Colors.deepPurple.shade400,
                          Colors.deepPurple.shade600,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(25),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.deepPurple.withOpacity(0.3),
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
                      color: Colors.grey[800],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Fill in the details below to book your service",
                    style: TextStyle(fontSize: 16, color: Colors.grey[600]),
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
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                color: Colors.deepPurple.shade50,
                                borderRadius: BorderRadius.circular(15),
                              ),
                              child: Icon(
                                Icons.person,
                                color: Colors.deepPurple.shade400,
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
                                      color: Colors.grey[600],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    widget.workerName!,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black87,
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
                                color: Colors.green.shade50,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                "Available",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.green.shade700,
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
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.orange.shade50,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  Icons.description,
                                  color: Colors.orange.shade600,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Text(
                                "Issue Description",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
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
                                borderRadius: BorderRadius.circular(15),
                                borderSide: BorderSide(
                                  color: Colors.grey.shade300,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(15),
                                borderSide: BorderSide(
                                  color: Colors.grey.shade300,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(15),
                                borderSide: BorderSide(
                                  color: Colors.deepPurple.shade400,
                                  width: 2,
                                ),
                              ),
                              filled: true,
                              fillColor: Colors.grey.shade50,
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
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade50,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  Icons.location_on,
                                  color: Colors.red.shade600,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Text(
                                "Service Address",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _addressController,
                            decoration: InputDecoration(
                              labelText: "Complete Address",
                              hintText:
                                  "Enter your full address with landmarks",
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(15),
                                borderSide: BorderSide(
                                  color: Colors.grey.shade300,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(15),
                                borderSide: BorderSide(
                                  color: Colors.grey.shade300,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(15),
                                borderSide: BorderSide(
                                  color: Colors.deepPurple.shade400,
                                  width: 2,
                                ),
                              ),
                              filled: true,
                              fillColor: Colors.grey.shade50,
                              contentPadding: const EdgeInsets.all(16),
                            ),
                            validator: (val) =>
                                val == null || val.trim().isEmpty
                                ? "Address is required"
                                : null,
                          ),
                        ],
                      ),
                    ),

                    // Date & Time Card
                    Container(
                      margin: const EdgeInsets.only(bottom: 30),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  Icons.schedule,
                                  color: Colors.blue.shade600,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Text(
                                "Preferred Schedule",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
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
                                      borderRadius: BorderRadius.circular(15),
                                      borderSide: BorderSide(
                                        color: Colors.grey.shade300,
                                      ),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(15),
                                      borderSide: BorderSide(
                                        color: Colors.grey.shade300,
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(15),
                                      borderSide: BorderSide(
                                        color: Colors.deepPurple.shade400,
                                        width: 2,
                                      ),
                                    ),
                                    filled: true,
                                    fillColor: Colors.grey.shade50,
                                    suffixIcon: Container(
                                      margin: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.deepPurple.shade50,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(
                                        Icons.calendar_today,
                                        color: Colors.deepPurple.shade400,
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
                                      _dateController.text = DateFormat(
                                        'yyyy-MM-dd',
                                      ).format(pickedDate);
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  controller: _timeController,
                                  decoration: InputDecoration(
                                    labelText: "Preferred Time",
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(15),
                                      borderSide: BorderSide(
                                        color: Colors.grey.shade300,
                                      ),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(15),
                                      borderSide: BorderSide(
                                        color: Colors.grey.shade300,
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(15),
                                      borderSide: BorderSide(
                                        color: Colors.deepPurple.shade400,
                                        width: 2,
                                      ),
                                    ),
                                    filled: true,
                                    fillColor: Colors.grey.shade50,
                                    suffixIcon: Container(
                                      margin: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.deepPurple.shade50,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(
                                        Icons.access_time,
                                        color: Colors.deepPurple.shade400,
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
                                      _timeController.text = pickedTime.format(
                                        context,
                                      );
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Submit Button
                    _isLoading
                        ? Container(
                            width: double.infinity,
                            height: 56,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.deepPurple.shade300,
                                  Colors.deepPurple.shade400,
                                ],
                              ),
                              borderRadius: BorderRadius.circular(16),
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
                              gradient: LinearGradient(
                                colors: [
                                  Colors.deepPurple.shade400,
                                  Colors.deepPurple.shade600,
                                ],
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                              ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.deepPurple.withOpacity(0.3),
                                  blurRadius: 15,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: _submitBooking,
                                borderRadius: BorderRadius.circular(16),
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
