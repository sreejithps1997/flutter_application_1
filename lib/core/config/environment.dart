//lib/core/config/  .dart

import 'package:flutter/foundation.dart';

/// Enum representing different deployment environments
enum Environment { development, staging, production }

/// Environment configuration class for managing app settings across environments
class EnvironmentConfig {
  /// Current environment - Change this for different builds
  static const Environment _currentEnvironment = kDebugMode
      ? Environment.development
      : Environment.production;

  /// Environment configurations
  static const Map<Environment, EnvironmentData> _configs = {
    Environment.development: EnvironmentData(
      name: 'Development',
      apiBaseUrl: 'https://dev-api.globalserviceportal.com',
      apiVersion: 'v1',
      appName: 'Global Service Portal (Dev)',
      enableLogging: true,
      enableAnalytics: false,
      enableCrashReporting: false,
      enablePerformanceMonitoring: true,
      apiTimeout: Duration(seconds: 30),
      maxRetryAttempts: 3,
      cacheValidityDuration: Duration(minutes: 5),
      enableMockData: true,
      enableDebugFeatures: true,
    ),
    Environment.staging: EnvironmentData(
      name: 'Staging',
      apiBaseUrl: 'https://staging-api.globalserviceportal.com',
      apiVersion: 'v1',
      appName: 'Global Service Portal (Staging)',
      enableLogging: true,
      enableAnalytics: true,
      enableCrashReporting: true,
      enablePerformanceMonitoring: true,
      apiTimeout: Duration(seconds: 30),
      maxRetryAttempts: 3,
      cacheValidityDuration: Duration(minutes: 15),
      enableMockData: false,
      enableDebugFeatures: true,
    ),
    Environment.production: EnvironmentData(
      name: 'Production',
      apiBaseUrl: 'https://api.globalserviceportal.com',
      apiVersion: 'v1',
      appName: 'Global Service Portal',
      enableLogging: false,
      enableAnalytics: true,
      enableCrashReporting: true,
      enablePerformanceMonitoring: true,
      apiTimeout: Duration(seconds: 25),
      maxRetryAttempts: 2,
      cacheValidityDuration: Duration(hours: 1),
      enableMockData: false,
      enableDebugFeatures: false,
    ),
  };

  /// Get current environment
  static Environment get currentEnvironment => _currentEnvironment;

  /// Get current environment configuration
  static EnvironmentData get current => _configs[_currentEnvironment]!;

  /// Check if current environment is development
  static bool get isDevelopment =>
      _currentEnvironment == Environment.development;

  /// Check if current environment is staging
  static bool get isStaging => _currentEnvironment == Environment.staging;

  /// Check if current environment is production
  static bool get isProduction => _currentEnvironment == Environment.production;

  /// Get environment name as string
  static String get environmentName => _currentEnvironment.name;

  /// Get complete API endpoint URL
  static String getApiEndpoint(String endpoint) {
    return '${current.apiBaseUrl}/${current.apiVersion}/$endpoint';
  }

  /// Check if feature is enabled for current environment
  static bool isFeatureEnabled(String featureName) {
    switch (featureName.toLowerCase()) {
      case 'logging':
        return current.enableLogging;
      case 'analytics':
        return current.enableAnalytics;
      case 'crashreporting':
        return current.enableCrashReporting;
      case 'performancemonitoring':
        return current.enablePerformanceMonitoring;
      case 'mockdata':
        return current.enableMockData;
      case 'debugfeatures':
        return current.enableDebugFeatures;
      default:
        return false;
    }
  }
}

/// Environment-specific configuration data
class EnvironmentData {
  final String name;
  final String apiBaseUrl;
  final String apiVersion;
  final String appName;
  final bool enableLogging;
  final bool enableAnalytics;
  final bool enableCrashReporting;
  final bool enablePerformanceMonitoring;
  final Duration apiTimeout;
  final int maxRetryAttempts;
  final Duration cacheValidityDuration;
  final bool enableMockData;
  final bool enableDebugFeatures;

  const EnvironmentData({
    required this.name,
    required this.apiBaseUrl,
    required this.apiVersion,
    required this.appName,
    required this.enableLogging,
    required this.enableAnalytics,
    required this.enableCrashReporting,
    required this.enablePerformanceMonitoring,
    required this.apiTimeout,
    required this.maxRetryAttempts,
    required this.cacheValidityDuration,
    required this.enableMockData,
    required this.enableDebugFeatures,
  });

  /// Convert to map for debugging purposes
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'apiBaseUrl': apiBaseUrl,
      'apiVersion': apiVersion,
      'appName': appName,
      'enableLogging': enableLogging,
      'enableAnalytics': enableAnalytics,
      'enableCrashReporting': enableCrashReporting,
      'enablePerformanceMonitoring': enablePerformanceMonitoring,
      'apiTimeoutMs': apiTimeout.inMilliseconds,
      'maxRetryAttempts': maxRetryAttempts,
      'cacheValidityMs': cacheValidityDuration.inMilliseconds,
      'enableMockData': enableMockData,
      'enableDebugFeatures': enableDebugFeatures,
    };
  }
}
