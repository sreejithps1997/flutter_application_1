// lib/core/utils/validators.dart
// This file contains validation functions for various input fields used in the application.
// It includes functions to validate email addresses, passwords, names, phone numbers, and other common fields.
// These functions are designed to ensure that user inputs meet specific criteria before being processed further.
// It helps in maintaining data integrity and providing user-friendly error messages when validation fails.

class Validators {
  static String? email(String? value) {
    if (value == null || value.isEmpty) {
      return 'Email is required';
    }

    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    if (!emailRegex.hasMatch(value)) {
      return 'Please enter a valid email address';
    }

    return null;
  }

  static String? password(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }

    if (value.length < 8) {
      return 'Password must be at least 8 characters long';
    }

    if (value.length > 20) {
      return 'Password must be less than 20 characters';
    }

    // Check for at least one uppercase letter
    if (!value.contains(RegExp(r'[A-Z]'))) {
      return 'Password must contain at least one uppercase letter';
    }

    // Check for at least one lowercase letter
    if (!value.contains(RegExp(r'[a-z]'))) {
      return 'Password must contain at least one lowercase letter';
    }

    // Check for at least one digit
    if (!value.contains(RegExp(r'[0-9]'))) {
      return 'Password must contain at least one number';
    }

    return null;
  }

  static String? confirmPassword(String? password, String? confirmPassword) {
    if (confirmPassword == null || confirmPassword.isEmpty) {
      return 'Please confirm your password';
    }

    if (password != confirmPassword) {
      return 'Passwords do not match';
    }

    return null;
  }

  static String? name(String? value) {
    if (value == null || value.isEmpty) {
      return 'Name is required';
    }

    if (value.trim().length < 2) {
      return 'Name must be at least 2 characters long';
    }

    if (value.trim().length > 50) {
      return 'Name must be less than 50 characters';
    }

    // Check if name contains only letters and spaces
    if (!RegExp(r'^[a-zA-Z\s]+$').hasMatch(value.trim())) {
      return 'Name should only contain letters and spaces';
    }

    return null;
  }

  static String? phoneNumber(String? value) {
    if (value == null || value.isEmpty) {
      return 'Phone number is required';
    }

    // Remove all non-digit characters
    final digitsOnly = value.replaceAll(RegExp(r'\D'), '');

    if (digitsOnly.length != 10) {
      return 'Phone number must be 10 digits long';
    }

    return null;
  }

  static String? required(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    return null;
  }

  static String? aadharNumber(String? value) {
    if (value == null || value.isEmpty) {
      return 'Aadhar number is required';
    }

    final digitsOnly = value.replaceAll(RegExp(r'\D'), '');

    if (digitsOnly.length != 12) {
      return 'Aadhar number must be 12 digits long';
    }

    return null;
  }

  static String? panNumber(String? value) {
    if (value == null || value.isEmpty) {
      return 'PAN number is required';
    }

    // PAN format: ABCDE1234F
    if (!RegExp(r'^[A-Z]{5}[0-9]{4}[A-Z]{1}$').hasMatch(value.toUpperCase())) {
      return 'Please enter a valid PAN number';
    }

    return null;
  }
}
