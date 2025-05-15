import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';

class GeminiService {
  final String _apiKey = 'AIzaSyCINxH7z4_OB6heLS3Kzan-8Z_MEyNMT7s'; // Use your actual key
  final Logger _logger = Logger(); // Initialize the logger

  Future<String> sendMessage(String message) async {
    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1/models/gemini-2.0-flash-lite:generateContent?key=$_apiKey',
    );

    final body = {
      "contents": [
        {
          "role": "user",
          "parts": [
            {"text": message}
          ]
        }
      ]
    };

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final reply = data['candidates'][0]['content']['parts'][0]['text'];
        _logger.i('Gemini response: $reply'); // Log the successful response
        return reply;
      } else {
        _logger.e('Gemini error ${response.statusCode}: ${response.body}'); // Log the error response
        throw Exception('Gemini response error');
      }
    } catch (e) {
      _logger.e('Gemini error: $e'); // Log the exception
      throw Exception('Error: $e');
    }
  }
}
