import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'privacy_policy.dart';
import 'currency_selection_screen.dart';
import 'feedback_screen.dart'; // ← NEW import
import '../providers/settings_provider.dart';

import 'package:share_plus/share_plus.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:package_info_plus/package_info_plus.dart';

// ─────────────────────────────────────────────────────────────────────────────
// CHANGES IN THIS FILE
// ─────────────────────────────────────────────────────────────────────────────
//
// ADDED → feedback_screen.dart import
// ADDED → 'Send Feedback' tile in the ABOUT section
//   • Placed between 'Share with Friends' and 'Privacy Policy'
//   • Navigates to FeedbackScreen via MaterialPageRoute
//   • Uses Icons.feedback_outlined for clear visual identity
//
// ALL OTHER CODE UNCHANGED.
// ─────────────────────────────────────────────────────────────────────────────

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final List<String> _themes = ['Emerald', 'Navy'];

  bool _notificationsEnabled = true;

  String _appVersion = '1.0.0';

  // ── Lifecycle ────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<SettingsProvider>(context, listen: false).loadProfile();
    });
    _loadAppVersion();
  }

  Future<void> _loadAppVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() {
          _appVersion = packageInfo.version;
        });
      }
    } catch (_) {}
  }


  // ── Profile ──────────────────────────────────────────────────────────────────

  void _showEditProfileDialog() {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final nameController = TextEditingController(text: settings.userName);
    final emailController = TextEditingController(text: settings.userEmail);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Edit Profile',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Name'),
              style: GoogleFonts.inter(),
            ),
            TextField(
              controller: emailController,
              decoration: const InputDecoration(labelText: 'Email'),
              keyboardType: TextInputType.emailAddress,
              style: GoogleFonts.inter(),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Provider.of<SettingsProvider>(
                context,
                listen: false,
              ).saveProfile(nameController.text, emailController.text);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
            ),
            child: Text(
              'Save',
              style: GoogleFonts.inter(
                color: Theme.of(context).colorScheme.onPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message, style: GoogleFonts.inter())),
    );
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final userName = settings.userName;
    final userEmail = settings.userEmail;

    final double bottomPadding = 16;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Settings',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
            fontSize: 24,
          ),
        ),
        elevation: 0,
        backgroundColor: Theme.of(context).colorScheme.surface,
        centerTitle: false,
        toolbarHeight: 80,
      ),

      body: SingleChildScrollView(
        padding: EdgeInsets.only(bottom: bottomPadding),
        child: Column(
          children: [
            // ── Profile section ──────────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              color: Theme.of(context).colorScheme.surface,
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            userName.isNotEmpty
                                ? userName.substring(0, 1).toUpperCase()
                                : 'MC',
                            style: GoogleFonts.inter(
                              color: Theme.of(context).colorScheme.onPrimary,
                              fontSize: 24,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              userName.isNotEmpty ? userName : 'Edit User Name',
                              style: GoogleFonts.inter(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                            Text(
                              userEmail.isNotEmpty
                                  ? userEmail
                                  : 'email@example.com',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: _showEditProfileDialog,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: BorderSide(color: Theme.of(context).dividerColor),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        'Edit Profile',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ── Preferences ──────────────────────────────────────────────
            _buildSectionHeader('PREFERENCES'),
            _buildSettingsGroup([
              _buildSettingSwitchTile(
                Icons.notifications_outlined,
                'Notifications',
                _notificationsEnabled,
                (val) {
                  setState(() => _notificationsEnabled = val);
                  _showSnackBar(
                    'Notifications ${val ? "enabled" : "disabled"}',
                  );
                },
              ),
              _buildDivider(),
              _buildSettingNavTile(
                Icons.attach_money,
                'Currency',
                '${settings.currencyCode} (${settings.currencySymbol})',
                () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const CurrencySelectionScreen(),
                  ),
                ),
              ),
              _buildDivider(),
              _buildSettingNavTile(
                Icons.palette_outlined,
                'Theme',
                settings.themeName,
                () {
                  int currentIndex = _themes.indexOf(settings.themeName);
                  if (currentIndex == -1) currentIndex = 0;
                  final int nextIndex = (currentIndex + 1) % _themes.length;
                  settings.setTheme(_themes[nextIndex]);
                  _showSnackBar('Theme changed to ${_themes[nextIndex]}');
                },
              ),
            ]),

            const SizedBox(height: 24),

            // ── About ────────────────────────────────────────────────────
            _buildSectionHeader('ABOUT'),
            _buildSettingsGroup([
              _buildSettingNavTile(
                Icons.star_outline_rounded,
                'Rate Us',
                '',
                () async {
                  try {
 InAppReview inAppReview = InAppReview.instance;
                    await inAppReview.openStoreListing(
                      appStoreId: 'com.reotech.mortgage_calculator',
                    );
                  } catch (e) {
                    _showSnackBar('Unable to open store for rating.');
                  }
                },
              ),
              _buildDivider(),
              _buildSettingNavTile(
                Icons.share_outlined,
                'Share with Friends',
                '',
                () {
                  const String shareMessage =
                      'Calculate your monthly mortgage payments, loan interest, and repayment schedules with USA Mortgage & Loan Calculator Pro!\n\n'
                      'Download now on Google Play Store:\n'
                      'https://play.google.com/store/apps/details?id=com.reotech.mortgage_calculator';
                  SharePlus.instance.share(ShareParams(text: shareMessage));
                },
              ),
              _buildDivider(),

              // ── NEW: Send Feedback tile ─────────────────────────────
              _buildSettingNavTile(
                Icons.feedback_outlined,
                'Send Feedback',
                '',
                () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const FeedbackScreen()),
                ),
              ),
              _buildDivider(),

              _buildSettingNavTile(
                Icons.policy_outlined,
                'Privacy Policy',
                '',
                () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const PrivacyPolicyScreen(),
                  ),
                ),
              ),
            ]),

            const SizedBox(height: 32),

            // ── Version ──────────────────────────────────────────────────
            Text(
              'Version $_appVersion',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // ── Helper widgets ────────────────────────────────────────────────────────────

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 24, bottom: 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsGroup(List<Widget> children) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildDivider() {
    return Divider(
      height: 1,
      indent: 56,
      color: Theme.of(context).dividerColor,
    );
  }

  Widget _buildSettingSwitchTile(
    IconData icon,
    String title,
    bool value,
    Function(bool) onChanged,
  ) {
    return ListTile(
      leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
      title: Text(
        title,
        style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500),
      ),
      trailing: Switch.adaptive(
        value: value,
        onChanged: onChanged,
        activeTrackColor: Theme.of(context).colorScheme.primary,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }

  Widget _buildSettingNavTile(
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap,
  ) {
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
      title: Text(
        title,
        style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (subtitle.isNotEmpty)
            Text(
              subtitle,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          const SizedBox(width: 4),
          Icon(
            Icons.chevron_right,
            size: 20,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ],
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }
}
