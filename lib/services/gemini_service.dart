import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../core/constants/api_keys.dart';

/// Which provider answered (useful for debug badges in UI).
enum AiProvider { gemini, groq, none }

/// Wraps the assistant reply with metadata.
class ChatResult {
  final String text;
  final AiProvider provider;
  final bool isError;

  const ChatResult({
    required this.text,
    required this.provider,
    this.isError = false,
  });
}

/// Drop-in replacement for GeminiService.
/// Primary  → Gemini 2.0 Flash Lite  (high free quota)
/// Fallback → Groq llama-3.3-70b     (generous free tier, ~14 k req/day)
///
/// Fallback triggers:
///   • HTTP 429  — rate limited  (Gemini enters 60 s cooldown)
///   • HTTP 500+ — server error
///   • Timeout   — no reply in 30 s
///   • Network exception
class GeminiService {
  // ── Gemini ────────────────────────────────────────────────────────────────
  static const String _geminiUrl =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash-lite:generateContent';

  // ── Groq (OpenAI-compatible) ───────────────────────────────────────────────
  static const String _groqUrl =
      'https://api.groq.com/openai/v1/chat/completions';
  static const String _groqModel = 'llama-3.3-70b-versatile';

  // ── Shared system prompt ───────────────────────────────────────────────────
  static const String _systemPrompt =
      'You are a helpful US mortgage and personal finance assistant built into a '
      'mobile app called "Mortgage Calculator - PITI, DTI". '
      'Keep your answers concise (3-5 sentences max unless a list is needed), '
      'practical, and professional. '
      'Focus on topics like mortgages, home buying, DTI, auto loans, credit '
      'cards, PITI, and interest rates. '
      'If asked about something unrelated to finance or mortgages, politely '
      'redirect the conversation. '
      'Never give personalised legal or tax advice — always suggest consulting '
      'a licensed professional for specific situations.';

  // ── Cooldown state ─────────────────────────────────────────────────────────
  DateTime? _geminiCooldownUntil;
  bool get _geminiOnCooldown =>
      _geminiCooldownUntil != null &&
      DateTime.now().isBefore(_geminiCooldownUntil!);

  // ── Public API (same signature as original GeminiService) ─────────────────

  /// Returns a plain [String] — keeps full backward-compatibility with
  /// any existing call-sites that used the old GeminiService.chat().
  Future<String> chat({
    required List<Map<String, String>> history,
    required String userMessage,
  }) async {
    final result = await chatWithMeta(
      history: history,
      userMessage: userMessage,
    );
    return result.text;
  }

  /// Same as [chat] but also returns which provider answered and whether
  /// it was an error — useful for showing a provider badge in the UI.
  Future<ChatResult> chatWithMeta({
    required List<Map<String, String>> history,
    required String userMessage,
  }) async {
    if (!_geminiOnCooldown) {
      final geminiResult = await _tryGemini(
        history: history,
        userMessage: userMessage,
      );
      if (geminiResult != null) return geminiResult;
    }

    // Fallback → Groq
    return _tryGroq(history: history, userMessage: userMessage);
  }

  // ── Gemini ─────────────────────────────────────────────────────────────────

  Future<ChatResult?> _tryGemini({
    required List<Map<String, String>> history,
    required String userMessage,
  }) async {
    final url = Uri.parse('$_geminiUrl?key=$kGeminiApiKey');

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
                'Understood. I am your Mortgage Calculator - PITI, DTI AI assistant, '
                'ready to help with mortgage and finance questions.',
          },
        ],
      },
      ...history.map(
        (msg) => {
          'role': msg['role'] == 'assistant' ? 'model' : 'user',
          'parts': [
            {'text': msg['text'] ?? ''},
          ],
        },
      ),
      {
        'role': 'user',
        'parts': [
          {'text': userMessage},
        ],
      },
    ];

    try {
      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'contents': contents}),
          )
          .timeout(const Duration(seconds: 30));

      switch (response.statusCode) {
        case 200:
          final text = _parseGeminiBody(response.body);
          if (text != null) {
            return ChatResult(text: text, provider: AiProvider.gemini);
          }
          return null; // empty → fall through to Groq

        case 429:
          // Cool down for 60 s then let Groq handle it
          _geminiCooldownUntil = DateTime.now().add(
            const Duration(seconds: 60),
          );
          return null;

        case 400:
          // Bad request — fall back to Groq
          debugPrint('GeminiService: Gemini returned 400 (Bad Request). Falling back to Groq.');
          return null;

        case 403:
          // Invalid API Key — fall back to Groq
          debugPrint('GeminiService: Gemini returned 403 (Forbidden/Invalid Key). Falling back to Groq.');
          return null;

        default:
          // 500+ or anything unexpected → try Groq
          return null;
      }
    } on TimeoutException {
      return null; // timeout → Groq
    } catch (_) {
      return null; // network error → Groq
    }
  }

  String? _parseGeminiBody(String body) {
    try {
      final data = jsonDecode(body) as Map<String, dynamic>;
      final candidates = data['candidates'] as List<dynamic>?;
      if (candidates == null || candidates.isEmpty) return null;
      final parts = candidates[0]['content']['parts'] as List<dynamic>?;
      if (parts == null || parts.isEmpty) return null;
      final text = parts[0]['text'] as String?;
      return (text != null && text.trim().isNotEmpty) ? text.trim() : null;
    } catch (_) {
      return null;
    }
  }

  // ── Groq ───────────────────────────────────────────────────────────────────

  Future<ChatResult> _tryGroq({
    required List<Map<String, String>> history,
    required String userMessage,
  }) async {
    final url = Uri.parse(_groqUrl);

    final List<Map<String, String>> messages = [
      {'role': 'system', 'content': _systemPrompt},
      ...history.map(
        (msg) => {
          'role': msg['role'] == 'assistant' ? 'assistant' : 'user',
          'content': msg['text'] ?? '',
        },
      ),
      {'role': 'user', 'content': userMessage},
    ];

    int attempt = 0;
    const int maxRetries = 3;

    while (attempt < maxRetries) {
      try {
        final response = await http
            .post(
              url,
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer $kGroqApiKey',
              },
              body: jsonEncode({
                'model': _groqModel,
                'messages': messages,
                'max_tokens': 1024,
                'temperature': 0.7,
              }),
            )
            .timeout(const Duration(seconds: 30));

        switch (response.statusCode) {
          case 200:
            final text = _parseGroqBody(response.body);
            return ChatResult(
              text:
                  text ??
                  'Sorry, I received an empty response. Please try again.',
              provider: AiProvider.groq,
              isError: text == null,
            );

          case 429:
            attempt++;
            if (attempt < maxRetries) {
              await Future.delayed(Duration(seconds: 3 * attempt));
              continue;
            }
            return const ChatResult(
              text:
                  'Both AI services are currently busy. '
                  'Please wait a moment and try again.',
              provider: AiProvider.none,
              isError: true,
            );

          case 401:
          case 403:
            return const ChatResult(
              text: 'Groq API key is invalid. Please update your .env file.',
              provider: AiProvider.none,
              isError: true,
            );

          default:
            attempt++;
            if (attempt >= maxRetries) {
              return ChatResult(
                text:
                    'AI service error (${response.statusCode}). '
                    'Please try again later.',
                provider: AiProvider.none,
                isError: true,
              );
            }
        }
      } on TimeoutException {
        attempt++;
        if (attempt >= maxRetries) {
          return const ChatResult(
            text: 'Connection timed out. Please check your internet and retry.',
            provider: AiProvider.none,
            isError: true,
          );
        }
        await Future.delayed(Duration(seconds: attempt));
      } catch (_) {
        attempt++;
        if (attempt >= maxRetries) {
          return const ChatResult(
            text: 'Connection error. Please check your internet and try again.',
            provider: AiProvider.none,
            isError: true,
          );
        }
        await Future.delayed(Duration(seconds: attempt));
      }
    }

    return const ChatResult(
      text: 'Could not connect to any AI service. Please try again later.',
      provider: AiProvider.none,
      isError: true,
    );
  }

  String? _parseGroqBody(String body) {
    try {
      final data = jsonDecode(body) as Map<String, dynamic>;
      final choices = data['choices'] as List<dynamic>?;
      if (choices == null || choices.isEmpty) return null;
      final content = choices[0]['message']?['content'] as String?;
      return (content != null && content.trim().isNotEmpty)
          ? content.trim()
          : null;
    } catch (_) {
      return null;
    }
  }
}
