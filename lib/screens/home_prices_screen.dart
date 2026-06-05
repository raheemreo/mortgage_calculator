import 'dart:io';
import '../widgets/gradient_app_bar.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../services/ad_service.dart';
import '../services/api_service.dart';
import 'city_insights_screen.dart';
import 'city_comparison_screen.dart';
import '../core/constants/theme_extensions.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AD PLACEMENT STRATEGY
// ─────────────────────────────────────────────────────────────────────────────
// REMOVED  → Bottom anchored BannerAd
//   • Showing a sticky BannerAd while inline NativeAds are also visible
//     violates AdMob policy (two ad formats visible simultaneously).
//   • All related state (_bottomBannerAd, _isBottomBannerAdLoaded,
//     _loadBottomBannerAd, didChangeDependencies) has been deleted.
//   • The hard-coded ad unit ID string is also gone — use a central
//     AdService / constants file instead (easier to swap test ↔ prod).
//
// KEPT & FIXED → Inline NativeAds between city cards
//   • First ad now appears after 5 content items  (_kFirstAdAfter = 5)
//     instead of 4, giving users a full first-screen of content before
//     seeing any ad.
//   • Ad interval increased to every 8 content items (_kAdInterval = 8)
//     instead of 7, comfortably within AdMob density guidelines.
//   • _isAdIndex / _dataIndexFor / _totalItemCount rewritten with a
//     reliable loop-based approach — the old arithmetic was fragile and
//     could map two list indices to the same provider.
//
// FIXED → NativeAdListItem loading placeholder height
//   • Reduced from 100 dp to 60 dp so a loading ad doesn't push content
//     off screen before the ad even fills in.
//   • "Sponsored" label kept — required by AdMob policy for native ads.
// ─────────────────────────────────────────────────────────────────────────────

/// Provider cards shown before the FIRST native ad slot.
const int _kFirstAdAfter = 5;

/// Provider cards shown between subsequent native ad slots.
const int _kAdInterval = 8;

class HomePricesScreen extends StatefulWidget {
  const HomePricesScreen({super.key});

  @override
  State<HomePricesScreen> createState() => _HomePricesScreenState();
}

class _HomePricesScreenState extends State<HomePricesScreen> {
 final TextEditingController _searchController = TextEditingController();

  String _selectedFilter = 'All Cities';
 final List<String> _filters = [
    'All Cities',
    'Top Rated',
    'A+ Rating',
    'A Rating',
    'B Rating',
    'C Rating',
  ];

  List<CityData> _allCities = [];
  List<CityData> _filteredCities = [];
  bool _isLoading = true;
  String? _errorMessage;

  // ── No BannerAd state — removed entirely ───────────────────────────────────

  @override
  void initState() {
    super.initState();
    _fetchData();
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

  // didChangeDependencies no longer needed (was only for banner ad loading).

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ── Data fetching ───────────────────────────────────────────────────────────

  void _fetchData() {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    ApisService()
        .getCityPrices()
        .then((cities) {
          if (mounted) {
            setState(() {
              _allCities = cities;
              _isLoading = false;
              _applyFilters();
            });
          }
        })
        .catchError((error) {
          if (mounted) {
            setState(() {
              _isLoading = false;
              _errorMessage = error.toString();
            });
          }
        });
  }

  void _applyFilters() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredCities = _allCities.where((city) {
        final matchesSearch =
            city.city.toLowerCase().contains(query) ||
            city.state.toLowerCase().contains(query);

        bool matchesFilter = true;
        switch (_selectedFilter) {
          case 'Top Rated':
            matchesFilter = city.rating == 'A+' || city.rating == 'A';
            break;
          case 'A+ Rating':
            matchesFilter = city.rating == 'A+';
            break;
          case 'A Rating':
            matchesFilter = city.rating == 'A';
            break;
          case 'B Rating':
            matchesFilter = city.rating.startsWith('B');
            break;
          case 'C Rating':
            matchesFilter = city.rating.startsWith('C');
            break;
          case 'All Cities':
          default:
            matchesFilter = true;
        }
        return matchesSearch && matchesFilter;
      }).toList();
    });
  }

  // ── Ad-index helpers ────────────────────────────────────────────────────────

  /// Returns true when [index] in the mixed list should render a native ad.
  bool _isAdIndex(int index) {
    if (index < _kFirstAdAfter) return false;
    final offset = index - _kFirstAdAfter;
    // Period = 1 ad slot + _kAdInterval content slots
    return offset % (_kAdInterval + 1) == 0;
  }

  /// Maps a mixed-list [index] to the actual index inside [_filteredCities].
  int _dataIndexFor(int listIndex) {
    if (listIndex < _kFirstAdAfter) return listIndex;
    int ads = 0;
    for (int i = _kFirstAdAfter; i < listIndex; i++) {
      if (_isAdIndex(i)) ads++;
    }
    return listIndex - ads;
  }

  /// Total item count for [n] city cards with ad slots interleaved.
  int _totalItemCount() {
    final n = _filteredCities.length;
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
    return total;
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  Color _getRatingColor(String rating) {
    if (rating == 'A+') return const Color(0xFF1E8449);
    if (rating == 'A') return const Color(0xFF27AE60);
    if (rating.startsWith('B')) return const Color(0xFFE67E22);
    if (rating.startsWith('C')) return const Color(0xFFE74C3C);
    return Colors.grey;
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryBlue = isDark ? const Color(0xFF60A5FA) : const Color(0xFF1E4ED8);
    final headerBgColor = isDark ? context.cs.surface : const Color(0xFF1E4ED8);

    return Scaffold(
      backgroundColor: context.pageBackground,
      appBar: GradientAppBar(
        backgroundColor: headerBgColor,
        title: Text(
          'Home Prices by City',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      // Body is now a plain Column — no sticky ad widget at the bottom.
      body: Column(
        children: [
          // ── Search bar ──────────────────────────────────────────────────
          Container(
            color: headerBgColor,
            padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: context.isDark ? context.inputFill : context.cs.surface,
                borderRadius: BorderRadius.circular(8),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (_) => _applyFilters(),
                decoration: InputDecoration(
                  hintText: 'Search cities...',
                  hintStyle: GoogleFonts.inter(color: Colors.grey.shade400),
                  prefixIcon: Icon(Icons.search, color: Colors.grey.shade400),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),

          // ── Filter chips ────────────────────────────────────────────────
          Container(
            color: context.cs.surface,
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: _filters.map((filter) {
                  final isSelected = _selectedFilter == filter;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(filter),
                      labelStyle: GoogleFonts.inter(
                        color: isSelected
                            ? (isDark ? Colors.black87 : Colors.white)
                            : context.textSecondary,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.w500,
                        fontSize: 12,
                      ),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          _selectedFilter = filter;
                          _applyFilters();
                        });
                      },
                      backgroundColor: context.cs.surface,
                      selectedColor: primaryBlue,
                      checkmarkColor: isSelected
                          ? (isDark ? Colors.black87 : Colors.white)
                          : null,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(
                          color: isSelected
                              ? primaryBlue
                              : context.borderColor,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          // ── City list ───────────────────────────────────────────────────
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          size: 48,
                          color: Colors.red,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Failed to load home prices',
                          style: GoogleFonts.inter(color: Colors.grey),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _fetchData,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryBlue,
                            foregroundColor: context.cs.surface,
                          ),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  )
                : _filteredCities.isEmpty
                ? Center(
                    child: Text(
                      'No cities found matching your criteria.',
                      style: GoogleFonts.inter(color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    // Clean 24 dp bottom padding — no banner
                    // height compensation needed.
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                    itemCount: _totalItemCount(),
                    itemBuilder: (context, index) {
                      // ── Ad slot ─────────────────────────────
                      if (_isAdIndex(index)) {
                        return const Padding(
                          padding: EdgeInsets.only(bottom: 16),
                          child: NativeAdListItem(),
                        );
                      }

                      // ── City card ────────────────────────────
                      final cityIndex = _dataIndexFor(index);
                      if (cityIndex >= _filteredCities.length) {
                        return const SizedBox.shrink();
                      }
                      return _buildCityCard(
                        _filteredCities[cityIndex],
                        primaryBlue,
                      );
                    },
                  ),
          ),

          // ── NO bottom BannerAd widget here ──────────────────────────────
        ],
      ),
    );
  }

  // ── City card ────────────────────────────────────────────────────────────────

  Widget _buildCityCard(CityData city, Color primaryBlue) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: context.cs.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: context.textPrimary.withAlpha((255 * 0.05).round()),
            offset: const Offset(0, 4),
            blurRadius: 10,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: [
            // Image
            SizedBox(
              height: 160,
              width: double.infinity,
              child: CachedNetworkImage(
                imageUrl: city.imageUrl.isNotEmpty
                    ? city.imageUrl
                    : 'https://images.unsplash.com/photo-1449844908441-8829872d2607',
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  color: Colors.grey.shade200,
                  child: const Center(child: CircularProgressIndicator()),
                ),
                errorWidget: (context, url, error) => Container(
                  color: Colors.grey.shade200,
                  child: const Icon(
                    Icons.image_not_supported,
                    color: Colors.grey,
                  ),
                ),
              ),
            ),

            // Content
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${city.city}, ${city.state}',
                              style: GoogleFonts.inter(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: primaryBlue,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Pop: ${(city.population / 1000000).toStringAsFixed(1)}M',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: context.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _getRatingColor(city.rating),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Rating: ${city.rating}',
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'MEDIAN PRICE',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: context.textSecondary,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '\$${(city.medianPrice / 1000).round()}k',
                              style: GoogleFonts.inter(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: isDark ? const Color(0xFF34D399) : const Color(0xFF1E8449),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'PRICE / SQFT',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: context.textSecondary,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '\$${city.pricePerSqft}',
                              style: GoogleFonts.inter(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: primaryBlue,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 45,
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      CityInsightsScreen(city: city),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryBlue,
                              foregroundColor: context.cs.surface,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: Text(
                              'View Details',
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: SizedBox(
                          height: 45,
                          child: OutlinedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => CityComparisonScreen(
                                    allCities: _allCities,
                                    initialCity: city,
                                  ),
                                ),
                              );
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: primaryBlue,
                              side: BorderSide(color: primaryBlue),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: Text(
                              'Compare',
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// NativeAdListItem
// ─────────────────────────────────────────────────────────────────────────────
// Changes from original:
//   • Loading placeholder height reduced: 100 dp → 60 dp.
//     A 100 dp blank slot before the ad fills is visually jarring and can
//     push city cards off-screen unnecessarily.
//   • "Sponsored" label is KEPT — AdMob policy requires native ads to be
//     clearly identified as ads. Do not remove it.
//   • factoryId 'adFactoryExample' is kept as-is; register your actual
//     platform factory in MainActivity.kt / AppDelegate.swift.
// ─────────────────────────────────────────────────────────────────────────────

class NativeAdListItem extends StatefulWidget {
  const NativeAdListItem({super.key});

  @override
  State<NativeAdListItem> createState() => _NativeAdListItemState();
}

class _NativeAdListItemState extends State<NativeAdListItem> {
  NativeAd? _nativeAd;
  bool _isAdLoaded = false;
  bool _isAdFailed = false;

  // Use AdService for native ad unit ID.
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
    // Silently collapse when the ad fails — no empty gap left in the list.
    if (_isAdFailed) return const SizedBox.shrink();

    // Loading placeholder: keep it small (60 dp) so it doesn't displace
    // content while the ad request is in flight.
      if (!_isAdLoaded || _nativeAd == null) {
      return Container(
        height: 60,
        margin: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: context.isDark ? context.cardColor : Colors.blue.shade50,
          borderRadius: BorderRadius.circular(16),
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
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.isDark ? context.cardColor : Colors.blue.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.isDark ? context.borderColor : Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Required AdMob disclosure label — do NOT remove.
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: context.isDark ? Colors.blue.withValues(alpha: 0.15) : Colors.blue.shade100,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Sponsored',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: context.isDark ? const Color(0xFF60A5FA) : Colors.blue,
                  ),
                ),
              ),
              const Spacer(),
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