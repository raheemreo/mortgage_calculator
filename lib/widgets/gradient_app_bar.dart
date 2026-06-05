import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/constants/app_colors.dart';

/// A reusable AppBar with the brand Navy→Crimson gradient background.
///
/// All colours stay fixed (gradient is always the same visual appearance
/// regardless of light/dark mode) — the status bar icons are forced white
/// via [SystemUiOverlayStyle.light].
class GradientAppBar extends AppBar {
  GradientAppBar({
    super.key,
    super.leading,
    super.automaticallyImplyLeading,
    super.title,
    super.actions,
    super.bottom,
    double? elevation,
    super.scrolledUnderElevation = 0,
    super.shadowColor,
    super.forceMaterialTransparency,
    Color? backgroundColor,
    Color? surfaceTintColor,
    super.foregroundColor = Colors.white,
    super.iconTheme = const IconThemeData(color: Colors.white),
    super.actionsIconTheme = const IconThemeData(color: Colors.white70),
    super.centerTitle = true,
    super.excludeHeaderSemantics,
    super.titleSpacing,
    super.shape,
    super.toolbarOpacity,
    super.bottomOpacity,
    super.toolbarHeight,
    super.leadingWidth,
    super.toolbarTextStyle,
    TextStyle? titleTextStyle,
    super.clipBehavior,
  }) : super(
          backgroundColor: Colors.transparent,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          systemOverlayStyle: SystemUiOverlayStyle.light,
          titleTextStyle: titleTextStyle?.copyWith(color: Colors.white) ??
              const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: AppColors.headerGradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
        );
}
