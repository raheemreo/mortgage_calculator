// compare_all_offers_screen.dart
// ─────────────────────────────────────────────────────────────────────────────
// CompareAllOffersScreen — reads live FRED data from FredMortgageProvider.
// All lender rates, APRs and monthly payments are live-computed.
//
// AdMob placements:
//  • Anchored adaptive Banner  → above the BottomNavigationBar (safe zone)
//  • Native Ad                 → naturally integrated between content sections
//  • Interstitial              → shown only on intentional user navigation taps
//    (never auto-triggered; never blocks back-navigation; loaded once per session)
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import '../widgets/gradient_app_bar.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../providers/fred_mortgage_provider.dart';
import '../services/ad_service.dart';
import 'lenders_in_usa_screen.dart';
import 'insurance_marketplace.dart';
import 'settings_screen.dart';
import '../core/constants/theme_extensions.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  DESIGN TOKENS  (single source of truth — never scatter Magic colours)
// ─────────────────────────────────────────────────────────────────────────────
abstract final class _AppColors {
  static const primary = Color(0xFF0B3D91);
  static const accent = Color(0xFF1E4ED8);
  static const emerald = Color(0xFF10B981);
  static const slate100 = Color(0xFFF1F5F9);
  static const successBg = Color(0xFFDCFCE7);
  static const successFg = Color(0xFF16A34A);
  static const errorBg = Color(0xFFFEF2F2);
  static const errorFg = Color(0xFFDC2626);
}

// ─────────────────────────────────────────────────────────────────────────────
//  SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class CompareAllOffersScreen extends StatefulWidget {
  const CompareAllOffersScreen({super.key});

  @override
  State<CompareAllOffersScreen> createState() => _CompareAllOffersScreenState();
}

class _CompareAllOffersScreenState extends State<CompareAllOffersScreen> {
  // ── Keys / controllers ─────────────────────
  final GlobalKey _tableKey = GlobalKey();
  final ScrollController _scroll = ScrollController();

  // ─────────────────────────────────────────────
  //  LIFECYCLE
  // ─────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    AdService().loadInterstitialAd(
      request: const AdRequest(
        contentUrl: AdContentUrl.mortgage,
        keywords: AdKeywords.mortgage,
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<FredMortgageProvider>();
      if (provider.loadState == FredLoadState.idle) {
        provider.fetchFredRates();
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────
  //  AD LOGIC
  // ─────────────────────────────────────────────

  /// Shows an interstitial ad using the centralized AdService.
  /// This automatically enforces the "time limits" (cooldowns).
  void _showInterstitial({required VoidCallback onAdDismissed}) {
    // We use ignoreThreshold: true here because these navigation taps
    // are intentional and should be governed primarily by the cooldown.
    AdService().showInterstitialAd(
      onAdClosed: onAdDismissed,
      ignoreThreshold: true,
    );
  }

  // ─────────────────────────────────────────────
  //  NAVIGATION HELPERS
  // ─────────────────────────────────────────────

  void _scrollToTable() {
    _showInterstitial(
      onAdDismissed: () {
        final ctx = _tableKey.currentContext;
        if (ctx == null || !mounted) return;
        Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      },
    );
  }

  void _goToLenderDetails(LenderOffer offer) {
    _showInterstitial(
      onAdDismissed: () {
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const LendersInUsaScreen()),
        );
      },
    );
  }

  void _onBottomNavTap(int index) {
    switch (index) {
      case 0:
        Navigator.popUntil(context, (r) => r.isFirst);
      case 1:
        // Already on this screen — no-op.
        break;
      case 2:
        _showInterstitial(
          onAdDismissed: () {
            if (!mounted) return;
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => const InsuranceMarketplaceScreen(),
              ),
            );
          },
        );
      case 3:
        _showInterstitial(
          onAdDismissed: () {
            if (!mounted) return;
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            );
          },
        );
    }
  }

  // ─────────────────────────────────────────────
  //  BUILD
  // ─────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.pageBackground,
      appBar: _buildAppBar(),
      body: SingleChildScrollView(
        // Bottom padding accounts for nav bar.
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 80),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildFredSection(),
            const SizedBox(height: 24),
            _buildCompareAllButton(),
            const SizedBox(height: 28),
            _buildPersonalizedOffers(),
            const SizedBox(height: 28),
            // ── Native Ad ──────────────────────────────────────────────────
            // Placed between Personalized Offers and the Comparison Table so
            // it appears as a natural content card — not adjacent to any
            // interactive element, preventing accidental taps.
            const _NativeOfferAd(),
            const SizedBox(height: 28),
            _buildComparisonTable(),
            const SizedBox(height: 40),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  // ─────────────────────────────────────────────
  //  APP BAR
  // ─────────────────────────────────────────────

  PreferredSizeWidget _buildAppBar() {
    return GradientAppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        tooltip: 'Back',
        onPressed: () => Navigator.pop(context),
      ),
      title: Text(
        'Compare All Offers',
        style: GoogleFonts.manrope(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(
            Icons.notifications_none,
            color: Colors.white70,
          ),
          tooltip: 'Notifications',
          onPressed: () {
            // Notifications implemented in specific service classes
          },
        ),
      ],
      bottom: const PreferredSize(
        preferredSize: Size.fromHeight(1),
        child: Divider(height: 1, color: Colors.white24),
      ),
    );
  }

  // ─────────────────────────────────────────────
  //  FRED SECTION
  // ─────────────────────────────────────────────

  Widget _buildFredSection() {
    return Consumer<FredMortgageProvider>(
      builder: (context, provider, _) {
        final data = provider.fredData;
        final isLoading = provider.loadState == FredLoadState.loading;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section header
            Row(
              children: [
                const Icon(
                  Icons.trending_up,
                  color: _AppColors.successFg,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'FRED Live Market Rates',
                  style: GoogleFonts.manrope(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: context.textPrimary,
                  ),
                ),
                const Spacer(),
                _FredStatusBadge(state: provider.loadState),
              ],
            ),
            if (data.date.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                'As of ${data.date}',
                style: TextStyle(
                  fontSize: 11,
                  color: context.textSecondary,
                ),
              ),
            ],
            const SizedBox(height: 12),

            // Error banner (shown under the header, not inside the card list)
            if (provider.loadState == FredLoadState.error &&
                provider.errorMessage != null)
              _ErrorBanner(message: provider.errorMessage!),

            // Rate cards
            SizedBox(
              height: 148,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _RateCard(
                    label: '30-Y Fixed',
                    labelBg: const Color(0xFFDBEAFE),
                    labelColor: const Color(0xFF1D4ED8),
                    rate: isLoading
                        ? null
                        : FredMortgageProvider.fmtPct(data.rate30Y),
                    subtitle: 'National avg 30-yr fixed mortgage',
                    change: isLoading ? null : data.weeklyChange,
                    isLoading: isLoading,
                  ),
                  const SizedBox(width: 12),
                  _RateCard(
                    label: '15-Y Fixed',
                    labelBg: const Color(0xFFD1FAE5),
                    labelColor: const Color(0xFF059669),
                    rate: isLoading
                        ? null
                        : FredMortgageProvider.fmtPct(data.rate15Y),
                    subtitle: 'Faster equity, lower total interest',
                    isLoading: isLoading,
                  ),
                  const SizedBox(width: 12),
                  _RateCard(
                    label: '5/1 ARM',
                    labelBg: const Color(0xFFFFE4E6),
                    labelColor: const Color(0xFFE11D48),
                    rate: isLoading
                        ? null
                        : FredMortgageProvider.fmtPct(data.rateArm51),
                    subtitle: 'Adjustable after 5-yr initial period',
                    sourceLabel: 'Est. Spread',
                    isLoading: isLoading,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  // ─────────────────────────────────────────────
  //  COMPARE ALL BUTTON
  // ─────────────────────────────────────────────

  Widget _buildCompareAllButton() => SizedBox(
    width: double.infinity,
    child: ElevatedButton.icon(
      onPressed: _scrollToTable,
      icon: const Icon(Icons.compare_arrows),
      label: const Text('Compare All Offers Side by Side'),
      style: ElevatedButton.styleFrom(
        backgroundColor: _AppColors.accent,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 3,
        shadowColor: _AppColors.accent.withValues(alpha: 0.3),
        textStyle: GoogleFonts.manrope(
          fontSize: 15,
          fontWeight: FontWeight.w800,
        ),
      ),
    ),
  );

  // ─────────────────────────────────────────────
  //  PERSONALIZED OFFERS
  // ─────────────────────────────────────────────

  Widget _buildPersonalizedOffers() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Row(
          children: [
            Icon(Icons.verified, color: context.primaryColor, size: 20),
            const SizedBox(width: 8),
            Text(
              'Personalized Offers',
              style: GoogleFonts.manrope(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: context.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        Consumer<FredMortgageProvider>(
          builder: (context, provider, _) {
            // Loading skeleton
            if (provider.loadState == FredLoadState.loading) {
              return Column(
                children: List.generate(
                  3,
                  (_) => const Padding(
                    padding: EdgeInsets.only(bottom: 14),
                    child: _ShimmerBox(
                      width: double.infinity,
                      height: 200,
                      radius: 16,
                    ),
                  ),
                ),
              );
            }

            final offers = provider.sortedOffers;

            if (offers.isEmpty) {
              return const _EmptyOffersPlaceholder();
            }

            return Column(
              children: [
                for (var i = 0; i < offers.length; i++) ...[
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: _OfferCard(
                      offer: offers[i],
                      onSelect: () => _goToLenderDetails(offers[i]),
                    ),
                  ),
                  // ── AdMob Native Ad (between 2nd & 3rd card) ──
                  // Policy compliance:
                  //  • §3.1 — "Sponsored" label + info icon disclosure
                  //  • §3.3 — 14px spacing from adjacent interactive cards
                  //  • Minimum 340px ad container height (validator safe)
                  //  • Hides entirely if ad fails to load (no empty space)
                  if (i == 1)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 14),
                      child: _NativeOfferAd(),
                    ),
                ],
              ],
            );
          },
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────
  //  COMPARISON TABLE
  // ─────────────────────────────────────────────

  Widget _buildComparisonTable() {
    return Column(
      key: _tableKey,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Row(
          children: [
            Icon(
              Icons.table_chart_outlined,
              color: context.primaryColor,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              'Detailed Comparison',
              style: GoogleFonts.manrope(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: context.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        Consumer<FredMortgageProvider>(
          builder: (context, provider, _) {
            final offers = provider.sortedOffers;
            if (offers.isEmpty) return const SizedBox.shrink();

            return Container(
              decoration: BoxDecoration(
                color: context.cs.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: context.borderColor),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x05000000),
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Table(
                  columnWidths: const {
                    0: FlexColumnWidth(1.8),
                    1: FlexColumnWidth(1),
                    2: FlexColumnWidth(1),
                    3: FlexColumnWidth(1.3),
                  },
                  children: [
                    _tableHeader(),
                    for (var i = 0; i < offers.length; i++)
                      _tableRow(offers[i], i),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  TableRow _tableHeader() => TableRow(
    decoration: BoxDecoration(color: context.isDark ? context.cardColor : const Color(0xFFF8FAFC)),
    children: [
      'Lender',
      'Rate',
      'APR',
      'Monthly',
    ].map((h) => _TableCell(text: h, isHeader: true)).toList(),
  );

  TableRow _tableRow(LenderOffer offer, int index) {
    final isTop = index == 0;
    return TableRow(
      decoration: BoxDecoration(
        color: isTop ? context.primaryColor.withValues(alpha: 0.1) : context.cs.surface,
        border: Border(top: BorderSide(color: context.borderColor)),
      ),
      children: [
        _TableCell(text: offer.name.split(' ').first, bold: true),
        _TableCell(
          text: FredMortgageProvider.fmtPct(offer.rate),
          color: isTop ? _AppColors.emerald : null,
          bold: isTop,
        ),
        _TableCell(text: FredMortgageProvider.fmtPct(offer.apr)),
        _TableCell(
          text: FredMortgageProvider.fmtCurrency(offer.monthlyTotal),
          bold: true,
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────
  //  BOTTOM NAV  (banner lives here — safe zone)
  // ─────────────────────────────────────────────

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: context.cs.surface,
        border: Border(top: BorderSide(color: context.borderColor)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Banner Ad removed.
          BottomNavigationBar(
            currentIndex: 1,
            onTap: _onBottomNavTap,
            type: BottomNavigationBarType.fixed,
            backgroundColor: context.cs.surface,
            selectedItemColor: context.cs.primary,
            unselectedItemColor: context.textSecondary,
            selectedFontSize: 10,
            unselectedFontSize: 10,
            elevation: 0,
            items: const [
              BottomNavigationBarItem(
                icon: Text('🏠', style: TextStyle(fontSize: 22)),
                activeIcon: Text('🏠', style: TextStyle(fontSize: 26)),
                
                
                
                
                
                
                
                label: 'Home',
              ),
              BottomNavigationBarItem(
                icon: Text('⚖️', style: TextStyle(fontSize: 22)),
                activeIcon: Text('⚖️', style: TextStyle(fontSize: 26)),
                
                
                
                
                
                
                
                label: 'Compare',
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
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  TABLE CELL  (extracted from the state class — now a proper widget)
// ─────────────────────────────────────────────────────────────────────────────

class _TableCell extends StatelessWidget {
  final String text;
  final bool isHeader;
  final bool bold;
  final Color? color;

  const _TableCell({
    required this.text,
    this.isHeader = false,
    this.bold = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 13,
        fontWeight: isHeader
            ? FontWeight.w700
            : bold
            ? FontWeight.w800
            : FontWeight.w500,
        color: color ?? (isHeader ? context.textSecondary : context.textPrimary),
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  NATIVE AD WIDGET
// ─────────────────────────────────────────────────────────────────────────────

/// Native ad rendered as a clearly-labelled sponsored card.
/// The "Sponsored" badge + info icon are required visual disclosures under
/// Google AdMob policy. The card is placed in a content area with adequate
/// spacing (28 px above and below) to prevent accidental taps.
class _NativeOfferAd extends StatefulWidget {
  const _NativeOfferAd();

  @override
  State<_NativeOfferAd> createState() => _NativeOfferAdState();
}

class _NativeOfferAdState extends State<_NativeOfferAd> {
  NativeAd? _ad;
  bool _isLoaded = false;

  /// AdMob policy: use NativeTemplateStyle (medium) — a built-in SDK template
  /// that does NOT require any custom platform factory registration.
  /// This is the correct out-of-the-box Flutter AdMob approach.
  static const _kAdHeight = 340.0;

  @override
  void initState() {
    super.initState();
    _loadAd();
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  void _loadAd() {
    _ad = NativeAd(
      adUnitId: AdService.nativeAdUnitId,
      // NativeTemplateStyle uses the SDK's built-in medium template.
      // No MainActivity.kt / AppDelegate.swift factory registration needed.
      nativeTemplateStyle: NativeTemplateStyle(
        templateType: TemplateType.medium,
        mainBackgroundColor: context.isDark ? context.cardColor : Colors.white,
        cornerRadius: 12.0,
        callToActionTextStyle: NativeTemplateTextStyle(
          textColor: context.isDark ? Colors.black : Colors.white,
          backgroundColor: context.primaryColor,
          style: NativeTemplateFontStyle.bold,
          size: 14.0,
        ),
        primaryTextStyle: NativeTemplateTextStyle(
          textColor: context.isDark ? Colors.white : const Color(0xFF0F172A),
          style: NativeTemplateFontStyle.bold,
          size: 15.0,
        ),
        secondaryTextStyle: NativeTemplateTextStyle(
          textColor: context.isDark ? Colors.white70 : const Color(0xFF64748B),
          style: NativeTemplateFontStyle.normal,
          size: 13.0,
        ),
        tertiaryTextStyle: NativeTemplateTextStyle(
          textColor: context.isDark ? Colors.white54 : const Color(0xFF94A3B8),
          style: NativeTemplateFontStyle.normal,
          size: 12.0,
        ),
      ),
      request: const AdRequest(
        contentUrl: AdContentUrl.mortgage,
        keywords: AdKeywords.mortgage,
      ),
      listener: NativeAdListener(
        onAdLoaded: (_) {
          if (mounted) setState(() => _isLoaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('[AdMob] Native ad failed: $error');
          ad.dispose();
        },
      ),
    )..load();
  }

  @override
  Widget build(BuildContext context) {
    // Hide entirely until the ad is ready — no empty space shown.
    if (!_isLoaded || _ad == null) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: context.cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.borderColor),
        boxShadow: [
          BoxShadow(
            color: context.textPrimary.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      // ── Policy-required disclosure header ─────────────────────────────────
      // Google AdMob policy §3.1: Ads must be clearly identified as ads.
      // The "Sponsored" label + info icon fulfil this requirement.
      // Adequate surrounding spacing (28 px above, 28 px below the card in the
      // parent Column) prevents accidental taps per §3.3.
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: context.isDark ? context.inputFill : _AppColors.slate100,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Sponsored',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: context.textSecondary,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                const Spacer(),
                Tooltip(
                  message: 'This is a paid advertisement',
                  child: Icon(
                    Icons.info_outline,
                    size: 15,
                    color: context.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // ── Ad content (min 340 px height required by AdMob validator) ────
          SizedBox(
            height: _kAdHeight,
            child: AdWidget(ad: _ad!),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  OFFER CARD
// ─────────────────────────────────────────────────────────────────────────────

class _OfferCard extends StatelessWidget {
  final LenderOffer offer;
  final VoidCallback onSelect;

  const _OfferCard({required this.offer, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.borderColor),
        boxShadow: [
          BoxShadow(
            color: context.textPrimary.withValues(alpha: 0.07),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildHeader(context),
          Divider(height: 1, color: context.borderColor),
          _buildBody(context),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Row(
        children: [
          _LogoWidget(url: offer.logoUrl),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  offer.name,
                  style: GoogleFonts.manrope(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: context.textPrimary,
                  ),
                ),
                Text(
                  offer.loanTerm,
                  style: TextStyle(
                    fontSize: 12,
                    color: context.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (offer.isTopMatch) const _TopMatchBadge(),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Rate / APR + Monthly payment
          Row(
            children: [
              Expanded(child: _buildRateColumn(context)),
              _buildMonthlyColumn(context),
            ],
          ),
          const SizedBox(height: 14),
          // Fee breakdown
          _FeeBreakdown(
            estimatedFees: offer.estimatedFees,
            closingCosts: offer.closingCosts,
          ),
          const SizedBox(height: 14),
          // CTA button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onSelect,
              style: ElevatedButton.styleFrom(
                backgroundColor: _AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
                shadowColor: _AppColors.primary.withValues(alpha: 0.25),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Select Offer',
                    style: GoogleFonts.manrope(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.chevron_right, size: 18),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRateColumn(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _FieldLabel('RATE / APR'),
        const SizedBox(height: 4),
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: '${offer.rate.toStringAsFixed(3)}%',
                style: GoogleFonts.manrope(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: _AppColors.emerald,
                ),
              ),
              TextSpan(
                text: '  / ${offer.apr.toStringAsFixed(2)}%',
                style: TextStyle(
                  fontSize: 13,
                  color: context.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMonthlyColumn(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        const _FieldLabel('MONTHLY P&I'),
        const SizedBox(height: 4),
        Text(
          FredMortgageProvider.fmtCurrency(offer.monthlyTotal),
          style: GoogleFonts.manrope(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: context.primaryColor,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  SMALL REUSABLE WIDGETS
// ─────────────────────────────────────────────────────────────────────────────

class _FieldLabel extends StatelessWidget {
 final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: TextStyle(
      fontSize: 10,
      fontWeight: FontWeight.w700,
      color: context.textSecondary,
      letterSpacing: 0.7,
    ),
  );
}

class _TopMatchBadge extends StatelessWidget {
  const _TopMatchBadge();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: _AppColors.successBg,
      borderRadius: BorderRadius.circular(6),
    ),
    child: const Text(
      'TOP MATCH',
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w800,
        color: _AppColors.successFg,
        letterSpacing: 0.5,
      ),
    ),
  );
}

class _LogoWidget extends StatelessWidget {
 final String url;
  const _LogoWidget({required this.url});

  @override
  Widget build(BuildContext context) => Container(
    width: 48,
    height: 48,
    decoration: BoxDecoration(
      color: context.isDark ? context.inputFill : _AppColors.slate100,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: context.borderColor),
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Image.network(
        url,
        width: 40,
        height: 40,
        fit: BoxFit.contain,
        // Graceful fallback using single wildcards to satisfy lint preferences
        errorBuilder: (_, _, _) =>
            Icon(Icons.account_balance, color: context.textSecondary),
      ),
    ),
  );
}

class _FeeBreakdown extends StatelessWidget {
  final double estimatedFees;
  final double closingCosts;
  const _FeeBreakdown({
    required this.estimatedFees,
    required this.closingCosts,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: context.isDark ? context.inputFill : const Color(0xFFF8FAFC),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Column(
      children: [
        _FeeRow(label: 'Estimated Fees', value: '\$$estimatedFees'),
        const SizedBox(height: 8),
        _FeeRow(label: 'Closing Costs', value: '\$$closingCosts'),
      ],
    ),
  );
}

class _FeeRow extends StatelessWidget {
 final String label;
 final String value;
  const _FeeRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(
        label,
        style: TextStyle(fontSize: 13, color: context.textSecondary),
      ),
      Text(
        value,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: context.textPrimary,
        ),
      ),
    ],
  );
}

class _EmptyOffersPlaceholder extends StatelessWidget {
  const _EmptyOffersPlaceholder();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 32),
    child: Center(
      child: Column(
        children: [
          Icon(
            Icons.inbox_outlined,
            size: 40,
            color: context.textSecondary,
          ),
          const SizedBox(height: 8),
          Text(
            'No offers available',
            style: GoogleFonts.manrope(
              fontSize: 14,
              color: context.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  FRED STATUS BADGE
// ─────────────────────────────────────────────────────────────────────────────

class _FredStatusBadge extends StatelessWidget {
  final FredLoadState state;
  const _FredStatusBadge({required this.state});

  @override
  Widget build(BuildContext context) {
    return switch (state) {
      FredLoadState.loading => _chip(
        'LOADING',
        context.isDark ? context.inputFill : _AppColors.slate100,
        context.textSecondary,
        spinner: true,
      ),
      FredLoadState.loaded => _chip(
        'LIVE',
        context.isDark ? _AppColors.emerald.withValues(alpha: 0.15) : _AppColors.successBg,
        context.isDark ? Colors.green.shade300 : _AppColors.successFg,
        dot: true,
      ),
      FredLoadState.error => _chip(
        'EST. DATA',
        context.isDark ? Colors.red.withValues(alpha: 0.15) : _AppColors.errorBg,
        context.isDark ? Colors.red.shade300 : _AppColors.errorFg,
      ),
      FredLoadState.idle => const SizedBox.shrink(),
    };
  }

  Widget _chip(
    String label,
    Color bg,
    Color fg, {
    bool spinner = false,
    bool dot = false,
  }) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(4),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (spinner)
          SizedBox(
            width: 8,
            height: 8,
            child: CircularProgressIndicator(strokeWidth: 1.5, color: fg),
          ),
        if (dot) CircleAvatar(radius: 3, backgroundColor: fg),
        if (spinner || dot) const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: fg,
            letterSpacing: 0.5,
          ),
        ),
      ],
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  RATE CARD
// ─────────────────────────────────────────────────────────────────────────────

class _RateCard extends StatelessWidget {
  final String label;
  final String subtitle;
  final Color labelBg;
  final Color labelColor;
  final String? rate;
  final double? change;
  final bool isLoading;
  final String sourceLabel;

  const _RateCard({
    required this.label,
    required this.labelBg,
    required this.labelColor,
    required this.rate,
    required this.subtitle,
    this.change,
    this.isLoading = false,
    this.sourceLabel = 'Source: FRED',
  });

  @override
  Widget build(BuildContext context) => Container(
    width: 200,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: context.cs.surface,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: context.borderColor),
      boxShadow: [
        BoxShadow(
          color: context.textPrimary.withValues(alpha: 0.05),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label + source
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: labelBg,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: labelColor,
                ),
              ),
            ),
            Text(
              sourceLabel,
              style: TextStyle(fontSize: 10, color: context.textSecondary),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Rate value or shimmer
        isLoading
            ? const _ShimmerBox(width: 100, height: 30, radius: 5)
            : Text(
                rate ?? '—',
                style: GoogleFonts.manrope(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: context.textPrimary,
                ),
              ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: TextStyle(fontSize: 11, color: context.textSecondary),
          maxLines: 2,
        ),
        if (change != null) ...[
          const SizedBox(height: 6),
          _RateChangeBadge(change: change!),
        ],
      ],
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  RATE CHANGE BADGE
// ─────────────────────────────────────────────────────────────────────────────

class _RateChangeBadge extends StatelessWidget {
  final double change;
  const _RateChangeBadge({required this.change});

  @override
  Widget build(BuildContext context) {
    final bps = (change * 100).round();
    if (bps == 0) {
      return _pill('No change wk', context.isDark ? context.inputFill : _AppColors.slate100, context.textSecondary);
    }
    final isUp = bps > 0;
    return _pill(
      '${isUp ? '▲' : '▼'} ${bps.abs()} bps wk',
      isUp ? _AppColors.errorBg : _AppColors.successBg,
      isUp ? _AppColors.errorFg : _AppColors.successFg,
    );
  }

  Widget _pill(String label, Color bg, Color fg) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(4),
    ),
    child: Text(
      label,
      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: fg),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  ERROR BANNER
// ─────────────────────────────────────────────────────────────────────────────

class _ErrorBanner extends StatelessWidget {
 final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: _AppColors.errorBg,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: const Color(0xFFFECACA)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.warning_amber_rounded,
          color: _AppColors.errorFg,
          size: 16,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            message,
            style: const TextStyle(fontSize: 12, color: _AppColors.errorFg),
          ),
        ),
      ],
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  SHIMMER BOX
// ─────────────────────────────────────────────────────────────────────────────

class _ShimmerBox extends StatefulWidget {
  final double width;
  final double height;
  final double radius;

  const _ShimmerBox({
    required this.width,
    required this.height,
    required this.radius,
  });

  @override
  State<_ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<_ShimmerBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _opacity = Tween<double>(
      begin: 0.3,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: _opacity,
    child: Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: context.borderColor,
        borderRadius: BorderRadius.circular(widget.radius),
      ),
    ),
  );
}