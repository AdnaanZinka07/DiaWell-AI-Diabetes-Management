import 'dart:convert';

import 'package:http/http.dart' as http;

class AiApiService {
  static const String _baseUrl = 'http://127.0.0.1:8001';

  Future<Map<String, dynamic>> predictRisk({
    required num pregnancies,
    required num glucose,
    required num bloodPressure,
    required num skinThickness,
    required num insulin,
    required num bmi,
    required num diabetesPedigreeFunction,
    required num age,
  }) async {
    return _post('/predict-risk', {
      'pregnancies': pregnancies,
      'glucose': glucose,
      'blood_pressure': bloodPressure,
      'skin_thickness': skinThickness,
      'insulin': insulin,
      'bmi': bmi,
      'diabetes_pedigree_function': diabetesPedigreeFunction,
      'age': age,
    });
  }

  Future<Map<String, dynamic>> predictGlucose({
    required List<num> glucoseReadings,
  }) async {
    return _post('/predict-glucose', {'glucose_readings': glucoseReadings});
  }

  Future<Map<String, dynamic>> detectAnomaly({
    required num glucose,
    required num previousGlucose,
  }) async {
    return _post('/detect-anomaly', {
      'glucose': glucose,
      'previous_glucose': previousGlucose,
    });
  }

  Future<Map<String, dynamic>> _post(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    final url = Uri.parse('$_baseUrl$endpoint');
    final encodedBody = jsonEncode(body);

    // ignore: avoid_print
    print('[AiApiService] POST $url');
    // ignore: avoid_print
    print('[AiApiService] Request body: $encodedBody');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: encodedBody,
      );

      // ignore: avoid_print
      print('[AiApiService] Response status: ${response.statusCode}');
      // ignore: avoid_print
      print('[AiApiService] Response body: ${response.body}');

      final decodedBody =
          response.body.isEmpty
              ? <String, dynamic>{}
              : jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return decodedBody;
      }

      return {
        'error': true,
        'statusCode': response.statusCode,
        'message': decodedBody['detail'] ?? 'Request failed',
        'details': decodedBody,
      };
    } catch (error, stackTrace) {
      // ignore: avoid_print
      print('[AiApiService] Exception type: ${error.runtimeType}');
      // ignore: avoid_print
      print('[AiApiService] Exception message: $error');
      // ignore: avoid_print
      print('[AiApiService] Stack trace: $stackTrace');
      return {
        'error': true,
        'message': 'Unable to connect to DiaWell-AI backend ($url): $error',
        'details': error.toString(),
      };
    }
  }
}
