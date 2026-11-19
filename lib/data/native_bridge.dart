import 'package:flutter/services.dart';

class DeviceConfig {
  final String baseUrl;
  final int deviceId;
  final String deviceSecret;
  const DeviceConfig(this.baseUrl, this.deviceId, this.deviceSecret);
}

class NativeHealth {
  final int pending;
  final int lastSmsAtMs; // 0 = never
  final int lastSyncOkAtMs; // 0 = never
  final int lastSyncErrorAtMs;
  final String lastSyncError;
  final int uploadedTotal;
  final Map<String, int> lastSmsByProvider;
  const NativeHealth({
    this.pending = 0,
    this.lastSmsAtMs = 0,
    this.lastSyncOkAtMs = 0,
    this.lastSyncErrorAtMs = 0,
    this.lastSyncError = '',
    this.uploadedTotal = 0,
    this.lastSmsByProvider = const {},
  });
}

/// Thin wrapper over the Android MethodChannel. All secrets live natively in
/// EncryptedSharedPreferences (Android Keystore backed).
class NativeBridge {
  static const _ch = MethodChannel('store.adverune.aps/device');

  Future<void> saveConfig(String baseUrl, int deviceId, String secret) =>
      _ch.invokeMethod('saveConfig', {'baseUrl': baseUrl, 'deviceId': deviceId, 'deviceSecret': secret});

  Future<DeviceConfig?> loadConfig() async {
    final m = await _ch.invokeMapMethod<String, dynamic>('loadConfig');
    if (m == null) return null;
    return DeviceConfig(m['baseUrl'] as String, (m['deviceId'] as num).toInt(), m['deviceSecret'] as String);
  }

  Future<void> clearConfig() => _ch.invokeMethod('clearConfig');
  Future<void> syncNow() => _ch.invokeMethod('syncNow');

  Future<void> setGatewayEnabled(String provider, bool enabled) =>
      _ch.invokeMethod('setGatewayEnabled', {'provider': provider, 'enabled': enabled});

  Future<Map<String, bool>> gatewayEnabled() async {
    final m = await _ch.invokeMapMethod<String, dynamic>('gatewayEnabled') ?? {};
    return m.map((k, v) => MapEntry(k, v == true));
  }

  Future<NativeHealth> health() async {
    final m = await _ch.invokeMapMethod<String, dynamic>('health') ?? {};
    final by = <String, int>{};
    final raw = m['lastSmsByProvider'];
    if (raw is Map) {
      raw.forEach((k, v) => by[k.toString()] = (v as num).toInt());
    }
    return NativeHealth(
      pending: (m['pending'] as num?)?.toInt() ?? 0,
      lastSmsAtMs: (m['lastSmsAt'] as num?)?.toInt() ?? 0,
      lastSyncOkAtMs: (m['lastSyncOkAt'] as num?)?.toInt() ?? 0,
      lastSyncErrorAtMs: (m['lastSyncErrorAt'] as num?)?.toInt() ?? 0,
      lastSyncError: (m['lastSyncError'] as String?) ?? '',
      uploadedTotal: (m['uploadedTotal'] as num?)?.toInt() ?? 0,
      lastSmsByProvider: by,
    );
  }

  Future<bool> isIgnoringBatteryOptimizations() async =>
      (await _ch.invokeMethod<bool>('isIgnoringBatteryOptimizations')) ?? false;

  Future<void> openBatterySettings() => _ch.invokeMethod('openBatterySettings');
}
