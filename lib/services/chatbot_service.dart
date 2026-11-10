import 'dart:convert';
import 'package:http/http.dart' as http;

class ChatbotService {
  static const String _baseUrl = String.fromEnvironment(
    'DIAWELL_API_BASE_URL',
    defaultValue: 'http://127.0.0.1:8001',
  );

  Future<String> getChatbotResponse(String userMessage) async {
    final response = await http
        .post(
          Uri.parse('$_baseUrl/chat'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'message': userMessage}),
        )
        .timeout(const Duration(seconds: 45));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return data['reply'] as String;
    }
    if (response.statusCode == 503) {
      return 'The chatbot is not configured. Please contact the project administrator.';
    }
    return "Sorry, I couldn't fetch the response. Please try again.";
  }
}
