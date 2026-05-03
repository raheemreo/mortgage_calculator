import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../providers/settings_provider.dart';
import 'insurance_marketplace.dart';
import 'settings_screen.dart';
import '../core/constants/theme_extensions.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AD PLACEMENT STRATEGY — what changed and why
// ─────────────────────────────────────────────────────────────────────────────
//
// REMOVED → InterstitialAd on "Recalculate Ratio" button (_handleRecalculate)
//   • Same violation as all previous calculator screens. Recalculating on
//     the same screen is not a natural transition point. Users who adjust
//     income or debt would be hit with a full-screen ad on every tap.
//   • "Recalculate" button now calls _calculateRatio() directly.
//   • ad_service.dart import removed.
//
// REMOVED → AdBannerWidget stacked above BottomNavigationBar in a Column
//   • Same policy violation fixed across every other screen in this project.
//     A banner in a Column above a nav bar is not a valid anchored placement.
//   • ad_banner_widget.dart import removed.
//
// ADDED → Anchored Adaptive BannerAd in a dedicated bottom slot
//   • This screen has a BottomNavigationBar, so we cannot use
//     bottomNavigationBar for the banner (that would stack them).
//   • Instead: the banner is placed in bottomSheet — anchored to the
//     absolute screen edge below the nav bar, with no adjacent widgets.
//   • BottomNavigationBar remains the sole occupant of bottomNavigationBar,
//     wrapped in SafeArea.
//   • Scroll view bottom padding compensates for combined nav + banner height.
//
//
// FIXED → Missing TextEditingController dispose()
//   • Both controllers now properly disposed.
//
// FIXED → GestureDetector added to dismiss keyboard on tap outside.
// ─────────────────────────────────────────────────────────────────────────────

class DtiRatioCalculatorScreen extends StatefulWidget {
  const DtiRatioCalculatorScreen({super.key});

  @override
  State<DtiRatioCalculatorScreen> createState() =>
      _DtiRatioCalculatorScreenState();
}

class _DtiRatioCalculatorScreenState extends State<DtiRatioCalculatorScreen> {
  final TextEditingController _incomeController = TextEditingController(
    text: '6500',
  );
  final TextEditingController _debtController = TextEditingController(
    text: '2145',
  );

  double _dtiRatio = 33.0;
  String _statusLabel = 'GOOD';
  Color _statusColor = const Color(0xFF22C55E);

  // ── Lifecycle ────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _calculateRatio();
  }

  @override
  void dispose() {
    _incomeController.dispose();
    _debtController.dispose();
    super.dispose();
  }

  // ── Calculation ──────────────────────────────────────────────────────────────

  void _calculateRatio() {
    // TextInputFormatter ensures only digits — no replaceAll(',','') needed.
    final income = double.tryParse(_incomeController.text) ?? 0;
    final debts = double.tryParse(_debtController.text) ?? 0;

    if (income > 0) {
      setState(() {
        _dtiRatio = (debts / income) * 100;
        if (_dtiRatio < 36) {
          _statusLabel = 'GOOD';
          _statusColor = const Color(0xFF22C55E);
        } else if (_dtiRatio <= 43) {
          _statusLabel = 'FAIR';
          _statusColor = const Color(0xFFF59E0B);
        } else {
          _statusLabel = 'HIGH';
          _statusColor = const Color(0xFFEF4444);
        }
      });
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);

    const double bottomPadding = kBottomNavigationBarHeight + 24;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F8),
      appBar: AppBar(
        backgroundColor: context.cs.surface,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, color: Color(0xFF334155)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'DTI Ratio Calculator',
          style: GoogleFonts.manrope(
            textStyle: const TextStyle(
              color: Color(0xFF0F172A),
              fontWeight: FontWeight.bold,
              fontSize: 17,
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_horiz, color: Color(0xFF94A3B8)),
            onPressed: () {},
          ),
        ],
      ),
      // BottomNavigationBar — sole occupant, no banner stacked here.
      bottomNavigationBar: SafeArea(
        child: Container(
          decoration: BoxDecoration(
            color: context.cs.surface,
            border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
            boxShadow: [
              BoxShadow(
                color: Color(0x0A000000),
                blurRadius: 10,
                offset: Offset(0, -4),
              ),
            ],
          ),
          child: BottomNavigationBar(
            currentIndex: 0,
            onTap: (index) {
              if (index == 0) {
                Navigator.pop(context);
              } else if (index == 1) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const InsuranceMarketplaceScreen(),
                  ),
                );
              } else if (index == 2) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                );
              }
            },
            type: BottomNavigationBarType.fixed,
            backgroundColor: context.cs.surface,
            selectedItemColor: const Color(0xFF0B3893),
            unselectedItemColor: const Color(0xFF94A3B8),
            selectedFontSize: 11,
            unselectedFontSize: 11,
            elevation: 0,
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.home_rounded, size: 26),
                label: 'Home',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.shield_rounded, size: 26),
                label: 'Insurance',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.settings_rounded, size: 26),
                label: 'Settings',
              ),
            ],
          ),
        ),
      ),
      // bottomSheet removed (Banner ad).
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, 24, 20, bottomPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header ────────────────────────────────────────────────
                Text(
                  'Your DTI Ratio',
                  style: GoogleFonts.manrope(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Review your Debt-to-Income ratio to determine your loan eligibility.',
                  style: TextStyle(
                    fontSize: 15,
                    color: context.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24),

                // ── Result card ───────────────────────────────────────────
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: context.cs.surface,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0B3893).withValues(alpha: 0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                    border: Border.all(color: const Color(0xFFF1F5F9)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'CURRENT RATIO',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF94A3B8),
                                  letterSpacing: 1.2,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: _statusColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  _statusLabel,
                                  style: TextStyle(
                                    color: _statusColor,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: _dtiRatio.toStringAsFixed(0),
                                  style: const TextStyle(
                                    fontSize: 40,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF0F172A),
                                    letterSpacing: -1,
                                  ),
                                ),
                                const TextSpan(
                                  text: '%',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF94A3B8),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      _buildGauge(),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _buildGaugeLabel('Good', '<36%', 0.36),
                          _buildGaugeLabel('Fair', '36-43%', 0.07),
                          _buildGaugeLabel('High', '>43%', 0.57),
                        ],
                      ),
                      const SizedBox(height: 24),
                      const Divider(color: Color(0xFFF1F5F9), height: 1),
                      const SizedBox(height: 16),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.check_circle,
                            color: _statusColor,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Your DTI is in a healthy range. You are likely to qualify for most standard loan options.',
                              style: TextStyle(
                                fontSize: 13,
                                color: Color(0xFF475569),
                                fontWeight: FontWeight.w500,
                                height: 1.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // ── Input fields ─────────────────────────────────────────
                _buildInputField(
                  label: 'Gross Monthly Income',
                  controller: _incomeController,
                  subtitle: 'Total income before taxes and deductions.',
                  symbol: settings.currencySymbol,
                ),
                const SizedBox(height: 20),
                _buildInputField(
                  label: 'Total Monthly Debts',
                  controller: _debtController,
                  subtitle:
                      'Rent/Mortgage, student loans, auto loans, credit cards.',
                  showDetails: true,
                  symbol: settings.currencySymbol,
                ),

                const SizedBox(height: 32),

                // ── Recalculate button — direct call, no interstitial ─────
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      _calculateRatio();
                      FocusScope.of(context).unfocus();
                    },
                    icon: const Icon(Icons.refresh, size: 20),
                    label: const Text('Recalculate Ratio'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0B3893),
                      foregroundColor: context.cs.surface,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      elevation: 4,
                      shadowColor: const Color(
                        0xFF0B3893,
                      ).withValues(alpha: 0.25),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Helper widgets ────────────────────────────────────────────────────────────

  Widget _buildGauge() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              height: 12,
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            Row(
              children: [
                Expanded(
                  flex: 36,
                  child: Container(
                    height: 12,
                    decoration: BoxDecoration(
                      border: Border(
                        right: BorderSide(color: context.cs.surface, width: 2),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  flex: 7,
                  child: Container(
                    height: 12,
                    decoration: BoxDecoration(
                      border: Border(
                        right: BorderSide(color: context.cs.surface, width: 2),
                      ),
                    ),
                  ),
                ),
                const Expanded(flex: 57, child: SizedBox(height: 12)),
              ],
            ),
            FractionallySizedBox(
              widthFactor: (_dtiRatio / 100).clamp(0.0, 1.0),
              child: Container(
                height: 12,
                decoration: BoxDecoration(
                  color: _statusColor,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
            Positioned(
              left:
                  (_dtiRatio / 100).clamp(0.0, 1.0) * constraints.maxWidth - 8,
              top: -2,
              child: Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: context.cs.surface,
                  shape: BoxShape.circle,
                  border: Border.all(color: _statusColor, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: context.textPrimary.withValues(alpha: 0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildGaugeLabel(String title, String value, double flex) {
    return Expanded(
      flex: (flex * 100).toInt(),
      child: Column(
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Color(0xFF94A3B8),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: Color(0xFFCBD5E1),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputField({
    required String label,
    required TextEditingController controller,
    required String subtitle,
    required String symbol,
    bool showDetails = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
            if (showDetails)
              TextButton.icon(
                onPressed: () {},
                icon: const Text(
                  'Details',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0B3893),
                  ),
                ),
                label: const Icon(
                  Icons.chevron_right,
                  size: 16,
                  color: Color(0xFF0B3893),
                ),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              )
            else
              const Icon(Icons.info, size: 18, color: Color(0xFF0B3893)),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: context.textPrimary.withValues(alpha: 0.02),
                blurRadius: 2,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
            decoration: InputDecoration(
              prefixIcon: Padding(
                padding: const EdgeInsets.only(left: 16, right: 8),
                child: Text(
                  symbol,
                  style: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              prefixIconConstraints: const BoxConstraints(
                minWidth: 0,
                minHeight: 0,
              ),
              filled: true,
              fillColor: context.cs.surface,
              contentPadding: const EdgeInsets.symmetric(
                vertical: 14,
                horizontal: 16,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: context.borderColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: context.borderColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: Color(0xFF0B3893),
                  width: 2,
                ),
              ),
            ),
            inputFormatters: [
              // Digits only — eliminates all manual string cleanup downstream.
              FilteringTextInputFormatter.digitsOnly,
            ],
            onChanged: (_) => _calculateRatio(),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 12,
            color: context.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
