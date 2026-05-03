import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import '../core/constants/api_keys.dart';

/// Service that talks to the Google Gemini 2.0 Flash REST API.
/// Maintains full conversation history for multi-turn context.
class GeminiService {
  static const String _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent';

  // System instruction sent before every conversation.
  static const String _systemPrompt =
      'You are a helpful US mortgage and personal finance assistant built into a mobile app called "USA Mortgage Pro". '
      'Keep your answers concise (3-5 sentences max unless a list is needed), practical, and professional. '
      'Focus on topics like mortgages, home buying, DTI, auto loans, credit cards, PITI, and interest rates. '
      'If asked about something unrelated to finance or mortgages, politely redirect the conversation. '
      'Never give personalised legal or tax advice — always suggest consulting a licensed professional for specific situations.';

  /// Sends [userMessage] to Gemini with the full [history] for context.
  /// [history] is a list of maps with keys "role" ('user' | 'model') and "text".
  /// Returns the assistant's reply as a plain string.
  Future<String> chat({
    required List<Map<String, String>> history,
    required String userMessage,
  }) async {
    final url = Uri.parse('$_baseUrl?key=$kGeminiApiKey');

    // Build content array: system prompt first, then full history, then new message
    final List<Map<String, dynamic>> contents = [
      {
        'role': 'user',
        'parts': [
          {'text': _systemPrompt},
        ],
      },
      {
        'role': 'model',
        'parts': [
          {
            'text':
                'Understood. I am your USA Mortgage Pro AI assistant, ready to help with mortgage and finance questions.',
          },
        ],
      },
      // Previous conversation turns
      ...history.map(
        (msg) => {
          'role': msg['role'] == 'assistant' ? 'model' : 'user',
          'parts': [
            {'text': msg['text']},
          ],
        },
      ),
      // New user message
      {
        'role': 'user',
        'parts': [
          {'text': userMessage},
        ],
      },
    ];

    int retryCount = 0;
    const int maxRetries = 3;

    while (retryCount < maxRetries) {
      try {
        final response = await http
            .post(
              url,
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({'contents': contents}),
            )
            .timeout(const Duration(seconds: 30));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          final candidates = data['candidates'] as List<dynamic>?;
          if (candidates != null && candidates.isNotEmpty) {
            final parts = candidates[0]['content']['parts'] as List<dynamic>?;
            if (parts != null && parts.isNotEmpty) {
              return (parts[0]['text'] as String).trim();
            }
          }
          return 'Sorry, I received an empty response. Please try again.';
        } else if (response.statusCode == 429) {
          // Rate limit - wait and retry
          retryCount++;
          if (retryCount < maxRetries) {
            // Wait 2s, then 4s, then 6s
            await Future.delayed(Duration(seconds: 2 * retryCount));
            continue;
          }
          return 'The AI service is currently very busy (Rate Limit). Please wait a moment and try again.';
        } else if (response.statusCode == 400) {
          return 'Invalid request. Please check your API key in api_keys.dart.';
        } else if (response.statusCode == 403) {
          return 'API key is invalid or expired. Please update api_keys.dart with a valid key.';
        } else {
          return 'An error occurred (${response.statusCode}). Please try again later.';
        }
      } catch (e) {
        if (e is http.ClientException || e is TimeoutException) {
          retryCount++;
          if (retryCount < maxRetries) {
            await Future.delayed(Duration(seconds: retryCount));
            continue;
          }
        }
        return 'Connection error. Please check your internet and try again.';
      }
    }
    return 'Could not connect to AI service. Please try again later.';
  }
}
