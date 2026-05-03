import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../services/ad_service.dart';
import '../providers/settings_provider.dart';
import '../core/constants/theme_extensions.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AD PLACEMENT STRATEGY — what changed and why
// ─────────────────────────────────────────────────────────────────────────────
//
// CONVERTED → StatelessWidget → StatefulWidget
//   • The original was a StatelessWidget, which cannot hold BannerAd state.
//   • Converted to StatefulWidget to manage the anchored banner lifecycle
//     (load, render, dispose) correctly.
//
// ADDED → Anchored Adaptive BannerAd in bottomNavigationBar
//   • This screen has no bottom nav bar, so the banner is the sole widget
//     in bottomNavigationBar — anchored to the absolute screen edge.
//   • Loaded in didChangeDependencies() (safe for MediaQuery).
//   • Wrapped in SafeArea for system gesture inset handling.
//   • ListView bottom padding compensates dynamically for banner height.
//
// ADDED → NativeAdScheduleItem mid-list using dynamic midpoint injection
//   • Identical strategy to more_tools_screen: one native ad at the true
//     midpoint of the payment schedule list.
//   • itemCount = schedule.length + 1 (one extra slot for the ad).
//   • midpoint  = schedule.length ~/ 2 (auto-adjusts to any schedule length).
//   • rowIndex  = index < midpoint ? index : index - 1.
//   • Placed at the midpoint so it is always:
//     - Away from the top (no accidental first-tap)
//     - Away from the bottom (no proximity to the anchored banner)
//     - Surrounded by non-interactive payment rows on both sides (safe buffer)
//
// FIXED → StatelessWidget _calculateSchedule() called in build()
//   • The original recalculated the full schedule on every build() call.
//     For a 600-month schedule this is expensive and unnecessary.
//   • Moved to initState() and cached in _schedule — calculated once.
//
// KEPT → Safety cap at 600 months (50 years) in _calculateSchedule().
// ─────────────────────────────────────────────────────────────────────────────

class CreditCardScheduleScreen extends StatefulWidget {
  final double balance;
  final double monthlyPayment;
  final double apr;

  const CreditCardScheduleScreen({
    super.key,
    required this.balance,
    required this.monthlyPayment,
    required this.apr,
  });

  @override
  State<CreditCardScheduleScreen> createState() =>
      _CreditCardScheduleScreenState();
}

class _CreditCardScheduleScreenState extends State<CreditCardScheduleScreen> {
  late final List<Map<String, dynamic>> _schedule;



  // ── Lifecycle ────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    // Calculate once and cache — not on every build().
    _schedule = _calculateSchedule();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }

  @override
  void dispose() {

    super.dispose();
  }

  // ── Banner ad ────────────────────────────────────────────────────────────────



  // ── Schedule calculation ─────────────────────────────────────────────────────

  List<Map<String, dynamic>> _calculateSchedule() {
 List<Map<String, dynamic>> schedule = [];
    double currentBalance = widget.balance;
    final double monthlyRate = (widget.apr / 100) / 12;
    int month = 1;

    while (currentBalance > 0 && month <= 600) {
      final double interest = currentBalance * monthlyRate;
      double principal = widget.monthlyPayment - interest;

      if (principal > currentBalance) principal = currentBalance;

      currentBalance -= principal;
      if (currentBalance < 0.01) currentBalance = 0;

      schedule.add({
        'month': month,
        'interest': interest,
        'principal': principal,
        'balance': currentBalance,
      });

      if (currentBalance <= 0) break;
      month++;
    }

    return schedule;
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final formatCurrency = NumberFormat.currency(
      symbol: settings.currencySymbol,
      decimalDigits: 2,
    );

    final double bottomPadding = 16.0;

    // Dynamic midpoint — ad auto-adjusts if schedule length changes.
    final int midpoint = _schedule.length ~/ 2;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: context.cs.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios,
            color: context.textSecondary,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Payment Schedule',
          style: TextStyle(
            color: context.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),

      body: Column(
        children: [
          // ── Summary header ───────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(20),
            color: context.cs.surface,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildSummaryItem(
                  'Start Balance',
                  formatCurrency.format(widget.balance),
                ),
                _buildSummaryItem(
                  'Monthly Pay',
                  formatCurrency.format(widget.monthlyPayment),
                ),
                _buildSummaryItem('APR', '${widget.apr}%'),
              ],
            ),
          ),
          const Divider(height: 1),

          // ── Payment list with midpoint native ad ─────────────────────────
          Expanded(
            child: ListView.separated(
              padding: EdgeInsets.fromLTRB(16, 16, 16, bottomPadding),
              // schedule rows + 1 ad slot
              itemCount: _schedule.length + 1,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                // ── Native ad at dynamic midpoint ──────────────────────────
                // Payment rows above and below are non-interactive —
                // ideal accidental-tap buffer on both sides.
                if (index == midpoint) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: _NativeAdScheduleItem(),
                  );
                }

                // Shift row index down by 1 for items after the ad slot
                final rowIndex = index < midpoint ? index : index - 1;
                if (rowIndex >= _schedule.length) {
                  return const SizedBox.shrink();
                }

                final monthData = _schedule[rowIndex];

                // ── Payment row ────────────────────────────────────────────
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: context.cs.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFF1F5F9)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '${monthData['month']}',
                            style: const TextStyle(
                              color: Color(0xFF2563EB),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Principal',
                                  style: TextStyle(
                                    // context.textSecondary used at runtime
                                    fontSize: 12,
                                  ),
                                ),
                                Text(
                                  formatCurrency.format(monthData['principal']),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Interest',
                                  style: TextStyle(
                                    color: context.textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                                Text(
                                  formatCurrency.format(monthData['interest']),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 24),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'Balance',
                            style: TextStyle(
                              color: context.textSecondary,
                              fontSize: 10,
                            ),
                          ),
                          Text(
                            formatCurrency.format(monthData['balance']),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: context.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(color: context.textSecondary, fontSize: 11),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: context.textPrimary,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _NativeAdScheduleItem — inline native ad for the payment list
// ─────────────────────────────────────────────────────────────────────────────
// • Loading placeholder: 60 dp (consistent with all other screens)
// • Collapses silently to SizedBox.shrink() on load failure
// • "Sponsored" label kept — required by AdMob policy
// • mounted check in onAdLoaded — prevents setState after dispose
// ─────────────────────────────────────────────────────────────────────────────

class _NativeAdScheduleItem extends StatefulWidget {
  const _NativeAdScheduleItem();

  @override
  State<_NativeAdScheduleItem> createState() => _NativeAdScheduleItemState();
}

class _NativeAdScheduleItemState extends State<_NativeAdScheduleItem> {
  NativeAd? _nativeAd;
  bool _isAdLoaded = false;
  bool _isAdFailed = false;

  // Use AdService for native ad unit ID.
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
        contentUrl: AdContentUrl.creditFinance,
        keywords: AdKeywords.creditFinance,
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
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(12),
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
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200),
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
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.blue.shade100,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'Sponsored',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
              ),
              const Icon(Icons.info_outline, size: 14, color: Colors.grey),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(child: AdWidget(ad: _nativeAd!)),
        ],
      ),
    );
  }
}