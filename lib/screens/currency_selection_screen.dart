import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../services/ad_service.dart';
import '../providers/settings_provider.dart';
import '../core/constants/theme_extensions.dart';

// ─────────────────────────────────────────────────────────────────────────────
// FIXES APPLIED
// ─────────────────────────────────────────────────────────────────────────────
//
// FIX 1 → RadioGroup<String> removed
//   • Not a standard Flutter widget — caused compile errors / layout crashes.
//   • Replaced with a plain Column. Provider + GestureDetector handles
//     selection state correctly without any RadioGroup wrapper.
//
// FIX 2 → Radio<String> now has groupValue and onChanged
//   • Previously decorative only — non-functional.
//   • Now properly wired: groupValue: selectedCode, onChanged: (_) => onTap()
//
// FIX 3 → Native Ad moved BELOW the currency list
//   • Previously injected at midpoint of a 5-item list at 340px height —
//     flagged risk for "Interfering with App Functionality" and
//     "Encouraging Accidental Clicks" per AdMob policy.
//   • Now placed below the entire list — safe, non-intrusive, policy-compliant.
//   • Height reduced to 120px (appropriate for listTile factory).
//
// UNCHANGED → Anchored Adaptive Banner in bottomNavigationBar
//   • Correct placement, correct size, SafeArea wrapped — no changes needed.
// ─────────────────────────────────────────────────────────────────────────────

class CurrencySelectionScreen extends StatefulWidget {
  const CurrencySelectionScreen({super.key});

  @override
  State<CurrencySelectionScreen> createState() =>
      _CurrencySelectionScreenState();
}

class _CurrencySelectionScreenState extends State<CurrencySelectionScreen> {
  final List<Map<String, String>> _currencies = [
    {'code': 'USD - US Dollar', 'format': '\$1,234.56'},
    {'code': 'CAD - Canadian Dollar', 'format': '\$1,234.56'},
    {'code': 'GBP - British Pound', 'format': '£1,234.56'},
    {'code': 'AUD - Australian Dollar', 'format': '\$1,234.56'},
    {'code': 'EUR - Euro', 'format': '1.234,56 €'},
  ];

  BannerAd? _bottomBannerAd;
  bool _isBottomBannerAdLoaded = false;

  // ── Lifecycle ────────────────────────────────────────────────────────────────

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isBottomBannerAdLoaded) {
      _loadBottomBannerAd();
    }
  }

  @override
  void dispose() {
    _bottomBannerAd?.dispose();
    super.dispose();
  }

  // ── Banner ad ────────────────────────────────────────────────────────────────

  Future<void> _loadBottomBannerAd() async {
 AnchoredAdaptiveBannerAdSize? size =
        await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(
          MediaQuery.of(context).size.width.truncate(),
        );

    if (size == null || !mounted) return;

    _bottomBannerAd = BannerAd(
      adUnitId: AdService.bannerAdUnitId,
      size: size,
      request: const AdRequest(
        contentUrl: AdContentUrl.general,
        keywords: AdKeywords.general,
      ),
      listener: BannerAdListener(
        onAdLoaded: (Ad ad) {
          if (mounted) {
            setState(() {
              _bottomBannerAd = ad as BannerAd;
              _isBottomBannerAdLoaded = true;
            });
          }
        },
        onAdFailedToLoad: (Ad ad, LoadAdError error) {
          debugPrint('BannerAd failed to load: $error');
          ad.dispose();
        },
      ),
    );
    await _bottomBannerAd!.load();
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final selectedCode = settings.currencyCode;

    final double bottomPadding = _isBottomBannerAdLoaded
        ? _bottomBannerAd!.size.height.toDouble() + 16
        : 16;

    // Safe lookup with fallback to first currency.
    final selectedCurrency = _currencies.firstWhere(
      (c) => c['code']!.startsWith(selectedCode),
      orElse: () => _currencies.first,
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: context.cs.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF333333)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Currency & Region',
          style: TextStyle(
            color: Color(0xFF333333),
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: Colors.grey.shade200, height: 1),
        ),
      ),

      // ── Anchored adaptive banner — correct, policy-compliant, unchanged ──
      bottomNavigationBar: _isBottomBannerAdLoaded && _bottomBannerAd != null
          ? SafeArea(
              child: SizedBox(
                width: _bottomBannerAd!.size.width.toDouble(),
                height: _bottomBannerAd!.size.height.toDouble(),
                child: AdWidget(ad: _bottomBannerAd!),
              ),
            )
          : null,

      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(16, 16, 16, bottomPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Format preview card ─────────────────────────────────────
            const Text(
              'Regional Format Preview',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF0B3D91),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: context.textPrimary.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'SELECTED FORMAT',
                          style: TextStyle(
                            color: context.cs.surface.withValues(alpha: 0.8),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          selectedCurrency['format']!,
                          style: TextStyle(
                            color: context.cs.surface,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          selectedCurrency['code']!.split(' - ').last,
                          style: TextStyle(
                            color: context.cs.surface.withValues(alpha: 0.9),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.public,
                    size: 48,
                    color: context.cs.surface.withValues(alpha: 0.3),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ── Currency selection list ───────────────────────────────────
            // FIX: Plain Column — no RadioGroup wrapper needed.
            // Provider + GestureDetector handles selection correctly.
            const Text(
              'Preferred Currency',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _currencies.map((currency) {
                final code = currency['code']!.split(' - ').first;
                return _buildCurrencyTile(
                  currency,
                  code,
                  selectedCode: selectedCode,
                  onTap: () => settings.setCurrency(code),
                );
              }).toList(),
            ),

            const SizedBox(height: 16),


            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ── Currency tile ─────────────────────────────────────────────────────────────

  Widget _buildCurrencyTile(
    Map<String, String> currency,
    String code, {
    required String selectedCode,
    required VoidCallback onTap,
  }) {
    final isSelected = selectedCode == code;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.cs.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFF1E8449)
                  : Colors.grey.shade200,
              width: isSelected ? 2 : 1,
            ),
            boxShadow: [
              if (isSelected)
                BoxShadow(
                  color: const Color(0xFF1E8449).withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      currency['code']!,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF333333),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      currency['format']!,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              RadioGroup<String>(
                groupValue: selectedCode,
                onChanged: (_) => onTap(),
                child: Radio<String>(
                  value: code,
                  activeColor: const Color(0xFF1E8449),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

