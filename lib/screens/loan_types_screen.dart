import 'package:flutter/material.dart';

import 'insurance_marketplace.dart';
import 'settings_screen.dart';
import 'lenders_in_usa_screen.dart';
import '../widgets/ad_native_widget.dart';
import '../core/constants/theme_extensions.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AD PLACEMENT STRATEGY — what changed and why
// ─────────────────────────────────────────────────────────────────────────────
//
// REMOVED → AdBannerWidget stacked above the BottomNavigationBar
//   • Identical violation to lenders_in_usa_screen: a BannerAd placed inside
//     a Column above a BottomNavigationBar is not anchored to the screen edge
//     and violates AdMob policy. Removed entirely.
//   • ad_banner_widget.dart import removed.
//
// REMOVED → AdService().isFirstLaunch guard on AdNativeWidget
//   • The isFirstLaunch guard is unnecessary — AdNativeWidget already
//     collapses silently (SizedBox.shrink) when the ad fails to load, which
//     covers the first-launch case without any special branching here.
//   • ad_service.dart import removed.
//
// KEPT → Inline AdNativeWidget between "Quick Tips" and the CTA button
//   • This is a natural, non-intrusive placement: the user has finished
//     reading all content and is about to take action. A single native ad
//     here is well within AdMob density guidelines for a non-scrolling screen.
//   • The SizedBox(height: 100) spacer that compensated for the old banner
//     has been reduced to a clean 32 dp — no fake space needed anymore.
// ─────────────────────────────────────────────────────────────────────────────

class LoanTypesScreen extends StatefulWidget {
  const LoanTypesScreen({super.key});

  @override
  State<LoanTypesScreen> createState() => _LoanTypesScreenState();
}

class _LoanTypesScreenState extends State<LoanTypesScreen> {
  int _currentIndex = 1;
  final List<Map<String, dynamic>> _loanTypes = [
    {
      'program': 'Conventional',
      'subtitle': 'Standard financing for most buyers',
      'downPayment': '3%',
      'creditScore': '620',
    },
    {
      'program': 'FHA',
      'subtitle': 'Government-backed for lower credit',
      'downPayment': '3.5%',
      'creditScore': '580',
    },
    {
      'program': 'VA',
      'subtitle': 'Zero down for Veterans & families',
      'downPayment': '0%',
      'creditScore': '620',
      'isMilitary': true,
    },
    {
      'program': 'USDA',
      'subtitle': 'Rural housing assistance program',
      'downPayment': '0%',
      'creditScore': '640',
    },
  ];

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF0B3D93);

    return Scaffold(
      backgroundColor: context.pageBackground,
      appBar: AppBar(
        backgroundColor: context.cs.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF0F172A)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Loan Types',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
      ),
      // BottomNavigationBar is now the SOLE occupant — no ad stacked on top.
      // SafeArea handles system gesture insets cleanly.
      bottomNavigationBar: SafeArea(
        child: Container(
          decoration: BoxDecoration(
            color: context.cs.surface,
            border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
          ),
          child: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (index) {
              setState(() => _currentIndex = index);
              if (index == 0) {
                Navigator.pop(context);
              } else if (index == 2) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const InsuranceMarketplaceScreen(),
                  ),
                );
              } else if (index == 3) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                );
              }
            },
            type: BottomNavigationBarType.fixed,
            backgroundColor: context.cs.surface,
            selectedItemColor: primaryColor,
            unselectedItemColor: const Color(0xFF94A3B8),
            selectedFontSize: 10,
            unselectedFontSize: 10,
            elevation: 0,
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.home_rounded, size: 28),
                label: 'Home',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.payments_rounded, size: 28),
                label: 'Loans',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.shield_rounded, size: 28),
                label: 'Insurance',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.settings_rounded, size: 28),
                label: 'Settings',
              ),
            ],
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Hero section ──────────────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: primaryColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Mortgage Options',
                    style: TextStyle(
                      color: context.cs.surface,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Find the perfect loan for your financial situation. Compare requirements and down payments side-by-side.',
                    style: TextStyle(
                      color: context.surface70,
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── Section header ────────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Requirement Comparison',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Updated Today',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── Table header ──────────────────────────────────────────────
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(12),
                ),
                border: Border.all(color: context.borderColor),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        'LOAN PROGRAM',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: context.textSecondary,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ),
                  VerticalDivider(color: context.borderColor, width: 1),
                  Expanded(
                    flex: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        'MIN. REQUIREMENTS',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: context.textSecondary,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Loan types table ──────────────────────────────────────────
            Container(
              decoration: BoxDecoration(
                color: context.cs.surface,
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(12),
                ),
                border: Border(
                  left: BorderSide(color: context.borderColor),
                  right: BorderSide(color: context.borderColor),
                  bottom: BorderSide(color: context.borderColor),
                ),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _loanTypes.length,
                separatorBuilder: (context, index) =>
                    const Divider(height: 1, color: Color(0xFFF1F5F9)),
                itemBuilder: (context, index) {
                  final loan = _loanTypes[index];
                  return Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    loan['program'],
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: primaryColor,
                                      fontSize: 15,
                                    ),
                                  ),
                                  if (loan['isMilitary'] == true) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF1F5F9),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        'MILITARY',
                                        style: TextStyle(
                                          fontSize: 8,
                                          fontWeight: FontWeight.bold,
                                          color: context.textSecondary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                loan['subtitle'],
                                style: TextStyle(
                                  fontSize: 11,
                                  color: context.textSecondary,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ), VerticalDivider(color: context.borderColor, width: 1),
                      Expanded(
                        flex: 2,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.payments_outlined,
                                    size: 14,
                                    color: primaryColor,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '${loan['downPayment']} Down',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.credit_score_outlined,
                                    size: 14,
                                    color: primaryColor,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '${loan['creditScore']} Score',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 24),

            // ── Native ad — natural break after table, before tips ────────
            // "Quick Tips" acts as a non-interactive buffer between the ad
            // and the CTA button, preventing accidental tap flagging.
            const Padding(
              padding: EdgeInsets.only(bottom: 24),
              child: AdNativeWidget(),
            ),

            // ── Quick Tips (buffer zone between ad and CTA) ───────────────
            const Text(
              'Quick Tips',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: primaryColor.withValues(alpha: 0.1)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline, color: primaryColor, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Did you know?',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: primaryColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Credit score requirements are guidelines. Many lenders may have their own "overlays" which might require a higher score.',
                          style: TextStyle(
                            fontSize: 13,
                            color: context.textSecondary,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── CTA button ────────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const LendersInUsaScreen(),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: context.cs.surface,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 4,
                  shadowColor: primaryColor.withValues(alpha: 0.4),
                ),
                child: const Text(
                  'Get Pre-Approved Loan',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}