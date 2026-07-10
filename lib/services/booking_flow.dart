import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../screens/customer_booking_detail_screen.dart';

class BookingFlow {
  // --- Firestore lookups ---
  static Future<Map<String, dynamic>?> _getWorker(String id) async {
    final snap = await FirebaseFirestore.instance
        .collection('workers')
        .doc(id)
        .get();
    return snap.data();
  }

  // --- Same gating rule used by your dashboard ---
  static bool isWorkerEligible(Map<String, dynamic>? w) {
    if (w == null) return false;
    final visible = (w['visibleToUsers'] ?? false) == true;
    final img = (w['imageUrl'] ?? '').toString().trim().isNotEmpty;
    final selfieOk = (w['verification']?['selfie'] ?? '') == 'verified';
    final hasLoc = w['location'] != null;
    final disabled = (w['accountDisabled'] ?? false) == true;

    return visible && !disabled && img && selfieOk && hasLoc;
  }

  /// Rebook flow you can call from anywhere
  /// `old` should be the booking map (must contain serviceType/issue, address, workerId if any).
  static Future<void> rebook(
    BuildContext context,
    Map<String, dynamic> old,
  ) async {
    final oldWorkerId = (old['workerId'] as String?)?.trim();

    // No worker tied to that booking
    if (oldWorkerId == null || oldWorkerId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'This booking wasn’t tied to a specific worker. Please pick another professional.',
          ),
        ),
      );
      return; // stop, no navigation
    }

    // Check current eligibility
    final worker = await _getWorker(oldWorkerId);
    if (!context.mounted) return;

    if (isWorkerEligible(worker)) {
      final workerName = (worker?['name'] ?? worker?['fullName'] ?? '')
          .toString();

      await Navigator.pushNamed(
        context,
        '/book-service',
        arguments: {
          'serviceType': old['serviceType'] ?? old['issue'],
          'address': old['address'],
          'isRepeatBooking': true,
          'workerId': oldWorkerId,
          'workerName': workerName,
        },
      );
      return;
    }

    // Worker no longer available
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'That worker is no longer available. Please select another professional.',
        ),
      ),
    );
    // stop, no navigation
  }

  /// Open worker profile only if the worker exists and is eligible.
  static Future<void> openWorkerProfile(
    BuildContext context,
    String? workerId,
  ) async {
    final id = workerId?.trim();

    // No worker ID
    if (id == null || id.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Worker not assigned yet.')));
      return;
    }

    // Fetch worker
    final worker = await _getWorker(id);
    if (!context.mounted) return;

    // Check eligibility
    if (!isWorkerEligible(worker)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This worker is not available right now.'),
        ),
      );
      return;
    }

    // Navigate to profile
    Navigator.pushNamed(
      context,
      '/worker-profile',
      arguments: {'workerId': id},
    );
  }

  /// STRICT: Only open booking details if a worker is assigned AND eligible.
  /// Otherwise, show a message and do not navigate.
  static Future<void> openBookingDetailsStrict(
    BuildContext context,
    Map<String, dynamic> booking,
  ) async {
    final workerId = (booking['workerId'] as String?)?.trim();

    // 1) No worker assigned
    if (workerId == null || workerId.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No worker assigned yet.')));
      return;
    }

    // 2) Validate worker eligibility
    try {
      final snap = await FirebaseFirestore.instance
          .collection('workers')
          .doc(workerId)
          .get();
      if (!context.mounted) return;

      final worker = snap.data();

      if (!isWorkerEligible(worker)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('This worker is not available right now.'),
          ),
        );
        return;
      }
    } catch (_) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not verify worker availability.')),
      );
      return;
    }

    // 3) All checks passed → open details
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CustomerBookingDetailScreen(booking: booking),
      ),
    );
  }
}
