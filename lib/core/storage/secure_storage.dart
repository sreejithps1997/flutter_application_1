// =============================================================================
// FIXED: Secure Storage Service Configuration
// lib/core/storage/secure_storage.dart
// =============================================================================

import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/app_constants.dart';
import '../utils/logger.dart';
import '../services/analytics_service.dart';

/// Secure storage service for sensitive data
class SecureStorageService {
  // FIXED: Corrected configuration without invalid parameters
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
      sharedPreferencesName: 'global_service_portal_secure',
      // Removed resetOnError - not available in AndroidOptions
    ),
    iOptions: IOSOptions(
      // FIXED: Changed IOSAccessibility to KeychainAccessibility
      accessibility: KeychainAccessibility.first_unlock_this_device,
      groupId: 'group.com.globalservice.portal',
    ),
    lOptions: LinuxOptions(
      // Removed resetOnError - not available in LinuxOptions
    ),
    wOptions: WindowsOptions(
      // Removed resetOnError - not available in WindowsOptions
    ),
    mOptions: MacOsOptions(
      // FIXED: Changed IOSAccessibility to KeychainAccessibility
      accessibility: KeychainAccessibility.first_unlock_this_device,
      groupId: 'group.com.globalservice.portal',
    ),
  );

  static bool _isInitialized = false;

  /// Secure storage keys
  static const String _authTokenKey = 'auth_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _biometricTokenKey = 'biometric_token';
  static const String _encryptionKeyKey = 'encryption_key';
  static const String _userCredentialsKey = 'user_credentials';
  static const String _pinCodeKey = 'pin_code';
  static const String _fingerprintDataKey = 'fingerprint_data';
  static const String _deviceIdKey = 'device_id';
  static const String _apiKeysPrefix = 'api_key_';

  /// Initialize secure storage with proper error handling
  static Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Test secure storage availability
      await _secureStorage.containsKey(key: 'test_key');

      _isInitialized = true;
      AppLogger.info('Secure storage initialized', 'SecureStorageService');

      await AnalyticsService.trackEvent('secure_storage_initialized');
    } catch (e, stackTrace) {
      AppLogger.error(
        'Failed to initialize secure storage',
        e,
        stackTrace,
        'SecureStorageService',
      );
      await AnalyticsService.recordError(
        e,
        stackTrace,
        reason: 'Secure storage initialization failed',
      );
      rethrow;
    }
  }

  /// Ensure secure storage is initialized
  static Future<void> _ensureInitialized() async {
    if (!_isInitialized) {
      await initialize();
    }
  }

  // Rest of your methods remain the same...
  // [Include all the other methods from your original file]

  /// Write secure data
  static Future<bool> write(String key, String value) async {
    try {
      await _ensureInitialized();
      await _secureStorage.write(key: key, value: value);
      AppLogger.debug('Secure data written: $key', 'SecureStorageService');
      return true;
    } catch (e, stackTrace) {
      AppLogger.error(
        'Failed to write secure data: $key',
        e,
        stackTrace,
        'SecureStorageService',
      );
      await AnalyticsService.recordError(
        e,
        stackTrace,
        reason: 'Secure storage write failed',
        context: {'key': key},
      );
      return false;
    }
  }

  /// Read secure data
  static Future<String?> read(String key) async {
    try {
      await _ensureInitialized();
      final value = await _secureStorage.read(key: key);
      AppLogger.debug('Secure data read: $key', 'SecureStorageService');
      return value;
    } catch (e, stackTrace) {
      AppLogger.error(
        'Failed to read secure data: $key',
        e,
        stackTrace,
        'SecureStorageService',
      );
      return null;
    }
  }

  /// Delete secure data
  static Future<bool> delete(String key) async {
    try {
      await _ensureInitialized();
      await _secureStorage.delete(key: key);
      AppLogger.debug('Secure data deleted: $key', 'SecureStorageService');
      return true;
    } catch (e, stackTrace) {
      AppLogger.error(
        'Failed to delete secure data: $key',
        e,
        stackTrace,
        'SecureStorageService',
      );
      return false;
    }
  }

  /// Check if key exists
  static Future<bool> containsKey(String key) async {
    try {
      await _ensureInitialized();
      return await _secureStorage.containsKey(key: key);
    } catch (e, stackTrace) {
      AppLogger.error(
        'Failed to check key existence: $key',
        e,
        stackTrace,
        'SecureStorageService',
      );
      return false;
    }
  }

  /// Get all keys
  static Future<Set<String>> getAllKeys() async {
    try {
      await _ensureInitialized();
      final allData = await _secureStorage.readAll();
      return allData.keys.toSet();
    } catch (e, stackTrace) {
      AppLogger.error(
        'Failed to get all keys',
        e,
        stackTrace,
        'SecureStorageService',
      );
      return <String>{};
    }
  }

  /// Clear all secure data
  static Future<bool> deleteAll() async {
    try {
      await _ensureInitialized();
      await _secureStorage.deleteAll();
      AppLogger.info('All secure data cleared', 'SecureStorageService');

      await AnalyticsService.trackEvent('secure_storage_cleared');
      return true;
    } catch (e, stackTrace) {
      AppLogger.error(
        'Failed to clear all secure data',
        e,
        stackTrace,
        'SecureStorageService',
      );
      return false;
    }
  }

  // Authentication methods
  static Future<bool> saveAuthToken(String token) async {
    return await write(_authTokenKey, token);
  }

  static Future<String?> getAuthToken() async {
    return await read(_authTokenKey);
  }

  static Future<bool> removeAuthToken() async {
    return await delete(_authTokenKey);
  }

  /// Save refresh token
  static Future<bool> saveRefreshToken(String refreshToken) async {
    return await write(_refreshTokenKey, refreshToken);
  }

  /// Get refresh token
  static Future<String?> getRefreshToken() async {
    return await read(_refreshTokenKey);
  }

  /// Remove refresh token
  static Future<bool> removeRefreshToken() async {
    return await delete(_refreshTokenKey);
  }

  /// Save biometric authentication token
  static Future<bool> saveBiometricToken(String token) async {
    return await write(_biometricTokenKey, token);
  }

  /// Get biometric authentication token
  static Future<String?> getBiometricToken() async {
    return await read(_biometricTokenKey);
  }

  /// Remove biometric authentication token
  static Future<bool> removeBiometricToken() async {
    return await delete(_biometricTokenKey);
  }

  /// Save user credentials (encrypted)
  static Future<bool> saveUserCredentials({
    required String email,
    required String encryptedPassword,
  }) async {
    try {
      final credentials = {
        'email': email,
        'password': encryptedPassword,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };

      final credentialsJson = jsonEncode(credentials);
      return await write(_userCredentialsKey, credentialsJson);
    } catch (e, stackTrace) {
      AppLogger.error(
        'Failed to save user credentials',
        e,
        stackTrace,
        'SecureStorageService',
      );
      return false;
    }
  }

  /// Get user credentials
  static Future<Map<String, dynamic>?> getUserCredentials() async {
    try {
      final credentialsJson = await read(_userCredentialsKey);
      if (credentialsJson == null) return null;

      return jsonDecode(credentialsJson) as Map<String, dynamic>;
    } catch (e, stackTrace) {
      AppLogger.error(
        'Failed to get user credentials',
        e,
        stackTrace,
        'SecureStorageService',
      );
      return null;
    }
  }

  /// Remove user credentials
  static Future<bool> removeUserCredentials() async {
    return await delete(_userCredentialsKey);
  }

  /// Save PIN code (hashed)
  static Future<bool> savePinCode(String pinCode) async {
    try {
      final hashedPin = _hashString(pinCode);
      return await write(_pinCodeKey, hashedPin);
    } catch (e, stackTrace) {
      AppLogger.error(
        'Failed to save PIN code',
        e,
        stackTrace,
        'SecureStorageService',
      );
      return false;
    }
  }

  /// Verify PIN code
  static Future<bool> verifyPinCode(String pinCode) async {
    try {
      final storedHashedPin = await read(_pinCodeKey);
      if (storedHashedPin == null) return false;

      final hashedPin = _hashString(pinCode);
      return hashedPin == storedHashedPin;
    } catch (e, stackTrace) {
      AppLogger.error(
        'Failed to verify PIN code',
        e,
        stackTrace,
        'SecureStorageService',
      );
      return false;
    }
  }

  /// Remove PIN code
  static Future<bool> removePinCode() async {
    return await delete(_pinCodeKey);
  }

  /// Check if PIN code is set
  static Future<bool> hasPinCode() async {
    return await containsKey(_pinCodeKey);
  }

  /// Save device ID
  static Future<bool> saveDeviceId(String deviceId) async {
    return await write(_deviceIdKey, deviceId);
  }

  /// Get device ID
  static Future<String?> getDeviceId() async {
    return await read(_deviceIdKey);
  }

  /// Generate and save device ID if not exists
  static Future<String> getOrCreateDeviceId() async {
    String? deviceId = await getDeviceId();

    if (deviceId == null) {
      deviceId = _generateDeviceId();
      await saveDeviceId(deviceId);
      AppLogger.info('Generated new device ID', 'SecureStorageService');
    }

    return deviceId;
  }

  /// Generate unique device ID
  static String _generateDeviceId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = DateTime.now().microsecondsSinceEpoch;
    final input = '${AppConstants.appName}_${timestamp}_$random';
    return _hashString(input);
  }

  /// Save encryption key
  static Future<bool> saveEncryptionKey(String key) async {
    return await write(_encryptionKeyKey, key);
  }

  /// Get encryption key
  static Future<String?> getEncryptionKey() async {
    return await read(_encryptionKeyKey);
  }

  /// Generate and save encryption key if not exists
  static Future<String> getOrCreateEncryptionKey() async {
    String? encryptionKey = await getEncryptionKey();

    if (encryptionKey == null) {
      encryptionKey = _generateEncryptionKey();
      await saveEncryptionKey(encryptionKey);
      AppLogger.info('Generated new encryption key', 'SecureStorageService');
    }

    return encryptionKey;
  }

  /// Generate random encryption key
  static String _generateEncryptionKey() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = DateTime.now().microsecondsSinceEpoch;
    final input = 'encryption_key_${timestamp}_$random';
    return _hashString(input);
  }

  /// Hash string using SHA-256
  static String _hashString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Save API key for specific service
  static Future<bool> saveApiKey(String serviceName, String apiKey) async {
    return await write('$_apiKeysPrefix$serviceName', apiKey);
  }

  /// Get API key for specific service
  static Future<String?> getApiKey(String serviceName) async {
    return await read('$_apiKeysPrefix$serviceName');
  }

  /// Remove API key for specific service
  static Future<bool> removeApiKey(String serviceName) async {
    return await delete('$_apiKeysPrefix$serviceName');
  }

  /// Save session data
  static Future<bool> saveSessionData(Map<String, dynamic> sessionData) async {
    try {
      final sessionJson = jsonEncode(sessionData);
      return await write('session_data', sessionJson);
    } catch (e, stackTrace) {
      AppLogger.error(
        'Failed to save session data',
        e,
        stackTrace,
        'SecureStorageService',
      );
      return false;
    }
  }

  /// Get session data
  static Future<Map<String, dynamic>?> getSessionData() async {
    try {
      final sessionJson = await read('session_data');
      if (sessionJson == null) return null;

      return jsonDecode(sessionJson) as Map<String, dynamic>;
    } catch (e, stackTrace) {
      AppLogger.error(
        'Failed to get session data',
        e,
        stackTrace,
        'SecureStorageService',
      );
      return null;
    }
  }

  /// Clear session data
  static Future<bool> clearSessionData() async {
    return await delete('session_data');
  }

  /// Clear all authentication related data
  static Future<bool> clearAuthData() async {
    try {
      final results = await Future.wait([
        removeAuthToken(),
        removeRefreshToken(),
        removeBiometricToken(),
        removeUserCredentials(),
        clearSessionData(),
      ]);

      final success = results.every((result) => result);

      if (success) {
        AppLogger.info('All auth data cleared', 'SecureStorageService');
        await AnalyticsService.trackEvent('auth_data_cleared');
      }

      return success;
    } catch (e, stackTrace) {
      AppLogger.error(
        'Failed to clear auth data',
        e,
        stackTrace,
        'SecureStorageService',
      );
      return false;
    }
  }
}

// Riverpod providers
final secureStorageServiceProvider = Provider<SecureStorageService>((ref) {
  return SecureStorageService();
});

final authTokenProvider = FutureProvider<String?>((ref) async {
  return await SecureStorageService.getAuthToken();
});

final isAuthenticatedProvider = FutureProvider<bool>((ref) async {
  final token = await SecureStorageService.getAuthToken();
  return token != null && token.isNotEmpty;
});
