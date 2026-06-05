import 'dart:async';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../main.dart';
import '../providers/notification_provider.dart';
import '../screens/notification_screen.dart';

/// Centralised Firebase initialisation and helper methods.
/// Call [FirebaseService.init] once inside [main] before [runApp].
class FirebaseService {
  FirebaseService._();

  static FirebaseAnalytics get _analytics => FirebaseAnalytics.instance;
  static FirebaseRemoteConfig? _remoteConfig;
  static NotificationProvider? _notificationProvider;

  // ─── Initialisation ────────────────────────────────────────────────────────

  static Future<void> init() async {
    // 1. Core Firebase Initialization (must be awaited)
    await Firebase.initializeApp();

    // 2. Crashlytics setup
    if (!kDebugMode) {
      await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(true);

      // Catch errors that Flutter can't catch itself
      FlutterError.onError =
          FirebaseCrashlytics.instance.recordFlutterFatalError;

      // FIX Crash #1: Pass all uncaught async errors to Crashlytics.
      // Previously, PlatformDispatcher.onError would surface FormError as
      // "Instance of 'FormError'" because .toString() wasn't called.
      // Now we safely stringify the error before recording.
      PlatformDispatcher.instance.onError = (error, stack) {
        FirebaseCrashlytics.instance.recordError(
          error,
          stack,
          reason: error.toString(), // explicit reason avoids opaque type names
          fatal: true,
        );
        return true;
      };
    }

    // 3. Remote Config setup (Settings & Defaults are local/fast)
    _remoteConfig = FirebaseRemoteConfig.instance;
    await _remoteConfig!.setConfigSettings(
      RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 10),
        minimumFetchInterval: const Duration(hours: 1),
      ),
    );
    await _remoteConfig!.setDefaults({
      'ai_chat_enabled': true,
      'ai_chat_intro_message':
          'Hi! I can help you with mortgage calculations, DTI ratios, loan comparisons, and more. What would you like to know?',
      'insurance_marketplace_enabled': true,
      'promo_banner_text': '',
      'latest_version_name': '3.0.1',
      'latest_version_code': 10,
      'update_required': false,
      'update_message':
          'A new version of Mortgage Calculator - PITI, DTI is available with improvements and bug fixes. Update now for the best experience.',
    });

    // 4. Trigger network-dependent tasks in the background
    _startBackgroundTasks();
  }

  /// Performs network-dependent or potentially slow setup in the background.
  static void _startBackgroundTasks() {
    // A. Fetch and activate Remote Config
    _remoteConfig
        ?.fetchAndActivate()
        .then((updated) {
          debugPrint("🔄 Remote Config updated: $updated");
        })
        .catchError((e) {
          debugPrint('⚠️ Remote Config fetch failed (background): $e');
        });

    // B. Setup FCM (permissions, listeners, etc.)
    _setupMessaging().catchError((e) {
      debugPrint('⚠️ FCM background setup failed: $e');
    });
  }

  // ─── Analytics helpers ──────────────────────────────────────────────────────

  /// Log a named event with optional parameters.
  static Future<void> logEvent(
    String name, [
    Map<String, Object>? parameters,
  ]) async {
    await _analytics.logEvent(name: name, parameters: parameters);
  }

  /// Log when the user opens a specific screen.
  static Future<void> logScreenView(String screenName) async {
    await _analytics.logScreenView(screenName: screenName);
  }

  /// Log when a calculator module is opened from the dashboard.
  static Future<void> logCalculatorOpened(String calculatorName) async {
    await logEvent('calculator_opened', {'name': calculatorName});
  }

  // ─── Remote Config helpers ──────────────────────────────────────────────────

  /// Read a string value from Remote Config with a [fallback] if unavailable.
  static String getRemoteString(String key, {String fallback = ''}) {
    return _remoteConfig?.getString(key) ?? fallback;
  }

  /// Read a boolean flag from Remote Config.
  static bool getRemoteBool(String key, {bool fallback = true}) {
    return _remoteConfig?.getBool(key) ?? fallback;
  }

  // ─── Crashlytics helpers ────────────────────────────────────────────────────

  /// Record a non-fatal error (e.g. from a catch block).
  static Future<void> recordError(
    Object exception,
    StackTrace? stack, {
    String? reason,
  }) async {
    if (!kDebugMode) {
      await FirebaseCrashlytics.instance.recordError(
        exception,
        stack,
        reason: reason,
        fatal: false,
      );
    }
  }

  // ─── Messaging setup ────────────────────────────────────────────────────────

  /// Sets up the notification handler with a [NotificationProvider] instance.
  /// This should be called once the provider is available in the UI.
  static void setNotificationProvider(NotificationProvider provider) {
    _notificationProvider = provider;
    debugPrint("✅ FirebaseService: NotificationProvider linked.");
  }

  static Future<void> _setupMessaging() async {
    final messaging = FirebaseMessaging.instance;

    // 1. Request permission
    // FIX Crash #3: Wrap in try/catch — requestPermission() throws
    // PlatformException on devices with outdated/missing Google Play Services.
    NotificationSettings? settings;
    try {
      settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
      debugPrint('🔔 FCM permission: ${settings.authorizationStatus}');
    } catch (e, stack) {
      debugPrint('⚠️ FCM requestPermission failed: $e');
      if (!kDebugMode) {
        FirebaseCrashlytics.instance.recordError(
          e, stack,
          reason: 'FCM requestPermission failed',
          fatal: false,
        );
      }
    }

    // 2. Log the FCM token in debug mode
    // FIX Crash #3: Wrap getToken() separately — it can throw
    // PlatformException independently of requestPermission().
    if (kDebugMode) {
      try {
        final token = await messaging.getToken();
        debugPrint('📲 FCM_TOKEN: $token');
      } catch (e) {
        debugPrint('⚠️ FCM getToken failed: $e');
      }
    }

    // 3. Foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('📩 Foreground FCM message received:');
      final title = message.notification?.title ?? 'Update';
      final body = message.notification?.body ?? 'A new message is available.';
      
      debugPrint('   Title : $title');
      debugPrint('   Body  : $body');

      // Add to our provider
      _notificationProvider?.addNotification(
        title,
        body,
        data: message.data,
      );
    });

    // 4. Background-to-foreground tap
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('🔗 FCM notification tapped (background): ${message.data}');
      // Reload the provider from SharedPreferences strictly to sync any background messages
      _notificationProvider?.reload();
      _handleNotificationData(message.data, isTerminated: false);
    });

    // 5. App launched via notification
    final initialMessage = await messaging.getInitialMessage();
    if (initialMessage != null) {
      debugPrint(
        '🚀 FCM app launched from notification: ${initialMessage.data}',
      );
      _handleNotificationData(initialMessage.data, isTerminated: true);
    }
  }

  /// Internal handler for notification deep-linking
  static void _handleNotificationData(Map<String, dynamic> data, {bool isTerminated = false}) {
    debugPrint('📍 Notification tapped, handling deep-link data: $data');

    void navigate() {
      if (navigatorKey.currentState != null) {
        navigatorKey.currentState!.push(
          MaterialPageRoute(builder: (_) => const NotificationScreen()),
        );
      } else {
        debugPrint('⚠️ navigatorKey.currentState is null, cannot navigate.');
      }
    }

    if (isTerminated) {
      // If the app was completely terminated, give the Splash screen enough time 
      // (1.5s + network update check) to finish BEFORE pushing the new route.
      Future.delayed(const Duration(seconds: 3), navigate);
    } else {
      // If the app is already in the background/foreground, navigate immediately.
      navigate();
    }

    if (data.containsKey('screen')) {
      final screen = data['screen'];
      debugPrint('📍 Deep-linking to screen: $screen');
    }
  }
}
