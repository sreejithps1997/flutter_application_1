// =============================================================================
// 2. lib/core/services/analytics_service.dart
// Analytics Service for Global Service Portal
// =============================================================================

import 'dart:developer' as developer;
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_performance/firebase_performance.dart';
import 'package:flutter/foundation.dart';
import '../config/environment.dart';
import '../constants/app_constants.dart';

/// Analytics service for tracking user interactions and app performance
class AnalyticsService {
  static final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;
  static final FirebaseCrashlytics _crashlytics = FirebaseCrashlytics.instance;
  static final FirebasePerformance _performance = FirebasePerformance.instance;

  static bool _isInitialized = false;

  /// Check if analytics is enabled for current environment
  static bool get _isAnalyticsEnabled =>
      EnvironmentConfig.current.enableAnalytics;

  /// Check if crash reporting is enabled for current environment
  static bool get _isCrashReportingEnabled =>
      EnvironmentConfig.current.enableCrashReporting;

  /// Check if performance monitoring is enabled for current environment
  static bool get _isPerformanceEnabled =>
      EnvironmentConfig.current.enablePerformanceMonitoring;

  /// Initialize analytics service
  static Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Set analytics collection enabled based on environment
      await _analytics.setAnalyticsCollectionEnabled(_isAnalyticsEnabled);

      // Set crashlytics collection enabled based on environment
      await _crashlytics.setCrashlyticsCollectionEnabled(
        _isCrashReportingEnabled,
      );

      // Set performance monitoring enabled based on environment
      await _performance.setPerformanceCollectionEnabled(_isPerformanceEnabled);

      // Set app info
      await setUserProperty('app_version', AppConstants.appVersion);
      await setUserProperty('environment', EnvironmentConfig.environmentName);

      _isInitialized = true;
      _logDebug('Analytics service initialized');
    } catch (e, stackTrace) {
      _logError('Failed to initialize analytics service', e, stackTrace);
    }
  }

  // =============================================================================
  // USER MANAGEMENT
  // =============================================================================

  /// Set user ID for analytics and crashlytics
  static Future<void> setUserId(String? userId) async {
    if (!_isInitialized) await initialize();

    try {
      if (_isAnalyticsEnabled && userId != null) {
        await _analytics.setUserId(id: userId);
      }

      if (_isCrashReportingEnabled) {
        await _crashlytics.setUserIdentifier(userId ?? 'anonymous');
      }

      _logDebug('User ID set: $userId');
    } catch (e, stackTrace) {
      _logError('Failed to set user ID', e, stackTrace);
    }
  }

  /// Set user property for analytics
  static Future<void> setUserProperty(String name, String? value) async {
    if (!_isAnalyticsEnabled) return;

    try {
      await _analytics.setUserProperty(name: name, value: value);
      _logDebug('User property set: $name = $value');
    } catch (e, stackTrace) {
      _logError('Failed to set user property', e, stackTrace);
    }
  }

  /// Set user type (customer, service_provider, admin)
  static Future<void> setUserType(String userType) async {
    await setUserProperty('user_type', userType);
  }

  // =============================================================================
  // SCREEN TRACKING
  // =============================================================================

  /// Track screen view
  static Future<void> trackScreen(
    String screenName, {
    String? screenClass,
  }) async {
    if (!_isAnalyticsEnabled) return;

    try {
      await _analytics.logScreenView(
        screenName: screenName,
        screenClass: screenClass ?? screenName,
      );
      _logDebug('Screen tracked: $screenName');
    } catch (e, stackTrace) {
      _logError('Failed to track screen', e, stackTrace);
    }
  }

  // =============================================================================
  // EVENT TRACKING
  // =============================================================================

  /// Track custom event with parameters
  static Future<void> trackEvent(
    String eventName, {
    Map<String, dynamic>? parameters,
  }) async {
    if (!_isAnalyticsEnabled) return;

    try {
      // Ensure parameter values are correct types for Firebase
      final Map<String, Object>? cleanedParameters = parameters?.map(
        (key, value) => MapEntry(key, _sanitizeParameterValue(value)),
      );

      await _analytics.logEvent(name: eventName, parameters: cleanedParameters);
      _logDebug('Event tracked: $eventName with params: $cleanedParameters');
    } catch (e, stackTrace) {
      _logError('Failed to track event', e, stackTrace);
    }
  }

  /// Track authentication events
  static Future<void> trackAuth(String action, {String? method}) async {
    await trackEvent(
      'auth_$action',
      parameters: {
        'method': method ?? 'email',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      },
    );
  }

  /// Track service-related events
  static Future<void> trackService(
    String action, {
    String? serviceId,
    String? serviceCategory,
    String? providerId,
    double? price,
  }) async {
    await trackEvent(
      'service_$action',
      parameters: {
        if (serviceId != null) 'service_id': serviceId,
        if (serviceCategory != null) 'service_category': serviceCategory,
        if (providerId != null) 'provider_id': providerId,
        if (price != null) 'price': price,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      },
    );
  }

  /// Track booking events
  static Future<void> trackBooking(
    String action, {
    String? bookingId,
    String? serviceId,
    String? providerId,
    double? amount,
  }) async {
    await trackEvent(
      'booking_$action',
      parameters: {
        if (bookingId != null) 'booking_id': bookingId,
        if (serviceId != null) 'service_id': serviceId,
        if (providerId != null) 'provider_id': providerId,
        if (amount != null) 'amount': amount,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      },
    );
  }

  /// Track search events
  static Future<void> trackSearch(
    String query, {
    String? category,
    String? location,
    int? resultCount,
  }) async {
    await trackEvent(
      'search',
      parameters: {
        'search_term': query,
        if (category != null) 'category': category,
        if (location != null) 'location': location,
        if (resultCount != null) 'result_count': resultCount,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      },
    );
  }

  // =============================================================================
  // ERROR TRACKING
  // =============================================================================

  /// Record error with crashlytics
  static Future<void> recordError(
    dynamic exception,
    StackTrace? stackTrace, {
    String? reason,
    bool fatal = false,
    Map<String, dynamic>? context,
  }) async {
    if (!_isCrashReportingEnabled) return;

    try {
      // Add context information
      if (context != null) {
        for (final entry in context.entries) {
          await _crashlytics.setCustomKey(entry.key, entry.value.toString());
        }
      }

      await _crashlytics.recordError(
        exception,
        stackTrace,
        reason: reason,
        fatal: fatal,
      );

      _logDebug('Error recorded: $exception');
    } catch (e, stackTrace) {
      _logError('Failed to record error', e, stackTrace);
    }
  }

  /// Record custom error with additional context
  static Future<void> recordCustomError(
    String message, {
    String? errorCode,
    String? component,
    Map<String, dynamic>? additionalData,
  }) async {
    final context = <String, dynamic>{
      'error_code': errorCode ?? 'unknown',
      'component': component ?? 'unknown',
      'environment': EnvironmentConfig.environmentName,
      'app_version': AppConstants.appVersion,
      if (additionalData != null) ...additionalData,
    };

    await recordError(
      Exception(message),
      StackTrace.current,
      reason: message,
      context: context,
    );
  }

  // =============================================================================
  // PERFORMANCE TRACKING
  // =============================================================================

  /// Start performance trace
  static Trace? startTrace(String name) {
    if (!_isPerformanceEnabled) return null;

    try {
      final trace = _performance.newTrace(name);
      trace.start();
      _logDebug('Performance trace started: $name');
      return trace;
    } catch (e, stackTrace) {
      _logError('Failed to start performance trace', e, stackTrace);
      return null;
    }
  }

  /// Stop performance trace
  static Future<void> stopTrace(Trace? trace) async {
    if (trace == null || !_isPerformanceEnabled) return;

    try {
      await trace.stop();
      _logDebug('Performance trace stopped');
    } catch (e, stackTrace) {
      _logError('Failed to stop performance trace', e, stackTrace);
    }
  }

  /// Track performance metrics for API calls
  static Future<T> trackApiCall<T>(
    String apiEndpoint,
    Future<T> Function() apiCall,
  ) async {
    final trace = startTrace('api_call_$apiEndpoint');
    trace?.putAttribute('endpoint', apiEndpoint);

    try {
      final stopwatch = Stopwatch()..start();
      final result = await apiCall();
      stopwatch.stop();

      trace?.putAttribute('success', 'true');
      trace?.setMetric('duration_ms', stopwatch.elapsedMilliseconds);

      return result;
    } catch (e) {
      trace?.putAttribute('success', 'false');
      trace?.putAttribute('error', e.toString());
      rethrow;
    } finally {
      await stopTrace(trace);
    }
  }

  // =============================================================================
  // UTILITY METHODS
  // =============================================================================

  /// Sanitize parameter values for Firebase Analytics
  static Object _sanitizeParameterValue(dynamic value) {
    if (value == null) return 'null';
    if (value is String || value is num || value is bool) return value;
    return value.toString();
  }

  /// Log debug messages
  static void _logDebug(String message) {
    if (EnvironmentConfig.current.enableLogging) {
      developer.log(message, name: 'AnalyticsService');
    }
  }

  /// Log error messages
  static void _logError(String message, dynamic error, StackTrace? stackTrace) {
    if (EnvironmentConfig.current.enableLogging) {
      developer.log(
        message,
        name: 'AnalyticsService',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }
}
