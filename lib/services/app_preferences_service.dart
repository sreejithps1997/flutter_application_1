import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppPreferencesService {
  static const _themeModeKey = 'theme_mode';
  static const _notificationsKey = 'settings_notifications';
  static const _soundKey = 'settings_sound';
  static const _locationKey = 'settings_location';
  static const _biometricKey = 'settings_biometric';
  static const _autoLockKey = 'settings_auto_lock';
  static const _dataUsageKey = 'settings_data_usage';
  static const _offlineModeKey = 'settings_offline_mode';
  static const _highContrastKey = 'settings_high_contrast';
  static const _autoUpdateKey = 'settings_auto_update';
  static const _languageKey = 'settings_language';
  static const _fontSizeKey = 'settings_font_size';
  static const _quickPayKey = 'payment_quick_pay';
  static const _autoPayKey = 'payment_auto_pay';
  static const _biometricPaymentsKey = 'payment_biometric';

  static final ValueNotifier<ThemeMode> themeMode = ValueNotifier<ThemeMode>(
    ThemeMode.light,
  );
  static final ValueNotifier<int> accessibilityVersion = ValueNotifier<int>(0);

  static SharedPreferences? _prefs;

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    themeMode.value = _themeModeFromName(
      _prefs?.getString(_themeModeKey) ?? 'light',
    );
  }

  static bool getBool(String key, {required bool fallback}) {
    return _prefs?.getBool(key) ?? fallback;
  }

  static String getString(String key, {required String fallback}) {
    return _prefs?.getString(key) ?? fallback;
  }

  static Future<void> setBool(String key, bool value) async {
    await _prefs?.setBool(key, value);
    if (key == _highContrastKey) {
      accessibilityVersion.value++;
    }
  }

  static Future<void> setString(String key, String value) async {
    await _prefs?.setString(key, value);
    if (key == _fontSizeKey) {
      accessibilityVersion.value++;
    }
  }

  static bool get notifications => getBool(_notificationsKey, fallback: true);
  static bool get soundEnabled => getBool(_soundKey, fallback: true);
  static bool get locationServices => getBool(_locationKey, fallback: true);
  static bool get biometricLogin => getBool(_biometricKey, fallback: true);
  static bool get autoLock => getBool(_autoLockKey, fallback: true);
  static bool get offlineMode => getBool(_offlineModeKey, fallback: false);
  static bool get highContrast => getBool(_highContrastKey, fallback: false);
  static bool get autoUpdate => getBool(_autoUpdateKey, fallback: true);
  static bool get quickPay => getBool(_quickPayKey, fallback: true);
  static bool get autoPay => getBool(_autoPayKey, fallback: false);
  static bool get biometricPayments =>
      getBool(_biometricPaymentsKey, fallback: true);
  static String get dataUsage =>
      getString(_dataUsageKey, fallback: 'WiFi Only');
  static String get language =>
      getString(_languageKey, fallback: 'English (India)');
  static String get fontSize => getString(_fontSizeKey, fallback: 'Medium');

  static double get textScaleFactor {
    switch (fontSize) {
      case 'Small':
        return 0.92;
      case 'Large':
        return 1.14;
      default:
        return 1.0;
    }
  }

  static Future<void> setThemeMode(ThemeMode value) async {
    themeMode.value = value;
    await setString(_themeModeKey, value.name);
  }

  static Future<void> resetSettings() async {
    await setThemeMode(ThemeMode.light);
    await setBool(_notificationsKey, true);
    await setBool(_soundKey, true);
    await setBool(_locationKey, true);
    await setBool(_biometricKey, true);
    await setBool(_autoLockKey, true);
    await setString(_dataUsageKey, 'WiFi Only');
    await setBool(_offlineModeKey, false);
    await setBool(_highContrastKey, false);
    await setBool(_autoUpdateKey, true);
    await setBool(_quickPayKey, true);
    await setBool(_autoPayKey, false);
    await setBool(_biometricPaymentsKey, true);
    await setString(_languageKey, 'English (India)');
    await setString(_fontSizeKey, 'Medium');
  }

  static Future<void> setNotifications(bool value) =>
      setBool(_notificationsKey, value);
  static Future<void> setSoundEnabled(bool value) => setBool(_soundKey, value);
  static Future<void> setLocationServices(bool value) =>
      setBool(_locationKey, value);
  static Future<void> setBiometricLogin(bool value) =>
      setBool(_biometricKey, value);
  static Future<void> setAutoLock(bool value) => setBool(_autoLockKey, value);
  static Future<void> setDataUsage(String value) =>
      setString(_dataUsageKey, value);
  static Future<void> setOfflineMode(bool value) =>
      setBool(_offlineModeKey, value);
  static Future<void> setHighContrast(bool value) =>
      setBool(_highContrastKey, value);
  static Future<void> setAutoUpdate(bool value) =>
      setBool(_autoUpdateKey, value);
  static Future<void> setLanguage(String value) =>
      setString(_languageKey, value);
  static Future<void> setFontSize(String value) =>
      setString(_fontSizeKey, value);
  static Future<void> setQuickPay(bool value) => setBool(_quickPayKey, value);
  static Future<void> setAutoPay(bool value) => setBool(_autoPayKey, value);
  static Future<void> setBiometricPayments(bool value) =>
      setBool(_biometricPaymentsKey, value);

  static ThemeMode _themeModeFromName(String value) {
    switch (value) {
      case 'dark':
        return ThemeMode.dark;
      case 'system':
        return ThemeMode.system;
      default:
        return ThemeMode.light;
    }
  }
}
