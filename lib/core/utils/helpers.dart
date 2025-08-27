//lib/core/utils/helpers.dart
// This file contains utility functions and helpers used throughout the application.
// It includes functions for formatting dates, currencies, strings, and other common tasks.
// It is designed to provide reusable code snippets that can be used across different parts of the app.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class Helpers {
  // Date and Time helpers
  static String formatDate(DateTime date) {
    return DateFormat('dd MMM yyyy').format(date);
  }

  static String formatDateTime(DateTime dateTime) {
    return DateFormat('dd MMM yyyy, hh:mm a').format(dateTime);
  }

  static String formatTime(DateTime dateTime) {
    return DateFormat('hh:mm a').format(dateTime);
  }

  static String timeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 7) {
      return formatDate(dateTime);
    } else if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
    } else {
      return 'Just now';
    }
  }

  // Currency helpers
  static String formatCurrency(double amount) {
    return '₹${amount.toStringAsFixed(2)}';
  }

  static String formatCurrencyCompact(double amount) {
    if (amount >= 10000000) {
      return '₹${(amount / 10000000).toStringAsFixed(1)}Cr';
    } else if (amount >= 100000) {
      return '₹${(amount / 100000).toStringAsFixed(1)}L';
    } else if (amount >= 1000) {
      return '₹${(amount / 1000).toStringAsFixed(1)}K';
    } else {
      return '₹${amount.toStringAsFixed(0)}';
    }
  }

  // String helpers
  static String capitalize(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1).toLowerCase();
  }

  static String capitalizeWords(String text) {
    if (text.isEmpty) return text;
    return text.split(' ').map((word) => capitalize(word)).join(' ');
  }

  static String truncateText(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength)}...';
  }

  // Phone number helpers
  static String formatPhoneNumber(String phoneNumber) {
    final digitsOnly = phoneNumber.replaceAll(RegExp(r'\D'), '');
    if (digitsOnly.length == 10) {
      return '+91 ${digitsOnly.substring(0, 5)} ${digitsOnly.substring(5)}';
    }
    return phoneNumber;
  }

  // Distance helpers
  static String formatDistance(double distanceInKm) {
    if (distanceInKm < 1) {
      return '${(distanceInKm * 1000).toInt()} m';
    } else {
      return '${distanceInKm.toStringAsFixed(1)} km';
    }
  }

  // Rating helpers
  static String formatRating(double rating) {
    return rating.toStringAsFixed(1);
  }

  static Color getRatingColor(double rating) {
    if (rating >= 4.5) return Colors.green;
    if (rating >= 3.5) return Colors.orange;
    if (rating >= 2.5) return Colors.yellow;
    return Colors.red;
  }

  // File size helpers
  static String formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024)
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  // Color helpers
  static Color getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
      case 'approved':
      case 'verified':
        return Colors.green;
      case 'pending':
      case 'in_progress':
        return Colors.orange;
      case 'cancelled':
      case 'rejected':
      case 'failed':
        return Colors.red;
      case 'draft':
        return Colors.grey;
      default:
        return Colors.blue;
    }
  }

  // Debug helpers
  static void debugLog(String message, [String? tag]) {
    debugPrint('${tag != null ? '[$tag] ' : ''}$message');
  }

  // Navigation helpers
  static void hideKeyboard(BuildContext context) {
    FocusScope.of(context).unfocus();
  }

  // Snackbar helpers
  static void showSnackBar(
    BuildContext context,
    String message, {
    Color? backgroundColor,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  static void showSuccessSnackBar(BuildContext context, String message) {
    showSnackBar(context, message, backgroundColor: Colors.green);
  }

  static void showErrorSnackBar(BuildContext context, String message) {
    showSnackBar(context, message, backgroundColor: Colors.red);
  }
}
