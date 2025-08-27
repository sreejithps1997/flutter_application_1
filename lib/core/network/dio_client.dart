// =============================================================================
// 3. lib/core/network/dio_client.dart
// Dio HTTP Client Configuration for Global Service Portal
// =============================================================================

import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../config/environment.dart';
import '../constants/app_constants.dart';
import '../errors/exceptions.dart';
import '../utils/logger.dart';
import '../services/analytics_service.dart';

/// Custom Dio HTTP client with production-ready configurations
class DioClient {
  static Dio? _instance;
  static final Connectivity _connectivity = Connectivity();

  /// Get singleton instance of configured Dio client
  static Dio get instance {
    _instance ??= _createDioInstance();
    return _instance!;
  }

  /// Create and configure Dio instance
  static Dio _createDioInstance() {
    final dio = Dio();

    // Base configuration
    dio.options = BaseOptions(
      baseUrl: EnvironmentConfig.current.apiBaseUrl,
      connectTimeout: EnvironmentConfig.current.apiTimeout,
      receiveTimeout: EnvironmentConfig.current.apiTimeout,
      sendTimeout: EnvironmentConfig.current.apiTimeout,
      headers: _getDefaultHeaders(),
      responseType: ResponseType.json,
      contentType: Headers.jsonContentType,
    );

    // Add interceptors
    _addInterceptors(dio);

    return dio;
  }

  /// Get default headers for all requests
  static Map<String, dynamic> _getDefaultHeaders() {
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'User-Agent': '${AppConstants.appName}/${AppConstants.appVersion}',
      'X-Client-Platform': Platform.isIOS ? 'iOS' : 'Android',
      'X-Client-Version': AppConstants.appVersion,
      'X-Environment': EnvironmentConfig.environmentName,
    };
  }

  /// Add interceptors to Dio instance
  static void _addInterceptors(Dio dio) {
    // Request interceptor
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: _onRequest,
        onResponse: _onResponse,
        onError: _onError,
      ),
    );

    // Logging interceptor (only in development)
    if (EnvironmentConfig.current.enableLogging) {
      dio.interceptors.add(
        LogInterceptor(
          requestBody: true,
          responseBody: true,
          requestHeader: true,
          responseHeader: false,
          error: true,
          logPrint: (obj) => AppLogger.debug(obj.toString(), 'DioClient'),
        ),
      );
    }

    // Retry interceptor
    dio.interceptors.add(_RetryInterceptor());
  }

  /// Handle request interceptor
  static void _onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    try {
      // Check connectivity
      final connectivityResult = await _connectivity.checkConnectivity();
      if (connectivityResult == ConnectivityResult.none) {
        throw const NetworkException('No internet connection');
      }

      // Add authentication token if available
      await _addAuthToken(options);

      // Log request
      AppLogger.debug(
        'Making ${options.method} request to ${options.path}',
        'DioClient',
      );

      handler.next(options);
    } catch (e) {
      handler.reject(
        DioException(
          requestOptions: options,
          error: e,
          type: DioExceptionType.unknown,
        ),
      );
    }
  }

  /// Handle response interceptor
  static void _onResponse(
    Response response,
    ResponseInterceptorHandler handler,
  ) {
    AppLogger.debug(
      'Response received: ${response.statusCode} for ${response.requestOptions.path}',
      'DioClient',
    );

    // Track successful API call
    AnalyticsService.trackEvent(
      'api_success',
      parameters: {
        'endpoint': response.requestOptions.path,
        'method': response.requestOptions.method,
        'status_code': response.statusCode,
      },
    );

    handler.next(response);
  }

  /// Handle error interceptor
  static void _onError(DioException error, ErrorInterceptorHandler handler) {
    final statusCode = error.response?.statusCode;
    final endpoint = error.requestOptions.path;

    AppLogger.error(
      'API Error: $statusCode for $endpoint',
      error,
      error.stackTrace,
      'DioClient',
    );

    // Track API error
    AnalyticsService.trackEvent(
      'api_error',
      parameters: {
        'endpoint': endpoint,
        'method': error.requestOptions.method,
        'status_code': statusCode,
        'error_type': error.type.name,
      },
    );

    // Record error for crashlytics
    AnalyticsService.recordError(
      error,
      error.stackTrace,
      reason: 'API Error: $statusCode',
      context: {
        'endpoint': endpoint,
        'method': error.requestOptions.method,
        'status_code': statusCode,
      },
    );

    handler.next(error);
  }

  /// Add authentication token to request headers
  static Future<void> _addAuthToken(RequestOptions options) async {
    try {
      // This would typically get the token from secure storage
      // For now, we'll add a placeholder
      final token = await _getAuthToken();
      if (token != null) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    } catch (e) {
      AppLogger.warning('Failed to add auth token: $e', 'DioClient');
    }
  }

  /// Get authentication token from storage
  static Future<String?> _getAuthToken() async {
    // TODO: Implement actual token retrieval from secure storage
    // This is a placeholder implementation
    return null;
  }

  /// Update authentication token
  static void setAuthToken(String? token) {
    if (token != null) {
      instance.options.headers['Authorization'] = 'Bearer $token';
    } else {
      instance.options.headers.remove('Authorization');
    }
  }

  /// Clear authentication token
  static void clearAuthToken() {
    instance.options.headers.remove('Authorization');
  }

  /// Update base URL (useful for switching environments)
  static void updateBaseUrl(String baseUrl) {
    instance.options.baseUrl = baseUrl;
  }
}

/// Retry interceptor for handling network failures
class _RetryInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (_shouldRetry(err)) {
      try {
        final response = await _retry(err.requestOptions);
        handler.resolve(response);
        return;
      } catch (e) {
        AppLogger.error('Retry failed', e, null, 'RetryInterceptor');
      }
    }
    handler.next(err);
  }

  /// Check if request should be retried
  bool _shouldRetry(DioException err) {
    // Retry on network errors, timeouts, and 5xx server errors
    return err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.receiveTimeout ||
        err.type == DioExceptionType.sendTimeout ||
        err.type == DioExceptionType.connectionError ||
        (err.response?.statusCode != null && err.response!.statusCode! >= 500);
  }

  /// Retry the request with exponential backoff
  Future<Response> _retry(RequestOptions requestOptions) async {
    final maxRetries = EnvironmentConfig.current.maxRetryAttempts;

    for (int i = 0; i < maxRetries; i++) {
      try {
        // Exponential backoff delay
        if (i > 0) {
          final delay = Duration(milliseconds: 1000 * (i * 2));
          await Future.delayed(delay);
        }

        AppLogger.debug(
          'Retrying request (attempt ${i + 1}/$maxRetries)',
          'RetryInterceptor',
        );

        return await DioClient.instance.fetch(requestOptions);
      } catch (e) {
        if (i == maxRetries - 1) rethrow;
        AppLogger.warning(
          'Retry attempt ${i + 1} failed: $e',
          'RetryInterceptor',
        );
      }
    }

    throw Exception('Max retry attempts exceeded');
  }
}
