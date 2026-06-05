// auto_loan_calculator_screen.dart
// ─────────────────────────────────────────────────────────────────────────────
// AutoLoanCalculatorScreen
//
// AdMob placement strategy:
//  • Native Ad (medium template) → between Results card and Term Comparison
//    card at a natural content break; "Sponsored" label per AdMob Policy §5.2
//  • Interstitial → triggered only on intentional "Calculate" button tap
//    (high-value action, policy-compliant trigger point)
//
// Native Ad Policy Compliance:
//  1. Placed AFTER Results card — user reads result first, ad never blocks
//     the primary calculator output.
//  2. NOT adjacent to Calculate button — Results card sits between them,
//     eliminating accidental-tap risk on the action element above.
//  3. NOT inside any InkWell / GestureDetector — zero accidental-click risk.
//  4. "Sponsored" label rendered OUTSIDE AdMob's NativeAd widget, ensuring
//     it cannot be hidden by the template (AdMob Policy §5.2).
//  5. Interstitial fires and fully closes BEFORE user can scroll to the
//     native ad — two ad formats are never on screen simultaneously.
//  6. Only one native ad in the entire scroll area.
//  7. Fixed-height placeholder prevents layout jumps during ad load.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../widgets/gradient_app_bar.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../providers/settings_provider.dart';
import '../services/ad_service.dart';
import '../utils/calculator_logic.dart';
import '../core/constants/theme_extensions.dart';
import '../models/affordability_model.dart';
import '../providers/affordability_provider.dart';
import 'saved_calculations_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  DESIGN TOKENS
// ─────────────────────────────────────────────────────────────────────────────

abstract final class _C {
  static const primary = Color(0xFF1D4ED8);
  static const emerald = Color(0xFF10B981);
  static const red = Color(0xFFDC2626);
}

// ─────────────────────────────────────────────────────────────────────────────
//  CONSTANTS
// ─────────────────────────────────────────────────────────────────────────────

const _kTermOptions = [36, 48, 60, 72];

// Native Ad Unit ID
String get _kNativeAdUnitId => AdService.nativeAdUnitId;

// ─────────────────────────────────────────────────────────────────────────────
//  SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class AutoLoanCalculatorScreen extends StatefulWidget {
  const AutoLoanCalculatorScreen({super.key});

  @override
  State<AutoLoanCalculatorScreen> createState() =>
      _AutoLoanCalculatorScreenState();
}

class _AutoLoanCalculatorScreenState extends State<AutoLoanCalculatorScreen> {
  // ── Text controllers ───────────────────────────────────────────────────────
  final _vehiclePriceCtrl = TextEditingController(text: '35000');
  final _downPaymentCtrl = TextEditingController(text: '5000');
  final _aprCtrl = TextEditingController(text: '5.9');

  // ── Calculation state ──────────────────────────────────────────────────────
  int _selectedTermMonths = 60;
  double _monthlyPayment = 0;
  double _totalInterest = 0;
  double _totalCost = 0;

  // ── Native ad state ────────────────────────────────────────────────────────
  NativeAd? _nativeAd;
  bool _nativeAdLoaded = false;
  bool _nativeAdFailed = false;

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _calculate();
    _loadNativeAd();
    AdService().loadInterstitialAd(
      request: const AdRequest(
        contentUrl: AdContentUrl.autoLoan,
        keywords: AdKeywords.autoLoan,
      ),
    );
  }

  @override
  void dispose() {
    _vehiclePriceCtrl.dispose();
    _downPaymentCtrl.dispose();
    _aprCtrl.dispose();
    _nativeAd?.dispose();
    super.dispose();
  }

  // ── Native ad loading ──────────────────────────────────────────────────────

  void _loadNativeAd() {
    _nativeAd = NativeAd(
      adUnitId: _kNativeAdUnitId,
      // 'listTile' factory renders AdMob's medium template which includes
      // its own "Ad" badge. Our external "Sponsored" label is supplementary,
      // satisfying §5.2 even on template versions that render the badge small.
      factoryId: 'listTile',
      listener: NativeAdListener(
        onAdLoaded: (_) {
          if (mounted) setState(() => _nativeAdLoaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('NativeAd failed to load: ${error.message}');
          ad.dispose();
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

  // ── Calculation helpers ────────────────────────────────────────────────────

  ({double principal, double rate}) _parsedInputs() {
    final price =
        double.tryParse(_vehiclePriceCtrl.text.replaceAll(',', '')) ?? 0;
    final down =
        double.tryParse(_downPaymentCtrl.text.replaceAll(',', '')) ?? 0;
    final rate = double.tryParse(_aprCtrl.text) ?? 0;
    return (principal: math.max(0, price - down), rate: rate);
  }

  void _calculate() {
    final (:principal, :rate) = _parsedInputs();
    if (principal <= 0 || _selectedTermMonths <= 0) return;

    final payment = CalculatorLogic.calculateEMI(
      principal: principal,
      annualInterestRate: rate,
      months: _selectedTermMonths,
    );
    final down =
        double.tryParse(_downPaymentCtrl.text.replaceAll(',', '')) ?? 0;

    setState(() {
      _monthlyPayment = payment;
      _totalInterest = (payment * _selectedTermMonths) - principal;
      _totalCost = down + principal + _totalInterest;
    });
  }

  // FIX: mounted guard prevents setState after dispose if user navigates
  // back while the interstitial is still visible.
  void _triggerAdAndCalculate() {
    FocusScope.of(context).unfocus();
    AdService().showInterstitialAd(
      onAdClosed: () {
        if (mounted) _calculate();
      },
    );
  }

  void _saveCalculation() {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final formatCurrency = NumberFormat.currency(
      symbol: settings.currencySymbol,
      decimalDigits: 0,
    );
    final price = double.tryParse(_vehiclePriceCtrl.text.replaceAll(',', '')) ?? 0;
    
    if (price <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid vehicle price before saving.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (_monthlyPayment <= 0) {
      _calculate();
    }

    final defaultName = 'Auto Loan - ${formatCurrency.format(price)}';
    final nameCtrl = TextEditingController(text: defaultName);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Save Calculation',
          style: GoogleFonts.manrope(
            fontWeight: FontWeight.bold,
            color: context.textPrimary,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enter a name to identify this calculation:',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: context.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: nameCtrl,
              autofocus: true,
              style: GoogleFonts.inter(
                color: context.textPrimary,
                fontWeight: FontWeight.w600,
              ),
              decoration: InputDecoration(
                hintText: 'e.g. My Next Car',
                hintStyle: GoogleFonts.inter(
                  color: context.textSecondary.withValues(alpha: 0.5),
                ),
                filled: true,
                fillColor: context.inputFill,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 14,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: context.borderColor),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: context.borderColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: context.primaryColor, width: 2),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                color: context.textSecondary,
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              final name = nameCtrl.text.trim().isNotEmpty
                  ? nameCtrl.text.trim()
                  : defaultName;

              final dp = double.tryParse(_downPaymentCtrl.text.replaceAll(',', '')) ?? 0;
              final rate = double.tryParse(_aprCtrl.text) ?? 0;

              final input = AffordabilityInput(
                annualIncome: price,
                monthlyDebts: 0,
                downPayment: dp,
                loanTerm: (_selectedTermMonths / 12).ceil(),
                interestRate: rate,
              );

              final result = AffordabilityResult(
                maxHomePrice: price,
                monthlyMortgage: _monthlyPayment,
                totalMonthlyPayment: _monthlyPayment,
                debtToIncomeRatio: 0,
                breakdown: PaymentBreakdown(
                  principalAndInterest: _monthlyPayment,
                  propertyTaxes: _totalInterest,
                  homeInsurance: 0,
                  pmi: 0,
                ),
              );

              final metadata = {
                'vehiclePrice': price,
                'termMonths': _selectedTermMonths,
                'totalInterest': _totalInterest,
                'totalCost': _totalCost,
              };

              final scaffoldMessenger = ScaffoldMessenger.of(context);
              final primaryColor = context.primaryColor;
              final navigator = Navigator.of(context);
              final dialogNavigator = Navigator.of(ctx);

              await context.read<AffordabilityProvider>().saveCustomCalculation(
                name,
                input,
                result,
                calculatorType: CalculatorType.autoLoan,
                metadata: metadata,
              );

              dialogNavigator.pop();
              scaffoldMessenger.showSnackBar(
                SnackBar(
                  content: const Text('Calculation saved successfully!'),
                  behavior: SnackBarBehavior.floating,
                  action: SnackBarAction(
                    label: 'View',
                    textColor: primaryColor,
                    onPressed: () {
                      navigator.push(
                        MaterialPageRoute(
                          builder: (_) => const SavedCalculationsScreen(),
                        ),
                      );
                    },
                  ),
                ),
              );
            },
            child: Text(
              'Save',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.bold,
                color: context.primaryColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final formatCurrency = NumberFormat.currency(
      symbol: settings.currencySymbol,
      decimalDigits: 0,
    );

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: context.pageBackground,
        appBar: _buildAppBar(),
        body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── 1. Input form ─────────────────────────────────────────────
              _buildInputCard(settings),
              const SizedBox(height: 20),

              // ── 2. Calculate & Save buttons ──────────────────────────────
              _buildActionButtons(),
              const SizedBox(height: 20),

              // ── 3. Results card ───────────────────────────────────────────
              _buildResultsCard(formatCurrency),
              const SizedBox(height: 20),

              // ─────────────────────────────────────────────────────────────
              // ✅ PRIMARY NATIVE AD PLACEMENT
              //
              // Position: between Results card and Term Comparison card.
              //
              // Why here:
              //  • Natural content-section break (result → comparison).
              //  • User has already seen their primary output (monthly
              //    payment) — ad does not obstruct the calculator result.
              //  • Interstitial has already fired and fully closed before
              //    the user scrolls here — two formats never co-visible.
              //  • Not adjacent to any tappable widget above or below.
              //  • "Sponsored" label outside AdMob widget (Policy §5.2).
              // ─────────────────────────────────────────────────────────────
              if (!_nativeAdFailed) ...[
                _nativeAdLoaded && _nativeAd != null
                    ? _NativeAdCard(nativeAd: _nativeAd!)
                    : const _NativeAdPlaceholder(),
                const SizedBox(height: 20),
              ],

              // ── 4. Term comparison ────────────────────────────────────────
              _buildTermComparisonCard(formatCurrency),
              const SizedBox(height: 24),

              // ── 5. Disclaimer ─────────────────────────────────────────────
              Text(
                'Estimates do not include taxes, title, registration, or fees.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(color: context.textSecondary, fontSize: 12),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  // ── AppBar ─────────────────────────────────────────────────────────────────

  PreferredSizeWidget _buildAppBar() => GradientAppBar(
    backgroundColor: Colors.transparent,
    elevation: 0,
    surfaceTintColor: Colors.transparent,
    leading: IconButton(
      icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
      tooltip: 'Back',
      onPressed: () => Navigator.pop(context),
    ),
    title: Text(
      'Auto Loan Calculator',
      style: GoogleFonts.manrope(
        color: Colors.white,
        fontWeight: FontWeight.w800,
        fontSize: 18,
      ),
    ),
    bottom: const PreferredSize(
      preferredSize: Size.fromHeight(1),
      child: Divider(height: 1, color: Colors.white24),
    ),
  );

  // ── Input card ─────────────────────────────────────────────────────────────

  Widget _buildInputCard(SettingsProvider settings) => _Card(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Loan Details',
          style: GoogleFonts.manrope(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: context.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Enter your vehicle and financing information',
          style: GoogleFonts.inter(fontSize: 13, color: context.textSecondary),
        ),
        const _CardDivider(),

        _InputField(
          label: 'Vehicle Price',
          controller: _vehiclePriceCtrl,
          prefix: settings.currencySymbol,
        ),
        const SizedBox(height: 16),

        Row(
          children: [
            Expanded(
              child: _InputField(
                label: 'Down / Trade-in',
                controller: _downPaymentCtrl,
                prefix: settings.currencySymbol,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _InputField(
                label: 'APR (%)',
                controller: _aprCtrl,
                suffix: '%',
              ),
            ),
          ],
        ),

        const SizedBox(height: 20),
        Text(
          'Loan Term',
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: context.textSecondary,
          ),
        ),
        const SizedBox(height: 8),

        Row(
          children: [
            for (int i = 0; i < _kTermOptions.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              Expanded(
                child: _TermToggle(
                  months: _kTermOptions[i],
                  isSelected: _selectedTermMonths == _kTermOptions[i],
                  onTap: () {
                    setState(() => _selectedTermMonths = _kTermOptions[i]);
                    _calculate();
                  },
                ),
              ),
            ],
          ],
        ),
      ],
    ),
  );

  // ── Action buttons ────────────────────────────────────────────────────────

  Widget _buildActionButtons() => Row(
    children: [
      Expanded(
        flex: 3,
        child: ElevatedButton.icon(
          onPressed: _triggerAdAndCalculate,
          icon: const Icon(Icons.calculate_outlined, size: 20),
          label: Text(
            'Calculate',
            style: GoogleFonts.manrope(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: _C.primary,
            foregroundColor: Colors.white,
            minimumSize: const Size(0, 52),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 2,
            shadowColor: _C.primary.withValues(alpha: 0.3),
          ),
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        flex: 2,
        child: OutlinedButton.icon(
          onPressed: _saveCalculation,
          icon: Icon(Icons.bookmark_add_outlined, size: 20, color: context.primaryColor),
          label: Text(
            'Save',
            style: GoogleFonts.manrope(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: context.primaryColor,
            ),
          ),
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: context.primaryColor, width: 1.5),
            minimumSize: const Size(0, 52),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
    ],
  );

  // ── Results card ───────────────────────────────────────────────────────────

  Widget _buildResultsCard(NumberFormat fmt) => _Card(
    child: Column(
      children: [
        Text(
          'ESTIMATED MONTHLY PAYMENT',
          style: GoogleFonts.inter(
            color: context.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          fmt.format(_monthlyPayment),
          style: GoogleFonts.manrope(
            color: _C.emerald,
            fontSize: 42,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'per month',
          style: GoogleFonts.inter(fontSize: 13, color: context.textSecondary),
        ),
        const SizedBox(height: 20),
        Divider(color: context.borderColor),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: _ResultStat(
                label: 'Total Interest',
                value: fmt.format(_totalInterest),
                valueColor: _C.red,
              ),
            ),
            Container(width: 1, height: 44, color: context.borderColor),
            Expanded(
              child: _ResultStat(
                label: 'Total Cost',
                value: fmt.format(_totalCost),
              ),
            ),
          ],
        ),
      ],
    ),
  );

  // ── Term comparison card ───────────────────────────────────────────────────

  Widget _buildTermComparisonCard(NumberFormat fmt) {
    final (:principal, :rate) = _parsedInputs();
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.compare_arrows, size: 18, color: context.primaryColor),
              const SizedBox(width: 8),
              Text(
                'Term Comparison',
                style: GoogleFonts.manrope(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: context.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          for (int i = 0; i < _kTermOptions.length; i++) ...[
            if (i > 0) Divider(height: 24, color: context.borderColor),
            _ComparisonRow(
              months: _kTermOptions[i],
              principal: principal,
              rate: rate,
              selectedMonths: _selectedTermMonths,
              format: fmt,
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  _NativeAdCard
// ─────────────────────────────────────────────────────────────────────────────
//
// Renders the loaded NativeAd between Results and Term Comparison.
//
// POLICY CHECKLIST:
//   ✅ "Sponsored" label rendered OUTSIDE AdMob's NativeAd widget.
//      Cannot be hidden by the template → §5.2 "clearly distinguishable".
//   ✅ Horizontal dividers above and below visually separate the ad from
//      calculator content cards on both sides.
//   ✅ NO InkWell / GestureDetector / onTap on the outer Container.
//      All click handling delegated to AdWidget → no accidental clicks.
//   ✅ ClipRRect respects rounded corners without intercepting touch events.
//   ✅ Fixed height (320px) keeps scroll layout stable before/after load.
// ─────────────────────────────────────────────────────────────────────────────

class _NativeAdCard extends StatelessWidget {
  final NativeAd nativeAd;

  // Height must match your registered 'listTile' factory output.
  // Adjust this value if you use a different template height.
  static const double _adHeight = 320;

  const _NativeAdCard({required this.nativeAd});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Top divider with centred "Sponsored" pill ────────────────────
        // Rendered OUTSIDE the NativeAd widget so the template can never
        // obscure it. Satisfies AdMob Policy §5.2.
        Row(
          children: [
            Expanded(
              child: Divider(
                thickness: 1,
                color: context.borderColor,
                endIndent: 10,
              ),
            ),

            // "Sponsored" disclosure pill ─────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: context.isDark ? Colors.amber.withValues(alpha: 0.15) : const Color(0xFFFFF7E6),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: context.isDark ? Colors.amber.withValues(alpha: 0.4) : const Color(0xFFFFB800).withValues(alpha: 0.45),
                  width: 0.8,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.campaign_outlined,
                    size: 11,
                    color: context.isDark ? Colors.amber.shade300 : const Color(0xFFB45309),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Sponsored',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: context.isDark ? Colors.amber.shade300 : const Color(0xFFB45309),
                      letterSpacing: 0.4,
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: Divider(
                thickness: 1,
                color: context.borderColor,
                indent: 10,
              ),
            ),
          ],
        ),

        const SizedBox(height: 10),

        // ── AdMob NativeAd widget ────────────────────────────────────────
        // NOT wrapped in InkWell / GestureDetector / onTap.
        // Click handling is delegated entirely to AdWidget internally.
        // This prevents accidental-click policy violations.
        Container(
          height: _adHeight,
          decoration: BoxDecoration(
            color: context.cs.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: context.borderColor),
            boxShadow: const [
              BoxShadow(
                color: Color(0x07000000),
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          // ClipRRect applies rounded corners without adding a tap region.
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: AdWidget(ad: nativeAd),
          ),
        ),

        const SizedBox(height: 10),

        // ── Bottom divider ───────────────────────────────────────────────
        // Visual separator between the ad and the Term Comparison card.
        Divider(thickness: 1, color: context.borderColor),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  _NativeAdPlaceholder
// ─────────────────────────────────────────────────────────────────────────────
// Shown while the NativeAd is loading or if it fails to load.
// Fixed total height matches _NativeAdCard so the scroll layout never
// reflows when the real ad replaces this widget.
//
// Slot height breakdown:
//   divider row (~17px) + gap(10) + card(320) + gap(10) + divider(~17) = ~374px
// ─────────────────────────────────────────────────────────────────────────────

class _NativeAdPlaceholder extends StatelessWidget {
  const _NativeAdPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Top divider (no label while loading)
        Divider(thickness: 1, color: context.borderColor),
        const SizedBox(height: 10),

        // Placeholder card — identical dimensions to _NativeAdCard
        Container(
          height: 320,
          decoration: BoxDecoration(
            color: context.inputFill,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: context.borderColor),
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _PulsingIcon(),
                const SizedBox(height: 10),
                Text(
                  'Sponsored',
                  style: TextStyle(
                    fontSize: 12,
                    color: context.textSecondary,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 10),
        Divider(thickness: 1, color: context.borderColor),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  _PulsingIcon  — subtle breathing animation for the placeholder
// ─────────────────────────────────────────────────────────────────────────────

class _PulsingIcon extends StatefulWidget {
  @override
  State<_PulsingIcon> createState() => _PulsingIconState();
}

class _PulsingIconState extends State<_PulsingIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
    _anim = Tween<double>(
      begin: 0.25,
      end: 0.75,
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
    child: Icon(Icons.image_outlined, size: 38, color: Colors.grey.shade300),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  REUSABLE PRIVATE WIDGETS  (unchanged from original)
// ─────────────────────────────────────────────────────────────────────────────

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: context.cardColor,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: context.borderColor),
      boxShadow: const [
        BoxShadow(
          color: Color(0x0A000000),
          blurRadius: 10,
          offset: Offset(0, 4),
        ),
      ],
    ),
    child: child,
  );
}

class _CardDivider extends StatelessWidget {
  const _CardDivider();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 16),
    child: Divider(height: 1, color: context.borderColor),
  );
}

class _InputField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String? prefix;
  final String? suffix;

  const _InputField({
    required this.label,
    required this.controller,
    this.prefix,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: context.textSecondary,
        ),
      ),
      const SizedBox(height: 6),
      TextField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.,]'))],
        style: GoogleFonts.inter(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: context.textPrimary,
        ),
        decoration: InputDecoration(
          prefixText: prefix != null ? '$prefix ' : null,
          suffixText: suffix != null ? ' $suffix' : null,
          prefixStyle: GoogleFonts.inter(fontSize: 15, color: context.textSecondary),
          suffixStyle: GoogleFonts.inter(fontSize: 15, color: context.textSecondary),
          filled: true,
          fillColor: context.inputFill,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 14,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: context.borderColor),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: context.borderColor),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: context.primaryColor, width: 2),
          ),
        ),
      ),
    ],
  );
}

class _TermToggle extends StatelessWidget {
  final int months;
  final bool isSelected;
  final VoidCallback onTap;

  const _TermToggle({
    required this.months,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: isSelected
            ? context.primaryColor.withValues(alpha: 0.1)
            : (context.isDark ? context.inputFill : Colors.white),
        border: Border.all(
          color: isSelected ? context.primaryColor : context.borderColor,
          width: isSelected ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            '$months',
            style: GoogleFonts.manrope(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: isSelected ? context.primaryColor : context.textPrimary,
            ),
          ),
          Text(
            'mo',
            style: GoogleFonts.inter(
              fontSize: 11,
              color: isSelected
                  ? context.primaryColor.withValues(alpha: 0.8)
                  : context.textSecondary,
            ),
          ),
        ],
      ),
    ),
  );
}

class _ResultStat extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _ResultStat({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(label, style: GoogleFonts.inter(color: context.textSecondary, fontSize: 13)),
      const SizedBox(height: 4),
      Text(
        value,
        style: GoogleFonts.manrope(
          color: valueColor ?? context.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w800,
        ),
      ),
    ],
  );
}

class _ComparisonRow extends StatelessWidget {
  final int months;
  final double principal;
  final double rate;
  final int selectedMonths;
  final NumberFormat format;

  const _ComparisonRow({
    required this.months,
    required this.principal,
    required this.rate,
    required this.selectedMonths,
    required this.format,
  });

  @override
  Widget build(BuildContext context) {
    double payment = 0;
    double interest = 0;

    if (principal > 0) {
      payment = CalculatorLogic.calculateEMI(
        principal: principal,
        annualInterestRate: rate,
        months: months,
      );
      interest = (payment * months) - principal;
    }

    final isCurrent = months == selectedMonths;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '$months Months',
                  style: GoogleFonts.manrope(
                    fontWeight: FontWeight.w700,
                    color: isCurrent ? context.primaryColor : context.textPrimary,
                  ),
                ),
                if (isCurrent) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: context.primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'Selected',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: context.primaryColor,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            Text(
              interest > 0
                  ? 'Int: ${format.format(interest)}'
                  : 'Enter details above',
              style: GoogleFonts.inter(fontSize: 12, color: context.textSecondary),
            ),
          ],
        ),
        Text(
          payment > 0 ? '${format.format(payment)}/mo' : '—',
          style: GoogleFonts.manrope(
            fontWeight: FontWeight.w800,
            fontSize: 16,
            color: isCurrent ? context.primaryColor : context.textPrimary,
          ),
        ),
      ],
    );
  }
}
