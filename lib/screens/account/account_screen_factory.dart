import 'package:flutter/material.dart';
import 'customer_account_screen.dart';
import 'worker_account_screen.dart';

class AccountScreenFactory {
  /// Returns the appropriate account screen widget based on user type
  static Widget createAccountScreen(String userType) {
    switch (userType.toLowerCase()) {
      case 'worker':
        return const WorkerAccountScreen();
      case 'customer':
      default:
        return const CustomerAccountScreen();
    }
  }

  /// Returns the route name string based on user type
  static String getAccountRoute(String userType) {
    switch (userType.toLowerCase()) {
      case 'worker':
        return WorkerAccountScreen.routeName;
      case 'customer':
      default:
        return CustomerAccountScreen.routeName;
    }
  }

  /// Optional: Validate if userType is supported
  static bool isSupportedUserType(String userType) {
    return ['worker', 'customer'].contains(userType.toLowerCase());
  }
}
