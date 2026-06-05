import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../widgets/gradient_app_bar.dart';

import 'package:provider/provider.dart';
import '../models/affordability_model.dart';
import '../providers/affordability_provider.dart';
import '../widgets/ad_fallback_widget.dart';
import '../core/constants/theme_extensions.dart';
import 'amortization_schedule_screen.dart';
import 'edit_calculation_screen.dart';
import 'saved_calculations_screen.dart';
import 'settings_screen.dart';

class CalculationDetailsScreen extends StatelessWidget {
  final SavedAffordabilityCalculation calculation;
  const CalculationDetailsScreen({super.key, required this.calculation});

  // ── Design tokens ───────────────────────────────────────────────────────────
  static const Color primary = Color(0xFF0037B1);
  static const Color primaryContainer = Color(0xFF1E4ED8);
  static const Color onSurface = Color(0xFF191C1E);
  static const Color onSurfaceVariant = Color(0xFF434655);
  static const Color outline = Color(0xFF747686);
  static const Color outlineVariant = Color(0xFFC4C5D7);
  static const Color errorColor = Color(0xFFBA1A1A);
  static const Color tertiary = Color(0xFF004E47);
  static const Color tertiaryContainer = Color(0xFF00685F);
  static const Color secondary = Color(0xFF515F74);
  static const Color surfaceContainerLowest = Colors.white;
  static const Color surfaceContainerLow = Color(0xFFF2F4F6);
  static const Color surfaceContainerHigh = Color(0xFFE6E8EA);
  static const Color surfaceContainerHighest = Color(0xFFE0E3E5);
  static const Color surface = Color(0xFFF7F9FB);


  // ── Metadata helpers ────────────────────────────────────────────────────────
  double _meta(SavedAffordabilityCalculation calc, String key, [double fallback = 0]) =>
      ((calc.metadata[key] as num?)?.toDouble()) ?? fallback;
  bool _metaBool(SavedAffordabilityCalculation calc, String key, [bool fallback = false]) =>
      (calc.metadata[key] as bool?) ?? fallback;
  int _metaInt(SavedAffordabilityCalculation calc, String key, [int fallback = 0]) =>
      (calc.metadata[key] as int?) ?? fallback;

  @override
  Widget build(BuildContext context) {
    return Consumer<AffordabilityProvider>(
      builder: (context, provider, child) {
        // Find the LATEST version of this calculation by ID
        final calc = provider.savedCalculations.firstWhere(
          (c) => c.id == calculation.id,
          orElse: () => calculation,
        );

        return Scaffold(
          extendBody: true,
          backgroundColor: context.pageBackground,
          appBar: _buildAppBar(context, provider, calc),
          bottomNavigationBar: _buildBottomNav(context),
          body: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  16,
                  16,
                  16,
                  kBottomNavigationBarHeight + 80,
                ),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton.icon(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                EditCalculationScreen(calculation: calc),
                          ),
                        ),
                        icon: const Icon(Icons.edit_rounded, size: 18),
                        label: const Text(
                          'Edit Calculation',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: primaryContainer,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildHeroCard(context, calc),
                    const SizedBox(height: 24),
                    // ── Type-specific input details ─────────────────────────────
                    _buildInputDetailsSection(context, calc),
                    const SizedBox(height: 24),
                    // ── Ad placement between input details and breakdown ─────────
                    _buildAdSpace(),
                    // ── Payment Breakdown (always) ──────────────────────────────
                    _buildBreakdownSection(context, calc),
                    const SizedBox(height: 24),
                    // ── Amortization CTA (not shown for auto loan) ──────────────
                    if (calc.calculatorType != CalculatorType.autoLoan) ...[
                      _buildAmortizationButton(context, calc),
                      const SizedBox(height: 32),
                    ],
                  ]),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context, AffordabilityProvider provider, SavedAffordabilityCalculation calc) {
    final titles = {
      CalculatorType.piti: 'PITI Details',
      CalculatorType.mortgage: 'Mortgage Details',
      CalculatorType.autoLoan: 'Auto Loan Details',
      CalculatorType.affordability: 'Affordability Details',
    };
    return GradientAppBar(
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      title: Text(
        titles[calc.calculatorType] ?? 'Calculation Details',
        style: const TextStyle(
          fontFamily: 'Manrope',
          fontWeight: FontWeight.w600,
          fontSize: 20,
          color: Colors.white,
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
          onPressed: () => _confirmDelete(context, provider, calc),
        ),
      ],
    );
  }

  void _confirmDelete(BuildContext context, AffordabilityProvider provider, SavedAffordabilityCalculation calc) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Delete Calculation?',
          style: TextStyle(fontFamily: 'Manrope', fontWeight: FontWeight.bold),
        ),
        content: Text('Delete "${calc.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              provider.deleteCalculation(calc.id);
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(foregroundColor: context.isDark ? Colors.red.shade300 : errorColor),
            child: const Text(
              'Delete',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  // ── Hero card ───────────────────────────────────────────────────────────────
  Widget _buildHeroCard(BuildContext context, SavedAffordabilityCalculation calc) {
    final fmt = context.currencyFormat(decimalDigits: 0);
    String budgetLabel;
    String budgetValue;
    switch (calc.calculatorType) {
      case CalculatorType.piti:
      case CalculatorType.mortgage:
        budgetLabel = 'Home Price';
        budgetValue = fmt.format(
          _meta(calc, 'homePrice', calc.input.annualIncome),
        );
        break;
      case CalculatorType.autoLoan:
        budgetLabel = 'Vehicle Price';
        budgetValue = fmt.format(
          _meta(calc, 'vehiclePrice', calc.input.annualIncome),
        );
        break;
      case CalculatorType.affordability:
        budgetLabel = 'Est. Budget';
        budgetValue = fmt.format(calc.result.maxHomePrice);
        break;
    }

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [primaryContainer, primary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: primary.withValues(alpha: 0.25),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -24,
            top: -24,
            child: Container(
              width: 192,
              height: 192,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(28),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'SAVED CALCULATION',
                        style: TextStyle(
                          fontSize: 12,
                          letterSpacing: 0.8,
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        calc.name,
                        style: const TextStyle(
                          fontFamily: 'Manrope',
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$budgetLabel: $budgetValue',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'MONTHLY PAYMENT',
                        style: TextStyle(
                          fontSize: 10,
                          letterSpacing: 0.8,
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                      ),
                      const SizedBox(height: 4),
                      RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: fmt.format(
                                calc.result.totalMonthlyPayment,
                              ),
                              style: const TextStyle(
                                fontFamily: 'Manrope',
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            TextSpan(
                              text: '/mo',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white.withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Type-specific input details ─────────────────────────────────────────────
  Widget _buildInputDetailsSection(BuildContext context, SavedAffordabilityCalculation calc) {
    switch (calc.calculatorType) {
      case CalculatorType.piti:
        return _buildPitiDetails(context, calc);
      case CalculatorType.mortgage:
        return _buildMortgageDetails(context, calc);
      case CalculatorType.autoLoan:
        return _buildAutoLoanDetails(context, calc);
      case CalculatorType.affordability:
        return _buildAffordabilityDetails(context, calc);
    }
  }

  // ── PITI details ────────────────────────────────────────────────────────────
  Widget _buildPitiDetails(BuildContext context, SavedAffordabilityCalculation calc) {
    final fmt = context.currencyFormat(decimalDigits: 0);
    final hp = _meta(calc, 'homePrice', calc.input.annualIncome);
    final dp = calc.input.downPayment;
    final dpPct = _meta(calc, 'downPaymentPct', hp > 0 ? (dp / hp * 100) : 0);
    final extraMonthly = _meta(calc, 'extraMonthly');
    final extraBiweekly = _meta(calc, 'extraBiweekly');
    final lumpSum = _meta(calc, 'lumpSum');
    final hasExtras = extraMonthly > 0 || extraBiweekly > 0 || lumpSum > 0;

    return Column(
      children: [
        _buildDetailCard('Loan Details', Icons.real_estate_agent_rounded, [
          _buildDetailRow('Home Price', fmt.format(hp)),
          _buildDetailRow('Down Payment', fmt.format(dp)),
          _buildDetailRow('Down Payment %', '${dpPct.toStringAsFixed(1)}%'),
          _buildDetailRow(
            'Interest Rate',
            '${calc.input.interestRate.toStringAsFixed(2)}%',
          ),
          _buildDetailRow('Loan Term', '${calc.input.loanTerm} Years'),
        ]),
        const SizedBox(height: 16),
        _buildDetailCard(
          'Homeowner Expenses',
          Icons.account_balance_wallet_rounded,
          [
            _buildDetailRow(
              'Property Tax (Annual)',
              fmt.format(_meta(calc, 'propertyTax')),
            ),
            _buildDetailRow(
              'Home Insurance (Annual)',
              fmt.format(_meta(calc, 'homeInsurance')),
            ),
            _buildDetailRow(
              'HOA Fees (Annual)',
              fmt.format(_meta(calc, 'hoaFees')),
            ),
            _buildDetailRow('PMI (Annual)', fmt.format(_meta(calc, 'pmi'))),
          ],
        ),
        if (hasExtras) ...[
          const SizedBox(height: 16),
          _buildDetailCard('Extra Payments', Icons.speed_rounded, [
            if (extraMonthly > 0)
              _buildDetailRow('Monthly Extra', fmt.format(extraMonthly)),
            if (extraBiweekly > 0)
              _buildDetailRow(
                'Bi-weekly Extra',
                fmt.format(extraBiweekly),
              ),
            if (lumpSum > 0)
              _buildDetailRow('One-time Lump Sum', fmt.format(lumpSum)),
          ]),
        ],
      ],
    );
  }

  // ── Mortgage details ────────────────────────────────────────────────────────
  Widget _buildMortgageDetails(BuildContext context, SavedAffordabilityCalculation calc) {
    final fmt = context.currencyFormat(decimalDigits: 0);
    final hp = _meta(calc, 'homePrice', calc.input.annualIncome);
    final includePmi = _metaBool(calc, 'includePmi');
    final includeEscrow = _metaBool(calc, 'includeEscrow');
    final pmiMonthly = _meta(calc, 'pmiMonthly');
    final taxInsMonthly = _meta(calc, 'taxInsMonthly');

    return Column(
      children: [
        _buildDetailCard('Loan Details', Icons.real_estate_agent_rounded, [
          _buildDetailRow('Home Price', fmt.format(hp)),
          _buildDetailRow(
            'Down Payment',
            fmt.format(calc.input.downPayment),
          ),
          _buildDetailRow('Loan Term', '${calc.input.loanTerm} Years'),
          _buildDetailRow(
            'Interest Rate',
            '${calc.input.interestRate.toStringAsFixed(2)}%',
          ),
        ]),
        if (includePmi) ...[
          const SizedBox(height: 16),
          _buildDetailCard('PMI', Icons.security_rounded, [
            _buildDetailRow(
              'Monthly PMI',
              '${fmt.format(pmiMonthly)}/mo',
            ),
            _buildDetailRow(
              'Note',
              'Applied (down payment < 20%)',
              isNote: true,
            ),
          ]),
        ],
        if (includeEscrow) ...[
          const SizedBox(height: 16),
          _buildDetailCard('Escrow', Icons.savings_rounded, [
            _buildDetailRow(
              'Tax & Insurance',
              '${fmt.format(taxInsMonthly)}/mo',
            ),
            _buildDetailRow(
              'Estimated at',
              '1.5% of home price/yr',
              isNote: true,
            ),
          ]),
        ],
      ],
    );
  }

  // ── Auto loan details ───────────────────────────────────────────────────────
  Widget _buildAutoLoanDetails(BuildContext context, SavedAffordabilityCalculation calc) {
    final fmt = context.currencyFormat(decimalDigits: 0);
    final vp = _meta(calc, 'vehiclePrice', calc.input.annualIncome);
    final termMonths = _metaInt(calc, 'termMonths', calc.input.loanTerm * 12);
    final totalInterest = _meta(calc, 'totalInterest');
    final totalCost = _meta(calc, 'totalCost');

    return _buildDetailCard('Loan Details', Icons.directions_car_rounded, [
      _buildDetailRow('Vehicle Price', fmt.format(vp)),
      _buildDetailRow(
        'Down Payment / Trade-in',
        fmt.format(calc.input.downPayment),
      ),
      _buildDetailRow(
        'APR',
        '${calc.input.interestRate.toStringAsFixed(2)}%',
      ),
      _buildDetailRow('Loan Term', '$termMonths months'),
      _buildDetailRow(
        'Total Interest',
        fmt.format(totalInterest),
        valueColor: const Color(0xFFDC2626),
      ),
      _buildDetailRow('Total Cost', fmt.format(totalCost)),
    ]);
  }

  // ── Affordability details ───────────────────────────────────────────────────
  Widget _buildAffordabilityDetails(BuildContext context, SavedAffordabilityCalculation calc) {
    final fmt = context.currencyFormat(decimalDigits: 0);
    final liveRate = _meta(calc, 'liveRate', calc.input.interestRate);

    return _buildDetailCard(
      'Financial Details',
      Icons.account_balance_rounded,
      [
        _buildDetailRow(
          'Annual Income',
          fmt.format(calc.input.annualIncome),
        ),
        _buildDetailRow(
          'Monthly Debts',
          fmt.format(calc.input.monthlyDebts),
        ),
        _buildDetailRow(
          'Down Payment',
          fmt.format(calc.input.downPayment),
        ),
        _buildDetailRow('Loan Term', '${calc.input.loanTerm} Years'),
        _buildDetailRow(
          'Live Mortgage Rate (FRED)',
          '${liveRate.toStringAsFixed(2)}%',
          valueColor: tertiary,
        ),
      ],
    );
  }

  // ── Payment Breakdown (shown for all) ───────────────────────────────────────
  Widget _buildBreakdownSection(BuildContext context, SavedAffordabilityCalculation calc) {
    final breakdown = calc.result.breakdown;
    final type = calc.calculatorType;

    final rows = <Widget>[];
    if (type == CalculatorType.autoLoan) {
      rows.addAll([
        _buildBreakdownRow(
          context,
          primaryContainer,
          'Monthly Payment',
          breakdown.principalAndInterest,
        ),
        const SizedBox(height: 8),
        _buildBreakdownRow(
          context,
          const Color(0xFFDC2626),
          'Total Interest',
          _meta(calc, 'totalInterest'),
        ),
        const SizedBox(height: 8),
        _buildBreakdownRow(context, tertiaryContainer, 'Total Cost', _meta(calc, 'totalCost')),
      ]);
    } else {
      rows.add(
        _buildBreakdownRow(
          context,
          primaryContainer,
          'Principal & Interest',
          breakdown.principalAndInterest,
        ),
      );
      if (breakdown.propertyTaxes > 0) {
        rows.addAll([
          const SizedBox(height: 8),
          _buildBreakdownRow(
            context,
            tertiaryContainer,
            'Property Taxes',
            breakdown.propertyTaxes,
          ),
        ]);
      }
      if (breakdown.homeInsurance > 0) {
        rows.addAll([
          const SizedBox(height: 8),
          _buildBreakdownRow(
            context,
            outlineVariant,
            'Home Insurance',
            breakdown.homeInsurance,
          ),
        ]);
      }
      if (breakdown.pmi > 0) {
        rows.addAll([
          const SizedBox(height: 8),
          _buildBreakdownRow(context, secondary, 'PMI', breakdown.pmi),
        ]);
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.borderColor),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Payment Breakdown',
            style: TextStyle(
              fontFamily: 'Manrope',
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: context.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          ...rows,
        ],
      ),
    );
  }

  Widget _buildBreakdownRow(BuildContext context, Color dotColor, String label, double value) {
    final fmt = context.currencyFormat(decimalDigits: 0);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.isDark ? context.inputFill : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.borderColor),
      ),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: context.textPrimary),
            ),
          ),
          Text(
            fmt.format(value),
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: context.textPrimary),
          ),
        ],
      ),
    );
  }

  // ── Detail card builder ─────────────────────────────────────────────────────
  Widget _buildDetailCard(String title, IconData icon, List<Widget> rows) {
    return Builder(
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: context.cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: context.borderColor),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: context.isDark ? context.primaryColor : primary, size: 20),
                  const SizedBox(width: 10),
                  Text(
                    title,
                    style: TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: context.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ...rows,
            ],
          ),
        );
      }
    );
  }

  Widget _buildDetailRow(
    String label,
    String value, {
    Color? valueColor,
    bool isNote = false,
  }) {
    return Builder(
      builder: (context) {
        final resolvedValueColor = valueColor != null
            ? (valueColor == tertiary
                ? (context.isDark ? Colors.teal.shade300 : tertiary)
                : (valueColor == primary
                    ? (context.isDark ? context.primaryColor : primary)
                    : (valueColor == const Color(0xFFDC2626)
                        ? (context.isDark ? Colors.red.shade300 : valueColor)
                        : valueColor)))
            : null;

        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  color: isNote ? context.textMuted : context.textSecondary,
                ),
              ),
              Flexible(
                child: Text(
                  value,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isNote ? context.textMuted : (resolvedValueColor ?? context.textPrimary),
                    fontStyle: isNote ? FontStyle.italic : FontStyle.normal,
                  ),
                ),
              ),
            ],
          ),
        );
      }
    );
  }

  // ── Amortization button ─────────────────────────────────────────────────────
  Widget _buildAmortizationButton(BuildContext context, SavedAffordabilityCalculation calc) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AmortizationScheduleScreen(
            principal: calc.result.maxHomePrice - calc.input.downPayment,
            interestRate: calc.input.interestRate,
            years: calc.input.loanTerm,
          ),
        ),
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [primaryContainer, primary],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: primary.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'View Amortization Schedule',
              style: TextStyle(
                fontFamily: 'Manrope',
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.white,
              ),
            ),
            SizedBox(width: 8),
            Icon(Icons.chevron_right_rounded, color: Colors.white, size: 22),
          ],
        ),
      ),
    );
  }

  // ── Ad space ────────────────────────────────────────────────────────────────
  Widget _buildAdSpace() => const AdFallbackWidget(
    keywords: ['mortgage', 'home loan', 'real estate', 'refinance'],
    contentUrl: 'https://www.consumerfinance.gov/owning-a-home/',
    margin: EdgeInsets.only(bottom: 24),
  );

  // ── Bottom nav ──────────────────────────────────────────────────────────────
  Widget _buildBottomNav(BuildContext context) {
    return ClipRRect(
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: (context.isDark ? context.cardColor : Colors.white).withValues(alpha: 0.8),
            border: Border(
              top: BorderSide(color: context.borderColor.withValues(alpha: 0.2)),
            ),
          ),
          child: SafeArea(
            child: BottomNavigationBar(
              currentIndex: 2,
              onTap: (index) {
                if (index == 0 || index == 1) {
                  Navigator.of(context).popUntil((r) => r.isFirst);
                } else if (index == 2) {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const SavedCalculationsScreen(),
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
              backgroundColor: Colors.transparent,
              selectedItemColor: context.isDark ? context.primaryColor : primaryContainer,
              unselectedItemColor: context.textSecondary.withValues(alpha: 0.6),
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
                  icon: Icon(Icons.analytics_outlined, size: 26),
                  activeIcon: Icon(Icons.analytics_rounded, size: 26),
                  
                  
                  
                  
                  
                  
                  label: 'Results',
                ),
                BottomNavigationBarItem(
                  icon: Text('💾', style: TextStyle(fontSize: 22)),
                  activeIcon: Text('💾', style: TextStyle(fontSize: 26)),
                  
                  
                  
                  
                  
                  
                  
                  label: 'Saved',
                ),
                BottomNavigationBarItem(
                  icon: Text('⚙️', style: TextStyle(fontSize: 22)),
                  activeIcon: Text('⚙️', style: TextStyle(fontSize: 26)),
                  
                  
                  
                  
                  
                  
                  label: 'Settings',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
