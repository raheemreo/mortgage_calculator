
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../providers/settings_provider.dart';
import '../services/ad_service.dart';
import '../utils/calculator_logic.dart';
import 'amortization_schedule_screen.dart';
import '../core/constants/theme_extensions.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Ad unit IDs
// Swap the production strings before release; test IDs are safe for dev only.
// ─────────────────────────────────────────────────────────────────────────────
abstract final class _AdIds {
  // Native Advanced
  static String get native => AdService.nativeAdUnitId;
}

// ─────────────────────────────────────────────────────────────────────────────
// Interstitial frequency counter
//
// FIX: The previous implementation stored _scheduleNavigationCount inside
// _PitiCalculatorScreenState. State is discarded and recreated whenever the
// widget is removed from the tree (e.g. the user navigates away and back).
// That reset the counter to 0 on every visit, so the "1-in-3" cap never
// accumulated across multiple screen sessions — the interstitial could fire
// on the very first navigation of every visit.
//
// Moving the counter to a singleton that lives outside widget state means it
// persists for the entire app session, matching how AdMob frequency caps work.
// ─────────────────────────────────────────────────────────────────────────────
class _InterstitialCounter {
  _InterstitialCounter._();
  static final _InterstitialCounter instance = _InterstitialCounter._();

  int _count = 0;
  static const int _frequency = 3;

  /// Returns true when the counter hits the frequency threshold.
  bool tick() {
    _count++;
    return _count % _frequency == 0;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PitiCalculatorScreen
// ─────────────────────────────────────────────────────────────────────────────
class PitiCalculatorScreen extends StatefulWidget {
  const PitiCalculatorScreen({super.key});

  @override
  State<PitiCalculatorScreen> createState() => _PitiCalculatorScreenState();
}

class _PitiCalculatorScreenState extends State<PitiCalculatorScreen> {
  final GlobalKey _resultKey = GlobalKey();

  // ── Text controllers ────────────────────────────────────────────────────────
  final _priceController = TextEditingController(text: '450,000');
  final _downPaymentController = TextEditingController(text: '90,000');
  final _downPercentController = TextEditingController(text: '20');
  final _rateController = TextEditingController(text: '6.5');
  final _taxController = TextEditingController(text: '5,400');
  final _insuranceController = TextEditingController(text: '1,200');
  final _hoaController = TextEditingController(text: '0');
  final _pmiController = TextEditingController(text: '0');
  final _extraMonthlyController = TextEditingController(text: '200');
  final _extraBiweeklyController = TextEditingController(text: '0');
  final _extraLumpSumController = TextEditingController(text: '0');

  // ── Calculator state ────────────────────────────────────────────────────────
  String _selectedTerm = '30';
  bool _extraPaymentsEnabled = true;
  double _monthlyPITI = 0;
  double _piAmount = 0;
  double _taxInsAmount = 0;
  bool _isSyncing = false; // guards recursive listener loops

  // ── Ad state ─────────────────────────────────────────────────────────────

  // FIX: NativeAd is now a full lifecycle object with load/dispose, not a
  // placeholder. The previous version had no NativeAd declaration at all —
  // "Native Ads" in the summary was aspirational, not implemented.
  NativeAd? _nativeAd;
  bool _isNativeLoaded = false;

  // ── Design tokens removed in favor of theme_extensions.dart ──
  @override
  void initState() {
    super.initState();
    _calculate(shouldUnfocus: false);
    _loadNativeAd();

    _priceController.addListener(_onPriceChanged);
    _downPaymentController.addListener(_onDownPaymentChanged);
    _downPercentController.addListener(_onDownPercentChanged);
  }

  @override
  void dispose() {
    _priceController
      ..removeListener(_onPriceChanged)
      ..dispose();
    _downPaymentController
      ..removeListener(_onDownPaymentChanged)
      ..dispose();
    _downPercentController
      ..removeListener(_onDownPercentChanged)
      ..dispose();
    _rateController.dispose();
    _taxController.dispose();
    _insuranceController.dispose();
    _hoaController.dispose();
    _pmiController.dispose();
    _extraMonthlyController.dispose();
    _extraBiweeklyController.dispose();
    _extraLumpSumController.dispose();

    _nativeAd?.dispose(); // FIX: native ad now properly disposed
    super.dispose();
  }

  // ── Down payment ↔ percentage sync ─────────────────────────────────────────
  double get _price =>
      double.tryParse(_priceController.text.replaceAll(',', '')) ?? 0;
  double get _down =>
      double.tryParse(_downPaymentController.text.replaceAll(',', '')) ?? 0;
  double get _percent => double.tryParse(_downPercentController.text) ?? 0;

  void _onPriceChanged() {
    if (_isSyncing) return;
    _isSyncing = true;
    if (_price > 0 && _percent > 0) {
      _downPaymentController.text = _fmt(
        (_price * _percent / 100).roundToDouble(),
      );
    }
    _isSyncing = false;
    _calculate(shouldUnfocus: false);
  }

  void _onDownPaymentChanged() {
    if (_isSyncing) return;
    _isSyncing = true;
    if (_price > 0) {
      _downPercentController.text = (_down / _price * 100).toStringAsFixed(1);
    }
    _isSyncing = false;
    _calculate(shouldUnfocus: false);
  }

  void _onDownPercentChanged() {
    if (_isSyncing) return;
    _isSyncing = true;
    if (_price > 0 && _percent > 0) {
      _downPaymentController.text = _fmt(
        (_price * _percent / 100).roundToDouble(),
      );
    }
    _isSyncing = false;
    _calculate(shouldUnfocus: false);
  }

  String _fmt(double v) => NumberFormat('#,##0', 'en_US').format(v);

  // ── Core calculation ────────────────────────────────────────────────────────
  void _calculate({bool shouldUnfocus = true}) {
    final rate = double.tryParse(_rateController.text) ?? 0;
    final years = int.tryParse(_selectedTerm) ?? 30;
    final tax =
        (double.tryParse(_taxController.text.replaceAll(',', '')) ?? 0) / 12;
    final ins =
        (double.tryParse(_insuranceController.text.replaceAll(',', '')) ?? 0) /
        12;
    final hoa =
        (double.tryParse(_hoaController.text.replaceAll(',', '')) ?? 0) / 12;
    final pmi =
        (double.tryParse(_pmiController.text.replaceAll(',', '')) ?? 0) / 12;
    final principal = (_price - _down).clamp(0.0, double.infinity).toDouble();
    final pi = CalculatorLogic.calculateEMI(
      principal: principal,
      annualInterestRate: rate,
      months: years * 12,
    );

    setState(() {
      _piAmount = pi;
      _taxInsAmount = tax + ins + hoa + pmi;
      _monthlyPITI = _piAmount + _taxInsAmount;
    });

    if (shouldUnfocus) {
      FocusScope.of(context).unfocus();
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_resultKey.currentContext != null) {
          Scrollable.ensureVisible(
            _resultKey.currentContext!,
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOut,
          );
        }
      });
    }
  }

  // ── Navigation to amortization screen ──────────────────────────────────────
  // Interstitial triggers here — a genuine navigation transition — not on the
  // Calculate button, which would interrupt the primary user workflow.
  // The persistent _InterstitialCounter prevents the cap resetting on rebuild.
  void _navigateToSchedule() {
    final principal = (_price - _down).clamp(0.0, double.infinity).toDouble();
    final rate = double.tryParse(_rateController.text) ?? 0;
    final years = int.tryParse(_selectedTerm) ?? 30;

    void go() {
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AmortizationScheduleScreen(
            principal: principal,
            interestRate: rate,
            years: years,
          ),
        ),
      );
    }

    if (_InterstitialCounter.instance.tick()) {
      AdService().showInterstitialAd(onAdClosed: go);
    } else {
      go();
    }
  }

  // ── Native Ad ───────────────────────────────────────────────────────────────
  // FIX: Full NativeAd lifecycle implemented. The previous version had no
  // NativeAd code at all. Placement: between the Extra Payments section and
  // the Calculate button. This is a natural pause in the form — the user has
  // finished entering data and is about to act — making it the least intrusive
  // position. The "Ad" label above the unit satisfies AdMob disclosure policy.
  //
  // IMPORTANT: 'listTile' must match a NativeAdFactory registered in
  // MainActivity.kt (Android) and AppDelegate.swift (iOS).
  // See: https://pub.dev/packages/google_mobile_ads#native-ads
  void _loadNativeAd() {
    _nativeAd = NativeAd(
      adUnitId: _AdIds.native,
      factoryId: 'listTile',
      request: const AdRequest(
        contentUrl: AdContentUrl.mortgage,
        keywords: AdKeywords.mortgage,
      ),
      listener: NativeAdListener(
        onAdLoaded: (_) {
          if (mounted) setState(() => _isNativeLoaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('[AdMob] Native failed: ${error.message}');
          ad.dispose();
          _nativeAd = null;
        },
      ),
    )..load();
  }

  // ────────────────────────────────────────────────────────────────────────────
  // Build
  // ────────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final symbol = settings.currencySymbol; // single read; reused below

    final formatCurrency = NumberFormat.currency(
      symbol: symbol,
      decimalDigits: 0,
    );

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDark ? const Color(0xFF60A5FA) : const Color(0xFF0B3D91);
    final secondaryColor = isDark ? const Color(0xFF34D399) : const Color(0xFF1E8449);
    final surfaceBg = context.pageBackground;
    final cardBgColor = context.cardColor;
    final borderCol = context.borderColor;

    return Scaffold(
      backgroundColor: surfaceBg,

      // ── AppBar ──────────────────────────────────────────────────────────────
      appBar: AppBar(
        backgroundColor: cardBgColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: primaryColor, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'PITI Calculator',
          style: TextStyle(
            color: primaryColor,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: borderCol, height: 1),
        ),
      ),

      // ── Body ────────────────────────────────────────────────────────────────
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Column(
          children: [
            // Result card
            Container(
              key: _resultKey,
              child: _ResultCard(
                monthlyPITI: _monthlyPITI,
                piAmount: _piAmount,
                taxInsAmount: _taxInsAmount,
                formatCurrency: formatCurrency,
                onViewSchedule: _navigateToSchedule,
                primaryColor: primaryColor,
              ),
            ),
            
            // ── Native Ad slot ────────────────────────────────────────────────
            if (_isNativeLoaded && _nativeAd != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: _NativeAdSlot(ad: _nativeAd!),
              ),

            // Loan Details
            _buildSection(
              title: 'Loan Details',
              icon: Icons.real_estate_agent_rounded,
              children: [
                _buildInputField(
                  'Home Price',
                  _priceController,
                  prefix: symbol,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: _buildInputField(
                        'Down Payment',
                        _downPaymentController,
                        prefix: symbol,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildInputField(
                        'Down %',
                        _downPercentController,
                        suffix: '%',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildInputField(
                        'Interest Rate',
                        _rateController,
                        suffix: '%',
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildDropdown(
                        label: 'Loan Term',
                        value: _selectedTerm,
                        options: const ['5', '10', '15', '20', '30'],
                        onChanged: (v) {
                          setState(() => _selectedTerm = v!);
                          _calculate(shouldUnfocus: false);
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Homeowner Expenses
            _buildSection(
              title: 'Homeowner Expenses',
              icon: Icons.account_balance_wallet_rounded,
              trailing: const _PillLabel(label: 'YEARLY'),
              children: [
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio: 2.2,
                  children: [
                    _buildInputField(
                      'Property Tax',
                      _taxController,
                      prefix: symbol,
                      small: true,
                    ),
                    _buildInputField(
                      'Home Insurance',
                      _insuranceController,
                      prefix: symbol,
                      small: true,
                    ),
                    _buildInputField(
                      'HOA Fees',
                      _hoaController,
                      prefix: symbol,
                      small: true,
                    ),
                    _buildInputField(
                      'PMI',
                      _pmiController,
                      prefix: symbol,
                      small: true,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Extra Payments
            _buildSection(
              title: 'Extra Payments',
              icon: Icons.speed_rounded,
              trailing: Switch(
                value: _extraPaymentsEnabled,
                onChanged: (v) => setState(() => _extraPaymentsEnabled = v),
                activeThumbColor: secondaryColor,
              ),
              children: [
                // FIX: symbol now threaded through from settings, not
                // hardcoded. The previous _buildRowInput call used a literal
                // '\$' string that ignored the user's currency preference.
                _buildRowInput(
                  'Monthly Extra',
                  _extraMonthlyController,
                  symbol,
                ),
                _buildRowInput(
                  'Bi-weekly Extra',
                  _extraBiweeklyController,
                  symbol,
                ),
                _buildRowInput(
                  'One-time Lump Sum',
                  _extraLumpSumController,
                  symbol,
                ),
              ],
            ),
            const SizedBox(height: 24),


            const SizedBox(height: 24),

            // Calculate button
            ElevatedButton.icon(
              onPressed: () => _calculate(),
              icon: const Icon(Icons.calculate_rounded),
              label: const Text('Calculate Payment'),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: isDark ? const Color(0xFF1E293B) : context.cs.surface,
                minimumSize: const Size(double.infinity, 56),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 4,
                shadowColor: primaryColor.withValues(alpha: 0.3),
                textStyle: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            // Clears the sticky banner height at the bottom.
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  // ────────────────────────────────────────────────────────────────────────────
  // Widget helpers
  // ────────────────────────────────────────────────────────────────────────────

  Widget _buildSection({
    required String title,
    required IconData icon,
    Widget? trailing,
    required List<Widget> children,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDark ? const Color(0xFF60A5FA) : const Color(0xFF0B3D91);
    
    return Container(
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(icon, color: primaryColor, size: 24),
                  const SizedBox(width: 12),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
                    ),
                  ),
                ],
              ),
              trailing ?? const SizedBox.shrink(),
            ],
          ),
          const SizedBox(height: 20),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInputField(
    String label,
    TextEditingController controller, {
    String? prefix,
    String? suffix,
    bool small = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: small ? 13 : 14,
            fontWeight: FontWeight.w500,
            color: context.labelColor,
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: small ? 48 : 56,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: context.inputFill,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: context.borderColor),
            ),
            child: TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[\d,.]')),
              ],
              style: const TextStyle(fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                prefixIcon: prefix != null
                    ? SizedBox(
                        width: 40,
                        child: Center(
                          child: Text(
                            prefix,
                            style: TextStyle(
                              color: context.labelColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      )
                    : null,
                suffixIcon: suffix != null
                    ? SizedBox(
                        width: 40,
                        child: Center(
                          child: Text(
                            suffix,
                            style: TextStyle(
                              color: context.labelColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdown({
    required String label,
    required String value,
    required List<String> options,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: context.labelColor,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: context.inputFill,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: context.borderColor),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              icon: Icon(Icons.expand_more, color: context.labelColor),
              items: options
                  .map(
                    (v) => DropdownMenuItem(
                      value: v,
                      child: Text(
                        '$v Years',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRowInput(
    String label,
    TextEditingController controller,
    String symbol, // FIX: always passed from settings — never hardcoded
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: context.textPrimary,
            ),
          ),
          SizedBox(
            width: 120,
            height: 40,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: context.inputFill,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: context.borderColor),
              ),
              child: TextField(
                controller: controller,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[\d,.]')),
                ],
                textAlign: TextAlign.right,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
                decoration: InputDecoration(
                  prefixIcon: Padding(
                    padding: const EdgeInsets.only(left: 8, top: 10),
                    child: Text(
                      symbol,
                      style: TextStyle(
                        color: context.labelColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _NativeAdSlot
//
// Extracted as its own StatelessWidget so _buildSection can stay pure and
// the "Ad" disclosure label always travels with the AdWidget — no risk of
// accidentally omitting it if the slot is reused elsewhere.
// ─────────────────────────────────────────────────────────────────────────────
class _NativeAdSlot extends StatelessWidget {
  const _NativeAdSlot({required this.ad});
  final NativeAd ad;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Disclosure pill — required by AdMob policy for native placements.
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            'SponsoredAd',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: context.textSecondary,
              letterSpacing: 0.5,
            ),
          ),
        ),
        const SizedBox(height: 8),
        // Standardized height (340px) to prevent advertiser assets clipping.
        Container(
          height: 340,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: context.cs.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: context.borderColor),
          ),
          child: AdWidget(ad: ad),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _ResultCard
// ─────────────────────────────────────────────────────────────────────────────
class _ResultCard extends StatelessWidget {
  const _ResultCard({
    required this.monthlyPITI,
    required this.piAmount,
    required this.taxInsAmount,
    required this.formatCurrency,
    required this.onViewSchedule,
    required this.primaryColor,
  });

  final double monthlyPITI;
  final double piAmount;
  final double taxInsAmount;
  final NumberFormat formatCurrency;
  final VoidCallback onViewSchedule;
  final Color primaryColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: context.cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.borderColor),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'EST. MONTHLY PITI',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
              color: context.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            formatCurrency.format(monthlyPITI),
            style: const TextStyle(
              fontSize: 40,
              fontWeight: FontWeight.bold,
              color: Color(0xFF10B981),
            ),
          ),
          const SizedBox(height: 16),
          const Divider(color: Color(0xFFF1F5F9)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _StatColumn(
                label: 'Principal & Interest',
                value: formatCurrency.format(piAmount),
                crossAxisAlignment: CrossAxisAlignment.start,
              ),
              _StatColumn(
                label: 'Taxes & Ins.',
                value: formatCurrency.format(taxInsAmount),
                crossAxisAlignment: CrossAxisAlignment.end,
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onViewSchedule,
              icon: const Icon(Icons.table_chart_rounded, size: 18),
              label: const Text('View Detailed Schedule'),
              style: OutlinedButton.styleFrom(
                foregroundColor: primaryColor,
                side: BorderSide(color: primaryColor),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Small helpers
// ─────────────────────────────────────────────────────────────────────────────
class _StatColumn extends StatelessWidget {
  const _StatColumn({
    required this.label,
    required this.value,
    required this.crossAxisAlignment,
  });
 final String label;
 final String value;
  final CrossAxisAlignment crossAxisAlignment;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: crossAxisAlignment,
      children: [
        Text(
          label,
          style: TextStyle(color: context.textSecondary, fontSize: 13),
        ),
        Text(
          value,
          style: TextStyle(
            color: context.textPrimary,
            fontWeight: FontWeight.w600, 
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}

class _PillLabel extends StatelessWidget {
  const _PillLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF374151) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: isDark ? const Color(0xFFE5E7EB) : const Color(0xFF475569),
        ),
      ),
    );
  }
}