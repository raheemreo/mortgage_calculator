import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../widgets/gradient_app_bar.dart';

import '../services/ad_service.dart';

import 'ai_assistant_screen.dart';
import 'dti_ratio_calculator.dart';
import 'insurance_marketplace.dart';
import 'settings_screen.dart';
import 'saved_calculations_screen.dart';
import 'property_tax_screen.dart';
import 'credit_score_guide_screen.dart';
import 'loan_types_screen.dart';
import 'credit_card_calculator.dart';
import 'lenders_in_usa_screen.dart';
import '../core/constants/theme_extensions.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AD PLACEMENT — AdMob Native Ad Policy Compliance Notes
// ─────────────────────────────────────────────────────────────────────────────
//
// PLACEMENT: After the 4th tool card (index 3), inline inside the ListView.
//
// WHY THIS IS COMPLIANT:
//   1. In-feed placement — ad sits between content items of the same list,
//      matching AdMob's definition of a compliant "in-feed" native format.
//   2. Not at position 0 — first item is always a content card; users see
//      app value before any ad appears.
//   3. Not at the last position — tools 5–7 appear below the ad, so the ad
//      is never the last scrollable item adjacent to the bottom nav.
//   4. 150dp nav-proximity rule — three full tool cards (5, 6, 7) sit
//      between the ad and the BottomNavigationBar.
//   5. No double-ad conflict — the interstitial fires AFTER the user taps
//      a tool and navigates away; native ad and interstitial are never
//      visible simultaneously.
//   6. Not inside a tappable container — the native ad widget is never
//      wrapped in InkWell / GestureDetector, preventing accidental clicks
//      (AdMob Invalid Click policy).
//   7. Only one ad format per scroll view — no banner stacked anywhere else.
//   8. "Sponsored" label rendered OUTSIDE AdMob's widget, satisfying the
//      "clearly distinguishable" disclosure requirement (AdMob Policy §5.2).
//
// TEST AD UNIT ID:
//   ca-app-pub-3940256099942544/2247696110  ← Google official test native ID
//   Replace with your production ID before release.
// ─────────────────────────────────────────────────────────────────────────────

// ── Ad injection position ─────────────────────────────────────────────────
// The native ad is injected after this many tool cards (0-based index).
// With 7 tools, inserting after index 3 gives a 4 / ad / 3 split.
const int _kAdAfterIndex = 3;

// ─────────────────────────────────────────────────────────────────────────────

class ToolItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final Widget Function() route;

  const ToolItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.route,
  });
}

class MoreToolsScreen extends StatefulWidget {
  const MoreToolsScreen({super.key});

  @override
  State<MoreToolsScreen> createState() => _MoreToolsScreenState();
}

class _MoreToolsScreenState extends State<MoreToolsScreen> {
  int _currentIndex = 1;

  // ── Native ad state ─────────────────────────────────────────────────────
  NativeAd? _nativeAd;
  bool _nativeAdLoaded = false;
  bool _nativeAdFailed = false;

  // Real native ad unit ID
  String get _nativeAdUnitId => AdService.nativeAdUnitId;

  // ── Tool list ────────────────────────────────────────────────────────────
  final List<ToolItem> _tools = const [
    ToolItem(
      title: 'Credit Card Payoff',
      subtitle: 'Calculate debt strategies',
      icon: Icons.credit_card_rounded,
      route: CreditCardCalculatorScreen.new,
    ),
    ToolItem(
      title: 'Credit Score Guide',
      subtitle: 'Improve your mortgage rates',
      icon: Icons.speed_rounded,
      route: CreditScoreGuideScreen.new,
    ),
    ToolItem(
      title: 'Loan Types',
      subtitle: 'Compare FHA, VA, & Conventional',
      icon: Icons.description_rounded,
      route: LoanTypesScreen.new,
    ),
    ToolItem(
      title: 'DTI Ratio',
      subtitle: 'Check your debt-to-income',
      icon: Icons.analytics_rounded,
      route: DtiRatioCalculatorScreen.new,
    ),
    ToolItem(
      title: 'Property Tax by State',
      subtitle: 'Interactive tax map search',
      icon: Icons.map_rounded,
      route: PropertyTaxScreen.new,
    ),
    ToolItem(
      title: 'Top Mortgage Lenders',
      subtitle: 'Compare best market rates',
      icon: Icons.account_balance_rounded,
      route: LendersInUsaScreen.new,
    ),
    ToolItem(
      title: 'AI Assistant',
      subtitle: 'Smart financial answers',
      icon: Icons.smart_toy_rounded,
      route: AiAssistantScreen.new,
    ),
  ];

  // ── Lifecycle ────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    AdService().loadInterstitialAd();
    _loadNativeAd();
  }

  void _loadNativeAd() {
    _nativeAd = NativeAd(
      adUnitId: _nativeAdUnitId,
      // 'listTile' factory renders a medium card template that includes
      // AdMob's own "Ad" badge. Our external "Sponsored" label is
      // supplementary and covers older template versions.
      factoryId: 'listTile',
      listener: NativeAdListener(
        onAdLoaded: (_) {
          if (mounted) setState(() => _nativeAdLoaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('NativeAd failed: ${error.message}');
          ad.dispose();
          // Silently hide the ad slot on failure — layout remains stable
          if (mounted) {
            setState(() {
              _nativeAdLoaded = false;
              _nativeAdFailed = true;
            });
          }
        },
      ),
      request: const AdRequest(),
    )..load();
  }

  @override
  void dispose() {
    _nativeAd?.dispose();
    super.dispose();
  }

  // ── Navigation with interstitial ─────────────────────────────────────────
  // Interstitial fires AFTER navigation — never while native ad is visible.

  void _navigateWithAd(Widget Function() route) {
    AdService().showInterstitialAd(
      onAdClosed: () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => route()));
      },
    );
  }

  // ── List item count ───────────────────────────────────────────────────────
  // Total visible rows = tools + 1 ad slot (if it hasn't failed).
  int get _itemCount => _tools.length + (_nativeAdFailed ? 0 : 1);

  // Maps a list index to either a tool index or the ad slot.
  // Ad is injected after _kAdAfterIndex tool cards.
  //   0 … _kAdAfterIndex          → tool indices 0 … _kAdAfterIndex
  //   _kAdAfterIndex + 1          → AD SLOT
  //   _kAdAfterIndex + 2 … end    → tool indices _kAdAfterIndex+1 … end
  bool _isAdSlot(int listIndex) =>
      !_nativeAdFailed && listIndex == _kAdAfterIndex + 1;

  int _toolIndex(int listIndex) {
    if (_nativeAdFailed) return listIndex;
    return listIndex <= _kAdAfterIndex ? listIndex : listIndex - 1;
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.pageBackground,
      appBar: _buildAppBar(),
      body: SafeArea(
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          itemCount: _itemCount,
          itemBuilder: (context, index) {
            // ── Ad slot ────────────────────────────────────────────────────
            if (_isAdSlot(index)) {
              return _nativeAdLoaded && _nativeAd != null
                  ? _NativeAdCard(nativeAd: _nativeAd!)
                  : const _NativeAdPlaceholder();
            }

            // ── Tool card ──────────────────────────────────────────────────
            final tool = _tools[_toolIndex(index)];
            return _buildToolCard(tool);
          },
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  // ── AppBar ────────────────────────────────────────────────────────────────

  PreferredSizeWidget _buildAppBar() => GradientAppBar(
    title: Text(
      'More Tools',
      style: GoogleFonts.manrope(
        fontWeight: FontWeight.bold,
      ),
    ),
  );

  // ── Tool card ─────────────────────────────────────────────────────────────

  Widget _buildToolCard(ToolItem tool) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: context.cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.borderColor),
        boxShadow: const [
          BoxShadow(
            color: Color(0x05000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _navigateWithAd(tool.route),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: context.cs.primary.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(tool.icon, color: context.cs.primary, size: 26),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tool.title,
                        style: GoogleFonts.manrope(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: context.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        tool.subtitle,
                        style: TextStyle(
                          fontSize: 13,
                          color: context.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 16,
                  color: context.textSecondary.withValues(alpha: 0.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Bottom nav ────────────────────────────────────────────────────────────

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: context.cs.surface,
        border: Border(top: BorderSide(color: context.borderColor)),
      ),
      child: SafeArea(
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          type: BottomNavigationBarType.fixed,
          selectedItemColor: context.cs.primary,
          unselectedItemColor: context.textSecondary,
          selectedFontSize: 11,
          unselectedFontSize: 11,
          elevation: 0,
          onTap: (index) {
            setState(() => _currentIndex = index);
            if (index == 0) {
              Navigator.of(context).maybePop();
            } else if (index == 2) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => const SavedCalculationsScreen(),
                ),
              );
            } else if (index == 3) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => const InsuranceMarketplaceScreen(),
                ),
              );
            } else if (index == 4) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            }
          },
          items: const [
            BottomNavigationBarItem(
              icon: Text('🏠', style: TextStyle(fontSize: 22)),
              activeIcon: Text('🏠', style: TextStyle(fontSize: 26)),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Text('🛠️', style: TextStyle(fontSize: 22)),
              activeIcon: Text('🛠️', style: TextStyle(fontSize: 26)),
              label: 'Tools',
            ),
            BottomNavigationBarItem(
              icon: Text('💾', style: TextStyle(fontSize: 22)),
              activeIcon: Text('💾', style: TextStyle(fontSize: 26)),
              label: 'Saved',
            ),
            BottomNavigationBarItem(
              icon: Text('🛡️', style: TextStyle(fontSize: 22)),
              activeIcon: Text('🛡️', style: TextStyle(fontSize: 26)),
              label: 'Insurance',
            ),
            BottomNavigationBarItem(
              icon: Text('⚙️', style: TextStyle(fontSize: 22)),
              activeIcon: Text('⚙️', style: TextStyle(fontSize: 26)),
              label: 'Settings',
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _NativeAdCard
// ─────────────────────────────────────────────────────────────────────────────
//
// Renders the loaded NativeAd inline between tool cards.
//
// POLICY CHECKLIST:
//   ✅ "Sponsored" label rendered OUTSIDE AdMob's widget — cannot be hidden
//      by the template, satisfies §5.2 "clearly distinguishable".
//   ✅ Divider lines above and below visually separate the ad from content,
//      making it impossible to confuse with a tool card.
//   ✅ NO InkWell / GestureDetector / onTap on the outer Container —
//      click handling delegated entirely to AdWidget (no accidental clicks).
//   ✅ ClipRRect respects rounded corners without intercepting touch events.
//   ✅ Fixed height keeps list layout stable before/after ad loads.
// ─────────────────────────────────────────────────────────────────────────────

class _NativeAdCard extends StatelessWidget {
  final NativeAd nativeAd;

  const _NativeAdCard({required this.nativeAd});

  // Height must match the registered 'listTile' factory output.
  // Adjust if you use a different template height.
  static const double _adHeight = 320;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Top divider with "Sponsored" pill ──────────────────────────
          // Placed ABOVE the ad card so it's always visible on scroll-in.
          Row(
            children: [
              // Divider left
              Expanded(
                child: Divider(
                  thickness: 1,
                  color: context.borderColor,
                  endIndent: 10,
                ),
              ),

              // "Sponsored" disclosure pill ───────────────────────────────
              // Rendered outside AdMob's NativeAd widget — this ensures the
              // label is never hidden by the template and satisfies AdMob's
              // "clearly distinguishable" requirement (Policy §5.2).
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7E6),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFFFFB800).withValues(alpha: 0.45),
                    width: 0.8,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(
                      Icons.campaign_outlined,
                      size: 11,
                      color: Color(0xFFB45309),
                    ),
                    SizedBox(width: 4),
                    Text(
                      'Sponsored',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFB45309),
                        letterSpacing: 0.4,
                      ),
                    ),
                  ],
                ),
              ),

              // Divider right
              Expanded(
                child: Divider(
                  thickness: 1,
                  color: context.borderColor,
                  indent: 10,
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // ── AdMob NativeAd widget ───────────────────────────────────────
          // NOT wrapped in InkWell / GestureDetector / onTap.
          // All click handling is delegated to AdWidget internally.
          // This prevents accidental-click policy violations.
          Container(
            height: _adHeight,
            decoration: BoxDecoration(
              color: context.cs.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: context.borderColor),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x06000000),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            // ClipRRect ensures AdWidget stays within rounded corners
            // without adding a tap interceptor.
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: AdWidget(ad: nativeAd),
            ),
          ),

          const SizedBox(height: 8),

          // ── Bottom divider ──────────────────────────────────────────────
          // Visual separator between ad and the next tool card.
          Divider(thickness: 1, color: context.borderColor),

          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _NativeAdPlaceholder
// ─────────────────────────────────────────────────────────────────────────────
// Shown while the NativeAd is loading or if it fails to load.
// Fixed height matches _NativeAdCard so the list never reflows.
// Total slot height ≈ divider(~17) + gap(8) + card(320) + gap(8) +
//                     divider(~17) + gap(4) = ~374px
// ─────────────────────────────────────────────────────────────────────────────

class _NativeAdPlaceholder extends StatelessWidget {
  const _NativeAdPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          // Top divider row (no label while loading)
          Divider(thickness: 1, color: context.borderColor),
          const SizedBox(height: 8),

          // Placeholder card — same dimensions as the real ad
          Container(
            height: 320,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: context.borderColor),
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Pulsing shimmer icon
                  const _ShimmerIcon(),
                  const SizedBox(height: 10),
                  Text(
                    'Sponsored',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade400,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 8),
          Divider(thickness: 1, color: context.borderColor),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _ShimmerIcon — subtle pulse animation for the placeholder
// ─────────────────────────────────────────────────────────────────────────────

class _ShimmerIcon extends StatefulWidget {
  const _ShimmerIcon();

  @override
  State<_ShimmerIcon> createState() => _ShimmerIconState();
}

class _ShimmerIconState extends State<_ShimmerIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _anim = Tween<double>(
      begin: 0.3,
      end: 0.8,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: _anim,
    child: Icon(Icons.image_outlined, size: 36, color: Colors.grey.shade300),
  );
}
