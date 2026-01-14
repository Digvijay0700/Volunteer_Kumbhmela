import 'package:flutter/services.dart';

class VolunteerGattService {
  static const MethodChannel _channel =
      MethodChannel('volunteer_gatt_channel');

  static Future<void> startListening(
      Function(double, double) onLocation) async {

    _channel.setMethodCallHandler((call) async {
      if (call.method == "onLocation") {
        onLocation(
          call.arguments["lat"],
          call.arguments["lng"],
        );
      }
    });

    await _channel.invokeMethod("startListening");
  }
}
