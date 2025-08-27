// =============================================================================
// 5. lib/core/network/network_info.dart
// Network Information Service for Global Service Portal
// =============================================================================

import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../utils/logger.dart';
import '../services/analytics_service.dart';

/// Network connection types
enum NetworkType { wifi, mobile, ethernet, none, unknown }

/// Network information data class
class NetworkInfo {
  final bool isConnected;
  final NetworkType type;
  final String? ssid;
  final String? bssid;
  final int? signalStrength;
  final bool isExpensive;
  final DateTime lastChecked;

  const NetworkInfo({
    required this.isConnected,
    required this.type,
    this.ssid,
    this.bssid,
    this.signalStrength,
    this.isExpensive = false,
    required this.lastChecked,
  });

  NetworkInfo copyWith({
    bool? isConnected,
    NetworkType? type,
    String? ssid,
    String? bssid,
    int? signalStrength,
    bool? isExpensive,
    DateTime? lastChecked,
  }) {
    return NetworkInfo(
      isConnected: isConnected ?? this.isConnected,
      type: type ?? this.type,
      ssid: ssid ?? this.ssid,
      bssid: bssid ?? this.bssid,
      signalStrength: signalStrength ?? this.signalStrength,
      isExpensive: isExpensive ?? this.isExpensive,
      lastChecked: lastChecked ?? this.lastChecked,
    );
  }

  /// Convert to map for analytics
  Map<String, dynamic> toMap() {
    return {
      'isConnected': isConnected,
      'type': type.name,
      'isExpensive': isExpensive,
      'hasWifi': type == NetworkType.wifi,
      'hasMobile': type == NetworkType.mobile,
      'lastChecked': lastChecked.millisecondsSinceEpoch,
    };
  }
}

/// Network information service
class NetworkInfoService {
  static final Connectivity _connectivity = Connectivity();
  static StreamController<NetworkInfo>? _networkController;
  static NetworkInfo? _currentNetworkInfo;
  static Timer? _periodicCheck;

  /// Get current network information
  static NetworkInfo? get currentNetworkInfo => _currentNetworkInfo;

  /// Stream of network status changes
  static Stream<NetworkInfo> get networkStream {
    _networkController ??= StreamController<NetworkInfo>.broadcast();
    return _networkController!.stream;
  }

  /// Initialize network monitoring
  static Future<void> initialize() async {
    try {
      // Get initial network status
      await _updateNetworkInfo();

      // Listen to connectivity changes - FIXED: List<ConnectivityResult>
      _connectivity.onConnectivityChanged.listen(_onConnectivityChanged);

      // Start periodic network checks
      _startPeriodicChecks();

      AppLogger.info('Network info service initialized', 'NetworkInfoService');
    } catch (e, stackTrace) {
      AppLogger.error(
        'Failed to initialize network info service',
        e,
        stackTrace,
        'NetworkInfoService',
      );
      try {
        await AnalyticsService.recordError(
          e,
          stackTrace,
          reason: 'Network service initialization failed',
        );
      } catch (_) {
        AppLogger.warning(
          'Analytics not available for error recording',
          'NetworkInfoService',
        );
      }
    }
  }

  /// Check if device is connected to internet
  static Future<bool> isConnected() async {
    try {
      await _updateNetworkInfo();
      return _currentNetworkInfo?.isConnected ?? false;
    } catch (e) {
      AppLogger.error(
        'Failed to check connectivity',
        e,
        null,
        'NetworkInfoService',
      );
      return false;
    }
  }

  /// Check if device has WiFi connection
  static bool hasWifiConnection() {
    return _currentNetworkInfo?.type == NetworkType.wifi;
  }

  /// Check if device has mobile connection
  static bool hasMobileConnection() {
    return _currentNetworkInfo?.type == NetworkType.mobile;
  }

  /// Check if connection is expensive (mobile data)
  static bool isExpensiveConnection() {
    return _currentNetworkInfo?.isExpensive ?? false;
  }

  /// Test internet connectivity with actual network request
  static Future<bool> testInternetConnectivity() async {
    try {
      final List<InternetAddress> result = await InternetAddress.lookup(
        'google.com',
      );
      final bool isConnected =
          result.isNotEmpty && result[0].rawAddress.isNotEmpty;

      try {
        await AnalyticsService.trackEvent(
          'connectivity_test',
          parameters: {
            'success': isConnected,
            'network_type': _currentNetworkInfo?.type.name ?? 'unknown',
          },
        );
      } catch (_) {
        AppLogger.warning(
          'Analytics not available for event tracking',
          'NetworkInfoService',
        );
      }

      return isConnected;
    } catch (e) {
      AppLogger.warning(
        'Internet connectivity test failed: $e',
        'NetworkInfoService',
      );

      try {
        await AnalyticsService.trackEvent(
          'connectivity_test',
          parameters: {'success': false, 'error': e.toString()},
        );
      } catch (_) {
        AppLogger.warning(
          'Analytics not available for error tracking',
          'NetworkInfoService',
        );
      }

      return false;
    }
  }

  /// Get network quality assessment
  static NetworkQuality getNetworkQuality() {
    final NetworkInfo? networkInfo = _currentNetworkInfo;
    if (networkInfo == null || !networkInfo.isConnected) {
      return NetworkQuality.none;
    }

    switch (networkInfo.type) {
      case NetworkType.wifi:
        final int signalStrength = networkInfo.signalStrength ?? 0;
        if (signalStrength > -50) return NetworkQuality.excellent;
        if (signalStrength > -60) return NetworkQuality.good;
        if (signalStrength > -70) return NetworkQuality.fair;
        return NetworkQuality.poor;

      case NetworkType.mobile:
        return NetworkQuality.good;

      case NetworkType.ethernet:
        return NetworkQuality.excellent;

      default:
        return NetworkQuality.unknown;
    }
  }

  /// FIXED: Handle connectivity changes with List<ConnectivityResult>
  static void _onConnectivityChanged(List<ConnectivityResult> results) async {
    final ConnectivityResult result = results.isNotEmpty
        ? results.first
        : ConnectivityResult.none;

    await _updateNetworkInfo(result);

    AppLogger.info(
      'Network connectivity changed: ${_currentNetworkInfo?.type.name}',
      'NetworkInfoService',
    );

    try {
      await AnalyticsService.trackEvent(
        'connectivity_changed',
        parameters: _currentNetworkInfo?.toMap(),
      );
    } catch (_) {
      AppLogger.warning(
        'Analytics not available for connectivity change tracking',
        'NetworkInfoService',
      );
    }
  }

  /// Update network information
  static Future<void> _updateNetworkInfo([
    ConnectivityResult? givenResult,
  ]) async {
    try {
      final ConnectivityResult connectivityResult;
      if (givenResult != null) {
        connectivityResult = givenResult;
      } else {
        final results = await _connectivity.checkConnectivity();
        connectivityResult = results.isNotEmpty
            ? results.first
            : ConnectivityResult.none;
      }

      final NetworkType networkType = _mapConnectivityResult(
        connectivityResult,
      );
      final bool isConnected = networkType != NetworkType.none;

      String? ssid;
      String? bssid;
      if (networkType == NetworkType.wifi) {
        ssid = null;
        bssid = null;
        AppLogger.info(
          'WiFi connection detected (details not available due to platform restrictions)',
          'NetworkInfoService',
        );
      }

      final NetworkInfo networkInfo = NetworkInfo(
        isConnected: isConnected,
        type: networkType,
        ssid: ssid,
        bssid: bssid,
        isExpensive: networkType == NetworkType.mobile,
        lastChecked: DateTime.now(),
      );

      _currentNetworkInfo = networkInfo;
      _networkController?.add(networkInfo);
    } catch (e, stackTrace) {
      AppLogger.error(
        'Failed to update network info',
        e,
        stackTrace,
        'NetworkInfoService',
      );

      _currentNetworkInfo = NetworkInfo(
        isConnected: false,
        type: NetworkType.unknown,
        lastChecked: DateTime.now(),
      );
      _networkController?.add(_currentNetworkInfo!);
    }
  }

  /// Map ConnectivityResult to NetworkType
  static NetworkType _mapConnectivityResult(ConnectivityResult result) {
    switch (result) {
      case ConnectivityResult.wifi:
        return NetworkType.wifi;
      case ConnectivityResult.mobile:
        return NetworkType.mobile;
      case ConnectivityResult.ethernet:
        return NetworkType.ethernet;
      case ConnectivityResult.none:
        return NetworkType.none;
      default:
        return NetworkType.unknown;
    }
  }

  /// Start periodic network checks
  static void _startPeriodicChecks() {
    _periodicCheck?.cancel();
    _periodicCheck = Timer.periodic(const Duration(minutes: 1), (Timer timer) {
      _updateNetworkInfo();
    });
  }

  /// Dispose resources
  static void dispose() {
    _periodicCheck?.cancel();
    _networkController?.close();
    _networkController = null;
    _currentNetworkInfo = null;
  }
}

/// Network quality levels
enum NetworkQuality { none, poor, fair, good, excellent, unknown }

/// Riverpod providers for network information
final Provider<NetworkInfoService> networkInfoServiceProvider =
    Provider<NetworkInfoService>((ProviderRef<NetworkInfoService> ref) {
      return NetworkInfoService();
    });

final StreamProvider<NetworkInfo> networkInfoProvider =
    StreamProvider<NetworkInfo>((StreamProviderRef<NetworkInfo> ref) {
      return NetworkInfoService.networkStream;
    });

final Provider<bool> isConnectedProvider = Provider<bool>((
  ProviderRef<bool> ref,
) {
  final AsyncValue<NetworkInfo> networkInfo = ref.watch(networkInfoProvider);
  return networkInfo.when(
    data: (NetworkInfo info) => info.isConnected,
    loading: () => false,
    error: (_, __) => false,
  );
});
