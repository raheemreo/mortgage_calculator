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
  int _retryCount = 0;

  @override
  void initState() {
    super.initState();
    _checkInitAndLoad();
  }

  Future<void> _checkInitAndLoad() async {
    await AdService().initializationComplete;
    if (mounted) {
      _loadAd();
    }
  }

  void _loadAd() {
    if (!AdService().isInitialized || _bannerAd != null) return;

    debugPrint('[AdMob] AdBannerWidget: Loading BannerAd...');
    _bannerAd = BannerAd(
      adUnitId: AdService.bannerAdUnitId,
      request: AdRequest(
        contentUrl: widget.contentUrl,
        keywords: widget.keywords,
      ),
      size: AdSize.banner,
      listener: BannerAdListener(
        onAdLoaded: (_) {
          _retryCount = 0; // Reset retry count
          if (mounted) setState(() => _isLoaded = true);
        },
        onAdFailedToLoad: (ad, err) {
          debugPrint('[AdMob] BannerAd failed to load: ${err.message}');
          ad.dispose();
          _bannerAd = null;
          if (mounted) setState(() => _isLoaded = false);

          // Retry logic (max 3 retries with exponential backoff)
          if (_retryCount < 3) {
            _retryCount++;
            final delay = Duration(seconds: 1 << _retryCount);
            debugPrint('[AdMob] AdBannerWidget retrying load in ${delay.inSeconds} seconds...');
            Future.delayed(delay, () {
              if (mounted) _loadAd();
            });
          }
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
