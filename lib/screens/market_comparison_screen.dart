import 'dart:math';
import '../widgets/gradient_app_bar.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../services/ad_service.dart';
import 'insurance_marketplace.dart';
import 'settings_screen.dart';
import '../core/constants/theme_extensions.dart';

// ── Data model for one city's comparison data ──────────────────────────────
class CityCompareData {
 final String city;
 final String state;
  final int rawPrice;
  final double pricePerSqft;
  final int daysOnMarket;
  final int inventoryCount;
  final double yearOverYearPct;

  const CityCompareData({
    required this.city,
    required this.state,
    required this.rawPrice,
    required this.pricePerSqft,
    required this.daysOnMarket,
    required this.inventoryCount,
    required this.yearOverYearPct,
  });

  String get formattedPrice {
    if (rawPrice >= 1000000) {
      return '\$${(rawPrice / 1000000).toStringAsFixed(2)}M';
    }
    final k = rawPrice ~/ 1000;
    return '\$${k}k';
  }

  String get label => '$city, $state';
}

// ── Static comparison city pool ──────────────────────────────────────────
const List<CityCompareData> _allCities = [
  CityCompareData(
    city: 'San Francisco',
    state: 'CA',
    rawPrice: 1450000,
    pricePerSqft: 1150,
    daysOnMarket: 21,
    inventoryCount: 980,
    yearOverYearPct: 6.2,
  ),
  CityCompareData(
    city: 'Los Angeles',
    state: 'CA',
    rawPrice: 920000,
    pricePerSqft: 785,
    daysOnMarket: 42,
    inventoryCount: 1420,
    yearOverYearPct: 5.0,
  ),
  CityCompareData(
    city: 'Seattle',
    state: 'WA',
    rawPrice: 980000,
    pricePerSqft: 680,
    daysOnMarket: 18,
    inventoryCount: 730,
    yearOverYearPct: 7.1,
  ),
  CityCompareData(
    city: 'New York',
    state: 'NY',
    rawPrice: 760000,
    pricePerSqft: 920,
    daysOnMarket: 55,
    inventoryCount: 2100,
    yearOverYearPct: 3.8,
  ),
  CityCompareData(
    city: 'Austin',
    state: 'TX',
    rawPrice: 650000,
    pricePerSqft: 520,
    daysOnMarket: 33,
    inventoryCount: 1100,
    yearOverYearPct: 4.5,
  ),
  CityCompareData(
    city: 'Miami',
    state: 'FL',
    rawPrice: 480000,
    pricePerSqft: 610,
    daysOnMarket: 48,
    inventoryCount: 1650,
    yearOverYearPct: 8.3,
  ),
  CityCompareData(
    city: 'Phoenix',
    state: 'AZ',
    rawPrice: 420000,
    pricePerSqft: 280,
    daysOnMarket: 62,
    inventoryCount: 1900,
    yearOverYearPct: 2.1,
  ),
  CityCompareData(
    city: 'Chicago',
    state: 'IL',
    rawPrice: 390000,
    pricePerSqft: 230,
    daysOnMarket: 70,
    inventoryCount: 2400,
    yearOverYearPct: 1.5,
  ),
  CityCompareData(
    city: 'Houston',
    state: 'TX',
    rawPrice: 350000,
    pricePerSqft: 180,
    daysOnMarket: 80,
    inventoryCount: 3200,
    yearOverYearPct: 0.8,
  ),
];

// ── Screen ─────────────────────────────────────────────────────────────────
class MarketComparisonScreen extends StatefulWidget {
  final CityCompareData locationA;

  const MarketComparisonScreen({super.key, required this.locationA});

  @override
  State<MarketComparisonScreen> createState() => _MarketComparisonScreenState();
}

class _MarketComparisonScreenState extends State<MarketComparisonScreen> {
  static const Color _primaryBlue = Color(0xFF0B3D93);

  int _viewIndex = 0; // 0=Cities, 1=Neighborhoods
  int _chartRange = 0; // 0=1Y, 1=3Y, 2=5Y
  late CityCompareData _locationB;

  // Pseudo–random monthly data for charts
  static const List<double> _chartDataA = [
    0.60,
    0.65,
    0.58,
    0.70,
    0.75,
    0.68,
    0.72,
    0.80,
  ];
  static const List<double> _chartDataB = [
    0.75,
    0.72,
    0.80,
    0.85,
    0.82,
    0.90,
    0.88,
    0.92,
  ];

  // AdMob Variables
  BannerAd? _bannerAd;
  bool _isBannerAdLoaded = false;
  NativeAd? _nativeAd;
  bool _isNativeAdLoaded = false;

  @override
  void initState() {
    super.initState();
    _locationB = _allCities.firstWhere(
      (c) => c.city != widget.locationA.city,
      orElse: () => _allCities.last,
    );

    // Initialize Ads via centralized AdService
    _loadBannerAd();
    _loadNativeAd();
    AdService().loadInterstitialAd();
  }

  @override
  void dispose() {
    // AdService manages interstitial lifecycle, but we still dispose local banner/native if any
    _bannerAd?.dispose();
    _nativeAd?.dispose();
    super.dispose();
  }

  // ── AdMob Loading Methods — using AdService unit IDs ──────────────────────
  void _loadBannerAd() {
    _bannerAd = BannerAd(
      adUnitId: AdService.bannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(
        contentUrl: AdContentUrl.realEstate,
        keywords: AdKeywords.realEstate,
      ),
      listener: BannerAdListener(
        onAdLoaded: (_) => setState(() => _isBannerAdLoaded = true),
        onAdFailedToLoad: (ad, error) {
          debugPrint('BannerAd failed to load: $error');
          ad.dispose();
        },
      ),
    )..load();
  }

  void _loadNativeAd() {
    _nativeAd = NativeAd(
      adUnitId: AdService.nativeAdUnitId,
      request: const AdRequest(
        contentUrl: AdContentUrl.realEstate,
        keywords: AdKeywords.realEstate,
      ),
      listener: NativeAdListener(
        onAdLoaded: (_) => setState(() => _isNativeAdLoaded = true),
        onAdFailedToLoad: (ad, error) {
          debugPrint('NativeAd failed to load: $error');
          ad.dispose();
        },
      ),
      nativeTemplateStyle: NativeTemplateStyle(
        templateType: TemplateType.medium,
        mainBackgroundColor: context.cs.surface,
        cornerRadius: 14.0,
      ),
    )..load();
  }

  // Triggers Interstitial Ad Contextually when changing comparisons using AdService
  void _handleCitySelectionChange(CityCompareData newCity) {
    AdService().showInterstitialAd(
      onAdClosed: () {
        if (mounted) setState(() => _locationB = newCity);
      },
    );
  }

  // ── Build Method ─────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final a = widget.locationA;
    final b = _locationB;

    return Scaffold(
      backgroundColor: context.pageBackground,
      appBar: _buildAppBar(context),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          _buildToggle(),
          _buildLocationInputs(a, b),
          _buildComparisonCards(a, b),
          _buildNativeAdView(), // Native Ad injected between content naturally
          _buildTrendChart(a, b),
          _buildAdBannerView(), // Safe Banner Ad placement
        ],
      ),
      bottomNavigationBar: _buildBottomNav(context),
    );
  }

  // ── App Bar ──────────────────────────────────────────────────────────────
  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return GradientAppBar(
      backgroundColor: context.cs.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: context.borderColor),
      ),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      title: Text(
        'Market Comparison',
        style: GoogleFonts.inter(
          color: const Color(0xFF0F172A),
          fontWeight: FontWeight.bold,
          fontSize: 18,
          letterSpacing: -0.3,
        ),
      ),
      centerTitle: true,
      actions: [
        IconButton(
          icon: const Icon(Icons.share_outlined, color: Colors.white),
          onPressed: () {},
        ),
      ],
    );
  }

  // ── UI Components ────────────────────────────────────────────────────────
  Widget _buildToggle() {
    final labels = const ['Cities', 'Neighborhoods'];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Container(
        height: 48,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: context.borderColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: List.generate(labels.length, (i) {
            final selected = i == _viewIndex;
            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _viewIndex = i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeInOut,
                  decoration: BoxDecoration(
                    color: selected ? context.cs.surface : Colors.transparent,
                    borderRadius: BorderRadius.circular(9),
                    boxShadow: selected
                        ? [
                            BoxShadow(
                              color: context.textPrimary.withValues(alpha: 0.08),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ]
                        : null,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    labels[i],
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: selected ? _primaryBlue : context.textSecondary,
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildLocationInputs(CityCompareData a, CityCompareData b) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(child: _locationField('LOCATION A', a.label, true)),
          const SizedBox(width: 12),
          Expanded(child: _locationInputDropdown('LOCATION B', b)),
        ],
      ),
    );
  }

  Widget _locationField(String label, String value, bool locked) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            color: context.textSecondary,
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: locked ? _primaryBlue.withValues(alpha: 0.05) : context.cs.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: locked
                  ? _primaryBlue.withValues(alpha: 0.2)
                  : context.borderColor,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  value,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF0F172A),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Icon(
                Icons.location_on_outlined,
                size: 16,
                color: Color(0xFF94A3B8),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _locationInputDropdown(String label, CityCompareData current) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            color: context.textSecondary,
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: () => _showCityPicker(context),
          child: Container(
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: context.cs.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: context.borderColor),
              boxShadow: [
                BoxShadow(
                  color: context.textPrimary.withValues(alpha: 0.03),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    current.label,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF0F172A),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Icon(
                  Icons.arrow_drop_down,
                  size: 20,
                  color: Color(0xFF94A3B8),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showCityPicker(BuildContext context) {
    final choices = _allCities
        .where((c) => c.city != widget.locationA.city)
        .toList();

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => ListView(
        padding: const EdgeInsets.only(top: 12, bottom: 24),
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'Select Comparison City',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: const Color(0xFF0F172A),
              ),
            ),
          ),
          ...choices.map(
            (c) => ListTile(
              leading: const Icon(
                Icons.location_on_outlined,
                color: _primaryBlue,
              ),
              title: Text(
                c.label,
                style: GoogleFonts.inter(fontWeight: FontWeight.w500),
              ),
              trailing: Text(
                c.formattedPrice,
                style: GoogleFonts.inter(
                  color: _primaryBlue,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _handleCitySelectionChange(c); // Interstitial ad wrapper
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComparisonCards(CityCompareData a, CityCompareData b) {
    final priceDiff = ((b.rawPrice - a.rawPrice) / a.rawPrice * 100).abs();
    final moreExpensive = b.rawPrice > a.rawPrice
        ? '${b.city} is ${priceDiff.toStringAsFixed(0)}% more expensive'
        : '${a.city} is ${priceDiff.toStringAsFixed(0)}% more expensive';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        children: [
          _comparisonCard(
            icon: Icons.payments_outlined,
            title: 'Average Listing Price',
            leftValue: a.formattedPrice,
            leftSub: '${a.city} Average',
            rightValue: b.formattedPrice,
            rightSub: '${b.city} Average',
            footer: moreExpensive,
            showFooter: true,
          ),
          const SizedBox(height: 12),
          _comparisonCard(
            icon: Icons.straighten_outlined,
            title: 'Price per Sq Ft',
            leftValue: '\$${a.pricePerSqft.toStringAsFixed(0)}',
            leftTrend: a.yearOverYearPct,
            rightValue: '\$${b.pricePerSqft.toStringAsFixed(0)}',
            rightTrend: b.yearOverYearPct,
          ),
          const SizedBox(height: 12),
          _comparisonCard(
            icon: Icons.calendar_today_outlined,
            title: 'Avg. Days on Market',
            leftValue: a.daysOnMarket.toString(),
            leftSub: 'Days',
            rightValue: b.daysOnMarket.toString(),
            rightSub: 'Days',
          ),
          const SizedBox(height: 12),
          _comparisonCard(
            icon: Icons.inventory_2_outlined,
            title: 'Market Inventory',
            leftValue: _fmtInventory(a.inventoryCount),
            leftSub: 'Active Listings',
            rightValue: _fmtInventory(b.inventoryCount),
            rightSub: 'Active Listings',
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  String _fmtInventory(int n) {
    if (n >= 1000) {
      return '${(n / 1000).toStringAsFixed(n % 1000 == 0 ? 0 : 1)}k';
    }
    return n.toString();
  }

  Widget _comparisonCard({
    required IconData icon,
    required String title,
    required String leftValue,
    String? leftSub,
    double? leftTrend,
    required String rightValue,
    String? rightSub,
    double? rightTrend,
    String? footer,
    bool showFooter = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: context.cs.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF1F5F9)),
        boxShadow: [
          BoxShadow(
            color: context.textPrimary.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Row(
              children: [
                Icon(icon, color: _primaryBlue, size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: const Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
          ),
          Container(height: 1, color: const Color(0xFFF1F5F9)),
          IntrinsicHeight(
            child: Row(
              children: [
                Expanded(child: _dataCell(leftValue, leftSub, leftTrend)),
                Container(width: 1, color: const Color(0xFFF1F5F9)),
                Expanded(child: _dataCell(rightValue, rightSub, rightTrend)),
              ],
            ),
          ),
          if (showFooter && footer != null) ...[
            Container(height: 1, color: const Color(0xFFF1F5F9)),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(14),
                ),
              ),
              child: Text(
                footer,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF475569),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _dataCell(String value, String? sub, double? trend) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: _primaryBlue,
            ),
          ),
          const SizedBox(height: 4),
          if (trend != null) ...[
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  trend >= 0
                      ? Icons.trending_up_rounded
                      : Icons.trending_down_rounded,
                  size: 14,
                  color: trend >= 0
                      ? const Color(0xFFDC2626)
                      : const Color(0xFF16A34A),
                ),
                const SizedBox(width: 2),
                Text(
                  '${trend >= 0 ? '+' : ''}${trend.toStringAsFixed(1)}%',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: trend >= 0
                        ? const Color(0xFFDC2626)
                        : const Color(0xFF16A34A),
                  ),
                ),
              ],
            ),
          ],
          if (sub != null)
            Text(
              sub,
              style: GoogleFonts.inter(
                fontSize: 11,
                color: const Color(0xFF94A3B8),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTrendChart(CityCompareData a, CityCompareData b) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug'];
    const rangeLabels = ['1Y', '3Y', '5Y'];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _primaryBlue.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _primaryBlue.withValues(alpha: 0.12)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Trend Analysis',
                        style: GoogleFonts.inter(
                          color: _primaryBlue,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Median Sale Price (Last 12 Months)',
                        style: GoogleFonts.inter(
                          color: context.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _legend(a.city, solid: true),
                    const SizedBox(height: 4),
                    _legend(b.city, solid: false),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: List.generate(rangeLabels.length, (i) {
                final sel = i == _chartRange;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => setState(() => _chartRange = i),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: sel ? _primaryBlue : Colors.transparent,
                        borderRadius: BorderRadius.circular(99),
                        border: sel
                            ? null
                            : Border.all(color: const Color(0xFFCBD5E1)),
                      ),
                      child: Text(
                        rangeLabels[i],
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: sel ? context.cs.surface : context.textSecondary,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 160,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: List.generate(months.length, (i) {
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _bar(_chartDataA[i], solid: false),
                              const SizedBox(width: 2),
                              _bar(_chartDataB[i], solid: true),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ),
            Container(height: 1, color: const Color(0xFFCBD5E1)),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: months
                  .map(
                    (m) => Text(
                      m,
                      style: GoogleFonts.inter(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF94A3B8),
                        letterSpacing: 0.5,
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _legend(String label, {required bool solid}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: solid ? _primaryBlue : _primaryBlue.withValues(alpha: 0.3),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF475569),
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }

  Widget _bar(double fraction, {required bool solid}) {
    const maxH = 130.0;
    return Container(
      width: 8,
      height: max(4.0, fraction * maxH),
      decoration: BoxDecoration(
        color: solid ? _primaryBlue : _primaryBlue.withValues(alpha: 0.3),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
      ),
    );
  }

  // ── Ad Views ──────────────────────────────────────────────────────────────
  Widget _buildAdBannerView() {
    if (_isBannerAdLoaded && _bannerAd != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16.0),
        child: Align(
          alignment: Alignment.center,
          child: SizedBox(
            width: _bannerAd!.size.width.toDouble(),
            height: _bannerAd!.size.height.toDouble(),
            child: AdWidget(ad: _bannerAd!),
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildNativeAdView() {
    if (_isNativeAdLoaded && _nativeAd != null) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Container(
          decoration: BoxDecoration(
            color: context.cs.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFF1F5F9)),
            boxShadow: [
              BoxShadow(
                color: context.textPrimary.withValues(alpha: 0.03),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          // Using typical medium native ad height footprint
          height: 320,
          child: AdWidget(ad: _nativeAd!),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  // ── Bottom Nav ────────────────────────────────────────────────────────────
  Widget _buildBottomNav(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.cs.surface,
        border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
      ),
      child: BottomNavigationBar(
        currentIndex: 1,
        onTap: (index) {
          if (index == 0) {
            Navigator.of(context).popUntil((route) => route.isFirst);
          } else if (index == 2) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (ctx) => const InsuranceMarketplaceScreen(),
              ),
            );
          } else if (index == 3) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (ctx) => const SettingsScreen()),
            );
          }
        },
        type: BottomNavigationBarType.fixed,
        backgroundColor: context.cs.surface,
        selectedItemColor: _primaryBlue,
        unselectedItemColor: const Color(0xFF94A3B8),
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
    );
  }
}