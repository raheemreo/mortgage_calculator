import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/constants/app_theme.dart';
import 'providers/calculator_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/affordability_provider.dart';
import 'providers/fred_mortgage_provider.dart';
import 'providers/notification_provider.dart';
import 'screens/home_dashboard.dart';
import 'screens/onboarding_screen.dart';
import 'screens/splash_screen.dart';
import 'services/ad_service.dart';
import 'services/firebase_service.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// Top-level background message handler for Firebase Cloud Messaging.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('📨 Background FCM message: ${message.notification?.title}');
  
  // Save notification locally so it appears in the NotificationScreen
  try {
    final prefs = await SharedPreferences.getInstance();
    final String? stored = prefs.getString('cached_notifications');
    List<dynamic> cached = [];
    if (stored != null) {
      try {
        cached = json.decode(stored);
      } catch (_) {}
    }
    
    // Create new item matching NotificationItem schema
    cached.insert(0, {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'title': message.notification?.title ?? 'Update',
      'body': message.notification?.body ?? 'A new message is available.',
      'timestamp': DateTime.now().toIso8601String(),
      'data': message.data,
      'isRead': false,
    });
    
    await prefs.setString('cached_notifications', json.encode(cached));
  } catch (e) {
    debugPrint('⚠️ Failed to save background notification: $e');
  }
}

void main() async {
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  // Load environment variables
  try {
    await dotenv.load(fileName: ".env");
    debugPrint("✅ .env loaded successfully");
  } catch (e) {
    debugPrint("⚠️ .env file not found or failed to load: $e");
  }

  // Register background handler
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Initialize Firebase
  try {
    await FirebaseService.init();
    debugPrint("✅ Firebase initialized successfully");
  } catch (e, stackTrace) {
    debugPrint("❌ Firebase initialization failed: $e");
    debugPrint(stackTrace.toString());
  }

  // Initialize Ads
  unawaited(MobileAds.instance.initialize());

  // 5. Initialize shared preferences and logic
  debugPrint("📦 Fetching SharedPreferences...");
  final prefs = await SharedPreferences.getInstance();
  final bool onboardingComplete = prefs.getBool('onboarding_complete') ?? false;

  // Initialize Ads with prefs
  unawaited(AdService().init(prefs));

  // 6. Launch App
  debugPrint("🚀 Calling runApp...");
  runApp(MyApp(
    showOnboarding: !onboardingComplete,
    prefs: prefs,
  ));
}

void unawaited(Future<void> future) {
  future.catchError((e) {
    debugPrint("⚠️ Unawaited future error: $e");
  });
}

class MyApp extends StatelessWidget {
  final bool showOnboarding;
  final SharedPreferences prefs;

  const MyApp({super.key, required this.showOnboarding, required this.prefs});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => CalculatorProvider()),
        ChangeNotifierProvider(create: (_) => SettingsProvider(prefs)),
        ChangeNotifierProvider(create: (_) => AffordabilityProvider()),
        ChangeNotifierProvider(create: (_) => FredMortgageProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider(prefs)),
      ],
      child: Consumer<SettingsProvider>(
        builder: (context, settings, _) {
          ThemeData theme = AppTheme.lightTheme;

          if (settings.themeName == 'Emerald') {
            theme = AppTheme.emeraldTheme;
          } else if (settings.themeName == 'Navy') {
            theme = AppTheme.lightTheme;
          }

          return MaterialApp(
            navigatorKey: navigatorKey,
            title: 'Mortgage Pro USA',
            debugShowCheckedModeBanner: false,
            theme: theme,
            themeMode: ThemeMode.light,
            home: SplashScreen(
              nextScreen: showOnboarding
                  ? const OnboardingScreen()
                  : const HomeDashboard(),
            ),
          );
        },
      ),
    );
  }
}
