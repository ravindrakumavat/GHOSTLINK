import 'package:battery_plus/battery_plus.dart';

class BatteryHelper {
  static final Battery _battery = Battery();

  static Future<int> getBatteryPercentage() async {
    return await _battery.batteryLevel;
  }
}