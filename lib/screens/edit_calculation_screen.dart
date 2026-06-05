import 'package:flutter/material.dart';
import '../widgets/gradient_app_bar.dart';
import 'package:provider/provider.dart';

import '../core/constants/theme_extensions.dart';
import '../models/affordability_model.dart';
import '../providers/affordability_provider.dart';
import '../utils/calculator_logic.dart';

class EditCalculationScreen extends StatefulWidget {
  final SavedAffordabilityCalculation calculation;

  const EditCalculationScreen({super.key, required this.calculation});

  @override
  State<EditCalculationScreen> createState() => _EditCalculationScreenState();
}

class _EditCalculationScreenState extends State<EditCalculationScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;

  // Controllers for all possible fields
  final _annualIncomeCtrl = TextEditingController();
  final _monthlyDebtsCtrl = TextEditingController();
  final _downPaymentCtrl = TextEditingController();
  final _interestRateCtrl = TextEditingController();
  final _homePriceCtrl = TextEditingController();
  final _vehiclePriceCtrl = TextEditingController();

  final _propertyTaxCtrl = TextEditingController();
  final _homeInsuranceCtrl = TextEditingController();
  final _hoaFeesCtrl = TextEditingController();
  final _pmiCtrl = TextEditingController();
  final _extraMonthlyCtrl = TextEditingController();
  final _extraBiweeklyCtrl = TextEditingController();
  final _lumpSumCtrl = TextEditingController();

  int _loanTerm = 30;
  bool _includePmi = false;
  bool _includeEscrow = false;

  // ── Design Tokens ─────────────────────────────────────────────────────────
  Color get primary => context.isDark ? context.primaryColor : const Color(0xFF0037B1);
  Color get surfaceContainerLow => context.inputFill;
  Color get outline => context.textSecondary;
  Color get background => context.pageBackground;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.calculation.name);
    _populateFields();
  }

  void _populateFields() {
    final calc = widget.calculation;
    final meta = calc.metadata;

    _loanTerm = calc.input.loanTerm;
    _downPaymentCtrl.text = calc.input.downPayment.toStringAsFixed(0);
    _interestRateCtrl.text = calc.input.interestRate.toStringAsFixed(2);

    if (calc.calculatorType == CalculatorType.piti) {
      _homePriceCtrl.text =
          (meta['homePrice'] as num?)?.toStringAsFixed(0) ??
          calc.input.annualIncome.toStringAsFixed(0);
      _propertyTaxCtrl.text =
          (meta['propertyTax'] as num?)?.toStringAsFixed(0) ?? '0';
      _homeInsuranceCtrl.text =
          (meta['homeInsurance'] as num?)?.toStringAsFixed(0) ?? '0';
      _hoaFeesCtrl.text = (meta['hoaFees'] as num?)?.toStringAsFixed(0) ?? '0';
      _pmiCtrl.text = (meta['pmi'] as num?)?.toStringAsFixed(0) ?? '0';
      _extraMonthlyCtrl.text =
          (meta['extraMonthly'] as num?)?.toStringAsFixed(0) ?? '0';
      _extraBiweeklyCtrl.text =
          (meta['extraBiweekly'] as num?)?.toStringAsFixed(0) ?? '0';
      _lumpSumCtrl.text = (meta['lumpSum'] as num?)?.toStringAsFixed(0) ?? '0';
    } else if (calc.calculatorType == CalculatorType.mortgage) {
      _homePriceCtrl.text =
          (meta['homePrice'] as num?)?.toStringAsFixed(0) ??
          calc.input.annualIncome.toStringAsFixed(0);
      _includePmi = (meta['includePmi'] as bool?) ?? false;
      _includeEscrow = (meta['includeEscrow'] as bool?) ?? false;
    } else if (calc.calculatorType == CalculatorType.autoLoan) {
      _vehiclePriceCtrl.text =
          (meta['vehiclePrice'] as num?)?.toStringAsFixed(0) ??
          calc.input.annualIncome.toStringAsFixed(0);
      _loanTerm = (meta['termMonths'] as num?)?.toInt() ?? _loanTerm * 12;
    } else if (calc.calculatorType == CalculatorType.affordability) {
      _annualIncomeCtrl.text = calc.input.annualIncome.toStringAsFixed(0);
      _monthlyDebtsCtrl.text = calc.input.monthlyDebts.toStringAsFixed(0);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _annualIncomeCtrl.dispose();
    _monthlyDebtsCtrl.dispose();
    _downPaymentCtrl.dispose();
    _interestRateCtrl.dispose();
    _homePriceCtrl.dispose();
    _vehiclePriceCtrl.dispose();
    _propertyTaxCtrl.dispose();
    _homeInsuranceCtrl.dispose();
    _hoaFeesCtrl.dispose();
    _pmiCtrl.dispose();
    _extraMonthlyCtrl.dispose();
    _extraBiweeklyCtrl.dispose();
    _lumpSumCtrl.dispose();
    super.dispose();
  }

  void _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;
    final provider = Provider.of<AffordabilityProvider>(context, listen: false);

    final String newName = _nameController.text.trim().isNotEmpty
        ? _nameController.text.trim()
        : 'Calculation';

    AffordabilityInput newInput;
    AffordabilityResult newResult;
    Map<String, dynamic> newMeta = {};

    final calcType = widget.calculation.calculatorType;

    if (calcType == CalculatorType.piti) {
      final hp = double.tryParse(_homePriceCtrl.text) ?? 0;
      final dp = double.tryParse(_downPaymentCtrl.text) ?? 0;
      final rate = double.tryParse(_interestRateCtrl.text) ?? 0;
      final years = _loanTerm;
      final pTax = double.tryParse(_propertyTaxCtrl.text) ?? 0;
      final hIns = double.tryParse(_homeInsuranceCtrl.text) ?? 0;
      final hoa = double.tryParse(_hoaFeesCtrl.text) ?? 0;
      final pmi = double.tryParse(_pmiCtrl.text) ?? 0;
      final eMo = double.tryParse(_extraMonthlyCtrl.text) ?? 0;
      final eBw = double.tryParse(_extraBiweeklyCtrl.text) ?? 0;
      final lSum = double.tryParse(_lumpSumCtrl.text) ?? 0;

      final principal = hp - dp;
      final pi = CalculatorLogic.calculateEMI(
        principal: principal,
        annualInterestRate: rate,
        months: years * 12,
      );
      final totalMo = pi + (pTax / 12) + (hIns / 12) + hoa + (pmi / 12);

      newInput = AffordabilityInput(
        annualIncome: hp,
        monthlyDebts: 0,
        downPayment: dp,
        loanTerm: years,
        interestRate: rate,
      );
      newResult = AffordabilityResult(
        maxHomePrice: hp,
        monthlyMortgage: pi,
        totalMonthlyPayment: totalMo,
        debtToIncomeRatio: 0,
        breakdown: PaymentBreakdown(
          principalAndInterest: pi,
          propertyTaxes: pTax / 12,
          homeInsurance: hIns / 12,
          pmi: pmi / 12,
        ),
      );
      newMeta = {
        'homePrice': hp,
        'downPaymentPct': hp > 0 ? (dp / hp * 100) : 0,
        'propertyTax': pTax,
        'homeInsurance': hIns,
        'hoaFees': hoa,
        'pmi': pmi,
        'extraMonthly': eMo,
        'extraBiweekly': eBw,
        'lumpSum': lSum,
      };
    } else if (calcType == CalculatorType.mortgage) {
      final hp = double.tryParse(_homePriceCtrl.text) ?? 0;
      final dp = double.tryParse(_downPaymentCtrl.text) ?? 0;
      final rate = double.tryParse(_interestRateCtrl.text) ?? 0;
      final years = _loanTerm;

      final principal = hp - dp;
      final pi = CalculatorLogic.calculateEMI(
        principal: principal,
        annualInterestRate: rate,
        months: years * 12,
      );
      final taxIns = _includeEscrow ? (hp * 0.015) / 12 : 0.0;
      final pmiVal = (_includePmi && dp < hp * 0.20)
          ? (principal * 0.005) / 12
          : 0.0;
      final totalMo = pi + taxIns + pmiVal;

      newInput = AffordabilityInput(
        annualIncome: hp,
        monthlyDebts: 0,
        downPayment: dp,
        loanTerm: years,
        interestRate: rate,
      );
      newResult = AffordabilityResult(
        maxHomePrice: hp,
        monthlyMortgage: pi,
        totalMonthlyPayment: totalMo,
        debtToIncomeRatio: 0,
        breakdown: PaymentBreakdown(
          principalAndInterest: pi,
          propertyTaxes: _includeEscrow ? taxIns : 0,
          homeInsurance: 0,
          pmi: _includePmi ? pmiVal : 0,
        ),
      );
      newMeta = {
        'homePrice': hp,
        'includePmi': _includePmi,
        'includeEscrow': _includeEscrow,
        'pmiMonthly': pmiVal,
        'taxInsMonthly': taxIns,
      };
    } else if (calcType == CalculatorType.autoLoan) {
      final vp = double.tryParse(_vehiclePriceCtrl.text) ?? 0;
      final dp = double.tryParse(_downPaymentCtrl.text) ?? 0;
      final rate = double.tryParse(_interestRateCtrl.text) ?? 0;
      final months = _loanTerm;

      final principal = vp - dp;
      final pi = CalculatorLogic.calculateEMI(
        principal: principal,
        annualInterestRate: rate,
        months: months,
      );
      final totalInterest = (pi * months) - principal;
      final totalCost = dp + principal + totalInterest;

      newInput = AffordabilityInput(
        annualIncome: vp,
        monthlyDebts: 0,
        downPayment: dp,
        loanTerm: (months / 12).ceil(),
        interestRate: rate,
      );
      newResult = AffordabilityResult(
        maxHomePrice: vp,
        monthlyMortgage: pi,
        totalMonthlyPayment: pi,
        debtToIncomeRatio: 0,
        breakdown: PaymentBreakdown(
          principalAndInterest: pi,
          propertyTaxes: totalInterest,
          homeInsurance: 0,
          pmi: 0,
        ),
      );
      newMeta = {
        'vehiclePrice': vp,
        'termMonths': months,
        'totalInterest': totalInterest,
        'totalCost': totalCost,
      };
    } else {
      // Affordability
      final income = double.tryParse(_annualIncomeCtrl.text) ?? 0;
      final debts = double.tryParse(_monthlyDebtsCtrl.text) ?? 0;
      final dp = double.tryParse(_downPaymentCtrl.text) ?? 0;
      final rate = double.tryParse(_interestRateCtrl.text) ?? 0;

      newInput = AffordabilityInput(
        annualIncome: income,
        monthlyDebts: debts,
        downPayment: dp,
        loanTerm: _loanTerm,
        interestRate: rate,
      );
      newResult = AffordabilityProvider.calculateForInput(newInput);
      newMeta = widget.calculation.metadata; // keep liveRate
    }

    await provider.updateCalculation(
      widget.calculation.id,
      newName,
      newInput,
      newResult,
      metadata: newMeta,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Changes saved successfully!')),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      backgroundColor: background,
      appBar: GradientAppBar(
        title: const Text(
          'Edit Calculation',
          style: TextStyle(
            fontFamily: 'Manrope',
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: Colors.white,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInputField(
                  label: 'CALCULATION NAME',
                  controller: _nameController,
                  prefixIcon: Icons.edit_rounded,
                ),
                const SizedBox(height: 24),
                _buildSpecificFields(),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _saveChanges,
                    icon: const Icon(Icons.save_rounded, size: 20),
                    label: const Text(
                      'Save Changes',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
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

  Widget _buildSpecificFields() {
    final type = widget.calculation.calculatorType;
    final currencySymbol = context.currencySymbol;
    if (type == CalculatorType.piti) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInputField(
            label: 'HOME PRICE',
            controller: _homePriceCtrl,
            prefixText: currencySymbol,
          ),
          const SizedBox(height: 16),
          _buildInputField(
            label: 'DOWN PAYMENT',
            controller: _downPaymentCtrl,
            prefixText: currencySymbol,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildInputField(
                  label: 'INTEREST RATE',
                  controller: _interestRateCtrl,
                  suffixText: '%',
                ),
              ),
              const SizedBox(width: 16),
              Expanded(child: _buildTermDropdown()),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            'EXPENSES (ANNUAL)',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: outline,
            ),
          ),
          const SizedBox(height: 16),
          _buildInputField(
            label: 'PROPERTY TAX',
            controller: _propertyTaxCtrl,
            prefixText: currencySymbol,
          ),
          const SizedBox(height: 16),
          _buildInputField(
            label: 'HOME INSURANCE',
            controller: _homeInsuranceCtrl,
            prefixText: currencySymbol,
          ),
          const SizedBox(height: 16),
          _buildInputField(
            label: 'HOA FEES',
            controller: _hoaFeesCtrl,
            prefixText: currencySymbol,
          ),
          const SizedBox(height: 16),
          _buildInputField(
            label: 'PMI',
            controller: _pmiCtrl,
            prefixText: currencySymbol,
          ),
        ],
      );
    } else if (type == CalculatorType.mortgage) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInputField(
            label: 'HOME PRICE',
            controller: _homePriceCtrl,
            prefixText: currencySymbol,
          ),
          const SizedBox(height: 16),
          _buildInputField(
            label: 'DOWN PAYMENT',
            controller: _downPaymentCtrl,
            prefixText: currencySymbol,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildInputField(
                  label: 'INTEREST RATE',
                  controller: _interestRateCtrl,
                  suffixText: '%',
                ),
              ),
              const SizedBox(width: 16),
              Expanded(child: _buildTermDropdown()),
            ],
          ),
          const SizedBox(height: 24),
          SwitchListTile(
            title: Text(
              'Include PMI',
              style: TextStyle(color: context.textPrimary, fontWeight: FontWeight.w500),
            ),
            activeThumbColor: primary,
            value: _includePmi,
            onChanged: (v) => setState(() => _includePmi = v),
          ),
          SwitchListTile(
            title: Text(
              'Include Taxes & Insurance (Escrow)',
              style: TextStyle(color: context.textPrimary, fontWeight: FontWeight.w500),
            ),
            activeThumbColor: primary,
            value: _includeEscrow,
            onChanged: (v) => setState(() => _includeEscrow = v),
          ),
        ],
      );
    } else if (type == CalculatorType.autoLoan) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInputField(
            label: 'VEHICLE PRICE',
            controller: _vehiclePriceCtrl,
            prefixText: currencySymbol,
          ),
          const SizedBox(height: 16),
          _buildInputField(
            label: 'DOWN PAYMENT',
            controller: _downPaymentCtrl,
            prefixText: currencySymbol,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildInputField(
                  label: 'APR',
                  controller: _interestRateCtrl,
                  suffixText: '%',
                ),
              ),
              const SizedBox(width: 16),
              Expanded(child: _buildMonthsDropdown()),
            ],
          ),
        ],
      );
    } else {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInputField(
            label: 'ANNUAL INCOME',
            controller: _annualIncomeCtrl,
            prefixText: currencySymbol,
          ),
          const SizedBox(height: 16),
          _buildInputField(
            label: 'MONTHLY DEBTS',
            controller: _monthlyDebtsCtrl,
            prefixText: currencySymbol,
          ),
          const SizedBox(height: 16),
          _buildInputField(
            label: 'DOWN PAYMENT',
            controller: _downPaymentCtrl,
            prefixText: currencySymbol,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildInputField(
                  label: 'INTEREST RATE',
                  controller: _interestRateCtrl,
                  suffixText: '%',
                ),
              ),
              const SizedBox(width: 16),
              Expanded(child: _buildTermDropdown()),
            ],
          ),
        ],
      );
    }
  }

  Widget _buildTermDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'LOAN TERM',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: outline,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<int>(
          initialValue: [5, 10, 15, 20, 30].contains(_loanTerm)
              ? _loanTerm
              : 30,
          dropdownColor: context.cardColor,
          style: TextStyle(color: context.textPrimary, fontWeight: FontWeight.bold),
          items: ['5 Years', '10 Years', '15 Years', '20 Years', '30 Years']
              .asMap()
              .entries
              .map((e) {
                final values = [5, 10, 15, 20, 30];
                return DropdownMenuItem<int>(
                  value: values[e.key],
                  child: Text(
                    e.value,
                    style: TextStyle(color: context.textPrimary),
                  ),
                );
              })
              .toList(),
          onChanged: (val) {
            if (val != null) setState(() => _loanTerm = val);
          },
          decoration: InputDecoration(
            filled: true,
            fillColor: surfaceContainerLow,
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

  Widget _buildMonthsDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'LOAN TERM',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: outline,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<int>(
          initialValue: [36, 48, 60, 72].contains(_loanTerm) ? _loanTerm : 60,
          dropdownColor: context.cardColor,
          style: TextStyle(color: context.textPrimary, fontWeight: FontWeight.bold),
          items: ['36 Months', '48 Months', '60 Months', '72 Months']
              .asMap()
              .entries
              .map((e) {
                final values = [36, 48, 60, 72];
                return DropdownMenuItem<int>(
                  value: values[e.key],
                  child: Text(
                    e.value,
                    style: TextStyle(color: context.textPrimary),
                  ),
                );
              })
              .toList(),
          onChanged: (val) {
            if (val != null) setState(() => _loanTerm = val);
          },
          decoration: InputDecoration(
            filled: true,
            fillColor: surfaceContainerLow,
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

  Widget _buildInputField({
    required String label,
    required TextEditingController controller,
    String? prefixText,
    String? suffixText,
    IconData? prefixIcon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: outline,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: label == 'CALCULATION NAME' ? TextInputType.text : const TextInputType.numberWithOptions(decimal: true),
          style: TextStyle(color: context.textPrimary, fontWeight: FontWeight.bold),
          decoration: InputDecoration(
            prefixText: prefixText != null ? '$prefixText ' : null,
            prefixStyle: TextStyle(color: context.textSecondary),
            suffixText: suffixText,
            suffixStyle: TextStyle(color: context.textSecondary),
            prefixIcon: prefixIcon != null ? Icon(prefixIcon, color: outline) : null,
            filled: true,
            fillColor: surfaceContainerLow,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: context.borderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: context.borderColor),
            ),
          ),
          validator: (v) {
            if (v == null || v.isEmpty) return 'Required';
            return null;
          },
        ),
      ],
    );
  }
}
