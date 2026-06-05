import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/settings_provider.dart';
import 'app_colors.dart';

extension ThemeExtensions on BuildContext {
  // ── Currency ───────────────────────────────────────────────────────────────
  String get currencySymbol =>
      Provider.of<SettingsProvider>(this).currencySymbol;

  NumberFormat currencyFormat({int decimalDigits = 0}) {
    return NumberFormat.currency(
      symbol: currencySymbol,
      decimalDigits: decimalDigits,
    );
  }

  // ── Core theme access ──────────────────────────────────────────────────────
  ColorScheme get cs => Theme.of(this).colorScheme;
  ThemeData get theme => Theme.of(this);
  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;
  bool get isDark => isDarkMode;

  // ── Semantic text colors ───────────────────────────────────────────────────
  Color get textPrimary =>
      isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;

  Color get textSecondary =>
      isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

  Color get textMuted =>
      isDark ? AppColors.textMutedDark : AppColors.textSecondaryLight;

  // ── Semantic surface colors ────────────────────────────────────────────────
  Color get borderColor =>
      isDark ? AppColors.borderDark : AppColors.borderLight;

  Color get cardColor =>
      isDark ? AppColors.cardDark : AppColors.cardLight;

  Color get pageBackground =>
      isDark ? AppColors.backgroundDark : AppColors.backgroundLight;

  Color get surfaceColor =>
      isDark ? AppColors.surfaceDark : AppColors.cardLight;

  Color get inputFill =>
      isDark ? AppColors.surfaceDark : AppColors.inputBackground;

  // ── Primary colors ─────────────────────────────────────────────────────────
  Color get primaryColor =>
      isDark ? AppColors.primaryDark : AppColors.primaryLight;

  // ── Gradient ───────────────────────────────────────────────────────────────
  LinearGradient get headerGradient => const LinearGradient(
        colors: AppColors.headerGradient,
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  // ── Card color helpers ─────────────────────────────────────────────────────
  Color get cardNavy =>
      isDark ? AppColors.cardNavyDark : AppColors.cardNavyLight;
  Color get cardGreen =>
      isDark ? AppColors.cardGreenDark : AppColors.cardGreenLight;
  Color get cardOrange =>
      isDark ? AppColors.cardOrangeDark : AppColors.cardOrangeLight;
  Color get cardRed =>
      isDark ? AppColors.cardRedDark : AppColors.cardRedLight;
  Color get cardIndigo =>
      isDark ? AppColors.cardIndigoDark : AppColors.cardIndigoLight;
  Color get cardSlate =>
      isDark ? AppColors.cardSlateDark : AppColors.cardSlateLight;
  Color get cardWhite =>
      isDark ? AppColors.cardDark : AppColors.cardLight;

  // ── Convenience opacity helpers ────────────────────────────────────────────
  Color get textPrimary12 => textPrimary.withValues(alpha: 0.12);
  Color get textPrimary87 => textPrimary.withValues(alpha: 0.87);
  Color get surface70 => cardColor.withValues(alpha: 0.70);
  Color get surface10 => cardColor.withValues(alpha: 0.10);
  Color get border50 => borderColor.withValues(alpha: 0.50);

  /// Alias for backwards compatibility
  Color get labelColor => textSecondary;
}
