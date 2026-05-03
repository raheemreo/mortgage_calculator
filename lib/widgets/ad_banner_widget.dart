import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../services/ad_service.dart';

/// Shared banner widget.
///
/// Pass [keywords] and [contentUrl] that match the screen context so AdMob
/// fills the slot with contextually relevant advertisers.
/// Both default to the general finance preset when omitted.
class AdBannerWidget extends StatefulWidget {
  final List<String> keywords;
  final String contentUrl;

  const AdBannerWidget({
    super.key,
    this.keywords = AdKeywords.general,
    this.contentUrl = AdContentUrl.general,
  });

  @override
  State<AdBannerWidget> createState() => _AdBannerWidgetState();
}

class _AdBannerWidgetState extends State<AdBannerWidget> {
  BannerAd? _bannerAd;
  bool _isLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadAd();
  }

  void _loadAd() {
    _bannerAd = BannerAd(
      adUnitId: AdService.bannerAdUnitId,
      request: AdRequest(
        contentUrl: widget.contentUrl,
        keywords: widget.keywords,
      ),
      size: AdSize.banner,
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (mounted) setState(() => _isLoaded = true);
        },
        onAdFailedToLoad: (ad, err) {
          ad.dispose();
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!AdService().isFirstLaunch && _isLoaded && _bannerAd != null) {
      return Container(
        color: Colors.transparent,
        width: _bannerAd!.size.width.toDouble(),
        height: _bannerAd!.size.height.toDouble(),
        alignment: Alignment.center,
        child: AdWidget(ad: _bannerAd!),
      );
    }

    // Fallback: no reserved space so layout is not disrupted.
    return const SizedBox.shrink();
  }
}
