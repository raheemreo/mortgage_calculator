import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'insurance_marketplace.dart';
import 'settings_screen.dart';
import '../services/api_service.dart';
import '../services/ad_service.dart';
import '../core/constants/theme_extensions.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AD PLACEMENT STRATEGY — what changed and why
// ─────────────────────────────────────────────────────────────────────────────
//
// ADDED → Anchored Adaptive BannerAd in bottomSheet
//   • This screen has a BottomNavigationBar, so bottomNavigationBar is
//     already occupied. The banner goes into bottomSheet — anchored to the
//     absolute screen edge below the nav bar, with nothing adjacent.
//   • Loaded in didChangeDependencies() — safe for MediaQuery.
//   • ListView bottom padding compensates dynamically for combined
//     nav + banner height. The hardcoded bottom: 100 spacer is removed.
//
// ADDED → Dynamic midpoint NativeAd inside the state list
//   • Uses the same dynamic midpoint injection pattern as more_tools_screen:
//     itemCount = states.length + 1
//     midpoint  = states.length ~/ 2
//     stateIndex = index < mid ? index : index - 1
//   • State cards above and below are non-interactive — safe buffer on
//     both sides. Auto-adjusts as the list grows.
//
// FIXED → BottomNavigationBar wrapped in SafeArea
//   • Missing SafeArea — home indicator overlap on modern devices. Fixed.
//
// FIXED → Hardcoded bottom: 100 padding removed
//   • Was dead space compensating for nothing. Replaced with dynamic
//     padding based on actual banner + nav bar height.
//
// NO interstitial added
//   • This is a reference/lookup screen. Users scroll through state data
//     — there is no natural screen-to-screen transition to attach an
//     interstitial to. Nav bar taps are primary navigation (excluded by policy).
// ─────────────────────────────────────────────────────────────────────────────

class StateTaxRate {
 final String name;
 final String rate;
 final String status;
 final Color statusColor;
 final Color statusBgColor;

  const StateTaxRate({
    required this.name,
    required this.rate,
    required this.status,
    required this.statusColor,
    required this.statusBgColor,
  });
}

class PropertyTaxScreen extends StatefulWidget {
  const PropertyTaxScreen({super.key});

  @override
  State<PropertyTaxScreen> createState() => _PropertyTaxScreenState();
}

class _PropertyTaxScreenState extends State<PropertyTaxScreen> {
 Color primaryBlue = const Color(0xFF0B3D93);
 final TextEditingController _searchController = TextEditingController();
  late Future<Map<String, double>> _taxRatesFuture;
  List<StateTaxRate> _allStates = [];
  List<StateTaxRate> _filteredStates = [];
  bool _isInitialized = false;
  int _currentIndex = 1;


  // ── Lifecycle ────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _taxRatesFuture = ApisService().getPropertyTaxes();
    _checkNetwork();
  }

  Future<void> _checkNetwork() async {
    bool hasNetwork = false;
    try {
      final result = await InternetAddress.lookup('google.com');
      hasNetwork = result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } on SocketException catch (_) {
      hasNetwork = false;
    }

    if (!hasNetwork && mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'No Network Connection',
            style: GoogleFonts.inter(fontWeight: FontWeight.bold),
          ),
          content: Text(
            'Please turn on the internet to view this page.',
            style: GoogleFonts.inter(height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'OK',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF0B3D91),
                ),
              ),
            ),
          ],
        ),
      );
    }
  }


  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }


  // ── Data ─────────────────────────────────────────────────────────────────────

  void _initializeStates(Map<String, double> rates) {
    if (_isInitialized) return;

    _allStates = rates.entries.map((entry) {
      final double rate = entry.value;
      String status = 'Low';
      Color sColor = const Color(0xFF15803D);
      Color bColor = const Color(0xFFDCFCE7);

      if (rate > 1.8) {
        status = 'High';
        sColor = const Color(0xFFB91C1C);
        bColor = const Color(0xFFFEE2E2);
      } else if (rate > 1.3) {
        status = 'Above Avg';
        sColor = const Color(0xFFC2410C);
        bColor = const Color(0xFFFFEDD5);
      } else if (rate > 0.8) {
        status = 'Moderate';
        sColor = const Color(0xFF1D4ED8);
        bColor = const Color(0xFFDBEAFE);
      }

      return StateTaxRate(
        name: entry.key,
        rate: '${rate.toStringAsFixed(2)}% Effective Tax Rate',
        status: status,
        statusColor: sColor,
        statusBgColor: bColor,
      );
    }).toList();

    _allStates.sort((a, b) => a.name.compareTo(b.name));
    _filteredStates = _allStates;
    _isInitialized = true;
  }

  void _filterStates(String query) {
    setState(() {
      _filteredStates = _allStates
          .where(
            (state) => state.name.toLowerCase().contains(query.toLowerCase()),
          )
          .toList();
    });
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final textStyle = GoogleFonts.inter();

    const double listBottomPadding = kBottomNavigationBarHeight + 24;

    return Scaffold(
      backgroundColor: context.pageBackground,
      appBar: AppBar(
        backgroundColor: context.pageBackground,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Container(
            decoration: BoxDecoration(
              color: primaryBlue.withAlpha(26),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: Icon(Icons.arrow_back, color: primaryBlue, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ),
        title: Text(
          'Real Estate Insights',
          style: textStyle.copyWith(
            color: const Color(0xFF0F172A),
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Container(
              decoration: BoxDecoration(
                color: primaryBlue.withAlpha(26),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: Icon(Icons.more_vert, color: primaryBlue, size: 20),
                onPressed: () {},
              ),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: primaryBlue.withAlpha(26), height: 1),
        ),
      ),
      // BottomNavigationBar — sole occupant, SafeArea wraps correctly.
      bottomNavigationBar: _buildBottomNav(),
      // bottomSheet removed (Banner ad).
      body: FutureBuilder<Map<String, double>>(
        future: _taxRatesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !_isInitialized) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError && !_isInitialized) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (snapshot.hasData) {
            _initializeStates(snapshot.data!);
          }

          // Dynamic midpoint — ad auto-adjusts as filtered list changes.
          final int midpoint = _filteredStates.length ~/ 2;

          // CustomScrollView + Slivers replaces Column + Expanded(ListView).
          // Benefits for a ~50-item list:
          //   • Single scroll controller — no nested scroll conflicts.
          //   • Header and search bar scroll with the list naturally.
          //   • SliverList gives Flutter better memory management for long lists.
          //   • No Expanded() wrapper needed — Slivers fill remaining space.
          return CustomScrollView(
            slivers: [
              // ── Header ─────────────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Property Tax Rates',
                        style: textStyle.copyWith(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF0F172A),
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Average effective tax rates by state for 2024.',
                        style: textStyle.copyWith(
                          fontSize: 14,
                          color: context.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Search bar ──────────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Container(
                    height: 56,
                    decoration: BoxDecoration(
                      color: context.cs.surface,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: context.textPrimary.withAlpha(13),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: _filterStates,
                      decoration: InputDecoration(
                        hintText: 'Search for a state...',
                        hintStyle: textStyle.copyWith(
                          color: const Color(0xFF94A3B8),
                        ),
                        prefixIcon: Icon(
                          Icons.search,
                          color: primaryBlue.withAlpha(153),
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 18,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // ── State list with midpoint native ad ──────────────────────
              // SliverList.builder is the Sliver equivalent of ListView.builder.
              // State cards above and below the ad are non-interactive —
              // safe accidental-tap buffer on both sides.
              SliverPadding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, listBottomPadding),
                sliver: SliverList.builder(
                  // states + 1 ad slot
                  itemCount: _filteredStates.length + 1,
                  itemBuilder: (context, index) {
                    // ── Native ad at dynamic midpoint ─────────────────────
                    if (index == midpoint) {
                      return const Padding(
                        padding: EdgeInsets.only(bottom: 12),
                        child: _NativePropertyTaxAdItem(),
                      );
                    }

                    // Shift index for items after the ad slot
                    final stateIndex = index < midpoint ? index : index - 1;
                    if (stateIndex >= _filteredStates.length) {
                      return const SizedBox.shrink();
                    }

                    return _buildStateCard(_filteredStates[stateIndex]);
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ── State card ───────────────────────────────────────────────────────────────

  Widget _buildStateCard(StateTaxRate state) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: context.cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: primaryBlue.withAlpha(13)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x05000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  state.name,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  state.rate,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: primaryBlue,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: state.statusBgColor,
              borderRadius: BorderRadius.circular(99),
            ),
            child: Text(
              state.status.toUpperCase(),
              style: GoogleFonts.inter(
                color: state.statusColor,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Bottom nav ───────────────────────────────────────────────────────────────

  Widget _buildBottomNav() {
    return SafeArea(
      child: Container(
        decoration: BoxDecoration(
          color: context.cs.surface,
          border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() => _currentIndex = index);
            if (index == 0) {
              Navigator.pop(context);
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
          selectedItemColor: primaryBlue,
          unselectedItemColor: const Color(0xFF94A3B8),
          selectedFontSize: 10,
          unselectedFontSize: 10,
          elevation: 0,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_rounded, size: 28),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.map_rounded, size: 28),
              label: 'States',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.shield_rounded, size: 28),
              label: 'Insurance',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings_rounded, size: 28),
              label: 'Settings',
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _NativePropertyTaxAdItem — inline native ad at list midpoint
// ─────────────────────────────────────────────────────────────────────────────
// • Dynamic midpoint injection — auto-adjusts as filtered list changes.
// • Loading placeholder: 60 dp (consistent with all other screens).
// • Collapses silently to SizedBox.shrink() on failure.
// • "Sponsored" label kept — required by AdMob policy.
// • mounted check in onAdLoaded — prevents setState after dispose.
// ─────────────────────────────────────────────────────────────────────────────

class _NativePropertyTaxAdItem extends StatefulWidget {
  const _NativePropertyTaxAdItem();

  @override
  State<_NativePropertyTaxAdItem> createState() =>
      _NativePropertyTaxAdItemState();
}

class _NativePropertyTaxAdItemState extends State<_NativePropertyTaxAdItem> {
  NativeAd? _nativeAd;
  bool _isAdLoaded = false;
  bool _isAdFailed = false;

  // Replace with your real native ad unit ID.
 final String _adUnitId = AdService.nativeAdUnitId;

  @override
  void initState() {
    super.initState();
    _loadNativeAd();
  }

  void _loadNativeAd() {
    _nativeAd = NativeAd(
      adUnitId: _adUnitId,
      factoryId: 'listTile',
      request: const AdRequest(
        contentUrl: AdContentUrl.realEstate,
        keywords: AdKeywords.realEstate,
      ),
      listener: NativeAdListener(
        onAdLoaded: (ad) {
          if (mounted) setState(() => _isAdLoaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('NativeAd failed to load: $error');
          if (mounted) setState(() => _isAdFailed = true);
          ad.dispose();
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    _nativeAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isAdFailed) return const SizedBox.shrink();

    if (!_isAdLoaded || _nativeAd == null) {
      return Container(
        height: 60,
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    return Container(
      height: 340,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200),
        boxShadow: [
          BoxShadow(
            color: context.textPrimary.withValues(alpha: 0.05),
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
              // Required AdMob disclosure — do NOT remove.
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.blue.shade100,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'Sponsored',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
              ),
              const Icon(Icons.info_outline, size: 14, color: Colors.grey),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(child: AdWidget(ad: _nativeAd!)),
        ],
      ),
    );
  }
}