import 'dart:async';
import 'package:flutter/foundation.dart';
import '../services/api_client.dart';

class AppNotification {
  final String id;
  final String type;
  final String title;
  final String body;
  final bool read;
  final DateTime createdAt;
  final Map<String, dynamic>? metadata;

  AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.read,
    required this.createdAt,
    this.metadata,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] ?? '',
      type: json['type'] ?? 'system',
      title: json['title'] ?? '',
      body: json['body'] ?? '',
      read: json['read'] ?? false,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }
}

class NotificationProvider extends ChangeNotifier {
  final ApiClient _api;

  List<AppNotification> _notifications = [];
  int _unreadCount = 0;
  bool _isLoading = false;
  Timer? _pollTimer;

  NotificationProvider(this._api);

  List<AppNotification> get notifications => _notifications;
  int get unreadCount => _unreadCount;
  bool get isLoading => _isLoading;

  /// Start periodic polling for new notifications (every 30s).
  void startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => refreshUnreadCount(),
    );
  }

  void stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  Future<void> loadNotifications({int limit = 50}) async {
    _isLoading = true;
    notifyListeners();

    try {
      final data = await _api.getNotifications(limit: limit);
      _notifications = data
          .map((json) =>
              AppNotification.fromJson(Map<String, dynamic>.from(json)))
          .toList();
      _unreadCount = _notifications.where((n) => !n.read).length;
    } catch (e) {
      debugPrint('Failed to load notifications: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> refreshUnreadCount() async {
    try {
      _unreadCount = await _api.getUnreadNotificationCount();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> markRead(String id) async {
    try {
      await _api.markNotificationRead(id);
      final idx = _notifications.indexWhere((n) => n.id == id);
      if (idx >= 0 && !_notifications[idx].read) {
        _notifications[idx] = AppNotification(
          id: _notifications[idx].id,
          type: _notifications[idx].type,
          title: _notifications[idx].title,
          body: _notifications[idx].body,
          read: true,
          createdAt: _notifications[idx].createdAt,
          metadata: _notifications[idx].metadata,
        );
        _unreadCount = (_unreadCount - 1).clamp(0, 999);
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> markAllRead() async {
    try {
      await _api.markAllNotificationsRead();
      _notifications = _notifications
          .map((n) => AppNotification(
                id: n.id,
                type: n.type,
                title: n.title,
                body: n.body,
                read: true,
                createdAt: n.createdAt,
                metadata: n.metadata,
              ))
          .toList();
      _unreadCount = 0;
      notifyListeners();
    } catch (_) {}
  }

  @override
  void dispose() {
    stopPolling();
    super.dispose();
  }
}
