import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import '../core/constants/app_colors.dart';
import '../core/constants/theme_extensions.dart';

class SplashScreen extends StatefulWidget {
  final Widget nextScreen;

  const SplashScreen({super.key, required this.nextScreen});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _progressController;

  @override
  void initState() {
    super.initState();
    FlutterNativeSplash.remove();

    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..forward();

    _startAppFlow();
  }

  Future<void> _startAppFlow() async {
    // Wait for at least some animation progress
    await Future.delayed(const Duration(milliseconds: 1500));
    _goNext();
  }

  void _goNext() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            widget.nextScreen,
        transitionDuration: const Duration(milliseconds: 800),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  void dispose() {
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0B3D91), Color(0xFF051F4A)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          children: [
            const Spacer(flex: 2),
            // Logo Area
            Container(
              width: 128,
              height: 128,
              decoration: BoxDecoration(
                color: context.cs.surface.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(32),
                border: Border.all(
                  color: context.cs.surface.withValues(alpha: 0.2),
                ),
                boxShadow: [
                  BoxShadow(
                    color: context.textPrimary.withValues(alpha: 0.2),
                    blurRadius: 40,
                    offset: const Offset(0, 20),
                  ),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(Icons.home, color: context.cs.surface, size: 60),
                  Positioned(
                    bottom: 24,
                    right: 24,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0B3D91),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFF0B3D91),
                          width: 2,
                        ),
                      ),
                      child: const Icon(
                        Icons.calculate,
                        color: AppColors.accent,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            // Text Area
            Column(
              children: [
                Text(
                  'USA Mortgage &',
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    color: context.cs.surface,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                  ),
                  textAlign: TextAlign.center,
                ),
                RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      color: context.cs.surface,
                      fontWeight: FontWeight.w800,
                      height: 1.1,
                    ),
                    children: const [
                      TextSpan(text: 'Loan Calculator '),
                      TextSpan(
                        text: 'Pro',
                        style: TextStyle(
                          color: AppColors.accent,
                          fontWeight: FontWeight.w900,
                          fontFamily: 'Inter',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'PROFESSIONAL FINANCIAL TOOLS',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: context.cs.surface.withValues(alpha: 0.7),
                fontWeight: FontWeight.w600,
                letterSpacing: 2.0,
              ),
            ),
            const Spacer(flex: 3),
            // Loading Bar Area
            Padding(
              padding: const EdgeInsets.only(bottom: 64.0, left: 40, right: 40),
              child: Column(
                children: [
                  Container(
                    width: 280,
                    height: 6,
                    decoration: BoxDecoration(
                      color: context.cs.surface.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: AnimatedBuilder(
                      animation: _progressController,
                      builder: (context, child) {
                        return Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            width: 280 * _progressController.value,
                            height: 6,
                            decoration: BoxDecoration(
                              color: AppColors.accent,
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.accent.withValues(
                                    alpha: 0.5,
                                  ),
                                  blurRadius: 10,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'LOADING...',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: context.cs.surface.withValues(alpha: 0.5),
                      fontWeight: FontWeight.w700,
                      letterSpacing: 4.0,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
