import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../widgets/gradient_app_bar.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/affordability_model.dart';
import '../providers/affordability_provider.dart';
import '../core/constants/theme_extensions.dart';
import '../widgets/ad_fallback_widget.dart';
import 'calculation_details_screen.dart';
import 'edit_calculation_screen.dart';
import 'insurance_marketplace.dart';
import 'settings_screen.dart';
import 'home_dashboard.dart';
import 'more_tools_screen.dart';

class SavedCalculationsScreen extends StatefulWidget {
  const SavedCalculationsScreen({super.key});

  @override
  State<SavedCalculationsScreen> createState() =>
      _SavedCalculationsScreenState();
}

class _SavedCalculationsScreenState extends State<SavedCalculationsScreen> {
  // ── Design tokens ──────────────────────────────────────────────────────────
  Color get primary => context.cs.primary;
  Color get primaryContainer => context.cs.primary;
  Color get onSurface => context.textPrimary;
  Color get onSurfaceVariant => context.textSecondary;
  Color get outline => context.borderColor;
  Color get outlineVariant => context.borderColor;
  Color get errorColor => context.isDark ? Colors.red.shade300 : const Color(0xFFBA1A1A);
  Color get tertiary => const Color(0xFF004E47);
  Color get secondaryContainer => context.isDarkMode ? context.cs.primary.withValues(alpha: 0.2) : const Color(0xFFD5E3FC);
  Color get onSecondaryContainer => context.isDarkMode ? Colors.white70 : const Color(0xFF57657A);
  Color get surfaceContainerLowest => context.cardColor;
  Color get surfaceContainerLow => context.inputFill;
  Color get surfaceContainerHigh => context.borderColor;
  Color get background => context.pageBackground;

  // ── State ──────────────────────────────────────────────────────────────────
  String _searchQuery = '';
  String _selectedFilter = 'All';
  int _currentIndex = 2;

  final List<String> _filters = [
    'All',
    'This Week',
    'This Month',
    'Last 3 Months',
    'Year to Date',
  ];

  @override
  void initState() {
    super.initState();
    // Ensure data is loaded when entering this screen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<AffordabilityProvider>().loadSavedCalculations();
      }
    });
  }

  NumberFormat get _currency => context.currencyFormat(decimalDigits: 0);

  // ── Filter logic ───────────────────────────────────────────────────────────
  List<SavedAffordabilityCalculation> _applyFilters(
    List<SavedAffordabilityCalculation> all,
  ) {
    final now = DateTime.now();
    DateTime cutoff;
    switch (_selectedFilter) {
      case 'This Week':
        cutoff = now.subtract(const Duration(days: 7));
        break;
      case 'This Month':
        cutoff = DateTime(now.year, now.month, 1);
        break;
      case 'Last 3 Months':
        cutoff = DateTime(now.year, now.month - 3, now.day);
        break;
      case 'Year to Date':
        cutoff = DateTime(now.year, 1, 1);
        break;
      default:
        cutoff = DateTime(1970); // All
    }

    var filtered = all.where((c) => c.date.isAfter(cutoff)).toList();

    if (_searchQuery.isNotEmpty) {
      filtered = filtered
          .where(
            (c) => c.name.toLowerCase().contains(_searchQuery.toLowerCase()),
          )
          .toList();
    }

    return filtered;
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  /// Primary value label shown on the card (left stat).
  _CardStat _primaryStat(SavedAffordabilityCalculation calc) {
    switch (calc.calculatorType) {
      case CalculatorType.piti:
        final hp =
            (calc.metadata['homePrice'] as num?)?.toDouble() ??
            calc.input.annualIncome;
        return _CardStat('Home Price', _currency.format(hp));
      case CalculatorType.mortgage:
        final hp =
            (calc.metadata['homePrice'] as num?)?.toDouble() ??
            calc.input.annualIncome;
        return _CardStat('Home Price', _currency.format(hp));
      case CalculatorType.autoLoan:
        final vp =
            (calc.metadata['vehiclePrice'] as num?)?.toDouble() ??
            calc.input.annualIncome;
        return _CardStat('Vehicle Price', _currency.format(vp));
      case CalculatorType.affordability:
        return _CardStat(
          'Est. Budget',
          _currency.format(calc.result.maxHomePrice),
          isPrimary: true,
        );
    }
  }

  /// Secondary value shown on the card (right stat).
  _CardStat _secondaryStat(SavedAffordabilityCalculation calc) {
    switch (calc.calculatorType) {
      case CalculatorType.piti:
        return _CardStat(
          'Monthly PITI',
          '${_currency.format(calc.result.totalMonthlyPayment)}/mo',
        );
      case CalculatorType.mortgage:
      case CalculatorType.autoLoan:
      case CalculatorType.affordability:
        return _CardStat(
          'Monthly Payment',
          '${_currency.format(calc.result.totalMonthlyPayment)}/mo',
        );
    }
  }

  /// Color-coded type badge.
  _TypeBadge _typeBadge(CalculatorType type) {
    final isDark = context.isDarkMode;
    switch (type) {
      case CalculatorType.piti:
        return _TypeBadge(
          type.displayName,
          isDark ? const Color(0xFF90CAF9) : const Color(0xFF0D47A1),
          isDark ? const Color(0xFF0D47A1).withValues(alpha: 0.25) : const Color(0xFFE3F2FD),
        );
      case CalculatorType.mortgage:
        return _TypeBadge(
          type.displayName,
          isDark ? const Color(0xFF81C784) : const Color(0xFF1B5E20),
          isDark ? const Color(0xFF1B5E20).withValues(alpha: 0.25) : const Color(0xFFE8F5E9),
        );
      case CalculatorType.autoLoan:
        return _TypeBadge(
          type.displayName,
          isDark ? const Color(0xFFFFB74D) : const Color(0xFFE65100),
          isDark ? const Color(0xFFE65100).withValues(alpha: 0.25) : const Color(0xFFFFF3E0),
        );
      case CalculatorType.affordability:
        return _TypeBadge(
          type.displayName,
          isDark ? const Color(0xFFCE93D8) : const Color(0xFF4A148C),
          isDark ? const Color(0xFF4A148C).withValues(alpha: 0.25) : const Color(0xFFF3E5F5),
        );
    }
  }

  // ── Delete all confirm ─────────────────────────────────────────────────────
  void _confirmDeleteAll(AffordabilityProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Delete All Calculations?',
          style: TextStyle(fontFamily: 'Manrope', fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'This will permanently delete all saved calculations and cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              provider.clearAllSavedCalculations();
            },
            style: TextButton.styleFrom(foregroundColor: errorColor),
            child: const Text(
              'Delete All',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AffordabilityProvider>(
      builder: (context, provider, _) {
        final filtered = _applyFilters(provider.savedCalculations);

        return Scaffold(
          extendBody: true,
          backgroundColor: background,
          appBar: _buildAppBar(context, provider),
          bottomNavigationBar: _buildBottomNav(context),
          body: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  16,
                  24,
                  16,
                  kBottomNavigationBarHeight + 80,
                ),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _buildSearchBar(),
                    const SizedBox(height: 24),
                    _buildFilterChips(),
                    const SizedBox(height: 24),
                    if (filtered.isEmpty)
                      _buildEmptyState()
                    else
                      ...filtered.map(
                        (calc) => Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: _buildCalcCard(context, calc, provider),
                        ),
                      ),
                    _buildAdSpace(),
                  ]),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context, AffordabilityProvider provider) {
    return GradientAppBar(
      titleSpacing: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const HomeDashboard()),
            (r) => false,
          );
        },
      ),
      title: const Text(
        'Saved Calculations',
        style: TextStyle(
          fontFamily: 'Manrope',
          fontWeight: FontWeight.w600,
          fontSize: 20,
          color: Colors.white,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => _confirmDeleteAll(provider),
          child: Text(
            'Delete All',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.red.shade200,
            ),
          ),
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(
          height: 1,
          color: outlineVariant.withValues(alpha: 0.2),
        ),
      ),
    );
  }

  // ── Search bar ─────────────────────────────────────────────────────────────
  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: context.isDark ? context.inputFill : surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.borderColor),
      ),
      child: TextField(
        onChanged: (v) => setState(() => _searchQuery = v),
        style: TextStyle(color: onSurface),
        decoration: InputDecoration(
          hintText: 'Search saved calculations...',
          hintStyle: TextStyle(color: outline, fontSize: 14),
          prefixIcon: Icon(Icons.search_rounded, color: outline),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }

  // ── Filter chips ───────────────────────────────────────────────────────────
  Widget _buildFilterChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _filters
            .map(
              (f) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => setState(() => _selectedFilter = f),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: _selectedFilter == f
                          ? primary
                          : (context.isDark ? context.inputFill : context.borderColor.withValues(alpha: 0.5)),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _selectedFilter == f ? Colors.transparent : context.borderColor),
                      boxShadow: _selectedFilter == f
                          ? [
                              BoxShadow(
                                color: primary.withValues(alpha: 0.2),
                                blurRadius: 8,
                              ),
                            ]
                          : null,
                    ),
                    child: Text(
                      f,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: _selectedFilter == f
                            ? FontWeight.w600
                            : FontWeight.w500,
                        color: _selectedFilter == f
                            ? Colors.white
                            : context.textSecondary,
                      ),
                    ),
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  // ── Calculation card ───────────────────────────────────────────────────────
  Widget _buildCalcCard(
    BuildContext context,
    SavedAffordabilityCalculation calc,
    AffordabilityProvider provider,
  ) {
    final dateStr = DateFormat('MMM dd, yyyy').format(calc.date);
    final apr = calc.input.interestRate.toStringAsFixed(1);
    final term = calc.input.loanTerm;
    final primary_ = _primaryStat(calc);
    final secondary_ = _secondaryStat(calc);
    final badge = _typeBadge(calc.calculatorType);

    return Container(
      decoration: BoxDecoration(
        color: surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: outlineVariant.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: onSurface.withValues(alpha: 0.04),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        dateStr.toUpperCase(),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
                          color: outline,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        calc.name,
                        style: TextStyle(
                          fontFamily: 'Manrope',
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
                // Type badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: badge.bg,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    badge.label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: badge.fg,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  onPressed: () => _showDeleteDialog(calc, provider),
                  icon: Icon(
                    Icons.delete_outline_rounded,
                    color: (context.isDark ? Colors.red.shade300 : errorColor).withValues(alpha: 0.6),
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Stats row
            Row(
              children: [
                _buildStat(
                  primary_.label,
                  primary_.value,
                  isPrimary: primary_.isPrimary,
                ),
                const SizedBox(width: 32),
                _buildStat(secondary_.label, secondary_.value),
              ],
            ),
            const SizedBox(height: 16),
            // Tags row
            Row(
              children: [
                _buildTag(
                  '$apr% ${calc.calculatorType == CalculatorType.autoLoan ? "APR" : "Rate"}',
                  tertiary.withValues(alpha: 0.1),
                  tertiary,
                ),
                const SizedBox(width: 8),
                _buildTag(
                  calc.calculatorType == CalculatorType.autoLoan
                      ? '${(calc.metadata['termMonths'] as int?) ?? calc.input.loanTerm * 12} mo'
                      : '$term Yr Fixed',
                  secondaryContainer,
                  onSecondaryContainer,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            EditCalculationScreen(calculation: calc),
                      ),
                    ),
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    label: const Text(
                      'Edit',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: primary,
                      side: BorderSide(color: primary.withValues(alpha: 0.4)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            CalculationDetailsScreen(calculation: calc),
                      ),
                    ),
                    icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                    label: const Text(
                      'View Details',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
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

  void _showDeleteDialog(
    SavedAffordabilityCalculation calc,
    AffordabilityProvider provider,
  ) {
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
            },
            style: TextButton.styleFrom(foregroundColor: errorColor),
            child: const Text(
              'Delete',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStat(String label, String value, {bool isPrimary = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 13, color: onSurfaceVariant),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontFamily: 'Manrope',
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: isPrimary ? primary : onSurface,
          ),
        ),
      ],
    );
  }

  Widget _buildTag(String label, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: fg),
      ),
    );
  }

  // ── Empty state ────────────────────────────────────────────────────────────
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 80),
        child: Column(
          children: [
            Icon(
              Icons.bookmark_border_rounded,
              size: 64,
              color: outline.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isNotEmpty
                  ? 'No results found'
                  : 'No saved calculations',
              style: TextStyle(
                fontFamily: 'Manrope',
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Save a calculation from any calculator\nto see it here.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: outline),
            ),
          ],
        ),
      ),
    );
  }

  // ── Ad space ───────────────────────────────────────────────────────────────
  Widget _buildAdSpace() {
    return const AdFallbackWidget(
      keywords: ['mortgage', 'home loan', 'real estate', 'refinance'],
      contentUrl: 'https://www.consumerfinance.gov/owning-a-home/',
      margin: EdgeInsets.only(top: 24),
    );
  }

  // ── Bottom nav ─────────────────────────────────────────────────────────────
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
              currentIndex: _currentIndex,
              onTap: (index) {
                setState(() => _currentIndex = index);
                if (index == 0) {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const HomeDashboard()),
                    (r) => false,
                  );
                } else if (index == 1) {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const MoreToolsScreen()),
                  );
                } else if (index == 3) {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const InsuranceMarketplaceScreen(),
                    ),
                  );
                } else if (index == 4) {
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
                  icon: Text('🛠️', style: TextStyle(fontSize: 22)),
                  activeIcon: Text('🛠️', style: TextStyle(fontSize: 26)),
                  
                  
                  
                  
                  
                  
                  
                  label: 'Tools',
                ),
                BottomNavigationBarItem(
                  icon: Text('💾', style: TextStyle(fontSize: 22)),
                  activeIcon: Text('💾', style: TextStyle(fontSize: 26)),
                  
                  
                  
                  
                  
                  
                  
                  label: 'Saved',
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
        ),
      ),
    );
  }
}

// ── Small data classes ─────────────────────────────────────────────────────

class _CardStat {
  final String label;
  final String value;
  final bool isPrimary;
  const _CardStat(this.label, this.value, {this.isPrimary = false});
}

class _TypeBadge {
  final String label;
  final Color fg;
  final Color bg;
  const _TypeBadge(this.label, this.fg, this.bg);
}
