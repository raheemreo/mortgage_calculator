import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AdRequest keyword presets — one per screen category.
// Using targeted keywords consistently raises CPM 3–5× vs empty requests
// in the US finance vertical (Google's own publisher guidance).
//
// Policy note (AdMob §4.4): keywords must be accurate and relevant to the
// screen content. Never use keyword stuffing or unrelated high-CPM keywords.
// ─────────────────────────────────────────────────────────────────────────────
abstract final class AdKeywords {
  // ── Mortgage / Home Loan screens ──────────────────────────────────────────
  static const List<String> mortgage = [
    'mortgage calculator',
    'mortgage rates',
    'home loan',
    'mortgage refinance',
    'first time home buyer',
    'home equity loan',
    'property tax',
    'closing costs',
    'home affordability',
    'mortgage pre approval',
  ];

  // ───────────────── Auto Loan Screens ─────────────────
  static const List<String> autoLoan = [
    'auto loan',
    'car loan calculator',
    'vehicle financing',
    'car payment',
    'auto refinance',
    'used car financing',
    'new car loan',
    'auto insurance quote',
    'gap insurance',
  ];

  // ───────────────── Insurance Marketplace Screens ─────────────────
  static const List<String> insurance = [
    'home insurance',
    'auto insurance',
    'life insurance',
    'health insurance',
    'insurance quote',
    'insurance comparison',
    'insurance coverage',
    'insurance premium',
    'bundle insurance',
  ];

  // ───────────────── Credit / Finance Screens ─────────────────
  static const List<String> creditFinance = [
    'credit score',
    'debt to income ratio',
    'personal loan',
    'debt consolidation',
    'credit card payoff',
    'credit report',
    'improve credit score',
    'loan calculator',
    'financial planning',
  ];

  // ───────────────── Real Estate / Housing Market Screens ─────────────────
  static const List<String> realEstate = [
    'real estate market',
    'home prices',
    'housing market',
    'property value',
    'buy a home',
    'home appraisal',
    'home search',
    'market trends',
    'property tax',
  ];

  // ───────────────── General / Utility Screens ─────────────────
  static const List<String> general = [
    'personal finance',
    'money management',
    'financial planning',
    'budgeting',
    'savings account',
    'investment planning',
    'financial calculator',
    'debt payoff',
    'emergency fund',
  ];
}

// ─────────────────────────────────────────────────────────────────────────────
// AdContentUrl
//
// Real pages from mortgagecalculatorreotech.blogspot.com — confirmed from the
// app's own Legal & Resources link tiles in PrivacyPolicyScreen.
//
// Each constant maps to the screen whose content it best describes:
//   • mortgage      → About the App page (describes the calculator itself)
//   • autoLoan      → About the App (no dedicated auto-loan page yet)
//   • insurance     → About the App (no dedicated insurance page yet)
//   • creditFinance → About the App (no dedicated credit page yet)
//   • realEstate    → About the App (no dedicated real-estate page yet)
//   • privacy       → Privacy & Policy page (used by PrivacyPolicyScreen)
//   • terms         → Terms of Service page
//   • contact       → Contact Us page
//   • general       → Blog homepage (settings / utility screens)
//
// When you publish dedicated Blogspot posts for Auto Loan, Insurance, etc.,
// replace the corresponding constants with those real URLs so Google's crawler
// can infer tighter category signals per screen.
// ─────────────────────────────────────────────────────────────────────────────
abstract final class AdContentUrl {
  static const _base = 'https://mortgagecalculatorreotech.blogspot.com';

  /// Mortgage calculator, PITI, Amortization, Rates screens.
  static const mortgage = '$_base/p/mortgage-calculator.html';

  /// Auto Loan screen — reuse About page until a dedicated post exists.
  static const autoLoan = '$_base/p/auto-loan-calculator.html';

  /// Insurance Marketplace screen — reuse About page until a dedicated post exists.
  static const insurance = '$_base/p/insurance-marketplace.html';

  /// DTI / Credit / Finance screens — reuse About page until dedicated post exists.
  static const creditFinance = '$_base/p/credit-finance-tools.html';

  /// Real-estate / Market screens — reuse About page until dedicated post exists.
  static const realEstate = '$_base/p/real-estate-market.html';

  /// Privacy Policy screen.
  static const privacy = '$_base/p/privacy-policy-of-mortgage-calculator.html';

  /// Terms of Service screen / link.
  static const terms = '$_base/p/terms-of-service-of-mortgage-calculator.html';

  /// Contact Us screen / link.
  static const contact = '$_base/p/contact-us-mortgage-calculator.html';

  /// Settings, currency, general utility screens.
  static const general = '$_base/p/general.html';
}

// ─────────────────────────────────────────────────────────────────────────────
// AdService
// ─────────────────────────────────────────────────────────────────────────────
class AdService {
  static final AdService _instance = AdService._internal();

  factory AdService() => _instance;

  AdService._internal();

  InterstitialAd? _interstitialAd;
  bool _isInterstitialAdReady = false;
  int _actionCount = 0;
  DateTime? _lastAdShownTime;
  bool _isFirstLaunch = true;

  bool get isFirstLaunch => _isFirstLaunch;
  int get actionCount => _actionCount;
  DateTime? get lastAdShownTime => _lastAdShownTime;

  // Configuration
  static const int _actionThreshold = 3;
  static const int _cooldownSeconds = 90;

  Future<void> init(SharedPreferences prefs) async {
    _isFirstLaunch = prefs.getBool('is_first_launch') ?? true;
    if (_isFirstLaunch) {
      await prefs.setBool('is_first_launch', false);
    }
    // Load the first interstitial with a general finance context.
    loadInterstitialAd();
  }

  // ── Ad Unit IDs ─────────────────────────────────────────────────────────────

  static String get appId {
    return Platform.isAndroid
        ? (dotenv.env['ANDROID_APP_ID'] ?? '')
        : (dotenv.env['IOS_APP_ID'] ?? '');
  }

  static String get bannerAdUnitId {
    return Platform.isAndroid
        ? (dotenv.env['ANDROID_BANNER_AD_UNIT_ID'] ?? '')
        : (dotenv.env['IOS_BANNER_AD_UNIT_ID'] ?? '');
  }

  static String get interstitialAdUnitId {
    return Platform.isAndroid
        ? (dotenv.env['ANDROID_INTERSTITIAL_AD_UNIT_ID'] ?? '')
        : (dotenv.env['IOS_INTERSTITIAL_AD_UNIT_ID'] ?? '');
  }

  static String get nativeAdUnitId {
    return Platform.isAndroid
        ? (dotenv.env['ANDROID_NATIVE_AD_UNIT_ID'] ?? '')
        : (dotenv.env['IOS_NATIVE_AD_UNIT_ID'] ?? '');
  }

  // ── Interstitial ────────────────────────────────────────────────────────────

  /// Loads (or pre-loads) an interstitial ad.
  ///
  /// Pass a screen-specific [request] so the next interstitial is filled with
  /// contextually relevant advertisers. Defaults to a general finance request
  /// when called from [init] before any screen context is available.
  ///
  /// AdMob policy: keywords must reflect the content the user has just seen,
  /// not the interstitial itself (which is full-screen and context-free).
  void loadInterstitialAd({
    AdRequest request = const AdRequest(
      contentUrl: AdContentUrl.general,
      keywords: AdKeywords.general,
    ),
  }) {
    InterstitialAd.load(
      adUnitId: interstitialAdUnitId,
      request: request,
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _isInterstitialAdReady = true;

          _interstitialAd?.fullScreenContentCallback =
              FullScreenContentCallback(
                onAdDismissedFullScreenContent: (ad) {
                  ad.dispose();
                  _isInterstitialAdReady = false;
                  // Reload with the same context as the dismissed ad.
                  loadInterstitialAd(request: request);
                },
                onAdFailedToShowFullScreenContent: (ad, error) {
                  ad.dispose();
                  _isInterstitialAdReady = false;
                  loadInterstitialAd(request: request);
                },
              );
        },
        onAdFailedToLoad: (err) {
          _isInterstitialAdReady = false;
        },
      ),
    );
  }

  void showInterstitialAd({
    required VoidCallback onAdClosed,
    bool isCalculation = true,
    bool ignoreThreshold = false,
  }) {
    // 1. NEVER show ads on first app launch/onboarding
    if (_isFirstLaunch) {
      debugPrint('AdService: Skipping ad - Initial App Launch Onboarding');
      onAdClosed();
      return;
    }

    // 2. Increment action count for meaningful interactions
    if (isCalculation) {
      _actionCount++;
    }

    final now = DateTime.now();
    final timeSinceLastAd = _lastAdShownTime == null
        ? const Duration(hours: 1) // Safe default
        : now.difference(_lastAdShownTime!);

    final bool isCooldownOver = timeSinceLastAd.inSeconds >= _cooldownSeconds;
    final bool isThresholdMet =
        ignoreThreshold || _actionCount >= _actionThreshold;

    debugPrint(
      'AdService: [Check] Actions: $_actionCount/$_actionThreshold, '
      'Cooldown: ${timeSinceLastAd.inSeconds}s/${_cooldownSeconds}s, '
      'IgnoreThreshold: $ignoreThreshold',
    );

    if (isThresholdMet && isCooldownOver) {
      if (_isInterstitialAdReady && _interstitialAd != null) {
        debugPrint('AdService: [Action] Showing Interstitial Ad');

        _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
          onAdDismissedFullScreenContent: (ad) {
            ad.dispose();
            _onAdHandled(onAdClosed);
          },
          onAdFailedToShowFullScreenContent: (ad, error) {
            ad.dispose();
            debugPrint('AdService: Failed to show ad: $error');
            _onAdHandled(onAdClosed, success: false);
          },
        );

        _interstitialAd!.show();
        _interstitialAd = null;
      } else {
        debugPrint('AdService: Ad not ready, skipping but preserving counter');
        onAdClosed();
        loadInterstitialAd(); // Reload for next opportunity
      }
    } else {
      debugPrint(
        'AdService: Ad suppressed '
        '(Threshold: $isThresholdMet, Cooldown: $isCooldownOver)',
      );
      onAdClosed();
    }
  }

  void _onAdHandled(VoidCallback onAdClosed, {bool success = true}) {
    _isInterstitialAdReady = false;
    if (success) {
      _actionCount = 0; // Reset after successful display
      _lastAdShownTime = DateTime.now();
    }
    loadInterstitialAd(); // Always reload after use/attempt
    onAdClosed();
  }
}
