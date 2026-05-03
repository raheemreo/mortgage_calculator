import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

// Internal Utils & Services
import '../utils/calculator_logic.dart';
import '../services/ad_service.dart';
import '../providers/settings_provider.dart';

// Widgets & Screens

import 'amortization_schedule_screen.dart';
import '../core/constants/theme_extensions.dart';

class MortgageCalculatorScreen extends StatefulWidget {
  const MortgageCalculatorScreen({super.key});

  @override
  State<MortgageCalculatorScreen> createState() =>
      _MortgageCalculatorScreenState();
}

class _MortgageCalculatorScreenState extends State<MortgageCalculatorScreen> {
  final GlobalKey _resultKey = GlobalKey();

  // ── Controllers ────────────────────────────────────────────────────────────
  late final TextEditingController _principalController;
  late final TextEditingController _downPaymentController;
  late final TextEditingController _interestController;

  // ── State Variables ────────────────────────────────────────────────────────
  String _selectedTerm = '30 Years';
  bool _includePmi = false;
  bool _includeEscrow = false;

  double _monthlyPayment = 0;
  double _piAmount = 0;
  double _taxInsAmount = 0;

  // ── Design Constants ───────────────────────────────────────────────────────
  static const Color _primaryBlue = Color(0xFF1E3A8A);
  static const Color _emerald = Color(0xFF10B981);
  static final Color _slate = const Color(0xFF64748B);

  @override
  void initState() {
    super.initState();
    _principalController = TextEditingController(text: '450,000');
    _downPaymentController = TextEditingController(text: '90,000');
    _interestController = TextEditingController(text: '6.5');

    // Pre-load interstitial for smooth navigation later
    AdService().loadInterstitialAd();

    // Initial fast-calculate
    _calculate(shouldUnfocus: false);
  }

  @override
  void dispose() {
    // Prevent Memory Leaks
    _principalController.dispose();
    _downPaymentController.dispose();
    _interestController.dispose();
    super.dispose();
  }

  // ── Logic ──────────────────────────────────────────────────────────────────

  void _calculate({bool shouldUnfocus = true}) {
    final String pText = _principalController.text.replaceAll(',', '');
    final String dText = _downPaymentController.text.replaceAll(',', '');

    final double homePrice = double.tryParse(pText) ?? 0;
    final double downPayment = double.tryParse(dText) ?? 0;
    final double interestRate = double.tryParse(_interestController.text) ?? 0;

    final int years = int.parse(_selectedTerm.split(' ')[0]);
    final int months = years * 12;

    final double principal = homePrice - downPayment;

    if (principal > 0 && interestRate >= 0 && years > 0) {
      double pi = CalculatorLogic.calculateEMI(
        principal: principal,
        annualInterestRate: interestRate,
        months: months,
      );

      double taxAndIns = 0;
      if (_includeEscrow) {
        // Generic 1.5% estimation for taxes/ins
        taxAndIns = (homePrice * 0.015) / 12;
      }

      double pmi = 0;
      if (_includePmi && downPayment < (homePrice * 0.20)) {
        // Generic 0.5% PMI
        pmi = (principal * 0.005) / 12;
      }

      setState(() {
        _piAmount = pi;
        _taxInsAmount = taxAndIns + pmi;
        _monthlyPayment = pi + _taxInsAmount;
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
  }

  /// Triggers Interstitial Ad at a natural transition point (Screen Navigation)
  void _navigateToSchedule() {
    AdService().showInterstitialAd(
      onAdClosed: () {
        double principal =
            (double.tryParse(_principalController.text.replaceAll(',', '')) ??
                0) -
            (double.tryParse(_downPaymentController.text.replaceAll(',', '')) ??
                0);
        final double rate = double.tryParse(_interestController.text) ?? 6.5;
        final int years = int.parse(_selectedTerm.split(' ')[0]);

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
      },
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final formatCurrency = NumberFormat.currency(
      symbol: settings.currencySymbol,
      decimalDigits: 0,
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: _buildAppBar(),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              key: _resultKey,
              child: _buildResultCard(formatCurrency),
            ),

            _buildFormBlock(settings),
            const SizedBox(height: 24),
            _buildActionButtons(),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  // ── UI Components ──────────────────────────────────────────────────────────

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: context.cs.surface,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(
          Icons.arrow_back_ios_new,
          color: _primaryBlue,
          size: 20,
        ),
        onPressed: () => Navigator.pop(context),
      ),
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.real_estate_agent_rounded, color: _primaryBlue),
          SizedBox(width: 8),
          Text(
            'Mortgage Calc',
            style: TextStyle(
              color: context.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      centerTitle: true,
      actions: [
        IconButton(
          icon: Icon(Icons.refresh_rounded, color: _slate),
          onPressed: _resetForm,
        ),
      ],
    );
  }

  Widget _buildResultCard(NumberFormat formatCurrency) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: context.cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.borderColor),
        boxShadow: [
          BoxShadow(
            color: context.textPrimary.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'EST. MONTHLY PAYMENT',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
              color: _slate,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            formatCurrency.format(_monthlyPayment),
            style: const TextStyle(
              fontSize: 40,
              fontWeight: FontWeight.bold,
              color: _emerald,
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Divider(color: Color(0xFFF1F5F9)),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildResultColumn(
                'Principal & Interest',
                formatCurrency.format(_piAmount),
                CrossAxisAlignment.start,
              ),
              _buildResultColumn(
                'Taxes & Ins.',
                formatCurrency.format(_taxInsAmount),
                CrossAxisAlignment.end,
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _navigateToSchedule,
              icon: const Icon(Icons.table_chart_rounded, size: 18),
              label: const Text('View Detailed Schedule'),
              style: OutlinedButton.styleFrom(
                foregroundColor: _primaryBlue,
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

  Widget _buildResultColumn(
    String label,
    String value,
    CrossAxisAlignment alignment,
  ) {
    return Column(
      crossAxisAlignment: alignment,
      children: [
        Text(label, style: TextStyle(color: _slate, fontSize: 13)),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ],
    );
  }

  Widget _buildFormBlock(SettingsProvider settings) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Loan Details',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const Divider(height: 32, color: Color(0xFFF1F5F9)),

          _buildInputField(
            'Home Price',
            _principalController,
            prefix: settings.currencySymbol,
          ),
          const SizedBox(height: 16),

          _buildInputField(
            'Down Payment',
            _downPaymentController,
            prefix: settings.currencySymbol,
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(child: _buildDropdownField()),
              const SizedBox(width: 16),
              Expanded(
                child: _buildInputField(
                  'Interest Rate',
                  _interestController,
                  suffix: '%',
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Switches
          _buildSwitchRow(
            'Include PMI',
            'Private Mortgage Insurance added if down payment is < 20%',
            _includePmi,
            (val) => setState(() {
              _includePmi = val;
              _calculate(shouldUnfocus: false);
            }),
          ),
          const SizedBox(height: 12),
          _buildSwitchRow(
            'Include Escrow',
            'Estimated Taxes and Insurance',
            _includeEscrow,
            (val) => setState(() {
              _includeEscrow = val;
              _calculate(shouldUnfocus: false);
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return ElevatedButton.icon(
      onPressed: () => _calculate(shouldUnfocus: true),
      icon: const Icon(Icons.calculate_rounded),
      label: const Text(
        'Calculate Payment',
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: _primaryBlue,
        foregroundColor: context.cs.surface,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 4,
      ),
    );
  }

  // ── Micro Helpers ──────────────────────────────────────────────────────────

  void _resetForm() {
    setState(() {
      _principalController.text = '450,000';
      _downPaymentController.text = '90,000';
      _interestController.text = '6.5';
      _selectedTerm = '30 Years';
      _includePmi = false;
      _includeEscrow = false;
    });
    _calculate(shouldUnfocus: true);
  }

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
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: _slate,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: context.textPrimary,
          ),
          decoration: InputDecoration(
            prefixText: prefix != null ? '$prefix ' : null,
            suffixText: suffix != null ? ' $suffix' : null,
            contentPadding: const EdgeInsets.symmetric(
              vertical: 16,
              horizontal: 16,
            ),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: context.borderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: context.borderColor),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Term',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: _slate,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: _selectedTerm,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: context.textPrimary,
          ),
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(
              vertical: 14,
              horizontal: 16,
            ),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: context.borderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: context.borderColor),
            ),
          ),
          items: ['30 Years', '20 Years', '15 Years', '10 Years', '5 Years']
              .map((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(
                    value,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: context.textPrimary,
                    ),
                  ),
                );
              })
              .toList(),
          onChanged: (val) {
            if (val != null) {
              setState(() {
                _selectedTerm = val;
              });
              _calculate(shouldUnfocus: false);
            }
          },
        ),
      ],
    );
  }

  Widget _buildSwitchRow(
    String title,
    String tooltip,
    bool value,
    Function(bool) onChanged,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Row(
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 6),
              Tooltip(
                message: tooltip,
                triggerMode: TooltipTriggerMode.tap,
                child: Icon(
                  Icons.info_outline_rounded,
                  size: 16,
                  color: _slate,
                ),
              ),
            ],
          ),
        ),
        Switch.adaptive(
          value: value,
          onChanged: onChanged,
          activeThumbColor: _primaryBlue,
        ),
      ],
    );
  }
}
