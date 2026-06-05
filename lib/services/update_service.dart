import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter/foundation.dart';

/// Model that describes the result of a version check.
class UpdateInfo {
  final String currentVersion;
  final String latestVersion;
  final bool updateRequired; // forced update — user MUST update
  final bool updateAvailable; // soft update — user can dismiss
  final String updateMessage; // custom message shown in dialog
  final String? announcementText; // optional persistent promo/announcement

  const UpdateInfo({
    required this.currentVersion,
    required this.latestVersion,
    required this.updateRequired,
    required this.updateAvailable,
    required this.updateMessage,
    this.announcementText,
  });
}

/// Checks the installed app version against Firebase Remote Config values
/// to determine if an update should be shown to the user.
class UpdateService {
  static const String _keyLatestVersionName = 'latest_version_name';
  static const String _keyLatestVersionCode = 'latest_version_code';
  static const String _keyUpdateRequired = 'update_required';
  static const String _keyUpdateMessage = 'update_message';
  static const String _keyPromoBannerText = 'promo_banner_text';

  /// Set sensible defaults so the app works even before Remote Config is set.
  static Map<String, dynamic> get remoteConfigDefaults => {
    _keyLatestVersionName: '3.0.1',
    _keyLatestVersionCode: 10,
    _keyUpdateRequired: false,
    _keyUpdateMessage:
        'A new version of Mortgage & Loan Calculator - DTI is available with improvements and bug fixes. Update now for the best experience.',
  };

  /// Fetches current device version and compares with Remote Config.
  static Future<UpdateInfo> checkForUpdate() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final remoteConfig = FirebaseRemoteConfig.instance;

      // Use existing/cached remote config values (updated in background by FirebaseService)
      final currentVersionName = packageInfo.version;
      final currentVersionCode = int.tryParse(packageInfo.buildNumber) ?? 1;

      final latestVersionName = remoteConfig.getString(_keyLatestVersionName);
      final latestVersionCode = remoteConfig.getInt(_keyLatestVersionCode);
      final updateRequired = remoteConfig.getBool(_keyUpdateRequired);
      final updateMessage = remoteConfig.getString(_keyUpdateMessage);
      final announcementText = remoteConfig.getString(_keyPromoBannerText);

      final bool updateAvailable =
          latestVersionCode > currentVersionCode ||
          _isNewer(latestVersionName, currentVersionName);

      return UpdateInfo(
        currentVersion: currentVersionName,
        latestVersion: latestVersionName,
        updateRequired: updateRequired && updateAvailable,
        updateAvailable: updateAvailable,
        updateMessage: updateMessage,
        announcementText: announcementText.isNotEmpty ? announcementText : null,
      );
    } catch (e) {
      debugPrint("⚠️ Update check failed: $e");
      return UpdateInfo(
        currentVersion: "1.0.0",
        latestVersion: "1.0.0",
        updateRequired: false,
        updateAvailable: false,
        updateMessage: "",
      );
    }
  }

  /// Returns true if [remote] is a higher semantic version than [current].
  static bool _isNewer(String remote, String current) {
    try {
      final r = remote.trim().split('.').map(int.parse).toList();
      final c = current.trim().split('.').map(int.parse).toList();

      for (int i = 0; i < 3; i++) {
        final rv = i < r.length ? r[i] : 0;
        final cv = i < c.length ? c[i] : 0;

        if (rv > cv) return true;
        if (rv < cv) return false;
      }
      return false;
    } catch (_) {
      return false;
    }
  }
}
