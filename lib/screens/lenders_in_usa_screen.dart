import 'dart:io';
import '../widgets/gradient_app_bar.dart';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';

import 'settings_screen.dart';
import 'insurance_marketplace.dart';
import '../widgets/ad_native_widget.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AD PLACEMENT STRATEGY — what changed and why
// ─────────────────────────────────────────────────────────────────────────────
//
// REMOVED → AdBannerWidget stacked above the BottomNavigationBar
//   • The original code placed a BannerAd inside bottomNavigationBar via a
//     Column([_buildAdBanner(), _buildBottomNav()]). This is a direct AdMob
//     policy violation: anchored banners must NOT be placed directly above or
//     below a navigation bar — they must be anchored to the absolute top or
//     bottom edge of the screen with no other persistent UI element adjacent.
//   • Additionally, the double-stacked bar (ad + nav) consumes ~110–150 dp of
//     vertical space, severely shrinking the content area on small phones.
//   • AdBannerWidget import removed;
import '../core/constants/theme_extensions.dart';
// ad_banner_widget.dart no longer needed
//     on this screen.
//
// REMOVED → isFirstLaunch guard on inline native ads
//   • AdService().isFirstLaunch returning SizedBox.shrink() for native ads
//     means the item count calculation is still wrong on first launch (slots
//     are counted but render nothing, misaligning lender indices).
//   • Correct approach: always compute the list without ad slots on first
//     launch, OR always include them and let the widget collapse on failure.
//     We now use the latter: NativeAdWidget already collapses on load failure,
//     so no special guard is needed here — AdService().isFirstLaunch is
//     removed from the itemBuilder entirely.
//
// FIXED → Ad frequency: every 3 items → every 5 items
//   • Original inserted an ad every 4th index slot (effectively every 3
//     content items). On a typical phone showing ~2 cards per screen that
//     means an ad appears every 1.5 screens — far too dense and risks AdMob
//     policy enforcement for "excessive ad density."
//   • New rule: first ad after 5 content items, then every 5 content items
//     (_kFirstAdAfter = 5, _kAdInterval = 5). That gives roughly one ad per
//     2–3 screens of content.
//
// FIXED → Index math
//   • Original: lenderIndex = index - (index ~/ 4) — this drifts when ad
//     slots are skipped (e.g. isFirstLaunch) and can map two list indices to
//     the same lender or skip a lender entirely.
//   • Replaced with the same reliable loop-based helpers used in the other
//     two screens (_isAdIndex, _lenderIndexFor, _totalItemCount).
//
// KEPT → BottomNavigationBar (no ad inside it)
//   • The nav bar is now the sole occupant of bottomNavigationBar, wrapped
//     in a SafeArea so it respects system gesture insets correctly.
// ─────────────────────────────────────────────────────────────────────────────

/// Content cards shown before the FIRST native ad.
const int _kFirstAdAfter = 5;

/// Content cards shown between subsequent native ad slots.
const int _kAdInterval = 5;

class LoanCompany {
  final int id;
 final String name;
 final String logo;
  final List<String> loanTypes;
 final String headquarters;
  final double rating;
 final String website;

  LoanCompany({
    required this.id,
    required this.name,
    required this.logo,
    required this.loanTypes,
    required this.headquarters,
    required this.rating,
    required this.website,
  });

  factory LoanCompany.fromJson(Map<String, dynamic> json) {
    return LoanCompany(
      id: json['id'] as int? ?? 0,
      name: json['name']?.toString() ?? '',
      logo: json['logo']?.toString() ?? '',
      loanTypes:
          (json['loan_types'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      headquarters: json['headquarters']?.toString() ?? '',
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      website: json['website']?.toString() ?? '',
    );
  }
}

class LendersInUsaScreen extends StatefulWidget {
  const LendersInUsaScreen({super.key});

  @override
  State<LendersInUsaScreen> createState() => _LendersInUsaScreenState();
}

class _LendersInUsaScreenState extends State<LendersInUsaScreen> {
  static const Color _primaryBlue = Color(0xFF0B3D93);
  late Future<List<LoanCompany>> _lendersFuture;

  @override
  void initState() {
    super.initState();
    _lendersFuture = _fetchLoanCompanies();
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
    super.dispose();
  }

  // ── Ad-index helpers ────────────────────────────────────────────────────────

  /// Returns true when [index] in the mixed list should render a native ad.
  bool _isAdIndex(int index) {
    if (index < _kFirstAdAfter) return false;
    final offset = index - _kFirstAdAfter;
    return offset % (_kAdInterval + 1) == 0;
  }

  /// Maps a mixed-list [index] to the actual index in the lenders array.
  int _lenderIndexFor(int listIndex) {
    if (listIndex < _kFirstAdAfter) return listIndex;
    int ads = 0;
    for (int i = _kFirstAdAfter; i < listIndex; i++) {
      if (_isAdIndex(i)) ads++;
    }
    return listIndex - ads;
  }

  /// Total mixed-list item count for [n] lender cards.
  int _totalItemCount(int n) {
    if (n == 0) return 0;
    int total = 0;
    int placed = 0;
    while (placed < n) {
      if (_isAdIndex(total)) {
        total++;
      } else {
        total++;
        placed++;
      }
    }
    // +1 for the disclaimer item at the end.
    return total + 1;
  }

  // ── Network ─────────────────────────────────────────────────────────────────

  Future<List<LoanCompany>> _fetchLoanCompanies() async {
    const url =
        'https://raw.githubusercontent.com/raheemreo/Mortgage-Calculator-pro/main/loan_companies.json';
    try {
      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data.containsKey('loan_companies')) {
          return (data['loan_companies'] as List)
              .map((json) => LoanCompany.fromJson(json))
              .toList();
        }
      }
    } catch (e) {
      debugPrint('Error fetching lenders: $e');
    }
    return [];
  }

  void _launchWebsite(String url) async {
    final bool? shouldContinue = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'Leaving App',
            style: GoogleFonts.inter(fontWeight: FontWeight.bold),
          ),
          content: Text(
            'You are leaving the app and will be redirected to an external website. Do you want to continue?',
            style: GoogleFonts.inter(height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                'Cancel',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                  color: context.textSecondary,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryBlue,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                'Continue',
                style: GoogleFonts.inter(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );

    if (shouldContinue != true) return;

    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not launch $url')));
      }
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.pageBackground,
      appBar: _buildAppBar(context),
      // bottomNavigationBar now contains ONLY the nav bar — no ad stacked
      // on top. SafeArea ensures the bar respects system gesture insets.
      bottomNavigationBar: SafeArea(child: _buildBottomNav(context)),
      body: CustomScrollView(
        slivers: [
          // ── Header ──────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [_buildHeader(), const SizedBox(height: 16)],
              ),
            ),
          ),

          // ── Lender list with inline native ads ──────────────────────────
          SliverFillRemaining(
            child: FutureBuilder<List<LoanCompany>>(
              future: _lendersFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                } else if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Error loading lenders: ${snapshot.error}',
                      style: GoogleFonts.inter(),
                    ),
                  );
                }

                final allLenders = snapshot.data ?? [];

                if (allLenders.isEmpty) {
                  return Center(
                    child: Text(
                      'No lenders found.',
                      style: GoogleFonts.inter(),
                    ),
                  );
                }

                final totalCount = _totalItemCount(allLenders.length);

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  itemCount: totalCount,
                  itemBuilder: (context, index) {
                    if (index == totalCount - 1) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 8, bottom: 8),
                        child: _buildDisclaimer(),
                      );
                    }
                    if (_isAdIndex(index)) {
                      return const Padding(
                        padding: EdgeInsets.only(bottom: 16),
                        child: AdNativeWidget(),
                      );
                    }
                    final lenderIndex = _lenderIndexFor(index);
                    if (lenderIndex >= allLenders.length) {
                      return const SizedBox.shrink();
                    }
                    return _buildLenderCard(allLenders[lenderIndex]);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ── App bar ──────────────────────────────────────────────────────────────────

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return GradientAppBar(
      backgroundColor: context.cs.surface,
      surfaceTintColor: context.cs.surface,
      elevation: 0,
      centerTitle: false,
      titleSpacing: 0,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: context.borderColor),
      ),
      leading: IconButton(
        icon: Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      title: Row(
        children: [
          const Icon(Icons.account_balance, color: Colors.white),
          const SizedBox(width: 8),
          Text(
            'USA Mortgage Pro',
            style: GoogleFonts.inter(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 18,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: Icon(Icons.notifications_none, color: Colors.white),
          onPressed: () {},
        ),
      ],
    );
  }

  // ── Header ───────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Text(
      'Compare the best rates and terms for 2026',
      style: GoogleFonts.inter(color: context.textSecondary, fontSize: 14),
    );
  }

  // ── Lender card ──────────────────────────────────────────────────────────────

  Widget _buildLenderCard(LoanCompany lender) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.borderColor),
        boxShadow: [
          BoxShadow(
            color: context.textPrimary.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 64,
                height: 64,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: context.cs.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: context.borderColor),
                  boxShadow: [
                    BoxShadow(
                      color: context.textPrimary.withValues(alpha: 0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: CachedNetworkImage(
                  imageUrl: lender.logo,
                  fit: BoxFit.contain,
                  placeholder: (context, url) =>
                      const Icon(Icons.business, color: Color(0xFFCBD5E1)),
                  errorWidget: (context, url, err) =>
                      const Icon(Icons.business, color: Color(0xFFCBD5E1)),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            lender.name,
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: context.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: context.isDark ? const Color(0xFFF59E0B).withValues(alpha: 0.15) : const Color(0xFFFFFBEB),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: context.isDark ? const Color(0xFFF59E0B).withValues(alpha: 0.3) : const Color(0xFFFEF3C7)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.star_rounded,
                                color: Color(0xFFF59E0B),
                                size: 14,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                lender.rating.toStringAsFixed(1),
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: context.isDark ? const Color(0xFFF59E0B) : const Color(0xFF92400E),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          size: 14,
                          color: context.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          lender.headquarters,
                          style: GoogleFonts.inter(
                            color: context.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: lender.loanTypes.map<Widget>((type) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: context.isDark ? context.borderColor : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: context.borderColor),
                          ),
                          child: Text(
                            type,
                            style: GoogleFonts.inter(
                              color: context.textSecondary,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.isDark ? context.inputFill : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: context.borderColor),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Est. APR',
                      style: GoogleFonts.inter(
                        color: context.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'See Website for Details',
                      style: GoogleFonts.inter(
                        color: context.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                Icon(
                  Icons.percent_rounded,
                  color: context.primaryColor.withValues(alpha: 0.2),
                  size: 28,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              if (lender.website.isNotEmpty) _launchWebsite(lender.website);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryBlue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Apply Now',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.arrow_forward_rounded, size: 18),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Disclaimer ───────────────────────────────────────────────────────────────

  Widget _buildDisclaimer() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _primaryBlue.withAlpha(13),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _primaryBlue.withAlpha(25)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.info, color: Color(0xFF2563EB), size: 16),
              const SizedBox(width: 6),
              Text(
                'IMPORTANT DISCLAIMER',
                style: GoogleFonts.inter(
                  color: context.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'This app is not a lender. We provide information about mortgage lenders and redirect users to their official websites for applications.',
            style: GoogleFonts.inter(
              color: context.textSecondary,
              fontSize: 12,
              fontStyle: FontStyle.italic,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ── Bottom nav — no ad here ──────────────────────────────────────────────────

  Widget _buildBottomNav(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.cs.surface,
        border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
      ),
      child: BottomNavigationBar(
        currentIndex: 1,
        onTap: (index) {
          if (index == 0) {
            Navigator.of(context).popUntil((route) => route.isFirst);
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
        selectedItemColor: _primaryBlue,
        unselectedItemColor: const Color(0xFF94A3B8),
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
            icon: Text('🏦', style: TextStyle(fontSize: 22)),
            activeIcon: Text('🏦', style: TextStyle(fontSize: 26)),
            
            
            
            
            
            
            
            label: 'Lenders',
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