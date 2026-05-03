import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationItem {
  final String id;
  final String title;
  final String body;
  final DateTime timestamp;
  final Map<String, dynamic>? data;
  bool isRead;

  NotificationItem({
    required this.id,
    required this.title,
    required this.body,
    required this.timestamp,
    this.data,
    this.isRead = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'body': body,
        'timestamp': timestamp.toIso8601String(),
        'data': data,
        'isRead': isRead,
      };

  factory NotificationItem.fromJson(Map<String, dynamic> json) => NotificationItem(
        id: json['id'],
        title: json['title'],
        body: json['body'],
        timestamp: DateTime.parse(json['timestamp']),
        data: json['data'],
        isRead: json['isRead'] ?? false,
      );
}

class NotificationProvider extends ChangeNotifier {
  final SharedPreferences _prefs;
  List<NotificationItem> _notifications = [];
  static const String _storageKey = 'cached_notifications';

  NotificationProvider(this._prefs) {
    _loadFromPrefs();
  }

  List<NotificationItem> get notifications => List.unmodifiable(_notifications);
  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  void _loadFromPrefs() {
    final String? stored = _prefs.getString(_storageKey);
    if (stored != null) {
      try {
        final List<dynamic> decoded = json.decode(stored);
        _notifications = decoded.map((item) => NotificationItem.fromJson(item)).toList();
        // Sort by timestamp descending
        _notifications.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      } catch (e) {
        debugPrint('⚠️ Failed to load notifications: $e');
        _notifications = [];
      }
    }
  }

  void reload() {
    _loadFromPrefs();
    notifyListeners();
  }

  Future<void> _saveToPrefs() async {
    final String encoded = json.encode(_notifications.map((n) => n.toJson()).toList());
    await _prefs.setString(_storageKey, encoded);
  }

  void addNotification(String title, String body, {Map<String, dynamic>? data}) {
    final newItem = NotificationItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      body: body,
      timestamp: DateTime.now(),
      data: data,
    );
    _notifications.insert(0, newItem);
    _saveToPrefs();
    notifyListeners();
  }

  void markAsRead(String id) {
    final index = _notifications.indexWhere((n) => n.id == id);
    if (index != -1 && !_notifications[index].isRead) {
      _notifications[index].isRead = true;
      _saveToPrefs();
      notifyListeners();
    }
  }

  void markAllAsRead() {
    bool changed = false;
    for (var n in _notifications) {
      if (!n.isRead) {
        n.isRead = true;
        changed = true;
      }
    }
    if (changed) {
      _saveToPrefs();
      notifyListeners();
    }
  }

  void deleteNotification(String id) {
    _notifications.removeWhere((n) => n.id == id);
    _saveToPrefs();
    notifyListeners();
  }

  void clearAll() {
    _notifications.clear();
    _saveToPrefs();
    notifyListeners();
  }
}
