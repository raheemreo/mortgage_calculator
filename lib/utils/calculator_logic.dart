import 'dart:math';

class CalculatorLogic {
  /// Calculate Monthly EMI
  /// M = P [ r(1 + r)^n ] / [ (1 + r)^n - 1]
  static double calculateEMI({
    required double principal,
    required double annualInterestRate,
    required int months,
  }) {
    if (principal <= 0 || months <= 0) return 0.0;
    if (annualInterestRate <= 0) return principal / months;

    double r = annualInterestRate / 12 / 100;
    double numerator = r * pow(1 + r, months);
    double denominator = pow(1 + r, months) - 1;

    return principal * (numerator / denominator);
  }

  /// Auto Loan Payment Calculation
  /// Exactly same as EMI but usually given term in months directly.
  static double calculateAutoLoan({
    required double principal,
    required double annualInterestRate,
    required int termInMonths,
  }) {
    return calculateEMI(
      principal: principal,
      annualInterestRate: annualInterestRate,
      months: termInMonths,
    );
  }

  /// Simple Credit Card Payoff estimation
  /// Using formula: N = -log(1 - (r * P) / M) / log(1 + r)
  /// N = months to payoff
  static int calculateCreditCardPayoffMonths({
    required double balance,
    required double monthlyPayment,
    required double apr,
  }) {
    if (balance <= 0 || monthlyPayment <= 0) return 0;
    if (apr <= 0) return (balance / monthlyPayment).ceil();

    double r = apr / 12 / 100;

    // If interest strictly exceeds the payment, it never pays off.
    if ((r * balance) >= monthlyPayment) {
      return -1; // Indicates infinite/never
    }

    double numerator = log(1 - ((r * balance) / monthlyPayment));
    double denominator = log(1 + r);

    double n = -(numerator / denominator);
    return n.ceil();
  }

  /// DTI (Debt-to-Income) Ratio Calculation
  static double calculateDTI({
    required double totalMonthlyDebt,
    required double grossMonthlyIncome,
  }) {
    if (grossMonthlyIncome <= 0) return 100.0; // Infinite DTI basically
    return (totalMonthlyDebt / grossMonthlyIncome) * 100;
  }

  /// Calculate Amortization Schedule
  static List<Map<String, dynamic>> calculateAmortizationSchedule({
    required double principal,
    required double annualInterestRate,
    required int months,
    double extraMonthly = 0,
  }) {
    List<Map<String, dynamic>> schedule = [];
    double balance = principal;
    double monthlyRate = annualInterestRate / 12 / 100;
    double emi = calculateEMI(
      principal: principal,
      annualInterestRate: annualInterestRate,
      months: months,
    );

    for (int i = 1; i <= months; i++) {
      if (balance <= 0) break;

      double interestPayment = balance * monthlyRate;
      double principalPayment = emi - interestPayment;

      // Apply extra payment to principal
      double totalPrincipalPaid = principalPayment + extraMonthly;

      if (totalPrincipalPaid > balance) {
        totalPrincipalPaid = balance;
      }

      balance -= totalPrincipalPaid;

      schedule.add({
        'month': i,
        'interest': interestPayment,
        'principal': principalPayment,
        'extra': extraMonthly,
        'balance': balance,
      });
    }
    return schedule;
  }
}
