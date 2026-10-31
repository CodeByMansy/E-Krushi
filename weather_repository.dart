// Ported from data/WeatherResponse.kt + WeatherApi.kt + WeatherRepository.kt
// Original used Retrofit + Gson hitting api.open-meteo.com/v1/forecast.
// Flutter version uses the `http` package directly against the same endpoint.

import 'dart:convert';
import 'package:http/http.dart' as http;

class CurrentWeather {
  final double temperature;
  final int humidity;
  final double windSpeed;
  final double precipitation;

  const CurrentWeather({
    required this.temperature,
    required this.humidity,
    required this.windSpeed,
    required this.precipitation,
  });

  factory CurrentWeather.fromJson(Map<String, dynamic> json) {
    return CurrentWeather(
      temperature: (json['temperature_2m'] as num).toDouble(),
      humidity: (json['relative_humidity_2m'] as num).toInt(),
      windSpeed: (json['wind_speed_10m'] as num).toDouble(),
      precipitation: (json['precipitation'] as num).toDouble(),
    );
  }
}

class WeatherRepository {
  WeatherRepository._();

  static const String _baseUrl = 'https://api.open-meteo.com/v1/forecast';

  static Future<CurrentWeather> getWeather({
    required double latitude,
    required double longitude,
  }) async {
    final uri = Uri.parse(_baseUrl).replace(queryParameters: {
      'latitude': latitude.toString(),
      'longitude': longitude.toString(),
      'current': 'temperature_2m,relative_humidity_2m,wind_speed_10m,precipitation',
      'timezone': 'auto',
    });

    final response = await http.get(uri);

    if (response.statusCode != 200) {
      throw Exception('Weather request failed (${response.statusCode})');
    }

    final Map<String, dynamic> body = jsonDecode(response.body) as Map<String, dynamic>;
    return CurrentWeather.fromJson(body['current'] as Map<String, dynamic>);
  }
}
