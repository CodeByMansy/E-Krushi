import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'models.dart';

class PredictionApi {
  // Replace this example IP with your laptop's IPv4 address.
  static const String baseUrl = 'http://192.168.1.156:5000';

  static Future<PredictionResult> predictDisease(File image) async {
    final client = http.Client();

    try {
      final response = await (() async {
        final request = http.MultipartRequest(
          'POST',
          Uri.parse('$baseUrl/predict'),
        );

        request.files.add(
          await http.MultipartFile.fromPath(
            'image',
            image.path,
          ),
        );

        final streamedResponse = await client.send(request);
        return http.Response.fromStream(streamedResponse);
      })().timeout(const Duration(seconds: 60));

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode != 200) {
        throw Exception(data['error'] ?? 'Prediction failed.');
      }

      return PredictionResult(
        disease: data['disease'] as String,
        confidence: (data['confidence'] as num).toDouble(),
        description: data['description'] as String,
        treatment: data['treatment'] as String,
        severity: data['severity'] as String,
      );
    } finally {
      client.close();
    }
  }
}