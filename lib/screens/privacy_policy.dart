// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import '../widgets/gradient_app_bar.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/constants/theme_extensions.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PrivacyPolicyScreen
// ─────────────────────────────────────────────────────────────────────────────
class PrivacyPolicyScreen extends StatefulWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  State<PrivacyPolicyScreen> createState() => _PrivacyPolicyScreenState();
}

class _PrivacyPolicyScreenState extends State<PrivacyPolicyScreen> {
  // ─────────────────────────────────────────────────────────────────────────
  // URL helpers
  // ─────────────────────────────────────────────────────────────────────────

  /// Opens an external link directly — no interstitial on a legal/policy
  /// screen per AdMob policy (ads must not appear on privacy/legal pages).
  Future<void> _launchExternalUrl(String url) async {
    await _openUrl(url);
  }

  Future<void> _openUrl(String url) async {
 Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open link. Please try again.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  /// mailto: opens the Mail app — not an external browser exit.
  Future<void> _launchMailto(String email) async {
    await _openUrl('mailto:$email');
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,

      // ── AppBar ─────────────────────────────────────────────────────────────
      appBar: GradientAppBar(
        title: Text(
          'Privacy Policy',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1.0),
          child: SizedBox(
            height: 1.0,
            child: Divider(height: 1.0, color: Colors.white24),
          ),
        ),
      ),

      // ── Scrollable body ────────────────────────────────────────────────────
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ────────────────────────────────────────────────────
              Text(
                'Privacy Policy – Mortgage Calculator',
                style: GoogleFonts.inter(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Last updated: March 10, 2026',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Mortgage Calculator ("we", "our", or "us") operates the '
                'Mortgage Calculator mobile application. This page informs '
                'users about our policies regarding the collection, use, and '
                'disclosure of information when using our app.',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  height: 1.6,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'By using this application, you agree to the collection and '
                'use of information in accordance with this policy.',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  height: 1.6,
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 40),

              // ── Section 1 ─────────────────────────────────────────────────
              _buildSectionTitle('1. Information Collection and Use'),
              _buildParagraph(
                'Mortgage Calculator is designed as a financial utility '
                'application that allows users to calculate mortgage '
                'payments, loan interest, and repayment schedules.',
              ),
              _buildParagraph(
                'The app does not require account registration and does not '
                'collect personal information such as name, email, or phone '
                'number directly from users.',
              ),
              _buildParagraph(
                'However, some information may be collected automatically '
                'through third-party services integrated into the app.',
              ),
              _buildParagraph(
                'Information collected automatically may include:',
              ),
              _buildBulletPoints(const [
                'Device type and device model',
                'Operating system version',
                'App usage statistics',
                'Crash logs and diagnostic information',
                'Advertising identifiers (such as Google Advertising ID)',
              ]),
              _buildParagraph(
                'This information is used only to improve the functionality, '
                'performance, and reliability of the application.',
              ),

              // ── Section 2 ─────────────────────────────────────────────────
              _buildSectionTitle('2. Advertising'),
              _buildParagraph(
                'This application displays advertisements provided by '
                'third-party advertising networks including:',
              ),
              _buildBulletPoints(const ['Google AdMob']),
              _buildParagraph(
                'These services may collect anonymous data such as:',
              ),
              _buildBulletPoints(const [
                'Advertising ID',
                'Device information',
                'Ad interaction information',
                'Approximate location (non-precise)',
              ]),
              _buildParagraph(
                'This information helps display relevant advertisements and '
                'measure advertising performance.',
              ),
              const SizedBox(height: 8),
              _buildInlineLink(
                label: 'Learn more about how Google uses data:',
                url: 'https://policies.google.com/technologies/ads',
              ),
              _buildParagraph(
                'Users can reset or disable the advertising ID from their '
                'device settings.',
              ),

              // ── Section 3 ─────────────────────────────────────────────────
              _buildSectionTitle('3. Analytics and Performance Monitoring'),
              _buildParagraph(
                'To improve the performance and reliability of the '
                'application, we may use analytics services such as:',
              ),
              _buildBulletPoints(const [
                'Firebase Analytics',
                'Firebase Crashlytics',
              ]),
              _buildParagraph(
                'These services help us understand how users interact with '
                'the app and identify technical errors.',
              ),
              _buildParagraph('Information collected may include:'),
              _buildBulletPoints(const [
                'App usage data',
                'Device information',
                'Crash reports and diagnostics',
              ]),
              _buildParagraph(
                'This data is collected anonymously and cannot be used to '
                'identify individual users.',
              ),

              // ── Section 4 ─────────────────────────────────────────────────
              _buildSectionTitle('4. Push Notifications'),
              _buildParagraph(
                'The application may send push notifications using:',
              ),
              _buildBulletPoints(const ['Firebase Cloud Messaging']),
              _buildParagraph('Notifications may include:'),
              _buildBulletPoints(const [
                'App updates',
                'Feature announcements',
                'Important information related to the application',
              ]),
              _buildParagraph(
                'Users can disable notifications at any time through their '
                'device settings.',
              ),

              // ── Section 5 ─────────────────────────────────────────────────
              _buildSectionTitle('5. Data Sharing'),
              _buildParagraph(
                'We do not sell, trade, or rent personal information to '
                'third parties.',
              ),
              _buildParagraph(
                'However, data may be processed by trusted third-party '
                'service providers used by the app for:',
              ),
              _buildBulletPoints(const [
                'Advertising',
                'Analytics',
                'Crash reporting',
                'Push notifications',
              ]),
              _buildParagraph(
                'These services operate under their own privacy policies and '
                'security practices.',
              ),

              // ── Section 6 ─────────────────────────────────────────────────
              _buildSectionTitle('6. Data Security'),
              _buildParagraph(
                'We value your trust in providing information to use the app '
                'and strive to use commercially acceptable means to protect '
                'it. However, no method of transmission over the internet or '
                'electronic storage is completely secure.',
              ),

              // ── Section 7 ─────────────────────────────────────────────────
              _buildSectionTitle("7. Children\u2019s Privacy"),
              _buildParagraph(
                'This application is not intended for children under the '
                'age of 13.',
              ),
              _buildParagraph(
                'We do not knowingly collect personally identifiable '
                'information from children. If we discover that a child has '
                'provided personal information, we will delete such '
                'information immediately.',
              ),

              // ── Section 8 ─────────────────────────────────────────────────
              _buildSectionTitle('8. Links to Third-Party Services'),
              _buildParagraph(
                'The app may contain links to external websites or services. '
                'We are not responsible for the privacy practices of '
                'third-party services.',
              ),
              _buildParagraph(
                'Users are encouraged to review the privacy policies of '
                'those services.',
              ),

              // ── Section 9 ─────────────────────────────────────────────────
              _buildSectionTitle('9. Changes to This Privacy Policy'),
              _buildParagraph(
                'We may update this Privacy Policy periodically. When we do, '
                'we will update the "Last updated" date on this page.',
              ),
              _buildParagraph(
                'Users are advised to review this page regularly for any '
                'changes.',
              ),

              // ── Section 10 ────────────────────────────────────────────────
              _buildSectionTitle('10. Contact Us'),
              _buildParagraph(
                'If you have any questions or suggestions regarding this '
                'Privacy Policy, please contact us:',
              ),
              const SizedBox(height: 16),
              _buildContactCard('ReoTech', 'contactreotechy@gmail.com'),

              // ── Legal & Resources ─────────────────────────────────────────
              const SizedBox(height: 48),
              _buildSectionTitle('Legal & Resources'),
              _buildExternalLinkTile(
                title: 'About the App',
                url:
                    'https://mortgagecalculatorreotech.blogspot.com/p/about-app-mortgage-calculator.html',
                icon: Icons.info_outline,
              ),
              _buildExternalLinkTile(
                title: 'Terms of Service',
                url:
                    'https://mortgagecalculatorreotech.blogspot.com/p/terms-of-service-of-mortgage-calculator.html',
                icon: Icons.description_outlined,
              ),
              _buildExternalLinkTile(
                title: 'Privacy Policy',
                url:
                    'https://mortgagecalculatorreotech.blogspot.com/p/privacy-policy-of-mortgage-calculator.html',
                icon: Icons.security_outlined,
              ),
              _buildExternalLinkTile(
                title: 'Contact Us',
                url:
                    'https://mortgagecalculatorreotech.blogspot.com/p/contact-us-mortgage-calculator.html',
                icon: Icons.contact_support_outlined,
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Content widgets
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 32, bottom: 16),
      child: Text(
        title,
        style: GoogleFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }

  Widget _buildParagraph(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 16,
          height: 1.6,
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
    );
  }

  Widget _buildBulletPoints(List<String> points) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16, left: 8),
      child: Column(
        children: points.map((point) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '• ',
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                  ),
                ),
                Expanded(
                  child: Text(
                    point,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      height: 1.6,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildInlineLink({required String label, required String url}) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 16,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          GestureDetector(
            onTap: () => _launchExternalUrl(url),
            child: Text(
              url,
              style: GoogleFonts.inter(
                fontSize: 15,
                color: colorScheme.primary,
                decoration: TextDecoration.underline,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactCard(String name, String email) {
    final colorScheme = Theme.of(context).colorScheme;
    final dividerColor = Theme.of(context).dividerColor;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: dividerColor),
        boxShadow: [
          BoxShadow(
            color: context.textPrimary.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.business, color: colorScheme.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                'Developer: $name',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.email_outlined, color: colorScheme.primary, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: GestureDetector(
                  onTap: () => _launchMailto(email),
                  child: Text(
                    email,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildExternalLinkTile({
    required String title,
    required String url,
    required IconData icon,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final dividerColor = Theme.of(context).dividerColor;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _launchExternalUrl(url),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            border: Border.all(color: dividerColor),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(icon, color: colorScheme.primary, size: 22),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: colorScheme.onSurface,
                  ),
                ),
              ),
              Icon(
                Icons.open_in_new,
                color: colorScheme.onSurfaceVariant,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
