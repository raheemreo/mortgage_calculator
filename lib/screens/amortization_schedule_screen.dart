import 'package:flutter/material.dart';
import '../widgets/gradient_app_bar.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../utils/calculator_logic.dart';
import '../services/pdf_service.dart';
import '../services/ad_service.dart';
import '../providers/settings_provider.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../core/constants/theme_extensions.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AD PLACEMENT STRATEGY — what changed and why
// ─────────────────────────────────────────────────────────────────────────────
//
// REMOVED → Anchored BannerAd in bottomNavigationBar Column
//   • The original placed a BannerAd inside:
//       bottomNavigationBar: Column([BannerAd, SizedBox(height:12)])
//   • This is not a valid anchored placement — AdMob requires the banner to
//     be the sole widget anchored to the absolute screen edge. A Column with
//     a SizedBox below it pushes the banner off the edge.
//   • Also: this screen has NO BottomNavigationBar, so the banner was sitting
//     in dead space below the content — poor UX and a policy grey area.
//   • All related state (_anchoredAdaptiveAd, _isBannerAdLoaded,
//     _loadAnchoredAdaptiveAd, didChangeDependencies) removed.
//
// KEPT & IMPROVED → NativeAdScheduleItem between the two table chunks
//   • Placement between "first 12 rows" and "remaining rows" is a genuine
//     content-break — the user has read a full screen of data and is
//     naturally pausing. This is the best possible native ad position on
//     this screen.
//   • The SizedBox(height: 40) dead-space spacer at the bottom was removed.
//   • Loading placeholder height reduced: 100 dp → 60 dp (consistent with
//     all other screens).
//   • mounted check added to onAdLoaded for safety.
//   • "Sponsored" label kept — required by AdMob policy.
//
// NOTE → InterstitialAd on Export PDF (AppBar action) is KEPT unchanged.
//   • Showing an interstitial before a high-value user action (PDF export)
//     is explicitly permitted by AdMob policy and is good monetization
//     practice. No changes needed there.
// ─────────────────────────────────────────────────────────────────────────────

class AmortizationScheduleScreen extends StatefulWidget {
  final double principal;
  final double interestRate;
  final int years;

  const AmortizationScheduleScreen({
    super.key,
    required this.principal,
    required this.interestRate,
    required this.years,
  });

  @override
  State<AmortizationScheduleScreen> createState() =>
      _AmortizationScheduleScreenState();
}

class _AmortizationScheduleScreenState
    extends State<AmortizationScheduleScreen> {
  bool _isMonthly = true;
  int _activeTab = 0; // 0: Balance, 1: Interest

  List<Map<String, dynamic>> _monthlySchedule = [];
  List<Map<String, dynamic>> _yearlySchedule = [];

  // ── No BannerAd state — removed entirely ───────────────────────────────────

  @override
  void initState() {
    super.initState();
    _calculateSchedule();
  }

  // didChangeDependencies no longer needed — was only for banner ad loading.

  @override
  void dispose() {
    super.dispose();
  }

  // ── Schedule calculation ─────────────────────────────────────────────────────

  void _calculateSchedule() {
    _monthlySchedule = CalculatorLogic.calculateAmortizationSchedule(
      principal: widget.principal,
      annualInterestRate: widget.interestRate,
      months: widget.years * 12,
    );

    _yearlySchedule = [];
    for (int i = 0; i < _monthlySchedule.length; i += 12) {
      int end = (i + 12 < _monthlySchedule.length)
          ? i + 12
          : _monthlySchedule.length;
      double yearlyInterest = 0;
      double yearlyPrincipal = 0;
      for (int j = i; j < end; j++) {
        yearlyInterest += _monthlySchedule[j]['interest'];
        yearlyPrincipal += _monthlySchedule[j]['principal'];
      }
      _yearlySchedule.add({
        'year': (i / 12).floor() + 1,
        'interest': yearlyInterest,
        'principal': yearlyPrincipal,
        'balance': _monthlySchedule[end - 1]['balance'],
      });
    }
  }

  List<FlSpot> _getChartSpots() {
    List<FlSpot> spots = [];
    var source = _yearlySchedule;
    if (source.isEmpty) return [const FlSpot(0, 0)];

    spots.add(FlSpot(0, _activeTab == 0 ? widget.principal : 0));

    double cumulativeInterest = 0;
    for (var entry in source) {
      if (_activeTab == 0) {
        spots.add(FlSpot(entry['year'].toDouble(), entry['balance']));
      } else {
        cumulativeInterest += entry['interest'];
        spots.add(FlSpot(entry['year'].toDouble(), cumulativeInterest));
      }
    }
    return spots;
  }

  double _getLifetimeInterest() {
    double total = 0;
    for (var entry in _monthlySchedule) {
      total += entry['interest'];
    }
    return total;
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    const Color navyColor = Color(0xFF0B3D91);
    const Color emeraldColor = Color(0xFF10B981);
    const Color goldColor = Color(0xFFF4D03F);

    return Scaffold(
      backgroundColor: context.pageBackground,
      appBar: GradientAppBar(
        backgroundColor: context.cs.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Amortization Chart',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        actions: [
          // InterstitialAd before PDF export is policy-compliant — kept as-is.
          TextButton(
            onPressed: () {
              AdService().showInterstitialAd(
                onAdClosed: () {
                  PdfService.generateAndPrintSchedule(
                    principal: widget.principal,
                    interestRate: widget.interestRate,
                    years: widget.years,
                    schedule: _isMonthly ? _monthlySchedule : _yearlySchedule,
                    isMonthly: _isMonthly,
                  );
                },
              );
            },
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Export PDF',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ],
      ),
      // No bottomNavigationBar — banner removed entirely.
      body: Column(
        children: [
          // ── Tabs ────────────────────────────────────────────────────────
          Container(
            color: context.cardColor,
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: context.borderColor)),
            ),
            child: Row(
              children: [
                _buildTab('Balance', _activeTab == 0,
                    () => setState(() => _activeTab = 0), context.isDark ? context.primaryColor : navyColor),
                _buildTab('Interest', _activeTab == 1,
                    () => setState(() => _activeTab = 1), context.isDark ? context.primaryColor : navyColor),
              ],
            ),
          ),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // ── Chart card ─────────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: context.cardColor,
                    borderRadius: BorderRadius.circular(16),
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
                      Text(
                        _activeTab == 0
                            ? 'Loan Balance Over Time'
                            : 'Cumulative Interest Paid',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: context.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            NumberFormat.currency(
                              symbol: settings.currencySymbol,
                              decimalDigits: 0,
                            ).format(
                              _activeTab == 0
                                  ? widget.principal
                                  : _getLifetimeInterest(),
                            ),
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: context.isDark ? context.primaryColor : navyColor,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: goldColor,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: (context.isDark ? context.primaryColor : navyColor).withValues(alpha: 0.05),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _buildChip('${widget.years} Years',
                              context.isDark ? context.inputFill : Colors.grey.shade100,
                              context.isDark ? context.textSecondary : Colors.grey.shade600),
                        ],
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        height: 180,
                        child: LineChart(
                          LineChartData(
                            gridData: const FlGridData(
                              show: true,
                              drawVerticalLine: false,
                            ),
                            titlesData: const FlTitlesData(show: false),
                            borderData: FlBorderData(show: false),
                            lineBarsData: [
                              LineChartBarData(
                                spots: _getChartSpots(),
                                isCurved: true,
                                color: context.isDark ? context.primaryColor : navyColor,
                                barWidth: 3,
                                dotData: const FlDotData(show: false),
                                belowBarData: BarAreaData(
                                  show: true,
                                  color: (context.isDark ? context.primaryColor : navyColor).withValues(alpha: 0.1),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          _buildLegend('Standard Schedule', context.isDark ? context.primaryColor : navyColor),
                          const SizedBox(width: 16),
                          _buildLegend('Accelerated Payoff', emeraldColor,
                              dashed: true),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // ── Payment breakdown header + toggle ──────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Payment Breakdown',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: context.textPrimary,
                      ),
                    ),
                    Container(
                      height: 36,
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: context.isDark ? context.inputFill : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: context.borderColor),
                      ),
                      child: Row(
                        children: [
                          _buildToggleButton('Monthly', _isMonthly,
                              () => setState(() => _isMonthly = true),
                              context.isDark ? context.primaryColor : navyColor),
                          _buildToggleButton('Yearly', !_isMonthly,
                              () => setState(() => _isMonthly = false),
                              context.isDark ? context.primaryColor : navyColor),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // ── First 12 rows ──────────────────────────────────────────
                Container(
                  decoration: BoxDecoration(
                    color: context.cardColor,
                    borderRadius: BorderRadius.circular(16),
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
                    children: [
                      _buildTableHeader(context.isDark ? context.inputFill : navyColor),
                      ...(_isMonthly ? _monthlySchedule : _yearlySchedule)
                          .take(12)
                          .indexed
                          .map((indexed) {
                        final int index = indexed.$1;
                        var entry = indexed.$2;
                        String title = _isMonthly
                            ? 'Payment ${entry['month']}'
                            : 'Year ${entry['year']}';
                        String subtitle =
                            'Princ: ${NumberFormat.currency(symbol: settings.currencySymbol, decimalDigits: 0).format(entry['principal'])} | Int: ${NumberFormat.currency(symbol: settings.currencySymbol, decimalDigits: 0).format(entry['interest'])}';
                        return _buildTableRow(
                          title,
                          subtitle,
                          NumberFormat.currency(
                            symbol: settings.currencySymbol,
                            decimalDigits: 0,
                          ).format(entry['balance']),
                          index % 2 != 0,
                          emeraldColor,
                        );
                      }),
                    ],
                  ),
                ),

                // ── Native ad — natural break between table chunks ─────────
                // Placed between row 1–12 and rows 13–50. The user has just
                // read a full screen of data; this is a genuine content pause.
                // Non-interactive table rows above and below act as buffers,
                // preventing accidental taps on the ad.
                const SizedBox(height: 16),
                const NativeAdScheduleItem(),
                const SizedBox(height: 16),

                // ── Remaining rows (13–50) ─────────────────────────────────
                Container(
                  decoration: BoxDecoration(
                    color: context.cardColor,
                    borderRadius: BorderRadius.circular(16),
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
                    children: [
                      ...(_isMonthly ? _monthlySchedule : _yearlySchedule)
                          .skip(12)
                          .take(38)
                          .indexed
                          .map((indexed) {
                        final int index = indexed.$1;
                        var entry = indexed.$2;
                        String title = _isMonthly
                            ? 'Payment ${entry['month']}'
                            : 'Year ${entry['year']}';
                        String subtitle =
                            'Princ: ${NumberFormat.currency(symbol: settings.currencySymbol, decimalDigits: 0).format(entry['principal'])} | Int: ${NumberFormat.currency(symbol: settings.currencySymbol, decimalDigits: 0).format(entry['interest'])}';
                        return _buildTableRow(
                          title,
                          subtitle,
                          NumberFormat.currency(
                            symbol: settings.currencySymbol,
                            decimalDigits: 0,
                          ).format(entry['balance']),
                          index % 2 != 0,
                          emeraldColor,
                        );
                      }),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Helper widgets ────────────────────────────────────────────────────────────

  Widget _buildTab(
      String title, bool isActive, VoidCallback onTap, Color activeColor) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isActive ? activeColor : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          child: Center(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: isActive ? activeColor : context.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChip(String text, Color bgColor, Color textColor,
      {IconData? icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: textColor),
            const SizedBox(width: 4),
          ],
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegend(String label, Color color, {bool dashed = false}) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 3,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: context.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildToggleButton(
      String title, bool isSelected, VoidCallback onTap, Color activeColor) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: isSelected ? (context.isDark ? context.cardColor : context.cs.surface) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          boxShadow: isSelected
              ? [ BoxShadow(color: context.textPrimary12, blurRadius: 4)]
              : null,
        ),
        child: Center(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color:
                  isSelected ? activeColor : context.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTableHeader(Color bgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'PAYMENT DETAILS',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          Text(
            'BALANCE',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableRow(String title, String subtitle, String balance,
      bool isAlt, Color emeraldColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: isAlt
          ? (context.isDark ? context.inputFill : const Color(0xFFF8FAFC))
          : (context.isDark ? context.cardColor : context.cs.surface),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: emeraldColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.check_circle, size: 18, color: emeraldColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: context.textPrimary,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: context.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Text(
            balance,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: context.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// NativeAdScheduleItem
// ─────────────────────────────────────────────────────────────────────────────
// Changes from original:
//   • Loading placeholder height: 100 dp → 60 dp (consistent with all screens)
//   • mounted check added to onAdLoaded for safety
//   • margin reduced from vertical:24 → vertical:8 (outer SizedBox handles gap)
//   • "Sponsored" label kept — required by AdMob policy
// ─────────────────────────────────────────────────────────────────────────────

class NativeAdScheduleItem extends StatefulWidget {
  const NativeAdScheduleItem({super.key});

  @override
  State<NativeAdScheduleItem> createState() => _NativeAdScheduleItemState();
}

class _NativeAdScheduleItemState extends State<NativeAdScheduleItem> {
  NativeAd? _nativeAd;
  bool _isAdLoaded = false;
  bool _isAdFailed = false;
 final String _adUnitId = AdService.nativeAdUnitId;

  @override
  void initState() {
    super.initState();
    _loadNativeAd();
  }

  void _loadNativeAd() {
    _nativeAd = NativeAd(
      adUnitId: _adUnitId,
      factoryId: 'listTile',
      request: const AdRequest(
        contentUrl: AdContentUrl.mortgage,
        keywords: AdKeywords.mortgage,
      ),
      listener: NativeAdListener(
        onAdLoaded: (ad) {
          if (mounted) setState(() => _isAdLoaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('NativeAd failed to load: $error');
          if (mounted) setState(() => _isAdFailed = true);
          ad.dispose();
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    _nativeAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isAdFailed) return const SizedBox.shrink();

    if (!_isAdLoaded || _nativeAd == null) {
      return Container(
        height: 60,
        decoration: BoxDecoration(
          color: context.isDark ? context.cardColor : Colors.blue.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.borderColor),
        ),
        child: const Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    return Container(
      height: 340,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.isDark ? context.cardColor : Colors.blue.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.isDark ? context.borderColor : Colors.blue.shade200),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Required AdMob disclosure — do NOT remove.
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: context.isDark ? context.inputFill : Colors.blue.shade100,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Sponsored',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: context.isDark ? context.primaryColor : Colors.blue,
                  ),
                ),
              ),
              Icon(Icons.info_outline, size: 14, color: context.textSecondary),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(child: AdWidget(ad: _nativeAd!)),
        ],
      ),
    );
  }
}