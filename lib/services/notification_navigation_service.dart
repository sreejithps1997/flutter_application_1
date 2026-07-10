import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../screens/customer_booking_detail_screen.dart';
import '../screens/customer_booking_review_screen.dart';
import '../screens/customer_payment_screen.dart';
import '../screens/generic_help_request_screen.dart';
import '../screens/identity_verification_screen.dart';
import '../screens/chat_screen.dart';
import '../screens/search_screen.dart';
import '../screens/worker_job_details_screen.dart';
import '../features/help_requests/presentation/customer_help_request_detail_screen.dart';
import '../features/help_requests/presentation/worker_help_requests_screen.dart';
import '../features/help_requests/presentation/worker_help_request_detail_screen.dart';
import '../features/worker_opportunities/presentation/worker_opportunity_feed_screen.dart';

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

class NotificationNavigationService {
  const NotificationNavigationService._();

  static Future<void> handlePayloadString(String? payload) async {
    if (payload == null || payload.trim().isEmpty) return;

    try {
      final decoded = jsonDecode(payload);
      if (decoded is Map<String, dynamic>) {
        await handleData(decoded);
      } else if (decoded is Map) {
        await handleData(Map<String, dynamic>.from(decoded));
      }
    } catch (_) {
      return;
    }
  }

  static Future<void> handleData(Map<String, dynamic> data) async {
    final navigator = appNavigatorKey.currentState;
    if (navigator == null) return;

    final type = _text(data, ['type']);
    final category = _text(data, ['category', 'notificationCategory']);
    final bookingId = _text(data, ['bookingId']);
    final documentId = _text(data, ['documentId']);
    final chatWithId = _text(data, ['chatWithId']);
    final workerId = _text(data, ['workerId']);
    final userRole = _text(data, ['userRole', 'role']);
    final helpRequestId = _text(data, ['helpRequestId', 'requestId']);

    if (_isChat(type, category) && chatWithId.isNotEmpty) {
      navigator.pushNamed(
        ChatScreen.routeName,
        arguments: {
          'chatWithId': chatWithId,
          'chatWithName': _text(data, ['chatWithName'], fallback: 'Chat'),
          'userRole': _text(data, ['userRole'], fallback: 'customer'),
          if (bookingId.isNotEmpty) 'bookingId': bookingId,
        },
      );
      return;
    }

    if (_isReview(type, category) &&
        bookingId.isNotEmpty &&
        workerId.isNotEmpty) {
      navigator.pushNamed(
        CustomerBookingReviewScreen.routeName,
        arguments: {'bookingId': bookingId, 'workerId': workerId},
      );
      return;
    }

    if (_isWorkerOpportunity(type, category)) {
      navigator.pushNamed(WorkerOpportunityFeedScreen.routeName);
      return;
    }

    if (_isDemandApproved(type, category)) {
      navigator.pushNamed(SearchScreen.routeName);
      return;
    }

    if (_isVerification(type, category) || documentId.isNotEmpty) {
      navigator.pushNamed(IdentityVerificationScreen.routeName);
      return;
    }

    if (_isPayment(type, category) && bookingId.isNotEmpty) {
      navigator.pushNamed(
        CustomerPaymentScreen.routeName,
        arguments: bookingId,
      );
      return;
    }

    if (_isBooking(type, category) && bookingId.isNotEmpty) {
      await _openBooking(navigator, bookingId);
      return;
    }

    if (_isHelpRequest(type, category)) {
      if (userRole == 'worker' || type == 'new_help_request') {
        if (helpRequestId.isNotEmpty) {
          navigator.pushNamed(
            WorkerHelpRequestDetailScreen.routeName,
            arguments: {'requestId': helpRequestId},
          );
          return;
        }
        navigator.pushNamed(WorkerHelpRequestsScreen.routeName);
        return;
      }
      if (helpRequestId.isNotEmpty) {
        navigator.pushNamed(
          CustomerHelpRequestDetailScreen.routeName,
          arguments: {'requestId': helpRequestId},
        );
        return;
      }
      navigator.pushNamed(GenericHelpRequestScreen.routeName);
      return;
    }

    navigator.pushNamed('/customer/notifications');
  }

  static Future<void> _openBooking(
    NavigatorState navigator,
    String bookingId,
  ) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('bookings')
        .doc(bookingId)
        .get();
    final data = snapshot.data();

    if (data == null) {
      navigator.pushNamed('/customer/notifications');
      return;
    }

    final booking = {'id': snapshot.id, ...data};
    final workerId = data['workerId']?.toString() ?? '';
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';

    if (workerId.isNotEmpty && currentUid == workerId) {
      navigator.pushNamed(
        WorkerJobDetailsScreen.routeName,
        arguments: bookingId,
      );
      return;
    }

    navigator.pushNamed(
      CustomerBookingDetailScreen.routeName,
      arguments: booking,
    );
  }

  static bool _isWorkerOpportunity(String type, String category) {
    return type == 'worker_category_opportunity' ||
        category == 'worker_opportunity';
  }

  static bool _isDemandApproved(String type, String category) {
    return type == 'demand_category_approved' || category == 'demand_discovery';
  }

  static bool _isVerification(String type, String category) {
    return type.contains('verification') || category == 'verification_workflow';
  }

  static bool _isPayment(String type, String category) {
    return type.contains('payment') || category.contains('payment');
  }

  static bool _isBooking(String type, String category) {
    return type.contains('booking') || category.contains('booking');
  }

  static bool _isHelpRequest(String type, String category) {
    return type.contains('help_request') || category.contains('help_request');
  }

  static bool _isChat(String type, String category) {
    return type.contains('chat') || category.contains('chat');
  }

  static bool _isReview(String type, String category) {
    return type.contains('review') || category.contains('review');
  }

  static String _text(
    Map<String, dynamic> data,
    List<String> keys, {
    String fallback = '',
  }) {
    for (final key in keys) {
      final value = data[key]?.toString().trim();
      if (value != null && value.isNotEmpty && value.toLowerCase() != 'null') {
        return value;
      }
    }
    return fallback;
  }
}
