// mortgage_offers_screen.dart
// ─────────────────────────────────────────────────────────────────────────────
// CompareMortgageScreen — fully connected to FredMortgageProvider.
// Features: Live FRED Market Rates, Personalized Offers, Detailed Comparison,
// and Policy-Compliant AdMob Integrations.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import '../widgets/gradient_app_bar.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../providers/fred_mortgage_provider.dart';
import '../services/ad_service.dart';
import '../widgets/ad_native_widget.dart'; // Ensure you have this created
import 'compare_all_offers_screen.dart';
import 'insurance_marketplace.dart';
import 'settings_screen.dart';
import '../core/constants/theme_extensions.dart';

class CompareMortgageScreen extends StatefulWidget {
  const CompareMortgageScreen({super.key});

  @override
  State<CompareMortgageScreen> createState() => _CompareMortgageScreenState();
}

class _CompareMortgageScreenState extends State<CompareMortgageScreen> {
  // ── Palette ────────────────────────────────────────────────────────────────
  static const Color _emerald = Color(0xFF10B981);


  // ── Lifecycle ──────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    AdService().loadInterstitialAd(); // Preload next interstitial via Service
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final p = context.read<FredMortgageProvider>();
      if (p.loadState == FredLoadState.idle) p.fetchFredRates();
    });
  }

  @override
  void dispose() {
    super.dispose();
  }


  void _showInterstitialAndNavigate(Widget screen) {
    // Use AdService to enforce "time limits" (cooldowns)
    AdService().showInterstitialAd(
      onAdClosed: () {
        if (!mounted) return;
        Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
      },
      ignoreThreshold: true, // Navigate on intentional user tap
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.pageBackground,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Page Title
                  Text(
                    'Compare Offers',
                    style: GoogleFonts.manrope(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: context.textPrimary,
                      letterSpacing: -0.5,
                    ),
                  ),
                  Text(
                    'Real-time market data and personalized quotes',
                    style: TextStyle(color: context.textSecondary, fontSize: 14),
                  ),
                  const SizedBox(height: 24),

                  // ── Top Section: FRED Live Data ──
                  _sectionHeader(
                    icon: Icons.trending_up,
                    title: 'FRED Live Market Rates',
                    iconColor: const Color(0xFF004E47),
                    showBadge: true,
                  ),
                  const SizedBox(height: 12),
                  _buildFredRateCards(),
                  const SizedBox(height: 32),

                  // ── Middle Section: Personalized Offers ──
                  _sectionHeader(
                    icon: Icons.verified,
                    title: 'Personalized Offers',
                    iconColor: context.primaryColor,
                  ),
                  const SizedBox(height: 12),
                  _buildCompareAllButton(context),
                  const SizedBox(height: 16),
                  _buildOfferCards(),
                  const SizedBox(height: 24),

                  // ── AdMob Native Ad (Natural Content Break) ──
                  const AdNativeWidget(),
                  const SizedBox(height: 24),

                  // ── Bottom Section: Detailed Comparison ──
                  _sectionHeader(
                    icon: Icons.table_chart_outlined,
                    title: 'Detailed Comparison',
                    iconColor: context.primaryColor,
                  ),
                  const SizedBox(height: 12),
                  _buildComparisonTable(),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(context),
    );
  }

  // ── Helper Widgets ─────────────────────────────────────────────────────────

  PreferredSizeWidget _buildAppBar() => GradientAppBar(
    backgroundColor: context.cs.surface,
    elevation: 1,
    shadowColor: context.textPrimary12,
    leading: const Padding(
      padding: EdgeInsets.only(left: 8.0),
      child: Icon(Icons.account_balance_wallet, color: Colors.white, size: 24),
    ),
    title: Text(
      'Mortgage Pro',
      style: GoogleFonts.manrope(
        color: Colors.white,
        fontWeight: FontWeight.w800,
        fontSize: 20,
        letterSpacing: -0.5,
      ),
    ),
    actions: [
      IconButton(
        icon: const Icon(Icons.notifications_none, color: Colors.white),
        onPressed: () {},
      ),
      const SizedBox(width: 8),
    ],
  );

  Widget _sectionHeader({
    required IconData icon,
    required String title,
    required Color iconColor,
    bool showBadge = false,
  }) => Row(
    children: [
      Icon(icon, color: iconColor, size: 20),
      const SizedBox(width: 8),
      Text(
        title,
        style: GoogleFonts.manrope(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: context.textPrimary,
        ),
      ),
      const Spacer(),
      if (showBadge)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: context.isDark ? context.inputFill : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            'LIVE DATA',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: context.textSecondary,
              letterSpacing: 0.5,
            ),
          ),
        ),
    ],
  );

  Widget _buildFredRateCards() {
    return Consumer<FredMortgageProvider>(
      builder: (context, provider, child) {
        final fd = provider.fredData;
        final loading = provider.loadState == FredLoadState.loading;
        return SizedBox(
          height: 130,
          child: ListView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            clipBehavior: Clip.none,
            children: [
              _fredRateCard(
                label: '30-Y Fixed',
                labelBg: const Color(0xFFD5E3FC),
                labelColor: context.primaryColor,
                rate: loading ? '—' : FredMortgageProvider.fmtPct(fd.rate30Y),
                desc: 'Standard 30-year fixed rate national average.',
              ),
              _fredRateCard(
                label: '15-Y Fixed',
                labelBg: const Color(0xFFD0F2ED),
                labelColor: const Color(0xFF004E47),
                rate: loading ? '—' : FredMortgageProvider.fmtPct(fd.rate15Y),
                desc: 'Faster equity building with lower interest.',
              ),
              _fredRateCard(
                label: '5/1 ARM',
                labelBg: const Color(0xFFFFE4E6),
                labelColor: const Color(0xFFE11D48),
                rate: loading ? '—' : FredMortgageProvider.fmtPct(fd.rateArm51),
                desc: 'Adjustable after 5 years, initial fixed period.',
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _fredRateCard({
    required String label,
    required Color labelBg,
    required Color labelColor,
    required String rate,
    required String desc,
  }) => Container(
    width: 280,
    margin: const EdgeInsets.only(right: 16),
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: context.cs.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: context.borderColor),
      boxShadow: [
        BoxShadow(
          color: context.textPrimary.withValues(alpha: 0.03),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: labelBg,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: labelColor,
                ),
              ),
            ),
            Text(
              'Source: FRED',
              style: TextStyle(fontSize: 10, color: context.textSecondary),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          rate,
          style: GoogleFonts.manrope(
            fontSize: 28,
            fontWeight: FontWeight.w900,
            color: context.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          desc,
          style: TextStyle(fontSize: 12, color: context.textSecondary, height: 1.2),
        ),
      ],
    ),
  );

  Widget _buildCompareAllButton(BuildContext context) => SizedBox(
    width: double.infinity,
    child: ElevatedButton.icon(
      onPressed: () =>
          _showInterstitialAndNavigate(const CompareAllOffersScreen()),
      icon: const Icon(Icons.compare_arrows),
      label: const Text('Compare All Offers'),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF1E4ED8),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 8,
        shadowColor: const Color(0xFF1E4ED8).withValues(alpha: 0.3),
        textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
      ),
    ),
  );

  Widget _buildOfferCards() {
    return Consumer<FredMortgageProvider>(
      builder: (context, provider, child) {
        if (provider.loadState == FredLoadState.loading) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32.0),
              child: CircularProgressIndicator(),
            ),
          );
        }
        final topOffers = provider.topThree;
        return Column(
          children: topOffers
              .map(
                (o) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _lenderCard(o, context),
                ),
              )
              .toList(),
        );
      },
    );
  }

  Widget _lenderCard(LenderOffer o, BuildContext context) {
    final bool isBest = o.name.contains('Rocket');
    return Container(
      decoration: BoxDecoration(
        color: context.cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isBest ? _emerald.withValues(alpha: 0.2) : context.borderColor,
        ),
        boxShadow: [
          BoxShadow(
            color: context.textPrimary.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          if (isBest)
            Positioned(
              right: 0,
              top: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: const BoxDecoration(
                  color: Color(0xFF10B981),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(12),
                  ),
                ),
                child: const Text(
                  'BEST RATE',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: context.isDark ? context.inputFill : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: context.borderColor),
                          ),
                          child: Icon(
                            Icons.rocket_launch,
                            color: isBest ? _emerald : context.textSecondary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              o.name,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: context.textPrimary,
                              ),
                            ),
                            Text(
                              o.loanTerm,
                              style: TextStyle(
                                fontSize: 12,
                                color: context.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          FredMortgageProvider.fmtPct(o.rate),
                          style: GoogleFonts.manrope(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            color: isBest ? _emerald : context.textPrimary,
                          ),
                        ),
                        Text(
                          'INTEREST RATE',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: context.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: context.isDark ? context.inputFill : const Color(0xFFF7F9FB),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _offerStat('APR', FredMortgageProvider.fmtPct(o.apr)),
                      _offerStat(
                        'Monthly',
                        FredMortgageProvider.fmtCurrency(o.monthlyTotal),
                      ),
                      _offerStat('Term', o.loanTerm),
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

  Widget _offerStat(String label, String value) => Column(
    children: [
      Text(label, style: TextStyle(fontSize: 12, color: context.textSecondary)),
      Text(
        value,
        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: context.textPrimary),
      ),
    ],
  );

  Widget _buildComparisonTable() {
    return Consumer<FredMortgageProvider>(
      builder: (context, provider, child) {
        final offers = provider.topThree;
        if (offers.isEmpty) return const SizedBox();

        return Container(
          decoration: BoxDecoration(
            color: context.cs.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: context.borderColor),
            boxShadow: [
              BoxShadow(
                color: context.textPrimary.withValues(alpha: 0.02),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Table(
            children: [
              TableRow(
                decoration: BoxDecoration(color: context.isDark ? context.cardColor : const Color(0xFFF8FAFC)),
                children: ['Lender', 'Rate', 'APR', 'Monthly']
                    .map(
                      (h) => Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          h,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: context.textSecondary,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
              ...offers.map(
                (o) => TableRow(
                  decoration: BoxDecoration(
                    border: Border(top: BorderSide(color: context.borderColor)),
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        o.name.split(' ').first,
                        style: TextStyle(fontWeight: FontWeight.bold, color: context.textPrimary),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        FredMortgageProvider.fmtPct(o.rate),
                        style: const TextStyle(
                          color: _emerald,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        FredMortgageProvider.fmtPct(o.apr),
                        style: TextStyle(color: context.textPrimary),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        FredMortgageProvider.fmtCurrency(o.monthlyTotal),
                        style: TextStyle(fontWeight: FontWeight.bold, color: context.textPrimary),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Bottom Nav ─────────────────────────────────────────────────────────────
  Widget _buildBottomNav(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.cs.surface,
        border: Border(top: BorderSide(color: context.borderColor)),
      ),
      child: BottomNavigationBar(
        currentIndex: 1, // Represents 'Rates' or 'Offers' page
        onTap: (index) {
          if (index == 0) {
            Navigator.popUntil(context, (route) => route.isFirst);
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
        selectedItemColor: context.cs.primary,
        unselectedItemColor: context.textSecondary,
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
            icon: Text('📈', style: TextStyle(fontSize: 22)),
            activeIcon: Text('📈', style: TextStyle(fontSize: 26)),
            
            
            
            
            
            
            
            label: 'Rates',
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
    );
  }
}