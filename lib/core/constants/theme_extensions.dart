import 'package:flutter/material.dart';
import 'app_colors.dart';

extension ThemeExtensions on BuildContext {
  /// Get the current ColorScheme
  ColorScheme get cs => Theme.of(this).colorScheme;

  /// Check if dark mode is active
  bool get isDarkMode => false;

  /// Alias for isDarkMode
  bool get isDark => false;

  /// Semantic color for primary text based on theme
  Color get textPrimary => AppColors.textPrimary;

  /// Semantic color for secondary/muted text based on theme
  Color get textSecondary => AppColors.textSecondary;

  /// Semantic color for borders based on theme
  Color get borderColor => AppColors.border;

  /// Semantic color for card/surface backgrounds based on theme
  Color get cardColor => AppColors.surface;

  /// Page background color
  Color get pageBackground => AppColors.background;

  /// Input fill color
  Color get inputFill => AppColors.inputBackground;

  /// Label color
  Color get labelColor => textSecondary;

  /// Opacity variations
  Color get textPrimary12 => textPrimary.withValues(alpha: 0.12);
  Color get textPrimary87 => textPrimary.withValues(alpha: 0.87);
  Color get surface70 => cardColor.withValues(alpha: 0.70);
  Color get surface10 => cardColor.withValues(alpha: 0.10);
}
