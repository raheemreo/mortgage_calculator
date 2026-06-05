// ============================================================
// API KEYS — KEEP PRIVATE
// Add this file to .gitignore to avoid leaking keys to git.
//
// Keys are loaded from your .env file via flutter_dotenv.
// Never hardcode values here — always use dotenv.env['KEY'].
//
// Get keys at:
//   Gemini → https://aistudio.google.com/app/apikey
//   Groq   → https://console.groq.com/keys
//   FRED   → https://fredaccount.stlouisfed.org/apikeys
// ============================================================

import 'package:flutter_dotenv/flutter_dotenv.dart';

// ignore_for_file: constant_identifier_names

// ── AI Providers ─────────────────────────────────────────────
String get kGeminiApiKey => dotenv.env['GEMINI_API_KEY'] ?? '';
String get kGroqApiKey => dotenv.env['Groq_API_KEY'] ?? '';
