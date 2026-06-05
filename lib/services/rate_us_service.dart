import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../screens/feedback_screen.dart';

class RateUsService {
  // Singleton pattern
  RateUsService._privateConstructor();
  static final RateUsService instance = RateUsService._privateConstructor();

  static const String _keyLaunchCount = 'launch_count';
  static const String _keyCalculationCount = 'calculation_count';
  static const String _keyLastPromptTimestamp = 'last_prompt_timestamp';
  static const String _keyHasRated = 'has_rated';

  static const int _targetLaunchCount = 5;
  static const int _targetCalculationCount = 3;
  static const int _cooldownDays = 7;

  bool _promptShownThisSession = false;

  /// Call this in main.dart or dashboard init
  Future<void> recordAppLaunch() async {
    final prefs = await SharedPreferences.getInstance();
    final count = prefs.getInt(_keyLaunchCount) ?? 0;
    await prefs.setInt(_keyLaunchCount, count + 1);
  }

  /// Call this when a calculation is completed or saved
  Future<void> recordCalculationAndCheck(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final count = prefs.getInt(_keyCalculationCount) ?? 0;
    await prefs.setInt(_keyCalculationCount, count + 1);

    if (context.mounted) {
      await _checkAndShowPrompt(context, prefs);
    }
  }

  Future<void> _checkAndShowPrompt(BuildContext context, SharedPreferences prefs) async {
    if (_promptShownThisSession) return;

    final hasRated = prefs.getBool(_keyHasRated) ?? false;
    if (hasRated) return;

    final lastPromptMillis = prefs.getInt(_keyLastPromptTimestamp) ?? 0;
    if (lastPromptMillis > 0) {
      final lastPromptDate = DateTime.fromMillisecondsSinceEpoch(lastPromptMillis);
      final daysSinceLastPrompt = DateTime.now().difference(lastPromptDate).inDays;
      if (daysSinceLastPrompt < _cooldownDays) {
        return; // still in cooldown
      }
    }

    final launchCount = prefs.getInt(_keyLaunchCount) ?? 0;
    final calcCount = prefs.getInt(_keyCalculationCount) ?? 0;

    if (launchCount >= _targetLaunchCount || calcCount >= _targetCalculationCount) {
      _promptShownThisSession = true;
      _showCustomDialog(context, prefs);
    }
  }

  void _showCustomDialog(BuildContext context, SharedPreferences prefs) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text(
            'Enjoying Mortgage Calculator App?',
            style: TextStyle(
              fontFamily: 'Manrope',
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
            textAlign: TextAlign.center,
          ),
          content: const Text(
            'We value your feedback. Would you mind taking a moment to rate us?',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14),
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FilledButton.icon(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    _handlePositiveFeedback(prefs);
                  },
                  icon: const Icon(Icons.sentiment_very_satisfied_rounded),
                  label: const Text('Yes, definitely!'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF0037B1),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    _handleNegativeFeedback(context, prefs);
                  },
                  icon: const Icon(Icons.sentiment_dissatisfied_rounded),
                  label: const Text('Not really'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF434655),
                    side: const BorderSide(color: Color(0xFFC4C5D7)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    _handleRemindLater(prefs);
                  },
                  child: const Text('Remind me later', style: TextStyle(color: Color(0xFF747686))),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Future<void> _handlePositiveFeedback(SharedPreferences prefs) async {
    await prefs.setBool(_keyHasRated, true);
    try {
      final Uri playStoreUri = Uri.parse(
        'https://play.google.com/store/apps/details?id=com.reotech.mortgage_calculator',
      );
      if (await canLaunchUrl(playStoreUri)) {
        await launchUrl(playStoreUri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('Failed to request review: \$e');
    }
  }

  Future<void> _handleNegativeFeedback(BuildContext context, SharedPreferences prefs) async {
    await prefs.setInt(_keyLastPromptTimestamp, DateTime.now().millisecondsSinceEpoch);
    if (context.mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const FeedbackScreen()),
      );
    }
  }

  Future<void> _handleRemindLater(SharedPreferences prefs) async {
    await prefs.setInt(_keyLastPromptTimestamp, DateTime.now().millisecondsSinceEpoch);
  }
}

