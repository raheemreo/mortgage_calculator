import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Shows an in-app update dialog.
///
/// [isForced] = true  → no dismiss button, blocks the app until updated.
/// [isForced] = false → user can dismiss and continue using the app.
///
/// [storeUrl] should be your Google Play Store listing URL.
class UpdateDialog extends StatelessWidget {
  final String latestVersion;
  final String currentVersion;
  final String message;
  final bool isForced;
  final String storeUrl;

  const UpdateDialog({
    super.key,
    required this.latestVersion,
    required this.currentVersion,
    required this.message,
    this.isForced = false,
    this.storeUrl =
        'https://play.google.com/store/apps/details?id=com.reotech.mortgage_calculator',
  });

  /// Convenient static helper — shows the dialog from any context.
  static Future<void> show(
    BuildContext context, {
    required String latestVersion,
    required String currentVersion,
    required String message,
    required bool isForced,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: !isForced,
      builder: (_) => UpdateDialog(
        latestVersion: latestVersion,
        currentVersion: currentVersion,
        message: message,
        isForced: isForced,
      ),
    );
  }

  Future<void> _openStore() async {
    final uri = Uri.parse(storeUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Prevent back-button dismiss for forced updates
      canPop: !isForced,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon badge
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0B3D91), Color(0xFF1565C0)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0B3D91).withValues(alpha: 0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.system_update_rounded,
                  color: Colors.white,
                  size: 36,
                ),
              ),
              const SizedBox(height: 20),

              // Title
              Text(
                isForced ? 'Update Required' : 'Update Available',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 6),

              // Version badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF0B3D91).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'v$currentVersion → v$latestVersion',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0B3D91),
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Message
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF475569),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),

              // Update button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _openStore,
                  icon: const Icon(Icons.download_rounded, size: 20),
                  label: const Text(
                    'Update Now',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0B3D91),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                ),
              ),

              // Dismiss (soft update only)
              if (!isForced) ...[
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text(
                    'Maybe Later',
                    style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}




