//lib/core/utils/logger.dart
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import '../config/environment.dart';

class AppLogger {
  static bool _isInitialized = false;
  static bool get _isEnabled => EnvironmentConfig.current.enableLogging;

  static void initialize() {
    if (_isInitialized) return;
    _isInitialized = true;

    if (_isEnabled) {
      info(
        'Logger initialized for ${EnvironmentConfig.currentEnvironment.name}',
      );
    }
  }

  static void debug(String message, [String? tag]) {
    if (!_isEnabled) return;
    developer.log(message, name: tag ?? 'DEBUG');
  }

  static void info(String message, [String? tag]) {
    if (!_isEnabled) return;
    developer.log(message, name: tag ?? 'INFO');
  }

  static void warning(String message, [String? tag]) {
    if (!_isEnabled) return;
    developer.log(message, name: tag ?? 'WARNING');
  }

  static void error(
    String message,
    dynamic error, [
    StackTrace? stackTrace,
    String? tag,
  ]) {
    if (_isEnabled) {
      developer.log(
        message,
        name: tag ?? 'ERROR',
        error: error,
        stackTrace: stackTrace,
      );
    }

    // Try to record errors in analytics if available
    try {
      // We'll import analytics dynamically to avoid circular dependencies
      _recordErrorToAnalytics(error ?? message, stackTrace, message);
    } catch (e) {
      // If analytics is not available, just log locally
      developer.log(
        'Analytics not available for error recording',
        name: 'AppLogger',
      );
    }
  }

  static void performance(String operation, Duration duration, [String? tag]) {
    if (!_isEnabled) return;
    developer.log(
      '$operation completed in ${duration.inMilliseconds}ms',
      name: tag ?? 'PERFORMANCE',
    );
  }

  // Helper method to record errors to analytics when available
  static void _recordErrorToAnalytics(
    dynamic error,
    StackTrace? stackTrace,
    String reason,
  ) {
    // This will be called from analytics service when available
    // For now, just log it
    if (_isEnabled) {
      developer.log('Error recorded: $reason', name: 'ErrorTracking');
    }
  }

  // Method for analytics service to register error recording
  static void Function(dynamic, StackTrace?, String)? _analyticsErrorRecorder;

  static void setAnalyticsErrorRecorder(
    void Function(dynamic, StackTrace?, String) recorder,
  ) {
    _analyticsErrorRecorder = recorder;
  }
}
