// fred_mortgage_provider.dart
//
// ─────────────────────────────────────────────────────────────────────────────
// Shared FRED API provider + models — imported by all mortgage screens.
//
// Usage:
//   // In main.dart / app root:
//   ChangeNotifierProvider(
//     create: (_) => FredMortgageProvider()..fetchFredRates(),
//   )
//
//   // In any screen:
//   final provider = context.watch<FredMortgageProvider>();
//   if (provider.loadState == FredLoadState.loading) { ... }
//   final offers = provider.sortedOffers;
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

// ─────────────────────────────────────────────────────────────────────────────
//  FRED API CONFIG
// ─────────────────────────────────────────────────────────────────────────────

class FredConfig {
  FredConfig._();

  static const String _apiKey = 'c474fce3dd81f47defc2a031d651021b';
  static const String _base =
      'https://api.stlouisfed.org/fred/series/observations';

  // Fetch latest 52 observations (1 year of weekly data) for the trend chart.
  static const String url30Y =
      '$_base?series_id=MORTGAGE30US&api_key=$_apiKey&file_type=json'
      '&sort_order=desc&limit=52';

  // Only need the most recent 15Y observation.
  static const String url15Y =
      '$_base?series_id=MORTGAGE15US&api_key=$_apiKey&file_type=json'
      '&sort_order=desc&limit=1';

  // ── Loan assumptions ──────────────────────────────────────────────────────

  /// Full property purchase price.
  static const double homePrice = 437500;

  /// Down payment as a fraction (20 % → 0.20).
  static const double downPaymentPct = 0.20;

  /// Loan principal = homePrice × (1 − downPaymentPct).
  static double get loanAmount => homePrice * (1 - downPaymentPct);

  /// Loan term in months (30 years).
  static const int termMonths = 360;

  // ── Fixed monthly add-ons ─────────────────────────────────────────────────
  static const double monthlyTax = 320.0;
  static const double monthlyIns = 125.0;
  static const double monthlyHoa = 82.0;
}

// ─────────────────────────────────────────────────────────────────────────────
//  FRED RATE DATA MODEL
// ─────────────────────────────────────────────────────────────────────────────

class FredRateData {
  /// Latest FRED MORTGAGE30US weekly rate (annual %, e.g. 6.76).
  final double rate30Y;

  /// Latest FRED MORTGAGE15US weekly rate (annual %). If the 15Y fetch
  /// fails, this is estimated as rate30Y − 0.62 (historical spread).
  final double rate15Y;

  /// Estimated 5/1 ARM rate = rate30Y − 0.30.
  final double rateArm51;

  /// Week-over-week change in the 30Y rate (positive = rising).
  final double weeklyChange;

  /// ISO-8601 observation date string from FRED, e.g. "2025-01-09".
  /// Empty string when using the fallback.
  final String date;

  /// Full list of fetched observations for charts and analysis.
  final List<Map<String, dynamic>> historicalData;

  const FredRateData({
    required this.rate30Y,
    required this.rate15Y,
    required this.rateArm51,
    required this.weeklyChange,
    required this.date,
    this.historicalData = const [],
  });

  /// Safe fallback used when the API is unavailable.
  factory FredRateData.fallback() => const FredRateData(
    rate30Y: 6.76,
    rate15Y: 6.14,
    rateArm51: 6.46,
    weeklyChange: 0.0,
    date: '',
    historicalData: [],
  );

  /// True when the API returned no data and we are showing estimates.
  bool get isEstimated => date.isEmpty;
}

// ─────────────────────────────────────────────────────────────────────────────
//  LENDER OFFER MODEL
// ─────────────────────────────────────────────────────────────────────────────

/// An immutable snapshot of a single lender's computed offer.
/// All monetary fields are in USD. Rate fields are annual percentages.
class LenderOffer {
  final String name;
  final String logoUrl;
  final String loanTerm;
  final bool isTopMatch;

  // ── Live-computed fields ──────────────────────────────────────────────────

  /// Final lender rate (annual %) = FRED 30Y rate + [rateSpread].
  final double rate;

  /// Annual Percentage Rate = [rate] + [aprSpread].
  final double apr;

  /// Monthly principal & interest payment only.
  final double pi;

  /// Total monthly payment = [pi] + tax + insurance + HOA.
  final double monthlyTotal;

  // ── Fixed display fields ──────────────────────────────────────────────────

  /// Estimated lender fees (origination, underwriting, etc.) in USD.
  final double estimatedFees;

  /// Total estimated closing costs in USD.
  final double closingCosts;

  // ── Spread metadata (relative to FRED 30Y index) ─────────────────────────

  /// How many percentage points this lender's rate is above/below FRED 30Y.
  final double rateSpread;

  /// Additional spread applied on top of [rate] to arrive at [apr].
  final double aprSpread;

  const LenderOffer({
    required this.name,
    required this.logoUrl,
    required this.loanTerm,
    required this.isTopMatch,
    required this.rate,
    required this.apr,
    required this.pi,
    required this.monthlyTotal,
    required this.estimatedFees,
    required this.closingCosts,
    required this.rateSpread,
    required this.aprSpread,
  });

  /// Returns a new [LenderOffer] with all rate-dependent fields recomputed
  /// from [fred30Y].
  LenderOffer withLiveFredRate(double fred30Y) {
    final double r = _r3(fred30Y + rateSpread);
    final double a = _r3(r + aprSpread);
    final double p = _computePI(r);
    final double m =
        p +
        FredConfig.monthlyTax +
        FredConfig.monthlyIns +
        FredConfig.monthlyHoa;

    return LenderOffer(
      name: name,
      logoUrl: logoUrl,
      loanTerm: loanTerm,
      isTopMatch: isTopMatch,
      rate: r,
      apr: a,
      pi: p,
      monthlyTotal: m,
      estimatedFees: estimatedFees,
      closingCosts: closingCosts,
      rateSpread: rateSpread,
      aprSpread: aprSpread,
    );
  }

  // ── Amortisation ──────────────────────────────────────────────────────────

  /// Standard amortisation formula:
  ///   M = P × [r(1+r)^n] / [(1+r)^n − 1]
  ///
  /// Uses dart:math pow() — O(log n) — instead of a naive linear loop.
  static double _computePI(double annualRatePct) {
    final double p = FredConfig.loanAmount;
    const int n = FredConfig.termMonths;
    final double r = annualRatePct / 100.0 / 12.0; // monthly rate

    if (r <= 0) return FredConfig.loanAmount / n;

    final double factor = math.pow(1.0 + r, n).toDouble();
    return p * (r * factor) / (factor - 1.0);
  }

  // ── Rounding helpers ──────────────────────────────────────────────────────

  /// Round to 3 decimal places (rate / APR — consistent with TRID disclosures).
  static double _r3(double v) => double.parse(v.toStringAsFixed(3));

  // ── Convenience ───────────────────────────────────────────────────────────

  /// Monthly total rounded to the nearest dollar (used for sorting).
  int get monthlyInt => monthlyTotal.round();
}

// ─────────────────────────────────────────────────────────────────────────────
//  LENDER TEMPLATE CATALOGUE
// ─────────────────────────────────────────────────────────────────────────────

/// Internal metadata container — never exposed outside this file.
///
/// Rate/monetary fields are intentionally absent here. They are computed
/// at runtime by [LenderOffer.withLiveFredRate] once per API fetch,
/// preventing stale fallback values from appearing in the UI.
class _LenderMeta {
  final String name;
  final String logoUrl;
  final String loanTerm;
  final bool isTopMatch;
  final double rateSpread;
  final double aprSpread;
  final double estimatedFees;
  final double closingCosts;

  const _LenderMeta({
    required this.name,
    required this.logoUrl,
    required this.loanTerm,
    required this.isTopMatch,
    required this.rateSpread,
    required this.aprSpread,
    required this.estimatedFees,
    required this.closingCosts,
  });

  /// Converts metadata into an uncomputed [LenderOffer] template.
  /// Always call [LenderOffer.withLiveFredRate] on the result before displaying.
  LenderOffer toTemplate() => LenderOffer(
    name: name,
    logoUrl: logoUrl,
    loanTerm: loanTerm,
    isTopMatch: isTopMatch,
    rate: 0,
    apr: 0,
    pi: 0,
    monthlyTotal: 0,
    estimatedFees: estimatedFees,
    closingCosts: closingCosts,
    rateSpread: rateSpread,
    aprSpread: aprSpread,
  );
}

class LenderTemplates {
  LenderTemplates._();

  static const List<_LenderMeta> _catalogue = [
    _LenderMeta(
      name: 'Rocket Mortgage',
      logoUrl:
          'https://lh3.googleusercontent.com/aida-public/AB6AXuA9v1yn-UGeW-ce2I5VB3Cq6Ti_l9RFr9zmHtcTqk-fQh-ZMIvfEfXaypFOc89zgpgTAATRV8tpmEPqlQhsNdku6s1FfuptMl9MEPtxnEYUJo9HWO_0rp5drXAZ7v9jmO32afufzRH-8KoG6vtWoRb8YlisVlZltrZcqVyFzIcWETtlTfrYLcmOtA6x-y_j-7UKGO4piaoJaD2QHweMICycoO-qdOmoyLd6HeTiLhrmKrIm2A1BzY1krkzRzF9Ur6LnQgBIdlhWQIAJ',
      loanTerm: '30-Year Fixed',
      isTopMatch: true,
      rateSpread: -0.625,
      aprSpread: 0.115,
      estimatedFees: 2450,
      closingCosts: 6200,
    ),
    _LenderMeta(
      name: 'Wells Fargo',
      logoUrl:
          'https://lh3.googleusercontent.com/aida-public/AB6AXuBuzZlA-sklsqKCEMzIp3mPQc3BUptNQGIcqIEhDFneE40jfp6jKdcPMZvm3soXuYcz1r3GF_2ucmG4c8meCR7z9hWOu0-77Wa8SIr5bf67rBXgyBl1BAFacmQGt47ZzLUI-zKkMy5l_uGzxuUv7UwR7roDH5AtSyZ91ZQupNY1e7W7i3Jt4DtkhhjjpJz91Fze7DmV_CmldyLv6jzPag1eftNeij2tu9cVkKylb8WGoX_OXL1a8Tp5Nu8bD__yMQ2WkdNx2BNExaBo',
      loanTerm: '30-Year Fixed',
      isTopMatch: false,
      rateSpread: -0.500,
      aprSpread: 0.100,
      estimatedFees: 1800,
      closingCosts: 5900,
    ),
    _LenderMeta(
      name: 'Chase',
      logoUrl:
          'https://lh3.googleusercontent.com/aida-public/AB6AXuCMrz9NfOj50XmZHZtFPKE89uJHheArRsb3cFe-X3hBe3laUjyJFUFO71EHhRenxoYb-LCnOZxAG8TD-TXVVLfc2TCghylQKozNQqrsMsWatCXRkW-W0DjCPkKnm77MZ_vr8VF2JtwAvKyTTLmLt5hObLv7CD6ph1C-txpUXNDBBfdEqTnWItmeoNTM_-tJsBoHgKMvOr9uoZt7VZEcIa89A4YPKRawdr8cjhY451YXBBF3cKf50r41bfqhuPkKJr77R6TZvVhgey85',
      loanTerm: '15-Year Fixed',
      isTopMatch: false,
      rateSpread: -0.885,
      aprSpread: 0.115,
      estimatedFees: 2100,
      closingCosts: 7400,
    ),
    _LenderMeta(
      name: 'Bank of America',
      logoUrl: 'https://logo.clearbit.com/bankofamerica.com',
      loanTerm: '30-Year Fixed',
      isTopMatch: false,
      rateSpread: -0.385,
      aprSpread: 0.115,
      estimatedFees: 1950,
      closingCosts: 6100,
    ),
    _LenderMeta(
      name: 'U.S. Bank',
      logoUrl: 'https://logo.clearbit.com/usbank.com',
      loanTerm: '30-Year Fixed',
      isTopMatch: false,
      rateSpread: -0.260,
      aprSpread: 0.110,
      estimatedFees: 1700,
      closingCosts: 5750,
    ),
    _LenderMeta(
      name: 'PennyMac',
      logoUrl: 'https://logo.clearbit.com/pennymac.com',
      loanTerm: '30-Year Fixed',
      isTopMatch: false,
      rateSpread: -0.375,
      aprSpread: 0.105,
      estimatedFees: 1550,
      closingCosts: 5400,
    ),
    _LenderMeta(
      name: 'Better.com',
      logoUrl: 'https://logo.clearbit.com/better.com',
      loanTerm: '30-Year Fixed',
      isTopMatch: false,
      rateSpread: -0.500,
      aprSpread: 0.100,
      estimatedFees: 1200,
      closingCosts: 4900,
    ),
  ];

  /// Returns uncomputed offer templates — spread metadata only.
  /// Always call [LenderOffer.withLiveFredRate] before displaying any offer.
  static List<LenderOffer> get templates =>
      _catalogue.map((m) => m.toTemplate()).toList();
}

// ─────────────────────────────────────────────────────────────────────────────
//  LOAD STATE
// ─────────────────────────────────────────────────────────────────────────────

enum FredLoadState { idle, loading, loaded, error }

// ─────────────────────────────────────────────────────────────────────────────
//  PROVIDER — single source of truth for all mortgage screens
// ─────────────────────────────────────────────────────────────────────────────

class FredMortgageProvider extends ChangeNotifier {
  // ── State ─────────────────────────────────────────────────────────────────
  FredLoadState _loadState = FredLoadState.idle;
  FredRateData _fredData = FredRateData.fallback();
  String? _errorMessage;

  // Offer cache — rebuilt once per fetchFredRates() completion, not on every
  // getter call. This prevents the amortisation formula from running inside
  // widget build() methods.
  List<LenderOffer> _cachedOffers = [];

  // Sort tab used by CompareAllOffersScreen (0 = rate, 1 = APR, 2 = monthly).
  // Calling setSortTab() only triggers notifyListeners() when the value changes.
  int _sortTab = 0;

  // ── Public getters ────────────────────────────────────────────────────────
  FredLoadState get loadState => _loadState;
  FredRateData get fredData => _fredData;
  String? get errorMessage => _errorMessage;
  int get sortTab => _sortTab;

  /// All lender offers sorted according to the active [sortTab].
  /// Returns a new list on each call — mutating it does not affect the cache.
  List<LenderOffer> get sortedOffers {
    final list = List<LenderOffer>.from(_cachedOffers);
    switch (_sortTab) {
      case 0:
        list.sort((a, b) => a.rate.compareTo(b.rate));
        break;
      case 1:
        list.sort((a, b) => a.apr.compareTo(b.apr));
        break;
      case 2:
        list.sort((a, b) => a.monthlyInt.compareTo(b.monthlyInt));
        break;
    }
    return list;
  }

  /// Convenience — top 3 cheapest-rate offers for the summary comparison card.
  List<LenderOffer> get topThree => sortedOffers.take(3).toList();

  // ── Sort control ──────────────────────────────────────────────────────────
  void setSortTab(int index) {
    if (_sortTab == index) return; // avoid unnecessary rebuilds
    _sortTab = index;
    notifyListeners();
  }

  // ── FRED API fetch ────────────────────────────────────────────────────────

  /// Fetches the latest FRED MORTGAGE30US and MORTGAGE15US rates, then rebuilds
  /// the internal offer cache. Safe to call multiple times:
  ///   • Returns immediately if a fetch is already in progress.
  ///   • Can be called again after [FredLoadState.loaded] to refresh data.
  ///   • Falls back to [FredRateData.fallback] on repeated failure so the UI
  ///     always has valid data to display.
  Future<void> fetchFredRates() async {
    if (_loadState == FredLoadState.loading) return;

    _loadState = FredLoadState.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      // ── 30-year rate ─────────────────────────────────────────────────────
      final http.Response res30 = await _fetchWithRetry(FredConfig.url30Y);
      if (res30.statusCode != 200) {
        throw Exception('FRED 30Y returned HTTP ${res30.statusCode}.');
      }

      final List<Map<String, dynamic>> obs30 = _validObservations(res30.body);
      if (obs30.isEmpty) {
        throw Exception('FRED 30Y: no valid observations in response.');
      }

      final double latest30 = double.parse(obs30[0]['value'] as String);
      final double prev30 = obs30.length > 1
          ? double.parse(obs30[1]['value'] as String)
          : latest30;

      // ── 15-year rate (best-effort) ────────────────────────────────────────
      // Falls back to historical spread (−0.62 pp) if the request fails.
      double rate15 = _r2(latest30 - 0.62);
      try {
        final http.Response res15 = await _fetchWithRetry(FredConfig.url15Y);
        if (res15.statusCode == 200) {
          final List<Map<String, dynamic>> obs15 = _validObservations(
            res15.body,
          );
          if (obs15.isNotEmpty) {
            rate15 = double.parse(obs15[0]['value'] as String);
          }
        }
      } catch (_) {
        // Non-fatal — keep the spread estimate computed above.
      }

      _fredData = FredRateData(
        rate30Y: latest30,
        rate15Y: rate15,
        rateArm51: _r2(latest30 - 0.30),
        weeklyChange: _r2(latest30 - prev30),
        date: obs30[0]['date'] as String,
        historicalData: obs30,
      );

      _loadState = FredLoadState.loaded;
    } catch (e) {
      _errorMessage =
          'Could not load live FRED data — showing estimates. (${e.toString()})';
      _fredData = FredRateData.fallback();
      _loadState = FredLoadState.error;
    }

    // Always rebuild the cache — uses live data on success, fallback on error.
    _rebuildCache();
    notifyListeners();
  }

  /// Rebuilds [_cachedOffers] from the current [_fredData].
  /// Called once per [fetchFredRates] completion.
  void _rebuildCache() {
    _cachedOffers = LenderTemplates.templates
        .map((t) => t.withLiveFredRate(_fredData.rate30Y))
        .toList();
  }

  // ── HTTP helpers ──────────────────────────────────────────────────────────

  /// GET [url] with a 10 s timeout. On HTTP 429/503 or a timeout exception,
  /// waits 1.5 s and retries once. Propagates the error on second failure.
  Future<http.Response> _fetchWithRetry(String url) async {
    Future<http.Response> attempt() =>
        http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));

    http.Response res;
    try {
      res = await attempt();
    } on Exception {
      // First attempt timed out or threw — wait then retry.
      await Future<void>.delayed(const Duration(milliseconds: 1500));
      return attempt(); // second failure propagates to the caller
    }

    if (res.statusCode == 429 || res.statusCode == 503) {
      await Future<void>.delayed(const Duration(milliseconds: 1500));
      return attempt();
    }

    return res;
  }

  /// Decodes a FRED JSON response and returns only observations whose
  /// value field is not the FRED missing-value sentinel `"."`.
  static List<Map<String, dynamic>> _validObservations(String body) {
    final Map<String, dynamic> decoded =
        jsonDecode(body) as Map<String, dynamic>;
    return (decoded['observations'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .where((o) => (o['value'] as String) != '.')
        .toList();
  }

  // ── Formatting utilities (shared by all mortgage screens) ─────────────────

  /// Formats an annual rate or APR.
  /// e.g. `fmtPct(6.76)` → `"6.760%"` (3 dp, matching TRID disclosure standard).
  static String fmtPct(double v, {int decimals = 3}) =>
      '${v.toStringAsFixed(decimals)}%';

  /// Formats a dollar amount with thousands separators, no cents.
  /// e.g. `fmtCurrency(6200)` → `"\$6,200"`
  /// Handles negative values and values up to 999,999,999.
  static String fmtCurrency(double v) {
    final String digits = v.round().abs().toString();
    final StringBuffer buf = StringBuffer();
    int count = 0;
    for (int i = digits.length - 1; i >= 0; i--) {
      if (count > 0 && count % 3 == 0) buf.write(',');
      buf.write(digits[i]);
      count++;
    }
    final String formatted = buf.toString().split('').reversed.join();
    return v < 0 ? '-\$$formatted' : '\$$formatted';
  }

  // ── Private rounding ──────────────────────────────────────────────────────

  static double _r2(double v) => double.parse(v.toStringAsFixed(2));
}
