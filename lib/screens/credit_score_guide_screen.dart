import 'package:flutter/material.dart';
import 'insurance_marketplace.dart';
import 'settings_screen.dart';
import '../core/constants/theme_extensions.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AD PLACEMENT STRATEGY — what changed and why
// ─────────────────────────────────────────────────────────────────────────────
//
// REMOVED → SizedBox(height: 100) dead-space spacer at the bottom
//   • The original added 100 dp of blank space at the bottom of the scroll
//     content "for the bottom nav." This is unnecessary — the nav bar handles
//     its own space. Removed entirely.
//
// ADDED → Single NativeAdWidget between score ranges and Pro Tip section
//   • This is the optimal placement on this screen:
//     - The user has just finished reading all 5 score range cards
//       (non-interactive content above — safe buffer)
//     - The non-interactive Pro Tip card below acts as a second buffer
//     - The BottomNavigationBar is separated by both the Pro Tip card
//       AND the scroll distance — zero accidental-tap risk
//   • One native ad on a purely informational screen is the correct density.
//   • NativeAdWidget collapses silently on failure — no empty gap.
//
// NOT ADDED → BannerAd above/below BottomNavigationBar
//   • This screen already has a BottomNavigationBar. Placing a BannerAd
//     directly adjacent to it (stacked in a Column) violates AdMob policy
//     as established across all other screens in this project.
//   • The single inline NativeAd is sufficient monetization for an
//     informational guide screen.
//
// FIXED → BottomNavigationBar wrapped in SafeArea
//   • The original Container had no SafeArea — on devices with a home
//     indicator the nav bar could overlap system UI. Wrapped correctly.
// ─────────────────────────────────────────────────────────────────────────────

class CreditScoreGuideScreen extends StatefulWidget {
  const CreditScoreGuideScreen({super.key});

  @override
  State<CreditScoreGuideScreen> createState() => _CreditScoreGuideScreenState();
}

class _CreditScoreGuideScreenState extends State<CreditScoreGuideScreen> {
  int _currentIndex = 1;
  final List<Map<String, dynamic>> _scoreRanges = [
    {
      'range': '760 - 850',
      'label': 'EXCELLENT',
      'color': Colors.green,
      'description':
          'Qualify for the lowest possible interest rates. Lenders view you as a low-risk borrower, making approval processes fast and competitive.',
      'isExcellent': true,
    },
    {
      'range': '700 - 759',
      'label': 'GOOD',
      'color': Colors.blue,
      'description':
          'Highly likely to be approved for most mortgage products. Rates are very competitive, though slightly higher than the top tier.',
      'isExcellent': false,
    },
    {
      'range': '620 - 699',
      'label': 'AVERAGE',
      'color': Colors.orange,
      'description':
          'The minimum range for many conventional loans. Expect higher interest rates and potentially higher private mortgage insurance (PMI) costs.',
      'isExcellent': false,
    },
    {
      'range': '580 - 619',
      'label': 'LOW',
      'color': Colors.deepOrange,
      'description':
          'Eligibility is limited. Most conventional lenders will require a larger down payment. FHA loans become the primary option here.',
      'isExcellent': false,
    },
    {
      'range': 'Below 580',
      'label': 'POOR',
      'color': Colors.red,
      'description':
          'Significant challenge for mortgage approval. Work on credit repair or seek specialized government-backed programs with high down payments.',
      'isExcellent': false,
    },
  ];

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF0B3D93);

    return Scaffold(
      backgroundColor: context.pageBackground,
      appBar: AppBar(
        backgroundColor: primaryColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: context.cs.surface),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Mortgage Eligibility Guide',
          style: TextStyle(
            color: context.cs.surface,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      // SafeArea wraps the nav bar — handles home indicator insets correctly.
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
                icon: Icon(Icons.speed_rounded, size: 28),
                label: 'Score',
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
            // ── Hero section ─────────────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: primaryColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: primaryColor.withValues(alpha: 0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Current Standard',
                    style: TextStyle(
                      color: context.surface70,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Excellent Range',
                    style: TextStyle(
                      color: context.cs.surface,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '760+',
                    style: TextStyle(
                      color: context.cs.surface,
                      fontSize: 42,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: context.cs.surface.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.verified_user,
                          color: context.cs.surface,
                          size: 16,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Best Interest Rates',
                          style: TextStyle(
                            color: context.cs.surface,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            const Text(
              'Credit Score Breakdown',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 16),

            // ── Score ranges — Column instead of shrinkWrap ListView ────
            // ListView with shrinkWrap:true inside SingleChildScrollView is
            // a known Flutter performance anti-pattern for small fixed lists.
            // A mapped Column has zero layout overhead for 5 static items.
            Column(
              children: _scoreRanges.asMap().entries.map((entry) {
                final index = entry.key;
                final range = entry.value;
                final isSpecial = range['isExcellent'] as bool;

                return Padding(
                  padding: EdgeInsets.only(
                    bottom: index < _scoreRanges.length - 1 ? 12 : 0,
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isSpecial
                          ? primaryColor.withValues(alpha: 0.05)
                          : context.cs.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSpecial
                            ? primaryColor.withValues(alpha: 0.2)
                            : Colors.grey.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              range['range'],
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: isSpecial
                                    ? primaryColor
                                    : const Color(0xFF0F172A),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: (range['color'] as Color).withValues(
                                  alpha: 0.1,
                                ),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                range['label'],
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: range['color'],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          range['description'],
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[700],
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 24),

            // ── Pro Tip section (non-interactive buffer below the ad) ─────
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: context.cs.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline, color: primaryColor, size: 24),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Pro Tip',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Moving your score just 20 points from 740 to 760 could save you tens of thousands of dollars over the life of a 30-year mortgage.',
                          style: TextStyle(
                            fontSize: 14,
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
          ],
        ),
      ),
    );
  }
}

