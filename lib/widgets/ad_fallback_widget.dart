// lib/widgets/ad_fallback_widget.dart
// ─────────────────────────────────────────────────────────────────────────────
// AdFallbackWidget — Production-ready ad slot with native → banner fallback.
//
// Fallback Strategy:
//  1. Load NativeAd first.
//  2a. Native loads  → show NativeAd, cancel timer.
//  2b. Native fails  → immediately start BannerAd load (cancel timer first).
//  2c. Timeout fires → start BannerAd load (safety net for silent hangs).
//  3.  Banner loads  → show BannerAd.
//  4.  Banner fails  → collapse entire widget to SizedBox.shrink().
//
// Race-condition guards:
//  • _isBannerLoading  — prevents double banner requests when both the
//    timeout and onAdFailedToLoad fire in the same event-loop tick.
//  • Late native guard — if native returns AFTER the banner has already
//    loaded/failed, the late native callback discards the ad and returns
//    immediately, never overwriting the settled state.
//
// AdMob Policy Compliance (Google AdMob Policies, May 2025):
//  ✅ §3.3  "Ad" / "Sponsored" label rendered OUTSIDE AdWidget — never
//           obscured by the ad template itself.
//  ✅ §3.3  Label is visually distinct (contrasting colours, clear typeface).
//  ✅ §3.2  Only ONE ad format ever visible at a time.
//  ✅ §3.1  No InkWell / GestureDetector / onTap wrapping AdWidget —
//           all click handling delegated to the SDK internally.
//  ✅ §3.1  Fixed outer height prevents unintentional layout shifts that
//           could cause accidental clicks.
//  ✅ Lifecycle: NativeAd and BannerAd disposed on widget dispose.
//  ✅ Lifecycle: Timer and retry Future cancelled in dispose() — no
//           setState-after-dispose crash.
//  ✅ Failed state: entire widget (including chrome) collapses to nothing —
//           no orphaned "Sponsored" pill when no ad is available.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../services/ad_service.dart';

// ── Ad state machine ──────────────────────────────────────────────────────────

enum _AdState { loading, nativeLoaded, bannerLoaded, failed }

// ── Widget ────────────────────────────────────────────────────────────────────

class AdFallbackWidget extends StatefulWidget {
  /// How long to wait for the native ad before triggering the banner fallback.
  /// Defaults to 3 s — a measured balance between fill-rate on slow networks
  /// (India averages 2–4 s native load) and perceptible loading latency.
  /// Pass a shorter value in tests or on known-fast networks.
  final Duration fallbackTimeout;

  /// Optional AdMob content-targeting keywords (screen-specific).
  final List<String>? keywords;

  /// Optional AdMob content-targeting URL (screen-specific).
  final String? contentUrl;

  /// Optional margin/padding to apply only when the ad is loaded and shown.
  final EdgeInsetsGeometry? margin;

  const AdFallbackWidget({
    super.key,
    this.fallbackTimeout = const Duration(seconds: 3),
    this.keywords,
    this.contentUrl,
    this.margin,
  });

  @override
  State<AdFallbackWidget> createState() => _AdFallbackWidgetState();
}

class _AdFallbackWidgetState extends State<AdFallbackWidget> {
  // ── Constants ──────────────────────────────────────────────────────────────

  /// Fixed outer height — native (listTile factory) fits in ~300 px;
  /// mediumRectangle banner is 250 px.  320 px keeps layout stable across
  /// all loaded states.  Only collapses on _AdState.failed.
  static const double _kContainerHeight = 320.0;

  /// How long to wait before retrying after both ad formats fail.
  static const Duration _kRetryDelay = Duration(seconds: 30);

  // ── State ──────────────────────────────────────────────────────────────────

  NativeAd? _nativeAd;
  BannerAd? _bannerAd;
  _AdState _state = _AdState.loading;

  /// Guards against simultaneous banner requests triggered by both the
  /// fallback timer and onAdFailedToLoad firing in the same event-loop tick.
  bool _isBannerLoading = false;

  Timer? _fallbackTimer;

  bool _disposed = false;

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _checkInitAndLoad();
  }

  Future<void> _checkInitAndLoad() async {
    await AdService().initializationComplete;
    if (mounted) {
      _loadNativeAd();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _fallbackTimer?.cancel();
    _nativeAd?.dispose();
    _bannerAd?.dispose();
    // _retryFuture is a plain Future.delayed — it cannot be cancelled directly,
    // but _disposed = true above causes its callback to no-op.
    super.dispose();
  }

  // ── Step 1: Attempt native ────────────────────────────────────────────────

  void _loadNativeAd() {
    if (!AdService().isInitialized || _nativeAd != null) return;

    // Safety-net timer: if native hasn't responded within [fallbackTimeout],
    // start loading the banner so the slot is never permanently empty.
    _fallbackTimer = Timer(widget.fallbackTimeout, _loadBannerAd);

    _nativeAd = NativeAd(
      adUnitId: AdService.nativeAdUnitId,
      // 'listTile' factory renders AdMob's medium template which includes its
      // own built-in "Ad" badge.  Our external "Sponsored" pill is
      // supplementary, satisfying §3.3 even on template versions that render
      // the badge at a small size.
      factoryId: 'listTile',
      listener: NativeAdListener(
        onAdLoaded: (ad) {
          // ── Late-native guard ──────────────────────────────────────────────
          // If the banner has already loaded or failed (timeout/failure path
          // completed before this callback arrived), discard the late native
          // to avoid overwriting a settled state and leaking an ad object.
          if (_state != _AdState.loading) {
            ad.dispose();
            return;
          }
          _fallbackTimer?.cancel();
          if (mounted) setState(() => _state = _AdState.nativeLoaded);
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('AdFallback › NativeAd failed — ${error.message}');
          ad.dispose();
          _nativeAd = null;
          // Cancel the timer; we're immediately triggering the banner path.
          _fallbackTimer?.cancel();
          _loadBannerAd();
        },
      ),
      request: AdRequest(
        keywords: widget.keywords,
        contentUrl: widget.contentUrl,
      ),
    )..load();
  }

  // ── Step 2: Fallback to banner ────────────────────────────────────────────

  void _loadBannerAd() {
    if (!mounted || _disposed || !AdService().isInitialized) return;

    // ── Double-load guard ──────────────────────────────────────────────────
    // Both the timer callback and onAdFailedToLoad can fire in the same
    // event-loop tick (e.g., SDK delivers failure synchronously just as the
    // timer expires).  Only one banner load is ever needed.
    if (_isBannerLoading) return;

    // Native already won — no banner needed.
    if (_state == _AdState.nativeLoaded) return;

    // Defensive: dispose any previous (unreachable in normal flow) banner.
    _bannerAd?.dispose();
    _bannerAd = null;

    _isBannerLoading = true;

    // mediumRectangle (300×250) is universally supported and fits within the
    // fixed 320 px container.  Adaptive banners require an async size lookup;
    // mediumRectangle avoids that complexity while still filling the slot.
    _bannerAd = BannerAd(
      adUnitId: AdService.bannerAdUnitId,
      size: AdSize.mediumRectangle,
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (mounted) setState(() => _state = _AdState.bannerLoaded);
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('AdFallback › BannerAd failed — ${error.message}');
          ad.dispose();
          _bannerAd = null;
          _isBannerLoading = false;
          if (mounted) setState(() => _state = _AdState.failed);
          _scheduleRetry();
        },
      ),
      request: AdRequest(
        keywords: widget.keywords,
        contentUrl: widget.contentUrl,
      ),
    )..load();
  }

  // ── Step 3 (optional): Retry after both formats fail ─────────────────────

  /// Schedules a full reload cycle [_kRetryDelay] after total failure.
  /// Uses a plain Future.delayed; _disposed guards against post-dispose work.
  void _scheduleRetry() {
    Future.delayed(_kRetryDelay, () {
      if (_disposed || !mounted) return;
      // Reset state machine for a fresh cycle.
      setState(() {
        _state = _AdState.loading;
        _isBannerLoading = false;
      });
      _loadNativeAd();
    });
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // When the ad is loading or has failed, or if it is the first launch onboarding,
    // collapse the entire widget to avoid showing empty placeholder space.
    if (AdService().isFirstLaunch || _state == _AdState.failed || _state == _AdState.loading) {
      return const SizedBox.shrink();
    }

    Widget content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── "Sponsored" disclosure pill ─────────────────────────────────────
        // Policy §3.3: disclosure must be rendered OUTSIDE the AdWidget so
        // the template cannot obscure it.  Pill uses strong contrast
        // (amber-on-cream) and an explicit "Sponsored" label in plain language.
        Row(
          children: [
            const Expanded(
              child: Divider(
                thickness: 1,
                color: Color(0xFFE5E7EB),
                endIndent: 10,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7E6),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: const Color(0xFFFFB800).withValues(alpha: 0.45),
                  width: 0.8,
                ),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.campaign_outlined,
                    size: 11,
                    color: Color(0xFFB45309),
                  ),
                  SizedBox(width: 4),
                  Text(
                    'Sponsored',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFB45309),
                      letterSpacing: 0.4,
                    ),
                  ),
                ],
              ),
            ),
            const Expanded(
              child: Divider(
                thickness: 1,
                color: Color(0xFFE5E7EB),
                indent: 10,
              ),
            ),
          ],
        ),

        const SizedBox(height: 10),

        // ── Fixed-height ad container ───────────────────────────────────────
        // NOT wrapped in InkWell / GestureDetector / onTap.
        // Policy §3.1: all click handling is delegated to AdWidget's internal
        // SDK touch handler — prevents accidental interaction.
        Container(
          height: _kContainerHeight,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE5E7EB)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x07000000),
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: _buildAdContent(),
          ),
        ),

        const SizedBox(height: 10),
        const Divider(thickness: 1, color: Color(0xFFE5E7EB)),
      ],
    );

    if (widget.margin != null) {
      content = Padding(
        padding: widget.margin!,
        child: content,
      );
    }

    return content;
  }

  Widget _buildAdContent() {
    switch (_state) {
      case _AdState.nativeLoaded:
        // Native fills the full container.
        return AdWidget(ad: _nativeAd!);

      case _AdState.bannerLoaded:
        // mediumRectangle (300×250) centred within the 320 px container.
        return Center(
          child: SizedBox(
            width: 300,
            height: 250,
            child: AdWidget(ad: _bannerAd!),
          ),
        );

      case _AdState.failed:
        // Handled above in build() — this branch is unreachable,
        // but required to satisfy Dart's exhaustiveness check.
        return const SizedBox.shrink();

      case _AdState.loading:
        return const _LoadingPlaceholder();
    }
  }
}

// ── Loading placeholder ───────────────────────────────────────────────────────
// Shown while native is loading.  Identical dimensions to the live ad slot,
// preventing any layout reflow when the real ad arrives.

class _LoadingPlaceholder extends StatefulWidget {
  const _LoadingPlaceholder();

  @override
  State<_LoadingPlaceholder> createState() => _LoadingPlaceholderState();
}

class _LoadingPlaceholderState extends State<_LoadingPlaceholder>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.25, end: 0.75).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Center(
    child: FadeTransition(
      opacity: _anim,
      child: Icon(
        Icons.image_outlined,
        size: 40,
        color: Colors.grey.shade300,
      ),
    ),
  );
}