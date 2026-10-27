import 'package:flutter_blue_plus/flutter_blue_plus.dart';

/// Represents a canonical discovered ResQMesh peer node in the local BLE peer registry.
class BlePeerNode {
  BluetoothDevice device;
  final String deviceId;
  String name;
  int rssi;
  DateTime lastSeen;
  bool isAvailable;
  int successCount;
  int failureCount;
  DateTime? lastAttempt;
  DateTime? lastSuccess;
  bool isConnecting;

  BlePeerNode({
    required this.device,
    required String deviceId,
    required this.name,
    required this.rssi,
    required this.lastSeen,
    this.isAvailable = true,
    this.successCount = 0,
    this.failureCount = 0,
    this.lastAttempt,
    this.lastSuccess,
    this.isConnecting = false,
  }) : deviceId = normalizeId(deviceId);

  /// Normalizes device identifiers (MAC address or UUID) to a canonical uppercase string.
  static String normalizeId(String rawId) {
    return rawId.trim().toUpperCase();
  }

  /// Bounded backoff duration based on consecutive failure count:
  /// 0 failures: 0s (immediate)
  /// 1 failure: 2s
  /// 2 failures: 5s
  /// 3+ failures: 10s
  Duration get backoffDuration {
    switch (failureCount) {
      case 0:
        return Duration.zero;
      case 1:
        return const Duration(seconds: 2);
      case 2:
        return const Duration(seconds: 5);
      default:
        return const Duration(seconds: 10);
    }
  }

  /// Whether this peer is ready for a transmission attempt (not in backoff).
  bool get isReadyForAttempt {
    if (isConnecting) return false;
    if (!isAvailable) return false;
    if (lastAttempt == null) return true;
    return DateTime.now().difference(lastAttempt!) >= backoffDuration;
  }

  void recordAttempt() {
    lastAttempt = DateTime.now();
  }

  void recordSuccess() {
    successCount++;
    failureCount = 0;
    lastSuccess = DateTime.now();
    isConnecting = false;
    isAvailable = true;
  }

  void recordFailure() {
    failureCount++;
    isConnecting = false;
  }
}
