
import 'dart:convert';
import 'package:http/http.dart' as http;

class Esp32SensorData {
  final double? temperature;
  final double? humidity;
  final bool? soilWet;
  final String soilStatus;
  final bool wifiConnected;

  const Esp32SensorData({
    required this.temperature,
    required this.humidity,
    required this.soilWet,
    required this.soilStatus,
    required this.wifiConnected,
  });

  factory Esp32SensorData.fromJson(Map<String, dynamic> json) {
    return Esp32SensorData(
      temperature: (json['temperature'] as num?)?.toDouble(),
      humidity: (json['humidity'] as num?)?.toDouble(),
      soilWet: json['soil_wet'] as bool?,
      soilStatus: (json['soil_status'] ?? 'UNKNOWN').toString(),
      wifiConnected: json['wifi_connected'] == true,
    );
  }
}

class Esp32SensorRepository {
  static Future<Esp32SensorData> getReadings(String baseUrl) async {
    final base = baseUrl.trim().replaceFirst(RegExp(r'/+$'), '');

    final response = await http
        .get(Uri.parse('$base/api/sensors'))
        .timeout(const Duration(seconds: 4));

    if (response.statusCode != 200) {
      throw Exception('ESP32 returned HTTP ${response.statusCode}');
    }

    final decoded = jsonDecode(response.body);

    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Invalid ESP32 sensor response');
    }

    return Esp32SensorData.fromJson(decoded);
  }
}
