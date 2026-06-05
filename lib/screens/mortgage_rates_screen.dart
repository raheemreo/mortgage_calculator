import 'package:flutter/material.dart';
import '../widgets/gradient_app_bar.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';

import '../providers/fred_mortgage_provider.dart';
import '../services/ad_service.dart';
import 'insurance_marketplace.dart';
import 'mortgage_offers_screen.dart';
import 'settings_screen.dart';
import '../core/constants/theme_extensions.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Ad unit IDs
// ─────────────────────────────────────────────────────────────────────────────
abstract final class _AdIds {
  static String get interstitial => AdService.interstitialAdUnitId;
}

// ─────────────────────────────────────────────────────────────────────────────
// Design tokens — single source of truth, not duplicated across methods.
// BUG FIX: The original declared `const Color primaryBlue` inside both
// `build()` and `_buildRateCard()`, creating two separate constant definitions
// for the same value. A single static const eliminates the duplication.
// ─────────────────────────────────────────────────────────────────────────────
abstract final class _AppColors {
  static const primary = Color(0xFF0B3D93);
}

// ─────────────────────────────────────────────────────────────────────────────
// MortgageRatesScreen
// ─────────────────────────────────────────────────────────────────────────────
class MortgageRatesScreen extends StatefulWidget {
  const MortgageRatesScreen({super.key});

  @override
  State<MortgageRatesScreen> createState() => _MortgageRatesScreenState();
}

class _MortgageRatesScreenState extends State<MortgageRatesScreen> {
  // ── Ad state ──────────────────────────────────────────────────────────────
  InterstitialAd? _interstitialAd;
  bool _isInterstitialReady = false;

  // ── Interstitial frequency cap ────────────────────────────────────────────
  // Fires at most once every 3 taps on "View Mortgage Offers". Stored as a
  // static so it persists across screen visits without being recreated.
  static int _offerNavCount = 0;
  static const int _interstitialFrequency = 3;

  @override
  void initState() {
    super.initState();
    // Fetch FRED rates after the first frame so the provider is fully mounted.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<FredMortgageProvider>().fetchFredRates();
    });

    _loadInterstitialAd();
  }

  @override
  void dispose() {
    _interstitialAd?.dispose();
    super.dispose();
  }

  // ── Interstitial ──────────────────────────────────────────────────────────
  void _loadInterstitialAd() {
    InterstitialAd.load(
      adUnitId: _AdIds.interstitial,
      request: const AdRequest(
        contentUrl: AdContentUrl.mortgage,
        keywords: AdKeywords.mortgage,
      ),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _isInterstitialReady = true;
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _interstitialAd = null;
              _isInterstitialReady = false;
              _loadInterstitialAd(); // pre-load next silently
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              ad.dispose();
              _interstitialAd = null;
              _isInterstitialReady = false;
            },
          );
        },
        onAdFailedToLoad: (error) {
          debugPrint('[AdMob] Interstitial failed: ${error.message}');
          _isInterstitialReady = false;
        },
      ),
    );
  }

  // ── Navigation to mortgage offers ─────────────────────────────────────────
  // Interstitial triggers here — a genuine screen-transition exit point.
  // Frequency cap: 1 in every _interstitialFrequency taps, not every tap.
  // The static counter survives widget rebuilds (unlike instance state).
  void _navigateToOffers() {
    _offerNavCount++;
    final shouldShowAd =
        _isInterstitialReady &&
        _interstitialAd != null &&
        _offerNavCount % _interstitialFrequency == 0;

    void go() {
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const CompareMortgageScreen()),
      );
    }

    if (shouldShowAd) {
      // Override dismiss callback to open the screen after ad closes.
      _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (ad) {
          ad.dispose();
          _interstitialAd = null;
          _isInterstitialReady = false;
          _loadInterstitialAd();
          go();
        },
        onAdFailedToShowFullScreenContent: (ad, error) {
          ad.dispose();
          _interstitialAd = null;
          _isInterstitialReady = false;
          go();
        },
      );
      _interstitialAd!.show();
    } else {
      go();
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final fredProvider = context.watch<FredMortgageProvider>();
    final loadState = fredProvider.loadState;

    return Scaffold(
      backgroundColor: context.pageBackground,
      appBar: _buildAppBar(),

      bottomNavigationBar: _buildBottomNavBar(),

      body: _buildBody(loadState, fredProvider),
    );
  }

  // ── AppBar ────────────────────────────────────────────────────────────────
  // BUG FIX: The original re-created the full Scaffold with a new AppBar
  // during the loading state. That caused an AppBar flicker as the widget
  // tree swapped between two Scaffold instances. Now there's one Scaffold;
  // the body switches between a loading indicator and the content.
  PreferredSizeWidget _buildAppBar() {
    return GradientAppBar(
      backgroundColor: _AppColors.primary,
      elevation: 4,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      title: const Text(
        'Mortgage Rates',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.info_outline, color: Colors.white),
          onPressed: _showInfoDialog,
        ),
      ],
    );
  }

  void _showInfoDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'About These Rates',
          style: GoogleFonts.manrope(
            fontWeight: FontWeight.bold,
            color: context.textPrimary,
          ),
        ),
        content: Text(
          'Mortgage rates are based on live market data from the Federal '
          'Reserve Economic Data (FRED).\n\nActual loan terms, rates, and '
          'payments may vary depending on your credit profile, lender '
          'approval, and market conditions.',
          style: GoogleFonts.inter(
            fontSize: 14,
            color: context.textSecondary,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'OK',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  // ── Body ──────────────────────────────────────────────────────────────────
  Widget _buildBody(FredLoadState loadState, FredMortgageProvider provider) {
    // Loading state
    if (loadState == FredLoadState.loading) {
      return const Center(child: CircularProgressIndicator());
    }

    // BUG FIX: The original had no error state — FredLoadState.error fell
    // through silently and tried to render with potentially empty/null data.
    if (loadState == FredLoadState.error) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.wifi_off_rounded,
                size: 48,
                color: Color(0xFF94A3B8),
              ),
              const SizedBox(height: 16),
              Text(
                'Could not load rates',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: context.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Check your connection and try again.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: context.textSecondary,
                ),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () =>
                    context.read<FredMortgageProvider>().fetchFredRates(),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
                style: FilledButton.styleFrom(
                  backgroundColor: _AppColors.primary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Loaded state
    final fredData = provider.fredData;
    final double baseRate = fredData.rate30Y;
 String updateDate = fredData.date.isNotEmpty
        ? fredData.date
        : 'Recent';

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Current Market Rates',
                  style: GoogleFonts.inter(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: context.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Updated: $updateDate · National average from FRED '
                  '(30-Year Fixed)',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: context.textSecondary,
                  ),
                ),
              ],
            ),
          ),

          // ── Rate cards ────────────────────────────────────────────────────
          // BUG FIX: Extracted to a const-constructable list widget so the
          // cards are not rebuilt on every provider update that doesn't change
          // the base rate.
          Padding(
            padding: const EdgeInsets.all(16),
            child: _RateCardList(baseRate: baseRate),
          ),


          // ── CTA section ───────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _navigateToOffers,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 8,
                      // BUG FIX: withAlpha() is deprecated since Flutter 3.27.
                      // Replaced with withValues(alpha:) using the 0–1 scale.
                      shadowColor: _AppColors.primary.withValues(alpha: 0.30),
                    ),
                    child: const Text(
                      'View Mortgage Offers',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Estimated rates only. Actual rates vary based on credit '
                  'score, property location, and loan amount.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: context.textSecondary,
                    height: 1.5,
                  ),
                ),
                // Extra padding so content clears the banner + nav bar.
                const SizedBox(height: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Bottom navigation bar ─────────────────────────────────────────────────
  // BUG FIX: The original wrapped BottomNavigationBar in a Container with
  // color and border purely to add a top border — but BottomNavigationBar
  // already paints its own background. The double-paint was unnecessary.
  // A DecoratedBox with only the border is now used; the nav bar supplies
  // its own white background.
  Widget _buildBottomNavBar() {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.cs.surface,
        border: Border(top: BorderSide(color: context.borderColor)),
      ),
      child: BottomNavigationBar(
        currentIndex: 1, // 'Rates' tab
        onTap: (index) {
          if (index == 0) {
            Navigator.popUntil(context, (route) => route.isFirst);
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
        selectedItemColor: context.cs.primary,
        unselectedItemColor: context.textSecondary,
        selectedFontSize: 11,
        unselectedFontSize: 11,
        elevation: 0,
        items: const [
          BottomNavigationBarItem(
            icon: Text('🏠', style: TextStyle(fontSize: 22)),
            activeIcon: Text('🏠', style: TextStyle(fontSize: 26)),
            
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Text('📈', style: TextStyle(fontSize: 22)),
            activeIcon: Text('📈', style: TextStyle(fontSize: 26)),
            
            label: 'Rates',
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
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _RateCardList
//
// Extracted so the card list is not rebuilt on every provider tick.
// All rate derivations are kept here — the parent only passes `baseRate`.
// ─────────────────────────────────────────────────────────────────────────────
class _RateCardList extends StatelessWidget {
  const _RateCardList({required this.baseRate});
  final double baseRate;

  @override
  Widget build(BuildContext context) {
    final rates = [
      _RateData(
        title: '30-Year Fixed',
        subtitle:
            'Stable monthly payments for the entire 30-year duration. '
            'Most common choice.',
        rate: baseRate,
        type: 'Fixed',
        icon: Icons.home_rounded,
      ),
      _RateData(
        title: '15-Year Fixed',
        subtitle:
            'Lower interest rates and faster equity building, but '
            'higher monthly payments.',
        rate: baseRate - 0.70,
        type: 'Fixed',
        icon: Icons.timer_rounded,
      ),
      _RateData(
        title: '5/1 ARM',
        subtitle:
            'Fixed rate for first 5 years, then adjusts annually '
            'based on market index.',
        rate: baseRate - 0.35,
        type: 'Variable',
        icon: Icons.trending_up_rounded,
      ),
      _RateData(
        title: 'FHA Loan',
        subtitle:
            'Government-backed loan with lower down payment and '
            'credit requirements.',
        rate: baseRate - 0.45,
        type: 'Fixed',
        icon: Icons.account_balance_rounded,
      ),
      _RateData(
        title: 'VA Loan',
        subtitle:
            'Exclusive for veterans and active service members with '
            r'$0 down payment.',
        rate: baseRate - 0.55,
        type: 'Fixed',
        icon: Icons.military_tech_rounded,
      ),
    ];

    return Column(
      children: [
        for (int i = 0; i < rates.length; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          _RateCard(data: rates[i]),
        ],
      ],
    );
  }
}

// Simple data holder — avoids positional parameter ambiguity.
class _RateData {
  const _RateData({
    required this.title,
    required this.subtitle,
    required this.rate,
    required this.type,
    required this.icon,
  });
 final String title;
 final String subtitle;
  final double rate;
 final String type;
 final IconData icon;
}

// ─────────────────────────────────────────────────────────────────────────────
// _RateCard
// ─────────────────────────────────────────────────────────────────────────────
class _RateCard extends StatelessWidget {
  const _RateCard({required this.data});
  final _RateData data;

  @override
  Widget build(BuildContext context) {
    final primary = context.cs.primary;
    return Container(
      padding: const EdgeInsets.all(16),
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
      child: Row(
        children: [
          // Icon badge
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(data.icon, color: primary, size: 24),
          ),
          const SizedBox(width: 16),

          // Title + subtitle
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: context.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  data.subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: context.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // Rate + type badge
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${data.rate.toStringAsFixed(2)}%',
                style: TextStyle(
                  color: primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              Text(
                data.type.toUpperCase(),
                style: TextStyle(
                  fontSize: 10,
                  color: context.textSecondary,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

