// =============================================================================
// 6. lib/core/storage/local_storage.dart
// Local Storage Service for Global Service Portal
// =============================================================================

import 'dart:convert';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/app_constants.dart';
import '../utils/logger.dart';
import '../services/analytics_service.dart';

/// Local storage service using Hive and SharedPreferences
class LocalStorageService {
  static SharedPreferences? _prefs;
  static Box? _hiveBox;
  static bool _isInitialized = false;

  /// Box names for different data types
  static const String _mainBoxName = 'app_data';
  static const String _cacheBoxName = 'cache_data';
  static const String _userBoxName = 'user_data';

  /// Initialize local storage
  static Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Initialize Hive
      await Hive.initFlutter();

      // Open Hive boxes
      _hiveBox = await Hive.openBox(_mainBoxName);

      // Initialize SharedPreferences
      _prefs = await SharedPreferences.getInstance();

      _isInitialized = true;
      AppLogger.info('Local storage initialized', 'LocalStorageService');

      // Track initialization
      await AnalyticsService.trackEvent('local_storage_initialized');
    } catch (e, stackTrace) {
      AppLogger.error(
        'Failed to initialize local storage',
        e,
        stackTrace,
        'LocalStorageService',
      );
      await AnalyticsService.recordError(
        e,
        stackTrace,
        reason: 'Local storage initialization failed',
      );
      rethrow;
    }
  }

  /// Ensure storage is initialized
  static Future<void> _ensureInitialized() async {
    if (!_isInitialized) {
      await initialize();
    }
  }

  // =============================================================================
  // SHARED PREFERENCES METHODS (for simple key-value storage)
  // =============================================================================

  /// Save string value
  static Future<bool> setString(String key, String value) async {
    try {
      await _ensureInitialized();
      final result = await _prefs!.setString(key, value);
      AppLogger.debug('Saved string: $key', 'LocalStorageService');
      return result;
    } catch (e, stackTrace) {
      AppLogger.error(
        'Failed to save string: $key',
        e,
        stackTrace,
        'LocalStorageService',
      );
      return false;
    }
  }

  /// Get string value
  static Future<String?> getString(String key, {String? defaultValue}) async {
    try {
      await _ensureInitialized();
      final value = _prefs!.getString(key) ?? defaultValue;
      AppLogger.debug('Retrieved string: $key = $value', 'LocalStorageService');
      return value;
    } catch (e, stackTrace) {
      AppLogger.error(
        'Failed to get string: $key',
        e,
        stackTrace,
        'LocalStorageService',
      );
      return defaultValue;
    }
  }

  /// Save boolean value
  static Future<bool> setBool(String key, bool value) async {
    try {
      await _ensureInitialized();
      final result = await _prefs!.setBool(key, value);
      AppLogger.debug('Saved bool: $key = $value', 'LocalStorageService');
      return result;
    } catch (e, stackTrace) {
      AppLogger.error(
        'Failed to save bool: $key',
        e,
        stackTrace,
        'LocalStorageService',
      );
      return false;
    }
  }

  /// Get boolean value
  static Future<bool> getBool(String key, {bool defaultValue = false}) async {
    try {
      await _ensureInitialized();
      final value = _prefs!.getBool(key) ?? defaultValue;
      AppLogger.debug('Retrieved bool: $key = $value', 'LocalStorageService');
      return value;
    } catch (e, stackTrace) {
      AppLogger.error(
        'Failed to get bool: $key',
        e,
        stackTrace,
        'LocalStorageService',
      );
      return defaultValue;
    }
  }

  /// Save integer value
  static Future<bool> setInt(String key, int value) async {
    try {
      await _ensureInitialized();
      final result = await _prefs!.setInt(key, value);
      AppLogger.debug('Saved int: $key = $value', 'LocalStorageService');
      return result;
    } catch (e, stackTrace) {
      AppLogger.error(
        'Failed to save int: $key',
        e,
        stackTrace,
        'LocalStorageService',
      );
      return false;
    }
  }

  /// Get integer value
  static Future<int> getInt(String key, {int defaultValue = 0}) async {
    try {
      await _ensureInitialized();
      final value = _prefs!.getInt(key) ?? defaultValue;
      AppLogger.debug('Retrieved int: $key = $value', 'LocalStorageService');
      return value;
    } catch (e, stackTrace) {
      AppLogger.error(
        'Failed to get int: $key',
        e,
        stackTrace,
        'LocalStorageService',
      );
      return defaultValue;
    }
  }

  /// Save double value
  static Future<bool> setDouble(String key, double value) async {
    try {
      await _ensureInitialized();
      final result = await _prefs!.setDouble(key, value);
      AppLogger.debug('Saved double: $key = $value', 'LocalStorageService');
      return result;
    } catch (e, stackTrace) {
      AppLogger.error(
        'Failed to save double: $key',
        e,
        stackTrace,
        'LocalStorageService',
      );
      return false;
    }
  }

  /// Get double value
  static Future<double> getDouble(
    String key, {
    double defaultValue = 0.0,
  }) async {
    try {
      await _ensureInitialized();
      final value = _prefs!.getDouble(key) ?? defaultValue;
      AppLogger.debug('Retrieved double: $key = $value', 'LocalStorageService');
      return value;
    } catch (e, stackTrace) {
      AppLogger.error(
        'Failed to get double: $key',
        e,
        stackTrace,
        'LocalStorageService',
      );
      return defaultValue;
    }
  }

  /// Save string list
  static Future<bool> setStringList(String key, List<String> value) async {
    try {
      await _ensureInitialized();
      final result = await _prefs!.setStringList(key, value);
      AppLogger.debug(
        'Saved string list: $key (${value.length} items)',
        'LocalStorageService',
      );
      return result;
    } catch (e, stackTrace) {
      AppLogger.error(
        'Failed to save string list: $key',
        e,
        stackTrace,
        'LocalStorageService',
      );
      return false;
    }
  }

  /// Get string list
  static Future<List<String>> getStringList(
    String key, {
    List<String>? defaultValue,
  }) async {
    try {
      await _ensureInitialized();
      final value = _prefs!.getStringList(key) ?? defaultValue ?? [];
      AppLogger.debug(
        'Retrieved string list: $key (${value.length} items)',
        'LocalStorageService',
      );
      return value;
    } catch (e, stackTrace) {
      AppLogger.error(
        'Failed to get string list: $key',
        e,
        stackTrace,
        'LocalStorageService',
      );
      return defaultValue ?? [];
    }
  }

  // =============================================================================
  // HIVE METHODS (for complex object storage)
  // =============================================================================

  /// Save object to Hive
  static Future<bool> saveObject(String key, dynamic value) async {
    try {
      await _ensureInitialized();
      await _hiveBox!.put(key, value);
      AppLogger.debug('Saved object: $key', 'LocalStorageService');
      return true;
    } catch (e, stackTrace) {
      AppLogger.error(
        'Failed to save object: $key',
        e,
        stackTrace,
        'LocalStorageService',
      );
      return false;
    }
  }

  /// Get object from Hive
  static Future<T?> getObject<T>(String key, {T? defaultValue}) async {
    try {
      await _ensureInitialized();
      final value = _hiveBox!.get(key, defaultValue: defaultValue) as T?;
      AppLogger.debug('Retrieved object: $key', 'LocalStorageService');
      return value;
    } catch (e, stackTrace) {
      AppLogger.error(
        'Failed to get object: $key',
        e,
        stackTrace,
        'LocalStorageService',
      );
      return defaultValue;
    }
  }

  /// Save JSON object
  static Future<bool> saveJson(String key, Map<String, dynamic> json) async {
    try {
      final jsonString = jsonEncode(json);
      return await saveObject(key, jsonString);
    } catch (e, stackTrace) {
      AppLogger.error(
        'Failed to save JSON: $key',
        e,
        stackTrace,
        'LocalStorageService',
      );
      return false;
    }
  }

  /// Get JSON object
  static Future<Map<String, dynamic>?> getJson(String key) async {
    try {
      final jsonString = await getObject<String>(key);
      if (jsonString == null) return null;

      return jsonDecode(jsonString) as Map<String, dynamic>;
    } catch (e, stackTrace) {
      AppLogger.error(
        'Failed to get JSON: $key',
        e,
        stackTrace,
        'LocalStorageService',
      );
      return null;
    }
  }

  /// Save list of objects
  static Future<bool> saveList(String key, List<dynamic> list) async {
    try {
      await _ensureInitialized();
      await _hiveBox!.put(key, list);
      AppLogger.debug(
        'Saved list: $key (${list.length} items)',
        'LocalStorageService',
      );
      return true;
    } catch (e, stackTrace) {
      AppLogger.error(
        'Failed to save list: $key',
        e,
        stackTrace,
        'LocalStorageService',
      );
      return false;
    }
  }

  /// Get list of objects
  static Future<List<T>> getList<T>(String key, {List<T>? defaultValue}) async {
    try {
      await _ensureInitialized();
      final value =
          _hiveBox!.get(key, defaultValue: defaultValue ?? []) as List;
      final typedList = value.cast<T>();
      AppLogger.debug(
        'Retrieved list: $key (${typedList.length} items)',
        'LocalStorageService',
      );
      return typedList;
    } catch (e, stackTrace) {
      AppLogger.error(
        'Failed to get list: $key',
        e,
        stackTrace,
        'LocalStorageService',
      );
      return defaultValue ?? [];
    }
  }

  // =============================================================================
  // CACHE MANAGEMENT
  // =============================================================================

  /// Save cache data with expiration
  static Future<bool> saveCache(
    String key,
    dynamic data, {
    Duration? expiration,
  }) async {
    try {
      final cacheData = {
        'data': data,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'expiration': expiration?.inMilliseconds,
      };

      return await saveObject('cache_$key', cacheData);
    } catch (e, stackTrace) {
      AppLogger.error(
        'Failed to save cache: $key',
        e,
        stackTrace,
        'LocalStorageService',
      );
      return false;
    }
  }

  /// Get cache data if not expired
  static Future<T?> getCache<T>(String key) async {
    try {
      final cacheData = await getObject<Map>('cache_$key');
      if (cacheData == null) return null;

      final timestamp = cacheData['timestamp'] as int?;
      final expiration = cacheData['expiration'] as int?;

      if (timestamp != null && expiration != null) {
        final now = DateTime.now().millisecondsSinceEpoch;
        final expiryTime = timestamp + expiration;

        if (now > expiryTime) {
          await removeCache(key);
          return null;
        }
      }

      return cacheData['data'] as T?;
    } catch (e, stackTrace) {
      AppLogger.error(
        'Failed to get cache: $key',
        e,
        stackTrace,
        'LocalStorageService',
      );
      return null;
    }
  }

  /// Remove cache data
  static Future<bool> removeCache(String key) async {
    try {
      await _ensureInitialized();
      await _hiveBox!.delete('cache_$key');
      AppLogger.debug('Removed cache: $key', 'LocalStorageService');
      return true;
    } catch (e, stackTrace) {
      AppLogger.error(
        'Failed to remove cache: $key',
        e,
        stackTrace,
        'LocalStorageService',
      );
      return false;
    }
  }

  /// Clear all cache data
  static Future<bool> clearCache() async {
    try {
      await _ensureInitialized();
      final keys = _hiveBox!.keys
          .where((key) => key.toString().startsWith('cache_'))
          .toList();

      for (final key in keys) {
        await _hiveBox!.delete(key);
      }

      AppLogger.info(
        'Cleared all cache data (${keys.length} items)',
        'LocalStorageService',
      );
      await AnalyticsService.trackEvent(
        'cache_cleared',
        parameters: {'items_count': keys.length},
      );

      return true;
    } catch (e, stackTrace) {
      AppLogger.error(
        'Failed to clear cache',
        e,
        stackTrace,
        'LocalStorageService',
      );
      return false;
    }
  }

  // =============================================================================
  // USER DATA METHODS
  // =============================================================================

  /// Save user authentication token
  static Future<bool> saveUserToken(String token) async {
    return await setString(AppConstants.userTokenKey, token);
  }

  /// Get user authentication token
  static Future<String?> getUserToken() async {
    return await getString(AppConstants.userTokenKey);
  }

  /// Remove user authentication token
  static Future<bool> removeUserToken() async {
    try {
      await _ensureInitialized();
      return await _prefs!.remove(AppConstants.userTokenKey);
    } catch (e, stackTrace) {
      AppLogger.error(
        'Failed to remove user token',
        e,
        stackTrace,
        'LocalStorageService',
      );
      return false;
    }
  }

  /// Save user type
  static Future<bool> saveUserType(String userType) async {
    return await setString(AppConstants.userTypeKey, userType);
  }

  /// Get user type
  static Future<String?> getUserType() async {
    return await getString(AppConstants.userTypeKey);
  }

  /// Save user data
  static Future<bool> saveUserData(Map<String, dynamic> userData) async {
    return await saveJson(AppConstants.userDataKey, userData);
  }

  /// Get user data
  static Future<Map<String, dynamic>?> getUserData() async {
    return await getJson(AppConstants.userDataKey);
  }

  /// Check if user is first time
  static Future<bool> isFirstTime() async {
    return await getBool(AppConstants.isFirstTimeKey, defaultValue: true);
  }

  /// Set first time flag
  static Future<bool> setFirstTime(bool isFirstTime) async {
    return await setBool(AppConstants.isFirstTimeKey, isFirstTime);
  }

  // =============================================================================
  // UTILITY METHODS
  // =============================================================================

  /// Check if key exists
  static Future<bool> hasKey(String key) async {
    try {
      await _ensureInitialized();
      return _prefs!.containsKey(key) || _hiveBox!.containsKey(key);
    } catch (e) {
      return false;
    }
  }

  /// Remove key from storage
  static Future<bool> remove(String key) async {
    try {
      await _ensureInitialized();
      final prefsResult = await _prefs!.remove(key);
      await _hiveBox!.delete(key);
      AppLogger.debug('Removed key: $key', 'LocalStorageService');
      return prefsResult;
    } catch (e, stackTrace) {
      AppLogger.error(
        'Failed to remove key: $key',
        e,
        stackTrace,
        'LocalStorageService',
      );
      return false;
    }
  }

  /// Clear all data from storage
  static Future<bool> clearAll() async {
    try {
      await _ensureInitialized();
      await _prefs!.clear();
      await _hiveBox!.clear();
      AppLogger.info('Cleared all local storage data', 'LocalStorageService');

      await AnalyticsService.trackEvent('local_storage_cleared');
      return true;
    } catch (e, stackTrace) {
      AppLogger.error(
        'Failed to clear all data',
        e,
        stackTrace,
        'LocalStorageService',
      );
      return false;
    }
  }

  /// Get storage size information
  static Future<Map<String, int>> getStorageInfo() async {
    try {
      await _ensureInitialized();

      final prefsKeys = _prefs!.getKeys();
      final hiveKeys = _hiveBox!.keys;

      return {
        'shared_prefs_keys': prefsKeys.length,
        'hive_keys': hiveKeys.length,
        'total_keys': prefsKeys.length + hiveKeys.length,
      };
    } catch (e, stackTrace) {
      AppLogger.error(
        'Failed to get storage info',
        e,
        stackTrace,
        'LocalStorageService',
      );
      return {'shared_prefs_keys': 0, 'hive_keys': 0, 'total_keys': 0};
    }
  }

  /// Close storage connections
  static Future<void> dispose() async {
    try {
      await _hiveBox?.close();
      _hiveBox = null;
      _prefs = null;
      _isInitialized = false;
      AppLogger.info('Local storage disposed', 'LocalStorageService');
    } catch (e, stackTrace) {
      AppLogger.error(
        'Failed to dispose local storage',
        e,
        stackTrace,
        'LocalStorageService',
      );
    }
  }
}

/// Riverpod providers for local storage
final localStorageServiceProvider = Provider<LocalStorageService>((ref) {
  return LocalStorageService();
});
