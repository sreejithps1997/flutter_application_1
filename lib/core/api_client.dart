// =============================================================================
// 4. lib/core/network/api_client.dart
// API Client for Global Service Portal
// =============================================================================

import 'package:dio/dio.dart';
import 'package:workable/core/network/dio_client.dart';
import 'errors/exceptions.dart';
import 'utils/logger.dart';
import 'services/analytics_service.dart';

/// Generic API response wrapper
class ApiResponse<T> {
  final T? data;
  final String? message;
  final bool success;
  final String? errorCode;
  final int? statusCode;

  const ApiResponse({
    this.data,
    this.message,
    this.success = true,
    this.errorCode,
    this.statusCode,
  });

  factory ApiResponse.success(T data, {String? message}) {
    return ApiResponse<T>(data: data, message: message, success: true);
  }

  factory ApiResponse.error(
    String message, {
    String? errorCode,
    int? statusCode,
  }) {
    return ApiResponse<T>(
      message: message,
      success: false,
      errorCode: errorCode,
      statusCode: statusCode,
    );
  }

  factory ApiResponse.fromJson(
    Map<String, dynamic> json,
    T Function(dynamic)? fromJson,
  ) {
    try {
      return ApiResponse<T>(
        data: fromJson != null ? fromJson(json['data']) : json['data'] as T?,
        message: json['message'] as String?,
        success: json['success'] as bool? ?? true,
        errorCode: json['error_code'] as String?,
        statusCode: json['status_code'] as int?,
      );
    } catch (e) {
      throw ServerException('Failed to parse API response: $e');
    }
  }
}

/// API client for making HTTP requests
class ApiClient {
  static final Dio _dio = DioClient.instance;

  // =============================================================================
  // GET REQUESTS
  // =============================================================================

  /// Make GET request
  static Future<ApiResponse<T>> get<T>(
    String endpoint, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    T Function(dynamic)? fromJson,
  }) async {
    try {
      final response = await AnalyticsService.trackApiCall(
        endpoint,
        () => _dio.get(
          endpoint,
          queryParameters: queryParameters,
          options: options,
        ),
      );

      return _handleResponse<T>(response, fromJson);
    } catch (e) {
      throw _handleError(e);
    }
  }

  /// Make GET request and return list
  static Future<ApiResponse<List<T>>> getList<T>(
    String endpoint, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    required T Function(Map<String, dynamic>) fromJson,
  }) async {
    try {
      final response = await AnalyticsService.trackApiCall(
        endpoint,
        () => _dio.get(
          endpoint,
          queryParameters: queryParameters,
          options: options,
        ),
      );

      return _handleListResponse<T>(response, fromJson);
    } catch (e) {
      throw _handleError(e);
    }
  }

  // =============================================================================
  // POST REQUESTS
  // =============================================================================

  /// Make POST request
  static Future<ApiResponse<T>> post<T>(
    String endpoint, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    T Function(dynamic)? fromJson,
  }) async {
    try {
      final response = await AnalyticsService.trackApiCall(
        endpoint,
        () => _dio.post(
          endpoint,
          data: data,
          queryParameters: queryParameters,
          options: options,
        ),
      );

      return _handleResponse<T>(response, fromJson);
    } catch (e) {
      throw _handleError(e);
    }
  }

  // =============================================================================
  // PUT REQUESTS
  // =============================================================================

  /// Make PUT request
  static Future<ApiResponse<T>> put<T>(
    String endpoint, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    T Function(dynamic)? fromJson,
  }) async {
    try {
      final response = await AnalyticsService.trackApiCall(
        endpoint,
        () => _dio.put(
          endpoint,
          data: data,
          queryParameters: queryParameters,
          options: options,
        ),
      );

      return _handleResponse<T>(response, fromJson);
    } catch (e) {
      throw _handleError(e);
    }
  }

  // =============================================================================
  // DELETE REQUESTS
  // =============================================================================

  /// Make DELETE request
  static Future<ApiResponse<T>> delete<T>(
    String endpoint, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    T Function(dynamic)? fromJson,
  }) async {
    try {
      final response = await AnalyticsService.trackApiCall(
        endpoint,
        () => _dio.delete(
          endpoint,
          data: data,
          queryParameters: queryParameters,
          options: options,
        ),
      );

      return _handleResponse<T>(response, fromJson);
    } catch (e) {
      throw _handleError(e);
    }
  }

  // =============================================================================
  // FILE UPLOAD
  // =============================================================================

  /// Upload file with progress tracking
  static Future<ApiResponse<T>> uploadFile<T>(
    String endpoint,
    String filePath,
    String fileName, {
    Map<String, dynamic>? additionalData,
    ProgressCallback? onSendProgress,
    T Function(dynamic)? fromJson,
  }) async {
    try {
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(filePath, filename: fileName),
        if (additionalData != null) ...additionalData,
      });

      final response = await AnalyticsService.trackApiCall(
        endpoint,
        () => _dio.post(
          endpoint,
          data: formData,
          onSendProgress: onSendProgress,
          options: Options(headers: {'Content-Type': 'multipart/form-data'}),
        ),
      );

      return _handleResponse<T>(response, fromJson);
    } catch (e) {
      throw _handleError(e);
    }
  }

  // =============================================================================
  // RESPONSE HANDLERS
  // =============================================================================

  /// Handle single item response
  static ApiResponse<T> _handleResponse<T>(
    Response response,
    T Function(dynamic)? fromJson,
  ) {
    try {
      if (response.statusCode == null ||
          response.statusCode! < 200 ||
          response.statusCode! >= 300) {
        throw ServerException('Invalid status code: ${response.statusCode}');
      }

      final data = response.data;

      if (data is Map<String, dynamic>) {
        return ApiResponse.fromJson(data, fromJson);
      } else {
        return ApiResponse.success(
          fromJson != null ? fromJson(data) : data as T,
        );
      }
    } catch (e) {
      AppLogger.error('Failed to handle response', e, null, 'ApiClient');
      throw ServerException('Failed to parse response: $e');
    }
  }

  /// Handle list response
  static ApiResponse<List<T>> _handleListResponse<T>(
    Response response,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    try {
      if (response.statusCode == null ||
          response.statusCode! < 200 ||
          response.statusCode! >= 300) {
        throw ServerException('Invalid status code: ${response.statusCode}');
      }

      final data = response.data;
      List<T> items = [];

      if (data is Map<String, dynamic>) {
        final listData = data['data'] as List?;
        if (listData != null) {
          items = listData
              .cast<Map<String, dynamic>>()
              .map((item) => fromJson(item))
              .toList();
        }

        return ApiResponse<List<T>>(
          data: items,
          message: data['message'] as String?,
          success: data['success'] as bool? ?? true,
        );
      } else if (data is List) {
        items = data
            .cast<Map<String, dynamic>>()
            .map((item) => fromJson(item))
            .toList();
        return ApiResponse.success(items);
      }

      return ApiResponse.success(items);
    } catch (e) {
      AppLogger.error('Failed to handle list response', e, null, 'ApiClient');
      throw ServerException('Failed to parse list response: $e');
    }
  }

  /// Handle API errors and convert to appropriate exceptions
  static Exception _handleError(dynamic error) {
    if (error is DioException) {
      switch (error.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          return const NetworkException(
            'Request timeout. Please check your connection and try again.',
          );

        case DioExceptionType.connectionError:
          return const NetworkException(
            'Unable to connect to server. Please check your internet connection.',
          );

        case DioExceptionType.badResponse:
          return _handleHttpError(error);

        case DioExceptionType.cancel:
          return const NetworkException('Request was cancelled');

        case DioExceptionType.unknown:
        default:
          return NetworkException('Network error occurred: ${error.message}');
      }
    }

    if (error is NetworkException ||
        error is ServerException ||
        error is AuthException ||
        error is ValidationException) {
      return error as Exception;
    }

    return ServerException('Unexpected error: ${error.toString()}');
  }

  /// Handle HTTP error responses
  static Exception _handleHttpError(DioException error) {
    final statusCode = error.response?.statusCode;
    final responseData = error.response?.data;

    String message = 'An error occurred';
    String? errorCode;

    if (responseData is Map<String, dynamic>) {
      message = responseData['message'] as String? ?? message;
      errorCode = responseData['error_code'] as String?;
    }

    switch (statusCode) {
      case 400:
        return ValidationException(message);
      case 401:
        return const AuthException(
          'Authentication failed. Please login again.',
        );
      case 403:
        return const AuthException(
          'Access denied. You do not have permission to perform this action.',
        );
      case 404:
        return ServerException('Resource not found');
      case 422:
        return ValidationException(message);
      case 429:
        return const ServerException(
          'Too many requests. Please try again later.',
        );
      case 500:
      case 502:
      case 503:
      case 504:
        return const ServerException(
          'Server error occurred. Please try again later.',
        );
      default:
        return ServerException('HTTP Error $statusCode: $message');
    }
  }
}
