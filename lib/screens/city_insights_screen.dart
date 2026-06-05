import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../services/ad_service.dart';
import '../services/api_service.dart';
import 'city_comparison_screen.dart';
import '../core/constants/theme_extensions.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AD PLACEMENT STRATEGY — what changed and why
// ─────────────────────────────────────────────────────────────────────────────
//
// FIXED → Banner loaded in initState instead of didChangeDependencies
//   • The original called _loadBottomBannerAd() from initState(), which runs
//     before the widget is fully laid out. MediaQuery.of(context) inside
//     initState is unreliable — it may return incorrect dimensions on first
//     frame, producing a wrongly-sized adaptive banner.
//   • Moved to didChangeDependencies() which is guaranteed to run after the
//     first layout pass, making MediaQuery safe to use.
//
// FIXED → Deprecated fixed AdSize.banner → AnchoredAdaptiveBannerAdSize
//   • AdSize.banner (hardcoded 320×50) is deprecated and produces poor fill
//     rates and incorrect sizing on modern device widths.
//   • Replaced with AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize()
//     which correctly fills the device width.
//
// FIXED → bottomNavigationBar wrapper missing SafeArea
//   • The original Container in bottomNavigationBar had no SafeArea, meaning
//     on devices with a home indicator the banner could overlap system UI.
//   • Wrapped in SafeArea for correct inset handling.
//
// FIXED → mounted check missing in onAdLoaded
//   • setState() called in onAdLoaded without a mounted check — if the user
//     navigates away before the ad loads this causes a setState-after-dispose
//     crash. Added mounted guard.
//
// REMOVED → SizedBox(height: 100) dead-space spacer
//   • The original added 100 dp of blank space at the bottom of the scroll
//     content "for the banner ad." The correct approach is to add bottom
//     padding equal to the loaded banner height dynamically — not a hardcoded
//     blank space that wastes screen real estate when the ad hasn't loaded.
//   • Replaced with a dynamic padding value passed into the SliverToBoxAdapter.
//
// KEPT → bottomNavigationBar BannerAd placement
//   • A banner in bottomNavigationBar (when there is no nav bar) is a valid
//     anchored placement for a detail screen. Kept with the fixes above.
//
// KEPT → No interstitial on "MARKET COMPARE" button
//   • Navigating to CityComparisonScreen is a natural screen transition, which
//     is a valid interstitial trigger point. However, this screen already shows
//     a loading dialog during the city fetch — adding an interstitial on top
//     of a loading state creates a poor UX. Left as-is; if an interstitial is
//     desired, trigger it AFTER the fetch completes and BEFORE the push.
// ─────────────────────────────────────────────────────────────────────────────

class CityInsightsScreen extends StatefulWidget {
  final CityData city;

  const CityInsightsScreen({super.key, required this.city});

  @override
  State<CityInsightsScreen> createState() => _CityInsightsScreenState();
}

class _CityInsightsScreenState extends State<CityInsightsScreen> {
  BannerAd? _bottomBannerAd;
  bool _isBottomBannerAdLoaded = false;

  // Use AdService for ad unit IDs.
 final String _adUnitId = AdService.bannerAdUnitId;

  // ── Ad loading ───────────────────────────────────────────────────────────────

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // didChangeDependencies is safe for MediaQuery — layout is guaranteed here.
    if (!_isBottomBannerAdLoaded) {
      _loadBottomBannerAd();
    }
  }

  Future<void> _loadBottomBannerAd() async {
 AnchoredAdaptiveBannerAdSize? size =
        await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(
          MediaQuery.of(context).size.width.truncate(),
        );

    if (size == null || !mounted) return;

    _bottomBannerAd = BannerAd(
      adUnitId: _adUnitId,
      size: size,
      request: const AdRequest(
        contentUrl: AdContentUrl.realEstate,
        keywords: AdKeywords.realEstate,
      ),
      listener: BannerAdListener(
        onAdLoaded: (Ad ad) {
          if (mounted) {
            setState(() {
              _bottomBannerAd = ad as BannerAd;
              _isBottomBannerAdLoaded = true;
            });
          }
        },
        onAdFailedToLoad: (Ad ad, LoadAdError error) {
          debugPrint('Bottom BannerAd failed to load: $error');
          ad.dispose();
        },
      ),
    );
    await _bottomBannerAd!.load();
  }

  @override
  void dispose() {
    _bottomBannerAd?.dispose();
    super.dispose();
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────

  Color _getRatingColor(String rating) {
    if (rating == 'A+') return const Color(0xFF1E8449);
    if (rating == 'A') return const Color(0xFF27AE60);
    if (rating.startsWith('B')) return const Color(0xFFE67E22);
    if (rating.startsWith('C')) return const Color(0xFFE74C3C);
    return Colors.grey;
  }

  String _formatPopulation(int pop) {
    return pop.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // Dynamic bottom padding so last list item is never hidden behind the banner.
    final double bottomPadding = _isBottomBannerAdLoaded
        ? _bottomBannerAd!.size.height.toDouble() + 16
        : 24;

    return Scaffold(
      backgroundColor: context.pageBackground,
      // Anchored adaptive banner — sole widget in bottomNavigationBar.
      // SafeArea handles home indicator insets correctly.
      bottomNavigationBar: _isBottomBannerAdLoaded && _bottomBannerAd != null
          ? SafeArea(
              child: SizedBox(
                width: _bottomBannerAd!.size.width.toDouble(),
                height: _bottomBannerAd!.size.height.toDouble(),
                child: AdWidget(ad: _bottomBannerAd!),
              ),
            )
          : null,
      body: CustomScrollView(
        slivers: [
          // ── Hero SliverAppBar ──────────────────────────────────────────
          SliverAppBar(
            expandedHeight: MediaQuery.of(context).size.height * 0.35,
            pinned: true,
            backgroundColor: context.cs.primary,
            iconTheme: IconThemeData(color: context.cs.surface),
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(
                left: 16,
                bottom: 16,
                right: 100,
              ),
              title: Text(
                '${widget.city.city}, ${widget.city.state}',
                style: GoogleFonts.inter(
                  color: context.cs.surface,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  CachedNetworkImage(
                    imageUrl: widget.city.imageUrl.isNotEmpty
                        ? widget.city.imageUrl
                        : 'https://images.unsplash.com/photo-1449844908441-8829872d2607',
                    fit: BoxFit.cover,
                    placeholder: (context, url) =>
                        Container(color: Colors.grey.shade800),
                    errorWidget: (context, url, error) =>
                        Container(color: Colors.grey.shade800),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          context.textPrimary.withAlpha((255 * 0.7).round()),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 16,
                    right: 16,
                    child: Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: _getRatingColor(widget.city.rating),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: context.cs.surface, width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: context.textPrimary.withAlpha((255 * 0.3).round()),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'RATING',
                            style: GoogleFonts.inter(
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                              color: context.cs.surface,
                            ),
                          ),
                          Text(
                            widget.city.rating,
                            style: GoogleFonts.inter(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: context.cs.surface,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Scrollable content ─────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              // Bottom padding compensates for banner height dynamically —
              // no hardcoded 100 dp spacer needed.
              padding: EdgeInsets.fromLTRB(20, 20, 20, bottomPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Top stats grid ───────────────────────────────────
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          'MEDIAN PRICE',
                          '\$${(widget.city.medianPrice / 1000).toStringAsFixed(0)}k',
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildStatCard(
                          'PRICE / SQFT',
                          '\$${widget.city.pricePerSqft}',
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildStatCard(
                          'GROWTH',
                          '',
                          subWidget: Column(
                            children: [
                              Text(
                                '${widget.city.growthIndex}',
                                style: GoogleFonts.inter(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF1E8449),
                                ),
                              ),
                              Text(
                                widget.city.growthIndex >= 8.5
                                    ? 'HIGH'
                                    : widget.city.growthIndex >= 7.0
                                    ? 'MED'
                                    : 'LOW',
                                style: GoogleFonts.inter(
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF1E8449),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // ── Compare button ───────────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        showDialog(
                          context: context,
                          barrierDismissible: false,
                          builder: (context) =>
                              const Center(child: CircularProgressIndicator()),
                        );
                        ApisService().getCityPrices().then((cities) {
                          if (!context.mounted) return;
                          Navigator.pop(context); // close loading dialog
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => CityComparisonScreen(
                                allCities: cities,
                                initialCity: widget.city,
                              ),
                            ),
                          );
                        });
                      },
                      icon: const Icon(Icons.compare_arrows),
                      label: Text(
                        'MARKET COMPARE',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: context.cs.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 4,
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ── Market analysis card ─────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: context.cs.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border(
                        left: BorderSide(color: context.cs.primary, width: 4),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: context.textPrimary.withAlpha((255 * 0.02).round()),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'MARKET ANALYSIS',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: context.cs.primary,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '"${widget.city.description}"',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: context.textSecondary,
                            fontStyle: FontStyle.italic,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ── Detailed metrics list ────────────────────────────
                  _buildListMetric(
                    'Population',
                    _formatPopulation(widget.city.population),
                  ),
                  _buildListMetric(
                    'Median Rent',
                    '\$${widget.city.medianRent}',
                    valueColor: context.cs.primary,
                  ),
                  _buildListMetric(
                    'Demand Score',
                    '${widget.city.demandScore}/10',
                    valueColor: const Color(0xFF1E8449),
                  ),
                  _buildListMetric(
                    'Livability Score',
                    widget.city.livabilityScore.toString(),
                  ),
                  _buildListMetric(
                    'Crime Rate Index',
                    widget.city.crimeRateIndex.toString(),
                  ),
                  _buildListMetric(
                    'School Rating',
                    '${widget.city.schoolRating}/10',
                  ),
                  _buildListMetric(
                    'Property Tax Rate',
                    '${widget.city.propertyTaxRate}%',
                  ),
                  _buildListMetric(
                    'Days on Market',
                    '${widget.city.daysOnMarket} days',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Widget helpers ────────────────────────────────────────────────────────────

  Widget _buildStatCard(String title, String value, {Widget? subWidget}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.cs.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: context.textPrimary.withAlpha((255 * 0.02).round()),
            offset: const Offset(0, 2),
            blurRadius: 4,
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: context.textSecondary,
              letterSpacing: 0.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          if (subWidget != null)
            subWidget
          else
            Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: context.cs.primary,
              ),
              textAlign: TextAlign.center,
            ),
        ],
      ),
    );
  }

  Widget _buildListMetric(
    String label,
    String value, {
    Color? valueColor,
  }) {
    final color = valueColor ?? context.textPrimary;
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: context.isDark ? context.borderColor.withValues(alpha: 0.2) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w500,
              color: context.textSecondary,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.inter(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}