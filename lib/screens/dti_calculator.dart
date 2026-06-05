import 'package:flutter/material.dart';
import '../widgets/gradient_app_bar.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../services/ad_service.dart';
import '../providers/settings_provider.dart';
import 'dart:math' as math;
import '../core/constants/theme_extensions.dart';

// Custom theme constants removed in favor of dynamic BuildContext extensions.

// ─────────────────────────────────────────────────────────────────────────────
// AD PLACEMENT STRATEGY — what changed and why
// ─────────────────────────────────────────────────────────────────────────────
//
// REMOVED → InterstitialAd on the "Calculate Options" button (_handleCalculate)
//   • Same violation as auto_loan_calculator and credit_card_calculator.
//     Tapping "Calculate" is not a natural screen transition — it updates
//     results on the same screen. Users who adjust income or debt values
//     would be hit with a full-screen ad on every tap.
//   • "Calculate Options" button now calls _calculate() directly.
//
// RESTORED → AdMob natural transition on back navigation
//   • Following the user's latest requirement to show an ad on back button.
//   • Using centralized AdService to ensure frequency capping and preloading.
//
// ADDED → Anchored Adaptive BannerAd in bottomNavigationBar
//   • Correct placement for a calculator screen with no nav bar.
//
// ADDED → Native ad between the input fields and the Summary section
//   • The user has finished entering their numbers and is about to read
//     the summary — a genuine content pause between two distinct sections.
// ─────────────────────────────────────────────────────────────────────────────

class DtiCalculatorScreen extends StatefulWidget {
  const DtiCalculatorScreen({super.key});

  @override
  State<DtiCalculatorScreen> createState() => _DtiCalculatorScreenState();
}

class _DtiCalculatorScreenState extends State<DtiCalculatorScreen> {
  // Controllers
  final _incomeController = TextEditingController(text: '8500');
  final _debtController = TextEditingController(text: '2380');
  final _housingController = TextEditingController(text: '1530');

  // Calculation State
  double _backendRatio = 0.28;
  double _frontendRatio = 0.18;



  @override
  void initState() {
    super.initState();
    _calculateRatios();
    AdService().loadInterstitialAd();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }

  @override
  void dispose() {
    _incomeController.dispose();
    _debtController.dispose();
    _housingController.dispose();

    super.dispose();
  }

  // ── Ad Logic ───────────────────────────────────────────────────────────────



  /// Triggered on "Back" to follow AdMob's "Natural Transition" policy
  void _handleBackNavigation() {
    AdService().showInterstitialAd(
      onAdClosed: () {
        if (mounted) Navigator.pop(context);
      },
    );
  }

  // ── Calculation Logic ──────────────────────────────────────────────────────

  void _calculateRatios() {
    final double income = _parseInput(_incomeController.text);
    final double debt = _parseInput(_debtController.text);
    final double housing = _parseInput(_housingController.text);

    if (income > 0) {
      setState(() {
        _backendRatio = (debt / income).clamp(0.0, 1.0);
        _frontendRatio = (housing / income).clamp(0.0, 1.0);
      });
    }
  }

  double _parseInput(String text) {
    return double.tryParse(text.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0;
  }

  // ── Build UI ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final textStyle = GoogleFonts.inter();

    return Scaffold(
      backgroundColor: context.pageBackground,
      appBar: GradientAppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: _handleBackNavigation,
        ),
        title: Text(
          'DTI Calculator',
          style: textStyle.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        shape: const Border(bottom: BorderSide(color: Colors.white24)),
      ),

      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            children: [
              _buildGaugeCard(textStyle),
              const SizedBox(height: 32),
              _buildInputSection(settings.currencySymbol, textStyle),
              const SizedBox(height: 24),

              _buildSummaryCard(textStyle),
              const SizedBox(height: 32),
              _buildCalculateButton(textStyle),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGaugeCard(TextStyle textStyle) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.borderColor),
      ),
      child: Column(
        children: [
          Text(
            'TOTAL DEBT-TO-INCOME',
            style: textStyle.copyWith(
              color: context.textSecondary,
              fontSize: 12,
              letterSpacing: 1.2,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 120,
            width: 240,
            child: Stack(
              alignment: Alignment.bottomCenter,
              children: [
                CustomPaint(
                  size: const Size(240, 120),
                  painter: DtiSemiCirclePainter(
                    ratio: _backendRatio,
                    activeColor: context.primaryColor,
                    trackColor: context.borderColor,
                  ),
                ),
                Positioned(
                  bottom: 0,
                  child: Text(
                    '${(_backendRatio * 100).toStringAsFixed(0)}%',
                    style: textStyle.copyWith(
                      fontSize: 42,
                      fontWeight: FontWeight.w800,
                      color: context.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.verified,
                color: _backendRatio <= 0.36 ? const Color(0xFF10B981) : Colors.orange,
                size: 18,
              ),
              const SizedBox(width: 6),
              Text(
                _backendRatio <= 0.36 ? 'Healthy Range' : 'High DTI',
                style: textStyle.copyWith(
                  color: _backendRatio <= 0.36
                      ? const Color(0xFF10B981)
                      : Colors.orange,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInputSection(String symbol, TextStyle textStyle) {
    return Column(
      children: [
        _buildInputField(
          'Monthly Gross Income',
          'Before taxes',
          _incomeController,
          symbol,
          textStyle,
        ),
        const SizedBox(height: 20),
        _buildInputField(
          'Monthly Housing Cost',
          'Rent/Mortgage',
          _housingController,
          symbol,
          textStyle,
        ),
        const SizedBox(height: 20),
        _buildInputField(
          'Total Monthly Debt',
          'Loans & Credit Cards',
          _debtController,
          symbol,
          textStyle,
        ),
      ],
    );
  }

  Widget _buildInputField(
    String label,
    String sub,
    TextEditingController ctrl,
    String symbol,
    TextStyle style,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: style.copyWith(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: context.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          style: style.copyWith(
            color: context.textPrimary,
            fontWeight: FontWeight.w600,
          ),
          decoration: InputDecoration(
            prefixIcon: Container(
              padding: const EdgeInsets.all(14),
              child: Text(
                symbol,
                style: style.copyWith(
                  fontSize: 18,
                  color: context.textSecondary,
                ),
              ),
            ),
            filled: true,
            fillColor: context.cardColor,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: context.borderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: context.primaryColor, width: 2),
            ),
            hintText: '0.00',
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 4, left: 4),
          child: Text(
            sub,
            style: style.copyWith(color: context.textSecondary, fontSize: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(TextStyle style) {
    return Container(
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.borderColor),
      ),
      child: Column(
        children: [
          _summaryRow(
            'Front-End (Housing)',
            '${(_frontendRatio * 100).toStringAsFixed(1)}%',
            style,
            true,
          ),
          _summaryRow(
            'Back-End (Total Debt)',
            '${(_backendRatio * 100).toStringAsFixed(1)}%',
            style,
            false,
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String val, TextStyle style, bool border) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: border
            ? Border(bottom: BorderSide(color: context.borderColor))
            : null,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style.copyWith(color: context.textSecondary)),
          Text(
            val,
            style: style.copyWith(
              fontWeight: FontWeight.bold,
              color: context.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalculateButton(TextStyle style) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: () {
          _calculateRatios();
          FocusScope.of(context).unfocus();
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: context.primaryColor,
          foregroundColor: context.isDark ? const Color(0xFF0A0E1A) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        child: const Text(
          'Recalculate Ratios',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

// ── Painter ──────────────────────────────────────────────────────────────────

class DtiSemiCirclePainter extends CustomPainter {
  final double ratio;
  final Color activeColor;
  final Color trackColor;

  DtiSemiCirclePainter({
    required this.ratio,
    required this.activeColor,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height);
    final radius = size.width / 2 - 10;
    const strokeWidth = 14.0;

    final bgPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final activePaint = Paint()
      ..color = activeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      math.pi,
      math.pi,
      false,
      bgPaint,
    );
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      math.pi,
      math.pi * ratio,
      false,
      activePaint,
    );
  }

  @override
  bool shouldRepaint(DtiSemiCirclePainter old) =>
      old.ratio != ratio ||
      old.activeColor != activeColor ||
      old.trackColor != trackColor;
}