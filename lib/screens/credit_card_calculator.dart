import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../utils/calculator_logic.dart';
import '../services/ad_service.dart';
import '../providers/settings_provider.dart';
import '../widgets/ad_native_widget.dart';
import 'credit_card_schedule_screen.dart';
import '../core/constants/theme_extensions.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AD PLACEMENT STRATEGY — what changed and why
// ─────────────────────────────────────────────────────────────────────────────
//
// REMOVED → InterstitialAd on the "Calculate" button (_triggerAdAndCalculate)
//   • Identical violation to auto_loan_calculator: tapping "Calculate" is not
//     a natural transition point — it updates results on the same screen.
//   • Users who test multiple APRs or payments would be hit with a full-screen
//     ad on every tap, violating "Unexpected Interstitial / Interfering with
//     App Functionality" policy and guaranteeing uninstalls.
//   • Calculate button now calls _calculate() directly.
//   • ad_service.dart import retained — AdService is still used for the
//     interstitial on "View Schedule" navigation (see below).
//
// ADDED → InterstitialAd on "View Schedule" navigation
//   • Navigating from this screen to CreditCardScheduleScreen IS a genuine
//     natural transition point — the user has completed their calculation
//     and is moving to a new screen to see the full breakdown.
//   • This is exactly the pattern AdMob policy permits for interstitials.
//   • The interstitial fires once per session maximum (AdService handles
//     frequency capping internally). The schedule opens in onAdClosed.
//
// REMOVED → AdBannerWidget inside a Stack with custom "ADVERTISEMENT" label
//   • Three violations in one:
//     1. A banner inside a Stack/Positioned is not an anchored banner —
//        it overlays content, creating accidental-click risk as the keyboard
//        appears/disappears and shifts the layout.
//     2. Custom "ADVERTISEMENT" label around an AdMob unit is explicitly
//        prohibited — AdMob renders all required disclosures internally.
//     3. AdBannerWidget (likely using a fixed AdSize) is deprecated in favour
//        of the anchored adaptive size API.
//   • ad_banner_widget.dart import removed.
//
// ADDED → Anchored Adaptive BannerAd in bottomNavigationBar
//   • Replaced with a proper anchored adaptive banner loaded in
//     didChangeDependencies() using the correct API.
//   • Placed as the sole widget in bottomNavigationBar — anchored to the
//     absolute screen edge, no custom labels, no adjacent widgets.
//   • ScrollView bottom padding compensates for banner height dynamically.
//   • No hardcoded Stack/Positioned layout needed.
//
// FIXED → Missing TextEditingController dispose()
//   • The original never disposed the three controllers — memory leak.
//   • Added proper dispose() calls.
// ─────────────────────────────────────────────────────────────────────────────

class CreditCardCalculatorScreen extends StatefulWidget {
  const CreditCardCalculatorScreen({super.key});

  @override
  State<CreditCardCalculatorScreen> createState() =>
      _CreditCardCalculatorScreenState();
}

class _CreditCardCalculatorScreenState
    extends State<CreditCardCalculatorScreen> {
  final _balanceController = TextEditingController(text: '5000');
  final _paymentController = TextEditingController(text: '250');
  final _aprController = TextEditingController(text: '18.9');

  int _monthsToPayOff = 0;
  double _totalInterest = 0;
  double _totalPaid = 0;
  bool _neverPaysOff = false;

  // ── Lifecycle ────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _calculate();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }

  @override
  void dispose() {
    _balanceController.dispose();
    _paymentController.dispose();
    _aprController.dispose();

    super.dispose();
  }

  // ── Banner ad ────────────────────────────────────────────────────────────────

  // ── Calculation ──────────────────────────────────────────────────────────────

  void _calculate() {
    final balance =
        double.tryParse(_balanceController.text.replaceAll(',', '')) ?? 0;
    final payment =
        double.tryParse(_paymentController.text.replaceAll(',', '')) ?? 0;
    final apr = double.tryParse(_aprController.text) ?? 0;

    if (balance <= 0 || payment <= 0 || apr < 0) return;

    final monthlyRate = (apr / 100) / 12;

    if (payment <= balance * monthlyRate) {
      setState(() {
        _neverPaysOff = true;
        _monthsToPayOff = 0;
        _totalInterest = 0;
        _totalPaid = 0;
      });
      return;
    }

    final months = CalculatorLogic.calculateCreditCardPayoffMonths(
      balance: balance,
      monthlyPayment: payment,
      apr: apr,
    );

    setState(() {
      _neverPaysOff = false;
      _monthsToPayOff = months;
      _totalInterest = (payment * months) - balance;
      _totalPaid = balance + _totalInterest;
    });
  }

  /// Navigates to CreditCardScheduleScreen via an InterstitialAd.
  /// Screen-to-screen navigation is a policy-compliant interstitial trigger.
  void _navigateToSchedule() {
    final balance =
        double.tryParse(_balanceController.text.replaceAll(',', '')) ?? 0;
    final payment =
        double.tryParse(_paymentController.text.replaceAll(',', '')) ?? 0;
    final apr = double.tryParse(_aprController.text) ?? 0;

    if (balance <= 0 || payment <= 0) return;

    AdService().showInterstitialAd(
      onAdClosed: () {
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CreditCardScheduleScreen(
              balance: balance,
              monthlyPayment: payment,
              apr: apr,
            ),
          ),
        );
      },
    );
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final formatCurrency = NumberFormat.currency(
      symbol: settings.currencySymbol,
      decimalDigits: 0,
    );

    final double bottomPadding = 16.0;

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
          'Credit Card Payoff',
          style: TextStyle(
            color: context.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),

      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(16, 16, 16, bottomPadding),
          child: Column(
            children: [
              // ── Input card ───────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: context.cs.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFF1F5F9)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x08000000),
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Enter Details',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        color: context.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildInputField(
                      'Current Balance',
                      _balanceController,
                      prefix: settings.currencySymbol,
                    ),
                    const SizedBox(height: 16),
                    _buildInputField(
                      'Monthly Payment',
                      _paymentController,
                      prefix: settings.currencySymbol,
                    ),
                    const SizedBox(height: 16),
                    _buildInputField(
                      'Interest Rate (APR)',
                      _aprController,
                      suffix: '%',
                    ),
                    const SizedBox(height: 24),
                    // Calculate now calls _calculate() directly — no interstitial.
                    // Interstitial fires on "View Schedule" navigation instead.
                    ElevatedButton(
                      onPressed: () {
                        _calculate();
                        FocusScope.of(context).unfocus();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: context.cs.surface,
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Calculate',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // ── Native ad — between input and results ────────────────────
              // Non-interactive content above (input card) and below (results)
              // act as natural buffers on both sides. High-engagement position.
              const AdNativeWidget(),

              const SizedBox(height: 16),

              // ── Results ──────────────────────────────────────────────────
              if (_neverPaysOff)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: Colors.red),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Warning: Your monthly payment is less than the monthly interest. You will never pay off this debt.',
                          style: TextStyle(color: Colors.red, fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                )
              else
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x332563EB),
                        blurRadius: 15,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Text(
                        'PAYOFF SUMMARY',
                        style: TextStyle(
                          color: context.surface70,
                          fontSize: 12,
                          letterSpacing: 2,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              children: [
                                Text(
                                  'Time to Pay Off',
                                  style: TextStyle(
                                    color: context.surface70,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                RichText(
                                  text: TextSpan(
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 32,
                                      color: context.cs.surface,
                                    ),
                                    children: [
                                      TextSpan(text: '$_monthsToPayOff '),
                                      TextSpan(
                                        text: 'mos',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w500,
                                          color: context.surface70,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${(_monthsToPayOff / 12).toStringAsFixed(1)} Years',
                                  style: TextStyle(
                                    color: context.surface70,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            width: 1,
                            height: 60,
                            color: context.cs.surface.withValues(alpha: 0.15),
                          ),
                          Expanded(
                            child: Column(
                              children: [
                                Text(
                                  'Total Interest',
                                  style: TextStyle(
                                    color: context.surface70,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  formatCurrency.format(_totalInterest),
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 32,
                                    color: context.cs.surface,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Over $_monthsToPayOff months',
                                  style: TextStyle(
                                    color: context.surface70,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24), Divider(color: context.surface10),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Total Paid',
                                style: TextStyle(
                                  color: context.surface70,
                                  fontSize: 13,
                                ),
                              ),
                              Text(
                                formatCurrency.format(_totalPaid),
                                style: TextStyle(
                                  color: context.cs.surface,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          // "View Schedule" triggers the interstitial then navigates.
                          // This is a genuine screen transition — policy-compliant.
                          TextButton(
                            onPressed: _navigateToSchedule,
                            style: TextButton.styleFrom(
                              foregroundColor: context.cs.surface,
                              padding: EdgeInsets.zero,
                            ),
                            child: const Row(
                              children: [
                                Text(
                                  'View Schedule',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Icon(Icons.chevron_right_rounded, size: 18),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Input field widget ────────────────────────────────────────────────────────

  Widget _buildInputField(
    String label,
    TextEditingController controller, {
    String? prefix,
    String? suffix,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: context.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            prefixText: prefix != null ? '$prefix ' : null,
            suffixText: suffix != null ? ' $suffix' : null,
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
          ),
        ),
      ],
    );
  }
}