// ─────────────────────────────────────────────────────────────────────────────
// Calculator-type identifier
// ─────────────────────────────────────────────────────────────────────────────

enum CalculatorType {
  piti,
  mortgage,
  autoLoan,
  affordability;

  static CalculatorType fromString(String? value) {
    switch (value) {
      case 'piti':
        return CalculatorType.piti;
      case 'mortgage':
        return CalculatorType.mortgage;
      case 'autoLoan':
        return CalculatorType.autoLoan;
      default:
        return CalculatorType.affordability;
    }
  }

  String get displayName {
    switch (this) {
      case CalculatorType.piti:
        return 'PITI';
      case CalculatorType.mortgage:
        return 'Mortgage';
      case CalculatorType.autoLoan:
        return 'Auto Loan';
      case CalculatorType.affordability:
        return 'Affordability';
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AffordabilityInput
// ─────────────────────────────────────────────────────────────────────────────

class AffordabilityInput {
  final double annualIncome;
  final double monthlyDebts;
  final double downPayment;
  final int loanTerm; // in years
  final double interestRate;

  AffordabilityInput({
    required this.annualIncome,
    required this.monthlyDebts,
    required this.downPayment,
    required this.loanTerm,
    required this.interestRate,
  });

  Map<String, dynamic> toJson() => {
        'annualIncome': annualIncome,
        'monthlyDebts': monthlyDebts,
        'downPayment': downPayment,
        'loanTerm': loanTerm,
        'interestRate': interestRate,
      };

  factory AffordabilityInput.fromJson(Map<String, dynamic> json) =>
      AffordabilityInput(
        annualIncome: (json['annualIncome'] as num?)?.toDouble() ?? 0.0,
        monthlyDebts: (json['monthlyDebts'] as num?)?.toDouble() ?? 0.0,
        downPayment: (json['downPayment'] as num?)?.toDouble() ?? 0.0,
        loanTerm: json['loanTerm'] as int? ?? 30,
        interestRate: (json['interestRate'] as num?)?.toDouble() ?? 0.0,
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// AffordabilityResult
// ─────────────────────────────────────────────────────────────────────────────

class AffordabilityResult {
  final double maxHomePrice;
  final double monthlyMortgage;
  final double totalMonthlyPayment;
  final double debtToIncomeRatio;
  final PaymentBreakdown breakdown;

  AffordabilityResult({
    required this.maxHomePrice,
    required this.monthlyMortgage,
    required this.totalMonthlyPayment,
    required this.debtToIncomeRatio,
    required this.breakdown,
  });

  Map<String, dynamic> toJson() => {
        'maxHomePrice': maxHomePrice,
        'monthlyMortgage': monthlyMortgage,
        'totalMonthlyPayment': totalMonthlyPayment,
        'debtToIncomeRatio': debtToIncomeRatio,
        'breakdown': breakdown.toJson(),
      };

  factory AffordabilityResult.fromJson(Map<String, dynamic> json) =>
      AffordabilityResult(
        maxHomePrice: (json['maxHomePrice'] as num?)?.toDouble() ?? 0.0,
        monthlyMortgage: (json['monthlyMortgage'] as num?)?.toDouble() ?? 0.0,
        totalMonthlyPayment:
            (json['totalMonthlyPayment'] as num?)?.toDouble() ?? 0.0,
        debtToIncomeRatio:
            (json['debtToIncomeRatio'] as num?)?.toDouble() ?? 0.0,
        breakdown: json['breakdown'] != null
            ? PaymentBreakdown.fromJson(json['breakdown'])
            : PaymentBreakdown(
                principalAndInterest: 0,
                propertyTaxes: 0,
                homeInsurance: 0,
                pmi: 0,
              ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// PaymentBreakdown
// ─────────────────────────────────────────────────────────────────────────────

class PaymentBreakdown {
  final double principalAndInterest;
  final double propertyTaxes;
  final double homeInsurance;
  final double pmi;

  PaymentBreakdown({
    required this.principalAndInterest,
    required this.propertyTaxes,
    required this.homeInsurance,
    required this.pmi,
  });

  double get total =>
      principalAndInterest + propertyTaxes + homeInsurance + pmi;

  Map<String, dynamic> toJson() => {
        'principalAndInterest': principalAndInterest,
        'propertyTaxes': propertyTaxes,
        'homeInsurance': homeInsurance,
        'pmi': pmi,
      };

  factory PaymentBreakdown.fromJson(Map<String, dynamic> json) =>
      PaymentBreakdown(
        principalAndInterest:
            (json['principalAndInterest'] as num?)?.toDouble() ?? 0.0,
        propertyTaxes: (json['propertyTaxes'] as num?)?.toDouble() ?? 0.0,
        homeInsurance: (json['homeInsurance'] as num?)?.toDouble() ?? 0.0,
        pmi: (json['pmi'] as num?)?.toDouble() ?? 0.0,
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// SavedAffordabilityCalculation
// ─────────────────────────────────────────────────────────────────────────────

class SavedAffordabilityCalculation {
  final String id;
  final String name;
  final DateTime date;
  final AffordabilityInput input;
  final AffordabilityResult result;

  /// Which calculator produced this record.
  final CalculatorType calculatorType;

  /// Calculator-specific extra fields (e.g. homePrice, metadata, etc.)
  /// Keys are documented per CalculatorType:
  ///
  /// piti        → homePrice, downPaymentPct, propertyTax, homeInsurance,
  ///               hoaFees, pmi, extraMonthly, extraBiweekly, lumpSum
  /// mortgage    → homePrice, includePmi, includeEscrow, pmiMonthly, taxInsMonthly
  /// autoLoan    → vehiclePrice, termMonths, totalInterest, totalCost
  /// affordability → liveRate
  final Map<String, dynamic> metadata;

  SavedAffordabilityCalculation({
    required this.id,
    required this.name,
    required this.date,
    required this.input,
    required this.result,
    this.calculatorType = CalculatorType.affordability,
    this.metadata = const {},
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'date': date.toIso8601String(),
        'input': input.toJson(),
        'result': result.toJson(),
        'calculatorType': calculatorType.name,
        'metadata': metadata,
      };

  factory SavedAffordabilityCalculation.fromJson(
    Map<String, dynamic> json,
  ) =>
      SavedAffordabilityCalculation(
        id: json['id'] as String? ??
            DateTime.now().millisecondsSinceEpoch.toString(),
        name: json['name'] as String? ?? 'Saved Calculation',
        date: json['date'] != null
            ? DateTime.parse(json['date'])
            : DateTime.now(),
        input: json['input'] != null
            ? AffordabilityInput.fromJson(json['input'])
            : AffordabilityInput(
                annualIncome: 0,
                monthlyDebts: 0,
                downPayment: 0,
                loanTerm: 30,
                interestRate: 0,
              ),
        result: json['result'] != null
            ? AffordabilityResult.fromJson(json['result'])
            : AffordabilityResult(
                maxHomePrice: 0,
                monthlyMortgage: 0,
                totalMonthlyPayment: 0,
                debtToIncomeRatio: 0,
                breakdown: PaymentBreakdown(
                  principalAndInterest: 0,
                  propertyTaxes: 0,
                  homeInsurance: 0,
                  pmi: 0,
                ),
              ),
        calculatorType:
            CalculatorType.fromString(json['calculatorType'] as String?),
        metadata:
            (json['metadata'] as Map<String, dynamic>?) ?? {},
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// MortgageRateData
// ─────────────────────────────────────────────────────────────────────────────

class MortgageRateData {
  final DateTime date;
  final double value;

  MortgageRateData({required this.date, required this.value});

  factory MortgageRateData.fromJson(Map<String, dynamic> json) {
    return MortgageRateData(
      date: DateTime.parse(json['date']),
      value: (json['value'] is String)
          ? double.parse(json['value'])
          : (json['value'] as num).toDouble(),
    );
  }
}
