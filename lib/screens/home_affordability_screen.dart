import 'package:flutter/material.dart';
import '../widgets/gradient_app_bar.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/affordability_model.dart';
import '../providers/affordability_provider.dart';
import '../widgets/ad_native_widget.dart';
import 'insurance_marketplace.dart';
import 'settings_screen.dart';
import '../core/constants/theme_extensions.dart';
import 'saved_calculations_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AD PLACEMENT STRATEGY — what changed and why
// ─────────────────────────────────────────────────────────────────────────────
//
// REMOVED → AdBannerWidget in Stack/Positioned overlay
//   • The original placed AdBannerWidget in a Positioned widget at the bottom
//     of a Stack that overlaid the entire CustomScrollView. This means:
//     1. The banner was not anchored to the screen edge — it was floating
//        over scrollable content, violating AdMob anchored banner policy.
//     2. As the user scrolled, content could appear behind the banner,
//        causing accidental clicks — a high-risk policy violation.
//     3. SizedBox(height: 100) at the bottom of the scroll list was a
//        hardcoded dead-space compensation for the floating banner.
//   • ad_banner_widget.dart import removed.
//
// ADDED → Anchored Adaptive BannerAd in bottomSheet
//   • This screen has a BottomNavigationBar, so bottomNavigationBar is
//     already occupied. The banner goes into bottomSheet — anchored to the
//     absolute screen edge below the nav bar, with nothing adjacent.
//   • Loaded in didChangeDependencies() — safe for MediaQuery.
//   • Scroll view bottom padding compensates for combined nav + banner height.
//   • SizedBox(height: 100) dead-space spacer removed.
//
// KEPT → AdNativeWidget between payment breakdown and end of list
//   • This is a good placement — the user has read all results and the
//     payment breakdown. The native ad sits after the last content section
//     as a natural end-of-content position.
//   • Non-interactive breakdown rows above act as a safe buffer.
//
// KEPT → Interstitial ad commented out in _calculate() on first session
//   • The original had this commented out — kept as-is. If re-enabled,
//     the first-calculation trigger is borderline acceptable (user completes
//     a full form and gets a result for the first time in a session), but
//     should remain once-per-session only, which the existing
//     _hasCalculatedSession flag correctly enforces.
//
// FIXED → BottomNavigationBar wrapped in SafeArea
//   • Missing SafeArea on the nav bar Container — home indicator overlap
//     on modern devices. Fixed.
// ─────────────────────────────────────────────────────────────────────────────

class HomeAffordabilityScreen extends StatefulWidget {
  const HomeAffordabilityScreen({super.key});

  @override
  State<HomeAffordabilityScreen> createState() =>
      _HomeAffordabilityScreenState();
}

class _HomeAffordabilityScreenState extends State<HomeAffordabilityScreen> {
  final GlobalKey _resultKey = GlobalKey();
  final _formKey = GlobalKey<FormState>();
 final TextEditingController _incomeController = TextEditingController();
 final TextEditingController _debtsController = TextEditingController();
 final TextEditingController _downPaymentController = TextEditingController();
 final TextEditingController _interestController = TextEditingController();

  int _loanTerm = 30;
  bool _hasCalculatedSession = false;
  int _currentIndex = 1;

  // ── Design system colors ─────────────────────────────────────────────────────
  static const Color primary = Color(0xFF0037B1);
  static const Color primaryContainer = Color(0xFF1E4ED8);
  static const Color outline = Color(0xFF747686);
  static const Color errorColor = Color(0xFFBA1A1A);
  static const Color tertiary = Color(0xFF004E47);
  static const Color secondary = Color(0xFF515F74);
  static const Color tertiaryContainer = Color(0xFF00685F);

  // ── Lifecycle ────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final provider = Provider.of<AffordabilityProvider>(
        context,
        listen: false,
      );

      await provider.init();

      if (mounted) {
        final lastInput = provider.lastInput;
        if (lastInput != null) {
          _incomeController.text = lastInput.annualIncome.toStringAsFixed(0);
          _debtsController.text = lastInput.monthlyDebts.toStringAsFixed(0);
          _downPaymentController.text = lastInput.downPayment.toStringAsFixed(
            0,
          );
          setState(() {
            _loanTerm = lastInput.loanTerm;
            _interestController.text = lastInput.interestRate.toStringAsFixed(
              2,
            );
          });
        } else {
          _incomeController.text = '120000';
          _debtsController.text = '500';
          _downPaymentController.text = '85000';
          setState(() {
            _loanTerm = 30;
            _interestController.text = provider.currentRate > 0
                ? provider.currentRate.toStringAsFixed(2)
                : '6.85';
          });
        }

        WidgetsBinding.instance.addPostFrameCallback((_) {
          _calculate();
        });
      }
    });
  }

  @override
  void dispose() {
    _incomeController.dispose();
    _debtsController.dispose();
    _downPaymentController.dispose();
    _interestController.dispose();
    super.dispose();
  }

  // ── Calculation ──────────────────────────────────────────────────────────────

  void _calculate() {
    if (!_formKey.currentState!.validate()) return;

    final provider = Provider.of<AffordabilityProvider>(context, listen: false);

    final input = AffordabilityInput(
      annualIncome: double.tryParse(_incomeController.text) ?? 0,
      monthlyDebts: double.tryParse(_debtsController.text) ?? 0,
      downPayment: double.tryParse(_downPaymentController.text) ?? 0,
      loanTerm: _loanTerm,
      interestRate: double.tryParse(_interestController.text) ?? 0,
    );

    provider.calculateAffordability(input);

    if (!_hasCalculatedSession) {
      _hasCalculatedSession = true;
      // Interstitial on first calculation (once-per-session) is borderline
      // acceptable. Re-enable only if _hasCalculatedSession flag is respected:
      // AdService().showInterstitialAd(onAdClosed: () {});
    }

    FocusManager.instance.primaryFocus?.unfocus();

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

  void _saveCalculation() {
    if (!_formKey.currentState!.validate()) return;

    // Ensure the current inputs are calculated and saved to the provider
    _calculate();

    final provider = Provider.of<AffordabilityProvider>(context, listen: false);
    final currencyFormat = NumberFormat.currency(symbol: '\$', decimalDigits: 0);
    final income = double.tryParse(_incomeController.text) ?? 0;

    final defaultName = 'Affordability - ${currencyFormat.format(income)}';
    final nameCtrl = TextEditingController(text: defaultName);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Save Calculation',
          style: TextStyle(
            fontFamily: 'Manrope',
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
              style: TextStyle(
                fontSize: 13,
                color: context.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: nameCtrl,
              autofocus: true,
              style: TextStyle(
                color: context.textPrimary,
                fontWeight: FontWeight.w600,
              ),
              decoration: InputDecoration(
                hintText: 'e.g. My Dream Home',
                hintStyle: TextStyle(
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
              style: TextStyle(
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

              final scaffoldMessenger = ScaffoldMessenger.of(context);
              final primaryColor = context.primaryColor;
              final navigator = Navigator.of(context);
              final dialogNavigator = Navigator.of(ctx);

              final rate = double.tryParse(_interestController.text) ?? 0;
              final metadata = {
                'liveRate': rate,
              };

              await provider.saveCurrentResult(
                name,
                calculatorType: CalculatorType.affordability,
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
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: context.primaryColor,
              ),
            ),
          ),
        ],
      ),
    );
  }


  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    const double bottomPadding = kBottomNavigationBarHeight + 24;

    return Scaffold(
      backgroundColor: context.pageBackground,
      appBar: _buildAppBar(),
      // BottomNavigationBar — sole occupant, SafeArea wraps it correctly.
      bottomNavigationBar: _buildBottomNav(),
      // bottomSheet removed (Banner ad).
      body: Consumer<AffordabilityProvider>(
        builder: (context, provider, _) {
          return CustomScrollView(
            slivers: [
              SliverPadding(
                padding: EdgeInsets.fromLTRB(16, 24, 16, bottomPadding),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _buildHeroHeader(),
                    const SizedBox(height: 24),

                    if (provider.errorMessage != null)
                      _buildErrorBanner(provider.errorMessage!),

                    _buildMarketInsights(provider),
                    const SizedBox(height: 24),

                    if (provider.result != null) ...[
                      _buildResultSection(provider.result!),
                      const SizedBox(height: 24),
                    ],

                    _buildInputForm(provider.isLoading),
                    const SizedBox(height: 24),

                    if (provider.result != null) ...[
                      _buildPaymentBreakdown(provider.result!.breakdown),
                      const SizedBox(height: 24),
                      // Native ad after all results — end-of-content placement.
                      // Non-interactive breakdown rows above act as a buffer.
                      const AdNativeWidget(),
                      const SizedBox(height: 24),
                    ],
                    // No dead-space SizedBox(height:100) — dynamic padding
                    // on SliverPadding handles the nav + banner clearance.
                  ]),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ── AppBar ───────────────────────────────────────────────────────────────────

  AppBar _buildAppBar() {
    return GradientAppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      titleSpacing: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      title: const Text(
        'USA Mortgage Calculator Pro',
        style: TextStyle(
          fontFamily: 'Manrope',
          fontWeight: FontWeight.bold,
          fontSize: 18,
          color: Colors.white,
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(
            Icons.notifications_outlined,
            color: Colors.white70,
          ),
          onPressed: () {},
        ),
      ],
      bottom: const PreferredSize(
        preferredSize: Size.fromHeight(1.0),
        child: SizedBox(
          height: 1.0,
          child: Divider(height: 1.0, color: Colors.white24),
        ),
      ),
    );
  }

  // ── Bottom nav ───────────────────────────────────────────────────────────────

  Widget _buildBottomNav() {
    return SafeArea(
      child: Container(
        decoration: BoxDecoration(
          color: context.cs.surface,
          border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() => _currentIndex = index);
            if (index == 0) {
              Navigator.pop(context);
            } else if (index == 2) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => const InsuranceMarketplaceScreen(),
                ),
              );
            } else if (index == 3) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            }
          },
          type: BottomNavigationBarType.fixed,
          backgroundColor: context.cs.surface,
          selectedItemColor: primary,
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
              icon: Text('💵', style: TextStyle(fontSize: 22)),
              activeIcon: Text('💵', style: TextStyle(fontSize: 26)),
              
              
              
              
              
              
              
              label: 'Loans',
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
      ),
    );
  }

  // ── Content widgets ───────────────────────────────────────────────────────────

  Widget _buildHeroHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Home Affordability Calculator',
          style: TextStyle(
            fontFamily: 'Manrope',
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: context.primaryColor,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Estimate the maximum home price you can afford using live mortgage data.',
          style: TextStyle(fontSize: 14, color: context.textSecondary, height: 1.5),
        ),
      ],
    );
  }

  Widget _buildErrorBanner(String message) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFDAD6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: errorColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: errorColor, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Color(0xFF93000A),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMarketInsights(AffordabilityProvider provider) {
    String trendStr = '+0.0%';
    Color fredTrendColor = tertiary;
    if (provider.historicalRates.length >= 2) {
      final latest = provider.historicalRates.last.value;
      final prev =
          provider.historicalRates[provider.historicalRates.length - 2].value;
      final diff = latest - prev;
      trendStr = diff > 0
          ? '+${diff.toStringAsFixed(2)}%'
          : '${diff.toStringAsFixed(2)}%';
      fredTrendColor = diff > 0 ? errorColor : tertiary;
    }

    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.cardColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'LIVE FRED RATE',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: context.textSecondary,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      provider.isLoading
                          ? '--'
                          : '${provider.currentRate.toStringAsFixed(2)}%',
                      style: const TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 4),
                    if (!provider.isLoading)
                      Text(
                        trendStr,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: fredTrendColor,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.cardColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PRICE TREND',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: context.textSecondary,
                    letterSpacing: 1.0,
                  ),
                ),
                SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      '+2.4%',
                      style: TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(width: 4),
                    Icon(Icons.trending_up, size: 14, color: tertiary),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildResultSection(AffordabilityResult result) {
    final currencyFormat = NumberFormat.currency(
      symbol: '\$',
      decimalDigits: 0,
    );

    return Container(
      key: _resultKey,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [primaryContainer, primary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: primary.withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -16,
            top: -16,
            child: Container(
              width: 128,
              height: 128,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'YOUR ESTIMATED HOME BUDGET',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.1,
                  color: Colors.white.withValues(alpha: 0.8),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                currencyFormat.format(result.maxHomePrice),
                style: const TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 24),
              Container(height: 1, color: Colors.white.withValues(alpha: 0.1)),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Monthly Payment',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          currencyFormat.format(result.totalMonthlyPayment),
                          style: const TextStyle(
                            fontFamily: 'Manrope',
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'DTI Ratio',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${result.debtToIncomeRatio.toStringAsFixed(0)}%',
                          style: const TextStyle(
                            fontFamily: 'Manrope',
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Recommended Range',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      '${currencyFormat.format(result.maxHomePrice * 0.9)} — ${currencyFormat.format(result.maxHomePrice * 1.05)}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInputForm(bool isLoading) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Financial Details',
              style: TextStyle(
                fontFamily: 'Manrope',
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 24),
            _buildInputField(
              label: 'ANNUAL INCOME',
              controller: _incomeController,
              prefixText: '\$',
            ),
            const SizedBox(height: 16),
            _buildInputField(
              label: 'MONTHLY DEBTS',
              controller: _debtsController,
              prefixText: '\$',
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildInputField(
                    label: 'DOWN PAYMENT',
                    controller: _downPaymentController,
                    prefixText: '\$',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'LOAN TERM',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: outline,
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<int>(
                        initialValue: _loanTerm,
                        icon: Icon(Icons.arrow_drop_down, color: context.textSecondary),
                        items: const [
                          DropdownMenuItem(value: 30, child: Text('30 Years')),
                          DropdownMenuItem(value: 20, child: Text('20 Years')),
                          DropdownMenuItem(value: 15, child: Text('15 Years')),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => _loanTerm = val);
                        },
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: context.textPrimary,
                        ),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: context.inputFill,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'LIVE MORTGAGE RATE (FRED)',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: outline,
                        letterSpacing: 1.0,
                      ),
                    ),
                    Text(
                      'Auto-filled',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: tertiary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _interestController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  // Allow digits and a single decimal point for interest rate.
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                  ],
                  validator: (val) {
                    if (val == null || val.isEmpty) return 'Required';
                    if (double.tryParse(val) == null) return 'Invalid rate';
                    return null;
                  },
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: context.textPrimary,
                  ),
                  decoration: InputDecoration(
                    suffixText: '%',
                    filled: true,
                    fillColor: context.inputFill,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: ElevatedButton(
                    onPressed: isLoading ? null : _calculate,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      elevation: 5,
                      shadowColor: primary.withValues(alpha: 0.3),
                    ),
                    child: Ink(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [primaryContainer, primary],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Container(
                        alignment: Alignment.center,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        child: isLoading
                            ? SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  color: context.cs.surface,
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                'Calculate Affordability',
                                style: TextStyle(
                                  fontFamily: 'Manrope',
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: context.cs.surface,
                                ),
                              ),
                      ),
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
                      style: TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: context.primaryColor,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: context.primaryColor, width: 1.5),
                      minimumSize: const Size(0, 54),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputField({
    required String label,
    required TextEditingController controller,
    required String prefixText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: outline,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          // Digits only for dollar fields — no decimals needed for income/debt/down payment.
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          validator: (val) {
            if (val == null || val.isEmpty) return 'Required';
            if (double.tryParse(val) == null) return 'Invalid number';
            return null;
          },
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: context.textPrimary),
          decoration: InputDecoration(
            prefixIcon: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                prefixText,
                style: TextStyle(color: context.textSecondary, fontSize: 16),
              ),
            ),
            prefixIconConstraints: const BoxConstraints(
              minWidth: 0,
              minHeight: 0,
            ),
            filled: true,
            fillColor: context.inputFill,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentBreakdown(PaymentBreakdown breakdown) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            'Payment Breakdown',
            style: TextStyle(
              fontFamily: 'Manrope',
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: context.cardColor,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              _buildBreakdownRow(
                color: primary,
                label: 'Principal & Interest',
                value: breakdown.principalAndInterest,
              ), Divider(height: 1, color: context.textPrimary12),
              _buildBreakdownRow(
                color: secondary,
                label: 'Property Taxes',
                value: breakdown.propertyTaxes,
              ), Divider(height: 1, color: context.textPrimary12),
              _buildBreakdownRow(
                color: tertiaryContainer,
                label: 'Home Insurance',
                value: breakdown.homeInsurance,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBreakdownRow({
    required Color color,
    required String label,
    required double value,
  }) {
    final currencyFormat = NumberFormat.currency(
      symbol: '\$',
      decimalDigits: 0,
    );
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 32,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          Text(
            currencyFormat.format(value),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}