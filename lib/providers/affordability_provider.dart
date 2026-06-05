import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/affordability_model.dart';
import '../services/fred_api_service.dart';

class AffordabilityProvider with ChangeNotifier {
  final FredApiService _apiService = FredApiService();

  static const String _storageKey = 'saved_affordability_calculations';

  List<MortgageRateData> _historicalRates = [];
  List<SavedAffordabilityCalculation> _savedCalculations = [];

  bool _isLoading = false;
  String? _errorMessage;

  AffordabilityResult? _result;
  AffordabilityInput? _lastInput;

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  AffordabilityProvider() {
    // Background load to ensure data is available ASAP
    loadSavedCalculations();
  }

  // ─────────────────────────────
  // Getters
  // ─────────────────────────────

  List<MortgageRateData> get historicalRates => _historicalRates;
  List<SavedAffordabilityCalculation> get savedCalculations =>
      _savedCalculations;
  bool get isLoading => _isLoading;
  AffordabilityInput? get lastInput => _lastInput;
  String? get errorMessage => _errorMessage;
  AffordabilityResult? get result => _result;

  double get currentRate => _historicalRates.isNotEmpty
      ? _historicalRates.last.value
      : FredApiService.fallbackRate;

  // ─────────────────────────────
  // Initialize Provider
  // ─────────────────────────────

  Future<void> init() async {
    if (_isInitialized && _historicalRates.isNotEmpty) return;

    _isLoading = true;
    notifyListeners();

    await loadSavedCalculations();

    try {
      _historicalRates = await _apiService.fetchMortgageRates();
    } catch (e) {
      debugPrint('Error fetching rates: $e');
      _historicalRates = [];
    }

    _errorMessage = _historicalRates.isEmpty
        ? 'Live rate unavailable. Showing estimated rate.'
        : null;

    _isLoading = false;
    _isInitialized = true;
    notifyListeners();
  }

  // ─────────────────────────────
  // Load Saved Calculations
  // ─────────────────────────────

  bool _isLoadingCalculations = false;
  Future<void> loadSavedCalculations() async {
    if (_isLoadingCalculations) return;
    _isLoadingCalculations = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      final String? data = prefs.getString(_storageKey);

      if (data == null || data.isEmpty) {
        _savedCalculations = [];
        _isLoadingCalculations = false;
        notifyListeners();
        return;
      }

      final List decoded = json.decode(data);
      _savedCalculations =
          decoded.map((e) => SavedAffordabilityCalculation.fromJson(e)).toList();
      _savedCalculations.sort((a, b) => b.date.compareTo(a.date));
      _isLoadingCalculations = false;
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading saved calculations: $e');
      _savedCalculations = [];
      _isLoadingCalculations = false;
      notifyListeners();
    }
  }

  // ─────────────────────────────
  // Save Current Affordability Result
  // ─────────────────────────────

  Future<void> saveCurrentResult(
    String name, {
    CalculatorType calculatorType = CalculatorType.affordability,
    Map<String, dynamic> metadata = const {},
  }) async {
    if (_result == null || _lastInput == null) return;

    final calc = SavedAffordabilityCalculation(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      date: DateTime.now(),
      input: _lastInput!,
      result: _result!,
      calculatorType: calculatorType,
      metadata: metadata,
    );

    _savedCalculations.insert(0, calc);
    await _persist();
    notifyListeners();
  }

  // ─────────────────────────────
  // Save Any Custom Calculation
  // ─────────────────────────────

  Future<void> saveCustomCalculation(
    String name,
    AffordabilityInput input,
    AffordabilityResult result, {
    CalculatorType calculatorType = CalculatorType.affordability,
    Map<String, dynamic> metadata = const {},
  }) async {
    final calc = SavedAffordabilityCalculation(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      date: DateTime.now(),
      input: input,
      result: result,
      calculatorType: calculatorType,
      metadata: metadata,
    );
    _savedCalculations.insert(0, calc);
    await _persist();
    notifyListeners();
  }

  // ─────────────────────────────
  // Delete Single Calculation
  // ─────────────────────────────

  Future<void> deleteCalculation(String id) async {
    _savedCalculations.removeWhere((c) => c.id == id);
    await _persist();
    notifyListeners();
  }

  // ─────────────────────────────
  // Clear All Calculations
  // ─────────────────────────────

  Future<void> clearAllSavedCalculations() async {
    _savedCalculations.clear();
    await _persist();
    notifyListeners();
  }

  // ─────────────────────────────
  // Persist to SharedPreferences
  // ─────────────────────────────

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded =
          json.encode(_savedCalculations.map((e) => e.toJson()).toList());
      await prefs.setString(_storageKey, encoded);
      debugPrint(
        'Persisted ${_savedCalculations.length} calculations',
      );
    } catch (e) {
      debugPrint('Error persisting calculations: $e');
    }
  }

  // ─────────────────────────────
  // Update Calculation
  // ─────────────────────────────

  Future<void> updateCalculation(
    String id,
    String name,
    AffordabilityInput input,
    AffordabilityResult result, {
    Map<String, dynamic>? metadata,
  }) async {
    final index = _savedCalculations.indexWhere((c) => c.id == id);
    if (index == -1) return;

    final existing = _savedCalculations[index];

    final updated = SavedAffordabilityCalculation(
      id: id,
      name: name,
      date: existing.date,
      input: input,
      result: result,
      calculatorType: existing.calculatorType, // always preserved
      metadata: metadata ?? existing.metadata, // preserve if not updated
    );

    _savedCalculations[index] = updated;
    await _persist();
    notifyListeners();
  }

  // ─────────────────────────────
  // Pure Math Calculation (Affordability)
  // ─────────────────────────────

  static AffordabilityResult calculateForInput(AffordabilityInput input) {
    double annual = input.annualIncome > 0 ? input.annualIncome : 0.001;
    double maxHousingPayment = (annual / 12) * 0.28;
    double maxTotalDebt = (annual / 12) * 0.36;
    double affordableMonthly = maxTotalDebt - input.monthlyDebts;
    double targetMonthly = min(maxHousingPayment, affordableMonthly);
    if (targetMonthly < 0) targetMonthly = 0;

    double homePrice = (targetMonthly * 12) / 0.05;

    for (int i = 0; i < 5; i++) {
      double loan = homePrice - input.downPayment;
      if (loan < 0) loan = 0;
      double monthlyTax = (homePrice * 0.012) / 12;
      double monthlyInsurance = 1000 / 12;
      double monthlyPMI = (homePrice > 0 &&
              input.downPayment / homePrice < 0.20)
          ? loan * 0.005 / 12
          : 0;
      double availablePI =
          targetMonthly - monthlyTax - monthlyInsurance - monthlyPMI;
      if (availablePI < 0) availablePI = 0;
      double r = (input.interestRate / 100) / 12;
      double n = input.loanTerm * 12.0;
      double maxLoan;
      if (r == 0) {
        maxLoan = availablePI * n;
      } else {
        final power = pow(1 + r, n);
        maxLoan = (power.isFinite && power > 0)
            ? availablePI * (power - 1) / (r * power)
            : 0;
      }
      homePrice = maxLoan + input.downPayment;
      if (!homePrice.isFinite) homePrice = 0;
    }

    double finalLoan = homePrice - input.downPayment;
    if (finalLoan < 0) finalLoan = 0;
    double r = (input.interestRate / 100) / 12;
    double n = input.loanTerm * 12.0;
    double monthlyPI;
    if (r == 0) {
      monthlyPI = n > 0 ? finalLoan / n : 0;
    } else {
      final power = pow(1 + r, n);
      monthlyPI = (power.isFinite && power > 1)
          ? finalLoan * r * power / (power - 1)
          : 0;
    }

    double monthlyTax = (homePrice * 0.012) / 12;
    double monthlyInsurance = 1000 / 12;
    double monthlyPMI =
        (homePrice > 0 && input.downPayment / homePrice < 0.20)
            ? finalLoan * 0.005 / 12
            : 0;
    double totalMonthly = monthlyPI + monthlyTax + monthlyInsurance + monthlyPMI;
    double dti = input.annualIncome > 0
        ? ((totalMonthly + input.monthlyDebts) / (input.annualIncome / 12)) *
            100
        : 0;

    if (!homePrice.isFinite) homePrice = 0;
    if (!monthlyPI.isFinite) monthlyPI = 0;
    if (!totalMonthly.isFinite) totalMonthly = 0;
    if (!dti.isFinite) dti = 0;

    return AffordabilityResult(
      maxHomePrice: homePrice,
      monthlyMortgage: monthlyPI,
      totalMonthlyPayment: totalMonthly,
      debtToIncomeRatio: dti,
      breakdown: PaymentBreakdown(
        principalAndInterest: monthlyPI,
        propertyTaxes: monthlyTax,
        homeInsurance: monthlyInsurance,
        pmi: monthlyPMI,
      ),
    );
  }

  // ─────────────────────────────
  // Mortgage Affordability Calculation (State Updating)
  // ─────────────────────────────

  void calculateAffordability(AffordabilityInput input) {
    _lastInput = input;
    _result = calculateForInput(input);
    notifyListeners();
  }
}
