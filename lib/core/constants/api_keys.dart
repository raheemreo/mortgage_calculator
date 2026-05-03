// ============================================================
// API KEYS — KEEP PRIVATE
// Add this file to .gitignore to avoid leaking keys to git.
// Get your free Gemini API key at: https://aistudio.google.com/app/apikey
// ============================================================

import 'package:flutter_dotenv/flutter_dotenv.dart';

// ignore_for_file: constant_identifier_names
String get kGeminiApiKey => dotenv.env['GEMINI_API_KEY'] ?? '';
