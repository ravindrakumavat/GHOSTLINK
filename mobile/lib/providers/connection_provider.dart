import 'package:flutter/foundation.dart';

/// Placeholder connection state consumed by the Home screen's
/// Connection Status Card. Real mesh/Bluetooth connectivity via
/// Nearby Connections is implemented in a later phase - this provider
/// only exposes the shape the UI needs today, with no live logic
/// behind it.
class ConnectionProvider extends ChangeNotifier {
  final bool _isConnected = false;
  final int _nearbyDeviceCount = 0;

  bool get isConnected => _isConnected;
  int get nearbyDeviceCount => _nearbyDeviceCount;
}
