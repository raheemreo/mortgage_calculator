import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'package:cached_network_image/cached_network_image.dart';
import '../widgets/ad_native_widget.dart';
import '../core/constants/theme_extensions.dart';

class InsuranceProvider {
 final String name;
 final String logo;
 final String website;
 final String category;
 final String description;
 final String rating;
  final int founded;
 final String headquarters;

  InsuranceProvider({
    required this.name,
    required this.logo,
    required this.website,
    required this.category,
    required this.description,
    required this.rating,
    required this.founded,
    required this.headquarters,
  });

  factory InsuranceProvider.fromJson(Map<String, dynamic> json) {
    return InsuranceProvider(
      name: json['name']?.toString() ?? '',
      logo: json['logo']?.toString() ?? '',
      website: json['website']?.toString() ?? '',
      category: json['category']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      rating: json['rating']?.toString() ?? '',
      founded: (json['founded'] as num?)?.toInt() ?? 0,
      headquarters: json['headquarters']?.toString() ?? '',
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AD PLACEMENT STRATEGY
// ─────────────────────────────────────────────────────────────────────────────
// • REMOVED the bottom anchored BannerAd entirely.
//   Reason: Running a sticky bottom banner alongside inline native ads
//   simultaneously risks violating Google AdMob policy ("ads must not be
//   placed where they are likely to be accidentally clicked" / "no more than
//   one ad per screen visible at a time for banner formats").
//
// • KEPT only inline Native Ads inserted between provider cards.
//   - First native ad appears after index 5 (after ~5 cards, roughly one
//     full scroll past the fold on most phones).
//   - Subsequent native ads appear every 8 content items, giving users
//     enough content between ads and staying within AdMob density guidelines.
//   - Native ads match the card visual style → feel less intrusive.
//
// • List bottom padding is a clean 24 dp — no need to compensate for a
//   sticky banner anymore.
// ─────────────────────────────────────────────────────────────────────────────

/// How many provider cards appear before the FIRST native ad.
const int _kFirstAdAfter = 5;

/// How many provider cards appear between subsequent native ads.
const int _kAdInterval = 8;

class InsuranceMarketplaceScreen extends StatefulWidget {
  const InsuranceMarketplaceScreen({super.key});

  @override
  State<InsuranceMarketplaceScreen> createState() =>
      _InsuranceMarketplaceScreenState();
}

class _InsuranceMarketplaceScreenState
    extends State<InsuranceMarketplaceScreen> {
  late Future<List<InsuranceProvider>> _providersFuture;

  @override
  void initState() {
    super.initState();
    _providersFuture = _fetchInsuranceProviders();
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

  // ── List index helpers ──────────────────────────────────────────────────────

  /// Returns true if the given list [index] should show a native ad.
  ///
  /// Layout pattern (0-based):
  ///   0..(_kFirstAdAfter-1)  → provider cards  (5 cards)
  ///   _kFirstAdAfter         → native ad        (index 5)
  ///   next _kAdInterval      → provider cards  (8 cards)
  ///   next index             → native ad
  ///   …and so on
  bool _isAdIndex(int index) {
    if (index < _kFirstAdAfter) return false;
    final offsetIndex = index - _kFirstAdAfter;
    // Slot pattern: [ad, 8 cards, ad, 8 cards, …]
    // Period = 1 (ad) + _kAdInterval (cards) = _kAdInterval + 1
    return offsetIndex % (_kAdInterval + 1) == 0;
  }

  /// Maps a list [index] (which may contain ad slots) to the actual provider
  /// index in the [providers] array.
  int _providerIndexFor(int listIndex) {
    if (listIndex < _kFirstAdAfter) return listIndex;

    int adsBeforeThis = 0;
    for (int i = _kFirstAdAfter; i < listIndex; i++) {
      if (_isAdIndex(i)) adsBeforeThis++;
    }
    return listIndex - adsBeforeThis;
  }

  /// Total item count for [n] providers, inserting ad slots as needed.
  int _totalItemCount(int n) {
    if (n == 0) return 0;

    int total = 0;
    int providersPlaced = 0;

    while (providersPlaced < n) {
      if (_isAdIndex(total)) {
        total++; // ad slot — doesn't consume a provider
      } else {
        total++;
        providersPlaced++;
      }
    }
    return total;
  }

  // ── Network ─────────────────────────────────────────────────────────────────

  Future<List<InsuranceProvider>> _fetchInsuranceProviders() async {
    const url =
        'https://raw.githubusercontent.com/raheemreo/Mortgage-Calculator-pro/main/insurance_companies.json';
    try {
      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is List) {
          return data.map((json) => InsuranceProvider.fromJson(json)).toList();
        }
      }
    } catch (e) {
      debugPrint('Error fetching insurance companies: $e');
    }
    return [];
  }

  Future<void> _launchUrl(String url) async {
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
                backgroundColor: const Color(0xFF0B3D91),
                foregroundColor: context.cs.surface,
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
 Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
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
    const Color primaryBlue = Color(0xFF0B3D91);
    const Color backgroundLight = Color(0xFFF8F9FC);
    final textStyle = GoogleFonts.inter();

    return Scaffold(
      backgroundColor: backgroundLight,
      appBar: AppBar(
        backgroundColor: context.cs.surface,
        elevation: 0,
        surfaceTintColor: context.cs.surface,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF334155)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Insurance Providers',
          style: textStyle.copyWith(
            color: context.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: false,
        titleSpacing: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: context.borderColor, height: 1),
        ),
      ),
      // No sticky bottom ad — body fills to the system safe area cleanly.
      body: FutureBuilder<List<InsuranceProvider>>(
        future: _providersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error loading providers: ${snapshot.error}',
                style: textStyle,
              ),
            );
          }

          final providers = snapshot.data ?? [];
          if (providers.isEmpty) {
            return Center(
              child: Text('No insurance providers found.', style: textStyle),
            );
          }

          final itemCount = _totalItemCount(providers.length);

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            itemCount: itemCount,
            itemBuilder: (context, index) {
              // ── Ad slot ──────────────────────────────────────────────────
              if (_isAdIndex(index)) {
                // Native ad widget styled to blend with the card list.
                // AdNativeWidget should render a medium or small native ad
                // template; it must NOT be a banner — banners inside a scroll
                // view violate AdMob policy.
                return const Padding(
                  padding: EdgeInsets.only(bottom: 16),
                  child: AdNativeWidget(),
                );
              }

              // ── Provider card ────────────────────────────────────────────
              final providerIndex = _providerIndexFor(index);
              if (providerIndex >= providers.length) {
                return const SizedBox.shrink();
              }

              return _buildProviderCard(
                providers[providerIndex],
                primaryBlue,
                textStyle,
              );
            },
          );
        },
      ),
    );
  }

  // ── Provider card widget ─────────────────────────────────────────────────────

  Widget _buildProviderCard(
    InsuranceProvider provider,
    Color primaryColor,
    TextStyle textStyle,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: context.cs.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFF1F5F9)),
                    boxShadow: [
                      BoxShadow(
                        color: context.textPrimary.withValues(alpha: 0.03),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(8),
                  child: CachedNetworkImage(
                    imageUrl: provider.logo,
                    fit: BoxFit.contain,
                    placeholder: (context, url) =>
                        const Icon(Icons.business, color: Color(0xFFCBD5E1)),
                    errorWidget: (context, url, error) =>
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
                          Expanded(
                            child: Text(
                              provider.name,
                              style: textStyle.copyWith(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF0F172A),
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
                              color: const Color(0xFFFFFBEB),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: const Color(0xFFFEF3C7),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.verified_user_rounded,
                                  size: 14,
                                  color: Color(0xFFF59E0B),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  provider.rating.split(' ')[0],
                                  style: textStyle.copyWith(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF92400E),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          provider.category,
                          style: textStyle.copyWith(
                            color: const Color(0xFF475569),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  provider.description,
                  style: textStyle.copyWith(
                    fontSize: 13,
                    color: context.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildMetaInfo(
                        Icons.history_rounded,
                        'Founded ${provider.founded}',
                        textStyle,
                      ),
                    ),
                    Expanded(
                      child: _buildMetaInfo(
                        Icons.location_on_outlined,
                        provider.headquarters,
                        textStyle,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _launchUrl(provider.website),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: context.cs.surface,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Apply Now',
                          style: textStyle.copyWith(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.arrow_forward_rounded, size: 18),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: context.borderColor),
                  ),
                  child: IconButton(
                    onPressed: () => _launchUrl(provider.website),
                    icon: Icon(
                      Icons.open_in_new_rounded,
                      size: 20,
                      color: context.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetaInfo(IconData icon, String text, TextStyle textStyle) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: const Color(0xFF94A3B8)),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            text,
            style: textStyle.copyWith(
              color: context.textSecondary,
              fontSize: 12,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}