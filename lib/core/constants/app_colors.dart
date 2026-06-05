import 'package:flutter/material.dart';

class AppColors {
  // ── Light Theme Palette ────────────────────────────────────────────────────
  // Primary brand color — deep royal blue from reference image
  static const Color primaryLight = Color(0xFF0B3D91);
  static const Color secondaryLight = Color(0xFF1E4ED8);

  // Page background — very subtle lavender-gray as in the reference image
  static const Color backgroundLight = Color(0xFFEEF1F8);
  static const Color surfaceLight = Color(0xFFEEF1F8);

  // Card / panel surface — pure white
  static const Color cardLight = Color(0xFFFFFFFF);

  // Text colors
  static const Color textPrimaryLight = Color(0xFF0F172A);
  static const Color textSecondaryLight = Color(0xFF64748B);

  // Borders and dividers
  static const Color borderLight = Color(0xFFDDE3F0);

  // Input field fill
  static const Color inputBackground = Color(0xFFF5F7FB);

  // ── Dark Theme Palette ─────────────────────────────────────────────────────
  // Primary accent — electric blue that pops on dark backgrounds
  static const Color primaryDark = Color(0xFF4F8CFF);
  static const Color secondaryDark = Color(0xFF6EA8FF);

  // Page background — very deep navy-black as in the reference image dark mode
  static const Color backgroundDark = Color(0xFF0A0E1A);
  static const Color surfaceDark = Color(0xFF111827);

  // Card surface — slightly lighter than the background
  static const Color cardDark = Color(0xFF1A2235);

  // Text colors
  static const Color textPrimaryDark = Color(0xFFF1F5F9);
  static const Color textSecondaryDark = Color(0xFF94A3B8);
  static const Color textMutedDark = Color(0xFF64748B);

  // Borders
  static const Color borderDark = Color(0xFF1E2D45);

  // ── Common Colors ──────────────────────────────────────────────────────────
  static const Color accent = Color(0xFFF4D03F);   // golden yellow accent
  static const Color error = Color(0xFFDC2626);
  static const Color white = Colors.white;
  static const Color cardShadow = Color(0x10000000);
  static const Color textLight = Color(0xFF9E9E9E);
  static const Color textDark = Color(0xFFF9FAFB);

  // ── Header Gradient (Deep Navy → Deep Crimson) ─────────────────────────────
  // Matches the reference design exactly: dark navy top-left, dark red bottom-right
  static const List<Color> headerGradient = [
    Color(0xFF0A1E5E), // Deep Navy
    Color(0xFF7B0E0E), // Deep Crimson
  ];

  // ── Card Color Palette (reference image card backgrounds) ─────────────────
  // Each module card gets a distinct premium color in light mode.
  // Dark mode variants are 30-40% darker.

  // Card 0 — Deep Navy (PITI)
  static const Color cardNavyLight = Color(0xFF0F1E36);
  static const Color cardNavyDark  = Color(0xFF1A2E4A);

  // Card 1 — White (Mortgage Calc)
  // (uses cardLight / cardDark directly)

  // Card 2 — White (DTI)
  // (uses cardLight / cardDark directly)

  // Card 3 — Teal Green (Auto Loan)
  static const Color cardGreenLight = Color(0xFF1B6B4A);
  static const Color cardGreenDark  = Color(0xFF0F3D2B);

  // Card 4 — Burnt Orange (Mortgage Rates)
  static const Color cardOrangeLight = Color(0xFFC45A10);
  static const Color cardOrangeDark  = Color(0xFF7B3A0A);

  // Card 5 — Deep Red (Home Prices)
  static const Color cardRedLight = Color(0xFFAB1A1A);
  static const Color cardRedDark  = Color(0xFF7A1010);

  // Card 6 — Indigo (Affordability)
  static const Color cardIndigoLight = Color(0xFF283593);
  static const Color cardIndigoDark  = Color(0xFF1A2468);

  // Card 7 — Slate (More Tools)
  static const Color cardSlateLight = Color(0xFF3D5068);
  static const Color cardSlateDark  = Color(0xFF273545);

  // ── Legacy Aliases (backwards compat with any screen still using these) ───
  static const Color primary = primaryLight;
  static const Color secondary = secondaryLight;
  static const Color background = backgroundLight;
  static const Color surface = cardLight;
  static const Color textPrimary = textPrimaryLight;
  static const Color textSecondary = textSecondaryLight;
  static const Color border = borderLight;
}
