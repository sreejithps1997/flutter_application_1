// lib/core/utils/extensions.dart
// This file contains various extension methods to enhance the functionality of built-in types like String, DateTime, double, and int.
// It includes methods for formatting dates, currencies, and strings, as well as providing utility functions
import 'package:flutter/material.dart';
import 'helpers.dart'; // Import the helpers file

extension StringExtensions on String {
  bool get isValidEmail {
    return RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    ).hasMatch(this); // Fixed: Added $ and .hasMatch(this)
  }

  bool get isValidPhone {
    final digitsOnly = replaceAll(RegExp(r'\D'), '');
    return digitsOnly.length == 10;
  }

  String get capitalize {
    if (isEmpty) return this;
    return this[0].toUpperCase() + substring(1).toLowerCase();
  }

  String get capitalizeWords {
    if (isEmpty) return this;
    return split(' ').map((word) => word.capitalize).join(' ');
  }

  String truncate(int maxLength) {
    if (length <= maxLength) return this;
    return '${substring(0, maxLength)}...';
  }
}

extension DateTimeExtensions on DateTime {
  String get timeAgo {
    final now = DateTime.now();
    final difference = now.difference(this);

    if (difference.inDays > 7) {
      return Helpers.formatDate(this);
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

  String get formatDate => Helpers.formatDate(this);
  String get formatDateTime => Helpers.formatDateTime(this);
  String get formatTime => Helpers.formatTime(this);

  bool get isToday {
    final now = DateTime.now();
    return year == now.year && month == now.month && day == now.day;
  }

  bool get isYesterday {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return year == yesterday.year &&
        month == yesterday.month &&
        day == yesterday.day;
  }
}

extension DoubleExtensions on double {
  String get formatCurrency => Helpers.formatCurrency(this);
  String get formatCurrencyCompact => Helpers.formatCurrencyCompact(this);
  String get formatDistance => Helpers.formatDistance(this);
  String get formatRating => Helpers.formatRating(this);
  Color get ratingColor => Helpers.getRatingColor(this);
}

extension IntExtensions on int {
  String get formatFileSize => Helpers.formatFileSize(this);
}

extension BuildContextExtensions on BuildContext {
  void hideKeyboard() => Helpers.hideKeyboard(this);
  void showSnackBar(String message) => Helpers.showSnackBar(this, message);
  void showSuccessSnackBar(String message) =>
      Helpers.showSuccessSnackBar(this, message);
  void showErrorSnackBar(String message) =>
      Helpers.showErrorSnackBar(this, message);

  // Theme extensions
  ThemeData get theme => Theme.of(this);
  TextTheme get textTheme => Theme.of(this).textTheme;
  ColorScheme get colorScheme => Theme.of(this).colorScheme;

  // MediaQuery extensions
  Size get screenSize => MediaQuery.of(this).size;
  double get screenWidth => MediaQuery.of(this).size.width;
  double get screenHeight => MediaQuery.of(this).size.height;
  EdgeInsets get padding => MediaQuery.of(this).padding;
  EdgeInsets get viewInsets => MediaQuery.of(this).viewInsets;
}
