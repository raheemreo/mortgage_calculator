import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
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

  final Completer<void> _initCompleter = Completer<void>();
  Future<void> get initializationComplete => _initCompleter.future;

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  InterstitialAd? _interstitialAd;
  bool _isInterstitialAdReady = false;
  bool _isInterstitialLoading = false;
  int _interstitialRetryAttempts = 0;
  int _actionCount = 0;
  DateTime? _lastAdShownTime;
  bool _isFirstLaunch = true;

  bool get isFirstLaunch => _isFirstLaunch;
  int get actionCount => _actionCount;
  DateTime? get lastAdShownTime => _lastAdShownTime;

  // Configuration
  static const int _actionThreshold = 3;
  static const int _cooldownSeconds = 90;

  // Cached native ads
  NativeAd? _cachedNativeAd;
  bool _isNativeAdLoading = false;

  Future<void> init(SharedPreferences prefs) async {
    _isFirstLaunch = prefs.getBool('is_first_launch') ?? true;
    if (_isFirstLaunch) {
      await prefs.setBool('is_first_launch', false);
    }
  }

  // ── UMP Consent Flow & Initialization ────────────────────────────────────────

  Future<void> runConsentFlowAndInitialize() async {
    final completer = Completer<void>();
    final params = ConsentRequestParameters();

    debugPrint('AdService: Requesting UMP consent information update...');
    ConsentInformation.instance.requestConsentInfoUpdate(
      params,
      () async {
        debugPrint('AdService: UMP consent information updated.');
        if (await ConsentInformation.instance.isConsentFormAvailable()) {
          debugPrint('AdService: Consent form is available. Loading/showing...');
          ConsentForm.loadAndShowConsentFormIfRequired((FormError? error) async {
            if (error != null) {
              debugPrint('AdService: Consent form error: ${error.message} (${error.errorCode})');
            } else {
              debugPrint('AdService: Consent flow completed successfully.');
            }
            await _initializeAdMob();
            completer.complete();
          });
        } else {
          debugPrint('AdService: Consent form is not available.');
          await _initializeAdMob();
          completer.complete();
        }
      },
      (FormError error) async {
        debugPrint('AdService: UMP Consent update failed: ${error.message} (${error.errorCode})');
        // Handle consent error gracefully: fall back to AdMob initialization
        await _initializeAdMob();
        completer.complete();
      },
    );

    return completer.future;
  }

  Future<void> _initializeAdMob() async {
    if (_isInitialized) return;
    try {
      debugPrint('AdService: Initializing Google Mobile Ads SDK...');
      final status = await MobileAds.instance.initialize();
      _isInitialized = true;
      debugPrint('AdService: Google Mobile Ads SDK initialized.');

      // Log mediation network statuses
      status.adapterStatuses.forEach((key, value) {
        debugPrint('AdService Adapter Status: $key -> state: ${value.state}, description: ${value.description}');
      });

      // Load interstitial and preload first native ad
      loadInterstitialAd();
      preloadNativeAd();

      if (!_initCompleter.isCompleted) {
        _initCompleter.complete();
      }
    } catch (e, stackTrace) {
      debugPrint('AdService: Failed to initialize MobileAds: $e');
      debugPrint(stackTrace.toString());
      if (!_initCompleter.isCompleted) {
        _initCompleter.completeError(e);
      }
    }
  }

  Future<void> showPrivacyOptionsForm(BuildContext context) async {
    final completer = Completer<void>();
    ConsentForm.showPrivacyOptionsForm((FormError? error) {
      if (error != null) {
        debugPrint('AdService: Failed to show privacy options form: ${error.message}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Consent preferences are only available when required by local privacy laws.',
              style: TextStyle(fontFamily: 'Inter'),
            ),
          ),
        );
        completer.completeError(error);
      } else {
        debugPrint('AdService: Privacy options form dismissed.');
        completer.complete();
      }
    });
    return completer.future;
  }

  Future<bool> isPrivacyOptionsRequired() async {
    try {
      final status = await ConsentInformation.instance.getPrivacyOptionsRequirementStatus();
      return status == PrivacyOptionsRequirementStatus.required;
    } catch (e) {
      debugPrint('AdService: Error checking privacy options requirement status: $e');
      return false;
    }
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
  void loadInterstitialAd({
    AdRequest request = const AdRequest(
      contentUrl: AdContentUrl.general,
      keywords: AdKeywords.general,
    ),
  }) {
    if (!_isInitialized) {
      debugPrint('AdService: Cannot load interstitial, AdMob not initialized.');
      return;
    }
    if (_isInterstitialAdReady || _isInterstitialLoading) {
      debugPrint('AdService: Interstitial ad already loaded or loading.');
      return;
    }

    _isInterstitialLoading = true;
    debugPrint('AdService: Loading Interstitial Ad...');

    InterstitialAd.load(
      adUnitId: interstitialAdUnitId,
      request: request,
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          debugPrint('AdService: Interstitial Ad loaded successfully.');
          _interstitialAd = ad;
          _isInterstitialAdReady = true;
          _isInterstitialLoading = false;
          _interstitialRetryAttempts = 0; // Reset retry counter

          _interstitialAd?.fullScreenContentCallback =
              FullScreenContentCallback(
                onAdDismissedFullScreenContent: (ad) {
                  debugPrint('AdService: Interstitial Ad dismissed.');
                  ad.dispose();
                  _isInterstitialAdReady = false;
                  loadInterstitialAd(request: request);
                },
                onAdFailedToShowFullScreenContent: (ad, error) {
                  debugPrint('AdService: Interstitial Ad failed to show: $error');
                  ad.dispose();
                  _isInterstitialAdReady = false;
                  loadInterstitialAd(request: request);
                },
              );
        },
        onAdFailedToLoad: (err) {
          debugPrint('AdService: Interstitial Ad failed to load: ${err.message}');
          _isInterstitialAdReady = false;
          _isInterstitialLoading = false;
          _interstitialAd = null;

          // Exponential backoff up to 6 attempts (max delay ~64s)
          if (_interstitialRetryAttempts < 6) {
            _interstitialRetryAttempts++;
            final delay = Duration(seconds: 1 << _interstitialRetryAttempts);
            debugPrint('AdService: Retrying interstitial load in ${delay.inSeconds} seconds...');
            Future.delayed(delay, () => loadInterstitialAd(request: request));
          }
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

  // ── Native Ad Preload & Caching ──────────────────────────────────────────

  void preloadNativeAd() {
    if (!_isInitialized || _cachedNativeAd != null || _isNativeAdLoading) return;

    _isNativeAdLoading = true;
    debugPrint('AdService: Preloading a NativeAd...');

    _cachedNativeAd = NativeAd(
      adUnitId: nativeAdUnitId,
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
      request: const AdRequest(
        contentUrl: AdContentUrl.general,
        keywords: AdKeywords.general,
      ),
      listener: NativeAdListener(
        onAdLoaded: (ad) {
          _isNativeAdLoading = false;
          debugPrint('AdService: Preloaded NativeAd loaded successfully.');
        },
        onAdFailedToLoad: (ad, error) {
          _isNativeAdLoading = false;
          ad.dispose();
          _cachedNativeAd = null;
          debugPrint('AdService: Preloaded NativeAd failed to load: ${error.message}');
          // Retry preloading after 30 seconds
          Future.delayed(const Duration(seconds: 30), () => preloadNativeAd());
        },
      ),
    );

    _cachedNativeAd!.load();
  }

  /// Retrieves the cached NativeAd (if any), and starts preloading the next one.
  NativeAd? getAndRefreshCachedNativeAd() {
    final ad = _cachedNativeAd;
    _cachedNativeAd = null;
    preloadNativeAd();
    return ad;
  }
}
