import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'home_dashboard.dart';
import '../core/constants/theme_extensions.dart';

/// 3-page onboarding carousel shown only on the very first app launch.
/// Sets [SharedPreferences] key "onboarding_complete" to true when the user
/// taps "Get Started", so it is never shown again.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  static const List<_OnboardingPage> _pages = [
    _OnboardingPage(
      icon: Icons.home_work_rounded,
      gradientStart: Color(0xFF0B3D91),
      gradientEnd: Color(0xFF1565C0),
      title: 'Your Mortgage\nCommand Center',
      subtitle:
          'Calculate payments, compare rates, and understand exactly what you can afford — all in one app.',
    ),
    _OnboardingPage(
      icon: Icons.calculate_rounded,
      gradientStart: Color(0xFF1B5E20),
      gradientEnd: Color(0xFF2E7D32),
      title: 'Every Calculator\nYou Need',
      subtitle:
          'From DTI ratios and PITI breakdowns to auto loans and credit card payoff plans — we have you covered.',
    ),
    _OnboardingPage(
      icon: Icons.smart_toy_rounded,
      gradientStart: Color(0xFF4A148C),
      gradientEnd: Color(0xFF7B1FA2),
      title: 'Ask AI,\nGet Answers',
      subtitle:
          'Our AI mortgage assistant gives you instant, personalised guidance on home buying, refinancing, and more.',
    ),
  ];

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_complete', true);
    if (!mounted) return;
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => const HomeDashboard()));
  }

  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    } else {
      _completeOnboarding();
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Page view
          PageView.builder(
            controller: _pageController,
            itemCount: _pages.length,
            onPageChanged: (i) => setState(() => _currentPage = i),
            itemBuilder: (context, index) =>
                _OnboardingPageView(page: _pages[index]),
          ),

          // Bottom controls
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(32, 0, 32, 48),
              child: Column(
                children: [
                  // Dot indicators
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _pages.length,
                      (i) => AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: _currentPage == i ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: context.cs.surface.withValues(
                            alpha: _currentPage == i ? 1.0 : 0.4,
                          ),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Primary button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _nextPage,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: context.cs.surface,
                        foregroundColor: _pages[_currentPage].gradientStart,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        _currentPage < _pages.length - 1
                            ? 'Next'
                            : 'Get Started',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Skip button (visible on pages 1-2)
                  if (_currentPage < _pages.length - 1)
                    TextButton(
                      onPressed: _completeOnboarding,
                      child: Text(
                        'Skip',
                        style: TextStyle(
                          color: context.cs.surface.withValues(alpha: 0.7),
                          fontSize: 14,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OnboardingPage {
  final IconData icon;
 final Color gradientStart;
 final Color gradientEnd;
 final String title;
 final String subtitle;

  const _OnboardingPage({
    required this.icon,
    required this.gradientStart,
    required this.gradientEnd,
    required this.title,
    required this.subtitle,
  });
}

class _OnboardingPageView extends StatelessWidget {
  final _OnboardingPage page;
  const _OnboardingPageView({required this.page});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [page.gradientStart, page.gradientEnd],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              const Spacer(flex: 2),
              // Icon
              Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  color: context.cs.surface.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(page.icon, size: 72, color: context.cs.surface),
              ),
              const Spacer(flex: 1),
              // Title
              Text(
                page.title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: context.cs.surface,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 16),
              // Subtitle
              Text(
                page.subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: context.cs.surface.withValues(alpha: 0.85),
                  fontSize: 16,
                  height: 1.6,
                ),
              ),
              const Spacer(flex: 3),
            ],
          ),
        ),
      ),
    );
  }
}




