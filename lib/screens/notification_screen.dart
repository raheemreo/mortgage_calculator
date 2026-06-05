import 'package:flutter/material.dart';
import '../widgets/gradient_app_bar.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/notification_provider.dart';
import '../services/update_service.dart';
import '../widgets/update_dialog.dart';
import '../core/constants/theme_extensions.dart';

class NotificationScreen extends StatelessWidget {
  const NotificationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<NotificationProvider>();
    final notifications = provider.notifications;

    return Scaffold(
      backgroundColor: context.pageBackground,
      appBar: GradientAppBar(
        title: Text(
          'Notifications',
          style: GoogleFonts.manrope(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        actions: [
          if (notifications.isNotEmpty)
            TextButton(
              onPressed: () => _confirmClearAll(context, provider),
              child: const Text(
                'Clear All',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
      body: notifications.isEmpty
          ? _buildEmptyState(context)
          : ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: notifications.length,
              itemBuilder: (context, index) {
                final item = notifications[index];
                return _buildNotificationTile(context, provider, item);
              },
            ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: context.isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.notifications_none_rounded,
              size: 64,
              color: context.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No Notifications Yet',
            style: GoogleFonts.manrope(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: context.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'We will notify you about updates and news.',
            style: TextStyle(color: context.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationTile(
    BuildContext context,
    NotificationProvider provider,
    NotificationItem item,
  ) {
    final timeStr = DateFormat('MMM d, h:mm a').format(item.timestamp);

    return Dismissible(
      key: Key(item.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.redAccent,
        child: Icon(Icons.delete, color: context.cs.surface),
      ),
      onDismissed: (_) => provider.deleteNotification(item.id),
      child: InkWell(
        onTap: () => _handleNotificationTap(context, provider, item),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: item.isRead ? Colors.transparent : context.cs.primary.withValues(alpha: 0.05),
            border: Border(bottom: BorderSide(color: context.borderColor)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: item.isRead
                      ? (context.isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9))
                      : (context.isDark ? const Color(0xFF1E3A8A) : const Color(0xFFDBEAFE)),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.notifications_active_rounded,
                  color: item.isRead
                      ? context.textSecondary
                      : (context.isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB)),
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            item.title,
                            style: TextStyle(
                              fontWeight: item.isRead
                                  ? FontWeight.w600
                                  : FontWeight.w800,
                              fontSize: 15,
                              color: context.textPrimary,
                            ),
                          ),
                        ),
                        if (!item.isRead)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: context.isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB),
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.body,
                      style: TextStyle(
                        fontSize: 14,
                        color: context.textSecondary,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      timeStr,
                      style: TextStyle(
                        fontSize: 11,
                        color: context.textSecondary.withValues(alpha: 0.7),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleNotificationTap(
    BuildContext context,
    NotificationProvider provider,
    NotificationItem item,
  ) {
    // 1. Mark as read
    provider.markAsRead(item.id);

    // 2. Extract action from data or title
    final data = item.data;
    final titleMatch = item.title.toLowerCase().contains('update');
    final bodyMatch = item.body.toLowerCase().contains('update');

    if (titleMatch || bodyMatch) {
      _triggerUpdateCheck(context);
      return;
    }

    if (data != null && data.containsKey('screen')) {
      final screen = data['screen'].toString().toLowerCase();
      debugPrint('📍 Notification tap: Deep-linking to $screen');
      _navigateToScreen(context, screen);
    }
  }

  Future<void> _triggerUpdateCheck(BuildContext context) async {
    // Show a loading indicator
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Checking for updates...')));

    final info = await UpdateService.checkForUpdate();
    if (context.mounted) {
      if (info.updateAvailable) {
        UpdateDialog.show(
          context,
          latestVersion: info.latestVersion,
          currentVersion: info.currentVersion,
          message: info.updateMessage,
          isForced: info.updateRequired,
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You are on the latest version.')),
        );
      }
    }
  }

  void _navigateToScreen(BuildContext context, String screen) {
    // Add logic here to navigate to specific screens based on 'screen' parameter
    // Example: if (screen == 'settings') Navigator.push(...)
    debugPrint('Navigation requested for: $screen');
  }

  void _confirmClearAll(BuildContext context, NotificationProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All?'),
        content: const Text(
          'This will delete all your notifications permanently.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              provider.clearAll();
              Navigator.pop(context);
            },
            child: const Text('Clear All', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}