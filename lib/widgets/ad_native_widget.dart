import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../services/ad_service.dart';

/// Shared native ad widget (NativeTemplateStyle medium — no factory required).
///
/// Pass [keywords] and [contentUrl] matching the screen context so AdMob
/// fills the slot with contextually relevant advertisers.
/// Both default to the general finance preset when omitted.
class AdNativeWidget extends StatefulWidget {
  final List<String> keywords;
  final String contentUrl;

  const AdNativeWidget({
    super.key,
    this.keywords = AdKeywords.general,
    this.contentUrl = AdContentUrl.general,
  });

  @override
  State<AdNativeWidget> createState() => _AdNativeWidgetState();
}

class _AdNativeWidgetState extends State<AdNativeWidget> {
  NativeAd? _nativeAd;
  bool _isLoaded = false;
  bool _isFailed = false;
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
    if (!AdService().isInitialized || _nativeAd != null) return;

    // Try to get preloaded cached ad
    final cachedAd = AdService().getAndRefreshCachedNativeAd();
    if (cachedAd != null) {
      debugPrint('[AdMob] AdNativeWidget: Using preloaded/cached NativeAd');
      _nativeAd = cachedAd;
      setState(() {
        _isLoaded = true;
        _isFailed = false;
      });
      return;
    }

    debugPrint('[AdMob] AdNativeWidget: Loading fresh NativeAd...');
    _nativeAd = NativeAd(
      adUnitId: AdService.nativeAdUnitId,
      // NativeTemplateStyle uses the SDK's built-in medium template.
      // No MainActivity.kt / AppDelegate.swift factory registration needed.
      nativeTemplateStyle: NativeTemplateStyle(
        templateType: TemplateType.medium,
        mainBackgroundColor: Colors.white,
        cornerRadius: 12.0,
        callToActionTextStyle: NativeTemplateTextStyle(
          textColor: Colors.white,
          backgroundColor: const Color(0xFF1E4ED8),
          style: NativeTemplateFontStyle.bold,
          size: 14.0,
        ),
        primaryTextStyle: NativeTemplateTextStyle(
          textColor: const Color(0xFF0F172A),
          style: NativeTemplateFontStyle.bold,
          size: 15.0,
        ),
        secondaryTextStyle: NativeTemplateTextStyle(
          textColor: const Color(0xFF64748B),
          style: NativeTemplateFontStyle.normal,
          size: 13.0,
        ),
        tertiaryTextStyle: NativeTemplateTextStyle(
          textColor: const Color(0xFF94A3B8),
          style: NativeTemplateFontStyle.normal,
          size: 12.0,
        ),
      ),
      request: AdRequest(
        contentUrl: widget.contentUrl,
        keywords: widget.keywords,
      ),
      listener: NativeAdListener(
        onAdLoaded: (ad) {
          _retryCount = 0; // Reset retry count
          if (mounted) {
            setState(() {
              _isLoaded = true;
              _isFailed = false;
            });
          }
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('[AdMob] NativeAd failed: ${error.message}');
          ad.dispose();
          _nativeAd = null;
          if (mounted) setState(() => _isFailed = true);

          // Retry logic (max 3 retries with exponential backoff)
          if (_retryCount < 3) {
            _retryCount++;
            final delay = Duration(seconds: 1 << _retryCount);
            debugPrint('[AdMob] AdNativeWidget retrying load in ${delay.inSeconds} seconds...');
            Future.delayed(delay, () {
              if (mounted) {
                setState(() => _isFailed = false);
                _loadAd();
              }
            });
          }
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
    if (_isFailed) return const SizedBox.shrink();

    if (!AdService().isFirstLaunch && _isLoaded && _nativeAd != null) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 16),
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Required ad disclosure (AdMob native policy §3.1) ──────────
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'Sponsored',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF64748B),
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                  const Spacer(),
                  const Tooltip(
                    message: 'This is a paid advertisement',
                    child: Icon(
                      Icons.info_outline,
                      size: 15,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 120, maxHeight: 400),
              child: AdWidget(ad: _nativeAd!),
            ),
            const SizedBox(height: 4),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }
}
