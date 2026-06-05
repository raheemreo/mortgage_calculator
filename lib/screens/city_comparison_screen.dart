import 'package:flutter/material.dart';
import '../widgets/gradient_app_bar.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../services/ad_service.dart';
import '../services/api_service.dart';
import '../core/constants/theme_extensions.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AD PLACEMENT STRATEGY
// ─────────────────────────────────────────────────────────────────────────────
//
// BANNER AD — Anchored adaptive banner pinned to the absolute bottom edge
//   • Rendered in a fixed-height Container below the scrollable body, never
//     inside the scroll area. This eliminates accidental-click risk entirely
//     because the ad never sits under a scroll gesture start point.
//   • Uses AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize() so the
//     banner fills the screen width correctly on every device / orientation.
//   • The ad container reserves its space immediately (placeholder height)
//     so layout does not jump when the ad loads.
//   • Re-loads on orientation change via didChangeDependencies orientation
//     tracking.
//
// REMOVED — bottomSheet usage from the original version
//   • bottomSheet is a modal-style surface that can overlap content and does
//     not anchor cleanly to the screen edge on all devices. It also conflicts
//     with keyboard-aware insets. A plain Column(body + ad row) is the
//     correct pattern for a persistent bottom banner.
//
// ─────────────────────────────────────────────────────────────────────────────

class CityComparisonScreen extends StatefulWidget {
  final List<CityData> allCities;
  final CityData initialCity;

  const CityComparisonScreen({
    super.key,
    required this.allCities,
    required this.initialCity,
  });

  @override
  State<CityComparisonScreen> createState() => _CityComparisonScreenState();
}

class _CityComparisonScreenState extends State<CityComparisonScreen> {
  // ── State ──────────────────────────────────────────────────────────────────

  late CityData _cityA;
  late CityData _cityB;

  BannerAd? _bottomBannerAd;
  bool _isBottomBannerAdLoaded = false;

  // Track orientation to avoid unnecessary banner reloads.
  Orientation? _lastOrientation;

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    // Use the provided instance if it's already in the list (matching by value equality)
    // or find the first matching instance in allCities.
    _cityA = widget.allCities.firstWhere(
      (c) => c == widget.initialCity,
      orElse: () => widget.initialCity,
    );
    // Select a default City B that is different from City A.
    _cityB = widget.allCities.firstWhere(
      (c) => c.city != _cityA.city,
      orElse: () => widget.allCities.last,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final orientation = MediaQuery.orientationOf(context);
    if (_lastOrientation != orientation) {
      _lastOrientation = orientation;
      _loadBottomBannerAd();
    }
  }

  Future<void> _loadBottomBannerAd() async {
    // Dispose any existing ad before loading a new one (e.g. on rotation).
    _bottomBannerAd?.dispose();
    if (mounted) {
      setState(() {
        _bottomBannerAd = null;
        _isBottomBannerAdLoaded = false;
      });
    }
 AnchoredAdaptiveBannerAdSize? size =
        await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(
          MediaQuery.sizeOf(context).width.truncate(),
        );

    if (size == null || !mounted) return;

    final ad = BannerAd(
      adUnitId: AdService.bannerAdUnitId,
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
          debugPrint('CityComparison BannerAd failed: $error');
          ad.dispose();
        },
      ),
    );

    await ad.load();
  }

  @override
  void dispose() {
    _bottomBannerAd?.dispose();
    super.dispose();
  }

  // ── City selection ─────────────────────────────────────────────────────────

  void _onCityAChanged(CityData? newCity) {
    if (newCity == null || newCity.city == _cityA.city) return;
    setState(() {
      _cityA = newCity;
      // Swap B if both slots would show the same city.
      if (_cityB.city == _cityA.city) {
        _cityB = widget.allCities.firstWhere(
          (c) => c.city != _cityA.city,
          orElse: () => widget.allCities.last,
        );
      }
    });
  }

  void _onCityBChanged(CityData? newCity) {
    if (newCity == null || newCity.city == _cityB.city) return;
    setState(() {
      _cityB = newCity;
      if (_cityA.city == _cityB.city) {
        _cityA = widget.allCities.firstWhere(
          (c) => c.city != _cityB.city,
          orElse: () => widget.allCities.first,
        );
      }
    });
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (widget.allCities.length < 2) {
      return Scaffold(
        appBar: _buildAppBar(),
        body: const Center(child: Text('Not enough cities to compare.')),
      );
    }

    // Fixed placeholder height so layout never jumps on ad load.
    final double bannerHeight = _isBottomBannerAdLoaded
        ? _bottomBannerAd!.size.height.toDouble()
        : 50.0;

    return Scaffold(
      backgroundColor: context.pageBackground,
      appBar: _buildAppBar(),
      // ── Body: scrollable content + fixed bottom banner ──────────────────
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: Column(
                children: [
                  _buildCitySelectors(),
                  const SizedBox(height: 24),
                  _buildComparisonTable(),
                  const SizedBox(height: 24),
                  _buildAnalystCard(),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),

          // ── Anchored adaptive banner ──────────────────────────────────
          // Sits below the scroll area — never inside it. The SafeArea
          // wrapper ensures the ad clears the system navigation bar.
          SafeArea(
            top: false,
            child: Container(
              width: double.infinity,
              height: bannerHeight,
              alignment: Alignment.center,
              color: context.cs.surface,
              child: _isBottomBannerAdLoaded && _bottomBannerAd != null
                  ? SizedBox(
                      width: _bottomBannerAd!.size.width.toDouble(),
                      height: _bottomBannerAd!.size.height.toDouble(),
                      child: AdWidget(ad: _bottomBannerAd!),
                    )
                  : const SizedBox.shrink(),
            ),
          ),
        ],
      ),
    );
  }

  // ── AppBar ─────────────────────────────────────────────────────────────────

  PreferredSizeWidget _buildAppBar() {
    return GradientAppBar(
      title: Text(
        'Market Comparison',
        style: GoogleFonts.inter(
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      backgroundColor: const Color(0xFF0B3D91),
      iconTheme: const IconThemeData(color: Colors.white),
      elevation: 0,
    );
  }

  // ── City selectors ─────────────────────────────────────────────────────────

  Widget _buildCitySelectors() {
    return Row(
      children: [
        Expanded(
          child: _buildLabelledDropdown(
            label: 'CITY A',
            current: _cityA,
            onChanged: _onCityAChanged,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildLabelledDropdown(
            label: 'CITY B',
            current: _cityB,
            onChanged: _onCityBChanged,
          ),
        ),
      ],
    );
  }

  Widget _buildLabelledDropdown({
    required String label,
    required CityData current,
    required ValueChanged<CityData?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: context.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        _buildDropdown(current, onChanged),
      ],
    );
  }

  Widget _buildDropdown(
    CityData currentSelection,
    ValueChanged<CityData?> onChanged,
  ) {
    // Safety check: ensure currentSelection is in the list to avoid Flutter assertion crash.
    final bool exists = widget.allCities.any((c) => c == currentSelection);
 CityData effectiveSelection = exists ? currentSelection : widget.allCities.first;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: context.cs.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: context.borderColor),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<CityData>(
          isExpanded: true,
          value: effectiveSelection,
          icon: Icon(Icons.arrow_drop_down, color: context.primaryColor),
          dropdownColor: context.cs.surface,
          style: GoogleFonts.inter(fontSize: 14, color: context.textPrimary),
          onChanged: onChanged,
          items: (() {
            // Ensure unique items by city + state to avoid "2 or more items with same value" crash
            final seen = <String>{};
            final uniqueCities = widget.allCities.where((c) {
              final key = '${c.city}|${c.state}';
              if (seen.contains(key)) return false;
              seen.add(key);
              return true;
            }).toList();

            return uniqueCities.map((CityData city) {
              return DropdownMenuItem<CityData>(
                value: city,
                child: Text(
                  '${city.city}, ${city.state}',
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }).toList();
          }()),
        ),
      ),
    );
  }

  // ── Comparison table ───────────────────────────────────────────────────────

  Widget _buildComparisonTable() {
    // Win-count summary row.
    int aWinCount = 0;
    int bWinCount = 0;

    void tally(bool aWins, bool bWins) {
      if (aWins) aWinCount++;
      if (bWins) bWinCount++;
    }

    tally(
      _cityA.medianPrice < _cityB.medianPrice,
      _cityB.medianPrice < _cityA.medianPrice,
    );
    tally(
      _cityA.pricePerSqft < _cityB.pricePerSqft,
      _cityB.pricePerSqft < _cityA.pricePerSqft,
    );
    tally(
      _cityA.growthIndex > _cityB.growthIndex,
      _cityB.growthIndex > _cityA.growthIndex,
    );
    tally(
      _cityA.demandScore > _cityB.demandScore,
      _cityB.demandScore > _cityA.demandScore,
    );
    tally(
      _cityA.livabilityScore > _cityB.livabilityScore,
      _cityB.livabilityScore > _cityA.livabilityScore,
    );
    tally(
      _cityA.schoolRating > _cityB.schoolRating,
      _cityB.schoolRating > _cityA.schoolRating,
    );
    tally(
      _cityA.crimeRateIndex < _cityB.crimeRateIndex,
      _cityB.crimeRateIndex < _cityA.crimeRateIndex,
    );
    tally(
      _cityA.propertyTaxRate < _cityB.propertyTaxRate,
      _cityB.propertyTaxRate < _cityA.propertyTaxRate,
    );
    tally(
      _cityA.daysOnMarket < _cityB.daysOnMarket,
      _cityB.daysOnMarket < _cityA.daysOnMarket,
    );

    return Container(
      decoration: BoxDecoration(
        color: context.cs.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.borderColor),
        boxShadow: [
          BoxShadow(
            color: context.textPrimary.withValues(alpha: 0.04),
            offset: const Offset(0, 4),
            blurRadius: 8,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Column(
          children: [
            // Header
            _buildTableHeader(),

            // Data rows
            _buildComparisonRow(
              'Median Price',
              _formatK(_cityA.medianPrice),
              _formatK(_cityB.medianPrice),
              aWins: _cityA.medianPrice < _cityB.medianPrice,
              bWins: _cityB.medianPrice < _cityA.medianPrice,
            ),
            _buildComparisonRow(
              'Price / Sqft',
              '\$${_cityA.pricePerSqft}',
              '\$${_cityB.pricePerSqft}',
              aWins: _cityA.pricePerSqft < _cityB.pricePerSqft,
              bWins: _cityB.pricePerSqft < _cityA.pricePerSqft,
            ),
            _buildComparisonRow(
              'Growth Index',
              '${_cityA.growthIndex}',
              '${_cityB.growthIndex}',
              aWins: _cityA.growthIndex > _cityB.growthIndex,
              bWins: _cityB.growthIndex > _cityA.growthIndex,
            ),
            _buildComparisonRow(
              'Demand Score',
              '${_cityA.demandScore}',
              '${_cityB.demandScore}',
              aWins: _cityA.demandScore > _cityB.demandScore,
              bWins: _cityB.demandScore > _cityA.demandScore,
            ),
            _buildComparisonRow(
              'Livability',
              '${_cityA.livabilityScore}',
              '${_cityB.livabilityScore}',
              aWins: _cityA.livabilityScore > _cityB.livabilityScore,
              bWins: _cityB.livabilityScore > _cityA.livabilityScore,
            ),
            _buildComparisonRow(
              'School Rating',
              '${_cityA.schoolRating}',
              '${_cityB.schoolRating}',
              aWins: _cityA.schoolRating > _cityB.schoolRating,
              bWins: _cityB.schoolRating > _cityA.schoolRating,
            ),
            _buildComparisonRow(
              'Crime Rate',
              '${_cityA.crimeRateIndex}',
              '${_cityB.crimeRateIndex}',
              aWins: _cityA.crimeRateIndex < _cityB.crimeRateIndex,
              bWins: _cityB.crimeRateIndex < _cityA.crimeRateIndex,
            ),
            _buildComparisonRow(
              'Property Tax',
              '${_cityA.propertyTaxRate}%',
              '${_cityB.propertyTaxRate}%',
              aWins: _cityA.propertyTaxRate < _cityB.propertyTaxRate,
              bWins: _cityB.propertyTaxRate < _cityA.propertyTaxRate,
            ),
            _buildComparisonRow(
              'Days on Market',
              '${_cityA.daysOnMarket}',
              '${_cityB.daysOnMarket}',
              aWins: _cityA.daysOnMarket < _cityB.daysOnMarket,
              bWins: _cityB.daysOnMarket < _cityA.daysOnMarket,
            ),
            _buildComparisonRow('Rating', _cityA.rating, _cityB.rating),

            // Summary row
            _buildSummaryRow(aWinCount, bWinCount),
          ],
        ),
      ),
    );
  }

  Widget _buildTableHeader() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.isDark ? context.cardColor : Colors.grey.shade50,
        border: Border(bottom: BorderSide(color: context.borderColor)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              'METRIC',
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: context.textSecondary,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              _cityA.city,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: context.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              _cityB.city,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: context.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComparisonRow(
    String metric,
    String valA,
    String valB, {
    bool aWins = false,
    bool bWins = false,
  }) {
    const winColor = Color(0xFF1E8449);
    final winBg = const Color(0xFF1E8449).withValues(alpha: 0.08);

    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: context.borderColor)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                metric,
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w500,
                  color: context.textSecondary,
                  fontSize: 13,
                ),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Container(
              color: aWins ? winBg : Colors.transparent,
              padding: const EdgeInsets.all(12),
              alignment: Alignment.center,
              child: Text(
                valA,
                style: GoogleFonts.inter(
                  fontWeight: aWins ? FontWeight.bold : FontWeight.normal,
                  color: aWins ? winColor : context.textPrimary,
                  fontSize: 13,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Container(
              color: bWins ? winBg : Colors.transparent,
              padding: const EdgeInsets.all(12),
              alignment: Alignment.center,
              child: Text(
                valB,
                style: GoogleFonts.inter(
                  fontWeight: bWins ? FontWeight.bold : FontWeight.normal,
                  color: bWins ? winColor : context.textPrimary,
                  fontSize: 13,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Summary row showing total wins for each city.
  Widget _buildSummaryRow(int aWins, int bWins) {
    final aLeads = aWins > bWins;
    final bLeads = bWins > aWins;

    return Container(
      color: context.isDark ? context.cardColor : Colors.grey.shade50,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              'WINS',
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: context.textSecondary,
              ),
            ),
          ),
          Expanded(flex: 2, child: _buildWinBadge(aWins, highlight: aLeads)),
          Expanded(flex: 2, child: _buildWinBadge(bWins, highlight: bLeads)),
        ],
      ),
    );
  }

  Widget _buildWinBadge(int count, {required bool highlight}) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: highlight
              ? const Color(0xFF1E8449).withValues(alpha: 0.12)
              : (context.isDark ? Colors.grey.shade800 : Colors.grey.shade200),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          '$count',
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: highlight ? const Color(0xFF1E8449) : (context.isDark ? Colors.grey.shade400 : Colors.grey.shade600),
          ),
        ),
      ),
    );
  }

  // ── Analyst perspective card ───────────────────────────────────────────────

  Widget _buildAnalystCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF0B3D91),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: context.textPrimary.withValues(alpha: 0.12),
            offset: const Offset(0, 4),
            blurRadius: 12,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.analytics, color: Color(0xFF27AE60), size: 24),
              const SizedBox(width: 8),
              Text(
                'ANALYST PERSPECTIVE',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _generatePerspective(),
            style: GoogleFonts.inter(
              fontSize: 13,
              height: 1.5,
              color: Colors.blue.shade50,
            ),
          ),
        ],
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  String _formatK(int val) => '\$${(val / 1000).toStringAsFixed(0)}k';

  /// Generates a short analyst blurb. Handles the equal-price edge case.
  String _generatePerspective() {
    final samePrice = _cityA.medianPrice == _cityB.medianPrice;
 CityData cheaper;
 CityData pricier;

    if (samePrice) {
      cheaper = _cityA;
      pricier = _cityB;
    } else if (_cityA.medianPrice < _cityB.medianPrice) {
      cheaper = _cityA;
      pricier = _cityB;
    } else {
      cheaper = _cityB;
      pricier = _cityA;
    }

    final highGrowth = _cityA.growthIndex >= _cityB.growthIndex
        ? _cityA
        : _cityB;

    if (samePrice) {
      return '${_cityA.city} and ${_cityB.city} share an identical median price '
          'of ${_formatK(_cityA.medianPrice)}, making growth index the key '
          'differentiator. ${highGrowth.city} leads with a growth index of '
          '${highGrowth.growthIndex}, making it the stronger pick for appreciation.';
    }

    return 'While ${cheaper.city} offers a more accessible entry point '
        '(${_formatK(cheaper.medianPrice)}), ${pricier.city} commands a premium '
        'that may reflect stronger fundamentals. Investors prioritising appreciation '
        'may favour ${highGrowth.city}, which leads with a growth index of '
        '${highGrowth.growthIndex}.';
  }
}