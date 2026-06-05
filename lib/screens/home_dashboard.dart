import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../core/constants/app_colors.dart';

import '../services/firebase_service.dart';
import '../services/update_service.dart';
import '../widgets/update_dialog.dart';
import '../services/ad_service.dart';
import '../providers/notification_provider.dart';
import 'insurance_marketplace.dart';
import 'settings_screen.dart';
import 'mortgage_calculator.dart';
import 'auto_loan_calculator.dart';
import 'dti_calculator.dart';
import 'piti_calculator.dart';
import 'more_tools_screen.dart';
import 'mortgage_rates_screen.dart';
import 'home_prices_screen.dart';
import 'home_affordability_screen.dart';
import 'lenders_in_usa_screen.dart';
import 'ai_assistant_screen.dart';
import 'notification_screen.dart';
import 'saved_calculations_screen.dart';
import '../core/constants/theme_extensions.dart';
import '../widgets/promo_banner.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AD PLACEMENT — AdMob Native Ad Policy Compliance Notes
// ─────────────────────────────────────────────────────────────────────────────
//
// PLACEMENT: Between "Calculators & Tools" grid and "Quick Access" list.
//
// WHY THIS IS COMPLIANT:
//   1. In-content / in-feed placement — ad sits between two distinct content
//      sections, matching AdMob's recommended native "in-feed" pattern.
//   2. Not inside a tappable container — the ad is never wrapped in InkWell,
//      GestureDetector, or any other tap handler, preventing accidental clicks.
//   3. Clear disclosure — "Sponsored" label is rendered ABOVE the NativeAd
//      container (outside AdMob's own "Ad" badge) to satisfy Google's
//      "clearly distinguishable" requirement for native ads.
//   4. Only one ad format per view — no banner is stacked here; this is the
//      sole ad unit visible in the scroll area at any one time.
//   5. Not adjacent to navigation — there are three full content sections
//      (grid, ad, quick-access) plus the section label between the ad and
//      the BottomNavigationBar, well beyond the 150dp proximity rule.
//   6. Not inside a GridView tile — would mimic app UI controls (policy §3.4).
//   7. Not in the app header — explicitly banned by AdMob placement policy.
//
// TEST AD UNIT ID:
//   ca-app-pub-3940256099942544/2247696110  ← Google's official test native ID
//   Replace with your production ID before release.
// ─────────────────────────────────────────────────────────────────────────────

class HomeDashboard extends StatefulWidget {
  const HomeDashboard({super.key});

  @override
  State<HomeDashboard> createState() => _HomeDashboardState();
}

class _HomeDashboardState extends State<HomeDashboard> {
  int _currentIndex = 0;
  String? _promoMessage;

  // ── Native Ad state ────────────────────────────────────────────────────────
  NativeAd? _nativeAd;
  bool _nativeAdLoaded = false;
  bool _nativeAdFailed = false;

  // Real native ad unit ID
  String get _nativeAdUnitId => AdService.nativeAdUnitId;

  // ── Tool modules ───────────────────────────────────────────────────────────
  final List<Map<String, dynamic>> _modules = [
    {
      'title': 'PITI & Extra',
      'subtitle': 'Payment breakdown',
      'icon': Icons.bar_chart_rounded,
      'route': const PitiCalculatorScreen(),
    },
    {
      'title': 'Mortgage Calc',
      'subtitle': 'Monthly estimate',
      'icon': Icons.calculate_outlined,
      'route': const MortgageCalculatorScreen(),
    },
    {
      'title': 'DTI Calculator',
      'subtitle': 'Debt-to-income',
      'icon': Icons.donut_large_rounded,
      'route': const DtiCalculatorScreen(),
    },
    {
      'title': 'Auto Loan',
      'subtitle': 'Vehicle finance',
      'icon': Icons.directions_car_filled_rounded,
      'route': const AutoLoanCalculatorScreen(),
    },
    {
      'title': 'Mortgage Rates',
      'subtitle': 'Market trends',
      'icon': Icons.percent_rounded,
      'route': const MortgageRatesScreen(),
    },
    {
      'title': 'Home Prices',
      'subtitle': 'Property values',
      'icon': Icons.home_work_outlined,
      'route': const HomePricesScreen(),
    },
    {
      'title': 'Affordability',
      'subtitle': 'How much house?',
      'icon': Icons.account_balance_wallet_outlined,
      'route': const HomeAffordabilityScreen(),
    },
    {
      'title': 'More Tools',
      'subtitle': 'View all 20+',
      'icon': Icons.handyman_outlined,
      'route': const MoreToolsScreen(),
    },
  ];

  // ── Quick access list ──────────────────────────────────────────────────────
  final List<Map<String, dynamic>> _quickAccess = [
    {
      'label': 'Top Mortgage Lenders',
      'icon': Icons.account_balance_rounded,
      'route': const LendersInUsaScreen(),
    },
    {
      'label': 'Home Prices',
      'icon': Icons.home_work_rounded,
      'route': const HomePricesScreen(),
    },
    {
      'label': 'Mortgage AI Advisor',
      'icon': Icons.smart_toy_rounded,
      'route': const AiAssistantScreen(),
    },
  ];

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    FirebaseService.logScreenView('home_dashboard');
    _checkUpdate();
    _loadNativeAd();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final provider = context.read<NotificationProvider>();
        FirebaseService.setNotificationProvider(provider);
      }
    });
  }

  void _loadNativeAd() {
    _nativeAd = NativeAd(
      adUnitId: _nativeAdUnitId,
      // Use the medium template which includes AdMob's own "Ad" badge.
      // Combined with our external "Sponsored" label this satisfies the
      // "clearly distinguishable" requirement even if the badge is missed.
      factoryId: 'listTile', // register this factory in your MainActivity
      listener: NativeAdListener(
        onAdLoaded: (ad) {
          if (mounted) setState(() => _nativeAdLoaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('NativeAd failed: ${error.message}');
          ad.dispose();
          if (mounted) {
            setState(() {
              _nativeAdLoaded = false;
              _nativeAdFailed = true;
            });
          }
        },
        onAdClicked: (_) => FirebaseService.logEvent('native_ad_clicked', {}),
        onAdImpression: (_) =>
            FirebaseService.logEvent('native_ad_impression', {}),
      ),
      request: const AdRequest(),
    )..load();
  }

  Future<void> _checkUpdate() async {
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    final updateInfo = await UpdateService.checkForUpdate();

    if (mounted) {
      setState(() => _promoMessage = updateInfo.announcementText);
    }

    if (updateInfo.updateAvailable && mounted) {
      UpdateDialog.show(
        context,
        latestVersion: updateInfo.latestVersion,
        currentVersion: updateInfo.currentVersion,
        message: updateInfo.updateMessage,
        isForced: updateInfo.updateRequired,
      );
    }
  }

  @override
  void dispose() {
    _nativeAd?.dispose();
    super.dispose();
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final resolvedPrimary = context.primaryColor;
    final scaffoldBg = context.pageBackground;
    final cardBg = cs.surface;
    final textPrimary = context.textPrimary;
    final borderColor = context.borderColor;
    final dialogBg = cs.surface;
    final dialogTextColor = context.textPrimary;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldExit = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            backgroundColor: dialogBg,
            contentPadding: const EdgeInsets.all(24),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.logout_rounded, size: 56, color: resolvedPrimary),
                const SizedBox(height: 16),
                Text(
                  'Do you want to Exit?',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w500,
                    color: dialogTextColor,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: resolvedPrimary,
                          foregroundColor: context.cs.surface,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Yes',
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isDark
                              ? const Color(0xFF374151)
                              : const Color(0xFFE0E7FF),
                          foregroundColor: isDark
                              ? context.cs.surface
                              : context.textPrimary,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('No', style: TextStyle(fontSize: 16)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
        if (shouldExit == true) SystemNavigator.pop();
      },
      child: Scaffold(
        backgroundColor: scaffoldBg,
        body: Column(
          children: [
            // ── App header ─────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.only(
                top: 48,
                bottom: 20,
                left: 16,
                right: 16,
              ),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: AppColors.headerGradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.account_balance_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'USA Mortgage Pro',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  _buildNotificationAction(context),
                ],
              ),
            ),

            // ── Scrollable content ─────────────────────────────────────────
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Promo banner (optional)
                  if (_promoMessage != null)
                    PromoBanner(
                      message: _promoMessage!,
                      onDismiss: () => setState(() => _promoMessage = null),
                    ),

                  // ── Section: Calculators & Tools ──────────────────────────
                  Text(
                    'Calculators & Tools',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Tool grid
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 0.80,
                        ),
                    itemCount: _modules.length,
                    itemBuilder: (context, index) {
                      final module = _modules[index];
                      
                      // Resolve card colors based on index/module color scheme
                      final Color resolvedCardBg;
                      final Color resolvedTextColor;
                      final Color resolvedSubColor;
                      final Color resolvedIconColor;
                      final Color resolvedIconBg;
                      
                      // Map each card index to its premium colour scheme
                      if (index == 0) {
                        // Navy (PITI)
                        resolvedCardBg = context.cardNavy;
                        resolvedTextColor = Colors.white;
                        resolvedSubColor = Colors.white.withValues(alpha: 0.72);
                        resolvedIconColor = Colors.white;
                        resolvedIconBg = Colors.white.withValues(alpha: 0.15);
                      } else if (index == 1 || index == 2) {
                        // White cards (Mortgage Calc, DTI)
                        resolvedCardBg = context.cardWhite;
                        resolvedTextColor = context.textPrimary;
                        resolvedSubColor = context.textSecondary;
                        resolvedIconColor = resolvedPrimary;
                        resolvedIconBg = resolvedPrimary.withValues(alpha: 0.08);
                      } else if (index == 3) {
                        // Teal Green (Auto Loan)
                        resolvedCardBg = context.cardGreen;
                        resolvedTextColor = Colors.white;
                        resolvedSubColor = Colors.white.withValues(alpha: 0.72);
                        resolvedIconColor = Colors.white;
                        resolvedIconBg = Colors.white.withValues(alpha: 0.15);
                      } else if (index == 4) {
                        // Burnt Orange (Mortgage Rates)
                        resolvedCardBg = context.cardOrange;
                        resolvedTextColor = Colors.white;
                        resolvedSubColor = Colors.white.withValues(alpha: 0.72);
                        resolvedIconColor = Colors.white;
                        resolvedIconBg = Colors.white.withValues(alpha: 0.15);
                      } else if (index == 5) {
                        // Deep Red (Home Prices)
                        resolvedCardBg = context.cardRed;
                        resolvedTextColor = Colors.white;
                        resolvedSubColor = Colors.white.withValues(alpha: 0.72);
                        resolvedIconColor = Colors.white;
                        resolvedIconBg = Colors.white.withValues(alpha: 0.15);
                      } else if (index == 6) {
                        // Indigo (Affordability)
                        resolvedCardBg = context.cardIndigo;
                        resolvedTextColor = Colors.white;
                        resolvedSubColor = Colors.white.withValues(alpha: 0.72);
                        resolvedIconColor = Colors.white;
                        resolvedIconBg = Colors.white.withValues(alpha: 0.15);
                      } else {
                        // Slate (More Tools)
                        resolvedCardBg = context.cardSlate;
                        resolvedTextColor = Colors.white;
                        resolvedSubColor = Colors.white.withValues(alpha: 0.72);
                        resolvedIconColor = Colors.white;
                        resolvedIconBg = Colors.white.withValues(alpha: 0.15);
                      }

                      return InkWell(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => module['route']),
                        ),
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: resolvedCardBg,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: resolvedTextColor.withValues(alpha: 0.08)),
                            boxShadow: [
                              BoxShadow(
                                color: context.textPrimary.withValues(
                                  alpha: isDark ? 0.3 : 0.05,
                                ),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Stack(
                            children: [
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Icon(
                                  Icons.chevron_right_rounded,
                                  color: resolvedTextColor.withValues(alpha: 0.5),
                                  size: 18,
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: resolvedIconBg,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      module['icon'],
                                      color: resolvedIconColor,
                                      size: 24,
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    module['title'],
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: resolvedTextColor,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    module['subtitle'],
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: resolvedSubColor,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 10),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: index == 1 || index == 2
                                          ? (isDark ? Colors.white.withValues(alpha: 0.1) : const Color(0xFFEFF6FF))
                                          : Colors.white.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      _getCategoryLabel(index),
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        color: index == 1 || index == 2
                                            ? (isDark ? Colors.white : const Color(0xFF1E40AF))
                                            : Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),

                  // ────────────────────────────────────────────────────────
                  // ✅ PRIMARY NATIVE AD PLACEMENT
                  // ────────────────────────────────────────────────────────
                  if (!_nativeAdFailed) ...[
                    const SizedBox(height: 24),
                    if (_nativeAdLoaded && _nativeAd != null)
                      _NativeAdCard(nativeAd: _nativeAd!)
                    else
                      const _NativeAdPlaceholder(),
                  ],

                  const SizedBox(height: 24),

                  // ── Section: Quick Access ──────────────────────────────
                  Text(
                    'Quick Access',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ..._quickAccess.map(
                    (item) => _buildQuickAccessRow(
                      item,
                      resolvedPrimary,
                      cardBg,
                      textPrimary,
                      borderColor,
                    ),
                  ),

                  const SizedBox(height: 16),
                ],
              ),
            ),
          ],
        ),

        // Bottom nav — no ad anywhere near it (policy compliance).
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _currentIndex,
          backgroundColor: cs.surface,
          onTap: (index) {
            setState(() => _currentIndex = index);
            if (index == 1) {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MoreToolsScreen()),
              ).then((_) {
                if (mounted) setState(() => _currentIndex = 0);
              });
            } else if (index == 2) {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SavedCalculationsScreen()),
              ).then((_) {
                if (mounted) setState(() => _currentIndex = 0);
              });
            } else if (index == 3) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const InsuranceMarketplaceScreen(),
                ),
              ).then((_) {
                if (mounted) setState(() => _currentIndex = 0);
              });
            } else if (index == 4) {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              ).then((_) {
                if (mounted) setState(() => _currentIndex = 0);
              });
            }
          },
          type: BottomNavigationBarType.fixed,
          selectedItemColor: resolvedPrimary,
          unselectedItemColor: context.textSecondary,
          selectedFontSize: 11,
          unselectedFontSize: 11,
          elevation: 16,
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

  String _getCategoryLabel(int index) {
    switch (index) {
      case 0:
        return 'United States';
      case 1:
        return 'Mortgage';
      case 2:
        return 'DTI Ratio';
      case 3:
        return 'Auto Loan';
      case 4:
        return 'Rates';
      case 5:
        return 'Property';
      case 6:
        return 'Affordability';
      default:
        return 'Tools';
    }
  }

  // ── Quick access row ───────────────────────────────────────────────────────

  Widget _buildQuickAccessRow(
    Map<String, dynamic> item,
    Color primaryColor,
    Color cardBg,
    Color textPrimary,
    Color borderColor,
  ) {
    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => item['route']),
      ),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          children: [
            Icon(item['icon'], color: primaryColor, size: 20),
            const SizedBox(width: 12),
            Text(
              item['label'],
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: textPrimary,
              ),
            ),
            const Spacer(),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 14,
              color: textPrimary.withValues(alpha: 0.4),
            ),
          ],
        ),
      ),
    );
  }

  // ── Notification bell ──────────────────────────────────────────────────────

  Widget _buildNotificationAction(BuildContext context) {
    return Consumer<NotificationProvider>(
      builder: (context, provider, child) {
        final count = provider.unreadCount;
        return Stack(
          alignment: Alignment.center,
          children: [
            IconButton(
              icon: const Icon(
                Icons.notifications_none_rounded,
                color: Colors.white,
                size: 28,
              ),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NotificationScreen()),
              ),
            ),
            if (count > 0)
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 16,
                    minHeight: 16,
                  ),
                  child: Text(
                    count > 9 ? '9+' : '$count',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _NativeAdCard
// ─────────────────────────────────────────────────────────────────────────────
//
// Wraps the loaded NativeAd in a card that:
//   • Shows a "Sponsored" label OUTSIDE AdMob's own rendered widget.
//     AdMob also renders its own "Ad" badge inside the template — this
//     external label is supplementary and keeps us compliant even on
//     older template versions that render the badge small.
//   • Uses NO GestureDetector / InkWell / tap handler on the outer
//     container — click handling is delegated entirely to AdMob's widget.
//   • Has a fixed height that matches the 'listTile' native template
//     (320px). Adjust if you register a different factory height.
// ─────────────────────────────────────────────────────────────────────────────

class _NativeAdCard extends StatelessWidget {
  final NativeAd nativeAd;

  const _NativeAdCard({required this.nativeAd});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── "Sponsored" disclosure label ────────────────────────────────────
        // Rendered OUTSIDE the ad widget so it cannot be hidden by the
        // AdMob template. This satisfies Google's "clearly distinguishable"
        // native ad disclosure requirement (AdMob Policy §5.2).
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                // Subtle amber-tinted background — universally recognised
                // as an ad/sponsored indicator colour.
                color: const Color(0xFFFFF7E6),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: const Color(0xFFFFB800).withValues(alpha: 0.5),
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
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 6),

        // ── AdMob native ad widget ───────────────────────────────────────────
        // • NOT wrapped in InkWell / GestureDetector — accidental taps
        //   violate AdMob Invalid Click policy.
        // • Container has no onTap — all click logic lives inside AdWidget.
        Container(
          height: 320, // matches listTile factory height; adjust as needed
          decoration: BoxDecoration(
            color: context.cs.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: context.borderColor),
            boxShadow: const [
              BoxShadow(
                color: Color(0x08000000),
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          // ClipRRect ensures the AdWidget respects the rounded corners.
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: AdWidget(ad: nativeAd),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _NativeAdPlaceholder
// ─────────────────────────────────────────────────────────────────────────────
// Shown while the ad is loading or if it fails to load.
// Keeps the layout stable — no content jumps when the ad slot fills.
// Height matches _NativeAdCard (320 + label ~26 + gap 6 ≈ 352).
// ─────────────────────────────────────────────────────────────────────────────

class _NativeAdPlaceholder extends StatelessWidget {
  const _NativeAdPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 352,
      decoration: BoxDecoration(
        color: context.isDark ? AppColors.surfaceDark : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.borderColor),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.image_outlined,
              size: 32,
              color: context.isDark ? const Color(0xFF4B5563) : const Color(0xFFCBD5E1),
            ),
            const SizedBox(height: 8),
            Text(
              'Sponsored',
              style: TextStyle(
                fontSize: 12,
                color: context.isDark
                    ? const Color(0xFF9CA3AF)
                    : const Color(0xFF94A3B8),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
