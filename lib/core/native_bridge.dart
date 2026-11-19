import 'package:flutter/services.dart';

import 'config.dart';

/// A claim harvested from a nearby polling-node beacon.
///
/// The backend authorises exactly one of the claims the phone reports, so
/// the vote flow tries them strongest-first until one is accepted.
class BeaconClaim {
  final int beaconId;
  final String bootNonce;
  final int counter;
  final String mac;

  const BeaconClaim({
    required this.beaconId,
    required this.bootNonce,
    required this.counter,
    required this.mac,
  });

  Map<String, dynamic> toJson() => <String, dynamic>{
        'beaconId': beaconId,
        'bootNonce': bootNonce,
        'counter': counter,
        'mac': mac,
      };

  factory BeaconClaim.fromMap(Map<dynamic, dynamic> m) => BeaconClaim(
        beaconId: (m['beaconId'] as num?)?.toInt() ?? 0,
        bootNonce: m['bootNonce']?.toString() ?? '',
        counter: (m['counter'] as num?)?.toInt() ?? 0,
        mac: m['mac']?.toString() ?? '',
      );
}

/// Bluetooth state reported by the platform.
class BluetoothStatus {
  final bool on;
  final bool node;

  const BluetoothStatus({required this.on, required this.node});

  /// `off` = phone Bluetooth off, `on` = Bluetooth on, `node` = a polling
  /// node signal is in range.
  String get state => !on ? 'off' : (node ? 'node' : 'on');
}

/// Error thrown by [NativeBridge]; [code] mirrors the platform error codes
/// (`NO_APP`, `TIMEOUT`, `PERMISSION_DENIED`, `BLUETOOTH_OFF`, …).
class NativeException implements Exception {
  final String code;
  final String message;

  const NativeException(this.code, this.message);

  @override
  String toString() => message;
}

/// MethodChannel bridge to the Android native layer (Kotlin).
///
/// Implemented by `MainActivity.kt`; every method degrades to a
/// [NativeException] with code `NO_APP` when the native side is missing.
class NativeBridge {
  static const MethodChannel _channel =
      MethodChannel('${AppConfig.appId}/native');

  /// Scans for polling-node beacons for [timeoutMs] and returns up to three
  /// claims, strongest signal first.
  Future<List<BeaconClaim>> scan({int timeoutMs = 15000}) async {
    try {
      final result = await _channel.invokeMethod<List<dynamic>>(
          'scan', <String, dynamic>{'timeoutMs': timeoutMs});
      if (result == null) return <BeaconClaim>[];
      return result
          .whereType<Map>()
          .map((e) => BeaconClaim.fromMap(e))
          .toList();
    } on PlatformException catch (e) {
      throw NativeException(
          e.code, e.message ?? 'Bluetooth scan failed. Please try again.');
    } on MissingPluginException {
      throw const NativeException(
          'NO_APP', 'Presence verification needs the Election Android app.');
    }
  }

  Future<BluetoothStatus> bluetoothStatus() async {
    try {
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>(
          'bluetoothStatus');
      return BluetoothStatus(
        on: result?['on'] == true,
        node: result?['node'] == true,
      );
    } on PlatformException catch (e) {
      throw NativeException(e.code, e.message ?? 'Bluetooth status unavailable.');
    } on MissingPluginException {
      return const BluetoothStatus(on: false, node: false);
    }
  }

  /// Shows the system "turn on Bluetooth" prompt.
  Future<void> enableBluetooth() async {
    try {
      await _channel.invokeMethod<void>('enableBluetooth');
    } on PlatformException catch (e) {
      throw NativeException(e.code, e.message ?? 'Could not enable Bluetooth.');
    } on MissingPluginException {
      // Nothing to do outside Android.
    }
  }

  /// Opens the app's system settings page.
  Future<void> openSettings() async {
    try {
      await _channel.invokeMethod<void>('openSettings');
    } on PlatformException catch (e) {
      throw NativeException(e.code, e.message ?? 'Could not open settings.');
    } on MissingPluginException {
      // Nothing to do outside Android.
    }
  }

  /// Starts the background notification poller with a limited token.
  Future<void> notifyStart(String token, String apiBase) async {
    try {
      await _channel.invokeMethod<void>('notifyStart',
          <String, dynamic>{'token': token, 'apiBase': apiBase});
    } on PlatformException catch (e) {
      throw NativeException(e.code, e.message ?? 'Notifications unavailable.');
    } on MissingPluginException {
      // Nothing to do outside Android.
    }
  }

  /// Stops the background notification poller.
  Future<void> notifyStop() async {
    try {
      await _channel.invokeMethod<void>('notifyStop');
    } on PlatformException catch (e) {
      throw NativeException(e.code, e.message ?? 'Notifications unavailable.');
    } on MissingPluginException {
      // Nothing to do outside Android.
    }
  }
}
