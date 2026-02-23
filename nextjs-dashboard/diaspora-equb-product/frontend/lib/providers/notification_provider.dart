import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/widgets.dart';
import '../services/api_client.dart';
import '../services/app_snackbar_service.dart';

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

  String? get status {
    final raw = metadata?['status'];
    if (raw is! String) return null;

    final normalized = raw.trim().toLowerCase();
    switch (normalized) {
      case 'pending':
      case 'confirmed':
      case 'failed':
        return normalized;
      default:
        return null;
    }
  }

  String get kind {
    final raw = metadata?['kind'];
    if (raw is String && raw.trim().isNotEmpty) {
      return raw.trim().toLowerCase();
    }

    if (_criticalTypes.contains(type)) {
      return 'risk';
    }
    if (_transactionTypes.contains(type)) {
      return 'transaction';
    }
    return 'system';
  }

  bool get isCritical => kind == 'risk' || _criticalTypes.contains(type);

  bool get isTransaction =>
      kind == 'transaction' || _transactionTypes.contains(type);
}

const Set<String> _criticalTypes = <String>{
  'default_triggered',
  'collateral_slashed',
  'stream_frozen',
};

const Set<String> _transactionTypes = <String>{
  'transfer_built',
  'withdraw_built',
  'faucet_credited',
  'collateral_deposit_confirmed',
  'collateral_released',
  'pool_created',
  'pool_joined',
  'contribution_confirmed',
  'payout_received',
  'wallet_bound',
};

const Set<String> _groupableNotificationTypes = <String>{
  'round_closed',
  'all_contributed',
  'contribution_confirmed',
  'pool_joined',
  'pool_created',
};

const int _latestIndividualNotificationsLimit = 12;

abstract class NotificationListItem {
  DateTime get latestCreatedAt;
  bool get hasUnread;
}

class NotificationSingleItem implements NotificationListItem {
  final AppNotification notification;

  NotificationSingleItem(this.notification);

  @override
  DateTime get latestCreatedAt => notification.createdAt;

  @override
  bool get hasUnread => !notification.read;
}

class NotificationGroupItem implements NotificationListItem {
  final String groupKey;
  final String type;
  final String? poolId;
  final List<AppNotification> notifications;

  NotificationGroupItem({
    required this.groupKey,
    required this.type,
    required this.notifications,
    this.poolId,
  });

  int get count => notifications.length;

  AppNotification get latestNotification => notifications.first;

  @override
  DateTime get latestCreatedAt => latestNotification.createdAt;

  @override
  bool get hasUnread => notifications.any((n) => !n.read);
}

class NotificationDisplaySections {
  final List<NotificationSingleItem> critical;
  final List<NotificationSingleItem> latest;
  final List<NotificationListItem> grouped;

  const NotificationDisplaySections({
    required this.critical,
    required this.latest,
    required this.grouped,
  });

  bool get isEmpty => critical.isEmpty && latest.isEmpty && grouped.isEmpty;
}

class NotificationProvider extends ChangeNotifier {
  final ApiClient _api;
  final void Function(AppNotification notification)? _onCriticalNotification;

  List<AppNotification> _notifications = [];
  int _unreadCount = 0;
  bool _isLoading = false;
  Timer? _pollTimer;
  Timer? _reconnectTimer;
  Timer? _fastSyncStopTimer;
  Timer? _fastSyncPulseTimer;
  StreamSubscription<String>? _sseSubscription;
  int _reconnectAttempts = 0;
  bool _sessionActive = false;
  bool _appInForeground = true;
  final Set<String> _shownCriticalSnackbarKeys = <String>{};
  String? _cursorCreatedAt;
  String? _cursorId;

  NotificationProvider(
    this._api, {
    void Function(AppNotification notification)? onCriticalNotification,
  }) : _onCriticalNotification = onCriticalNotification;

  List<AppNotification> get notifications => _notifications;
  int get unreadCount => _unreadCount;
  bool get isLoading => _isLoading;
  NotificationDisplaySections get displaySections => _buildDisplaySections();

  void handleAuthStateChanged(bool isAuthenticated) {
    if (isAuthenticated) {
      _startSession();
    } else {
      _stopSession(clearState: true);
    }
  }

  void _startSession() {
    _sessionActive = true;
    unawaited(loadNotifications());
    unawaited(refreshUnreadCount());
    if (_appInForeground) {
      startPolling();
      _connectSse();
    }
  }

  void handleAppLifecycleChanged(AppLifecycleState state) {
    if (!_sessionActive) {
      _appInForeground = state == AppLifecycleState.resumed;
      return;
    }

    switch (state) {
      case AppLifecycleState.resumed:
        _appInForeground = true;
        startPolling();
        _connectSse();
        unawaited(_syncIncremental(limit: 50));
        unawaited(refreshUnreadCount());
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        _appInForeground = false;
        stopPolling();
        _reconnectTimer?.cancel();
        _reconnectTimer = null;
        _sseSubscription?.cancel();
        _sseSubscription = null;
        break;
    }
  }

  void triggerFastSync({Duration duration = const Duration(seconds: 45)}) {
    if (!_sessionActive) return;

    _fastSyncStopTimer?.cancel();
    _fastSyncPulseTimer?.cancel();
    _fastSyncPulseTimer = Timer.periodic(
      const Duration(seconds: 4),
      (_) {
        if (_sessionActive) {
          unawaited(_syncIncremental(limit: 20));
          unawaited(refreshUnreadCount());
        }
      },
    );
    _fastSyncStopTimer = Timer(duration, () {
      _fastSyncPulseTimer?.cancel();
      _fastSyncPulseTimer = null;
    });
  }

  /// Start periodic polling for new notifications (every 30s).
  void startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) {
        if (_sessionActive) {
          unawaited(_syncIncremental(limit: 20));
          unawaited(refreshUnreadCount());
        }
      },
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
      _rebuildCursor();
    } catch (e) {
      debugPrint('Failed to load notifications: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> refreshUnreadCount() async {
    if (!_sessionActive) return;
    try {
      _unreadCount = await _api.getUnreadNotificationCount();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> _syncIncremental({int limit = 50}) async {
    if (!_sessionActive) return;

    if (_cursorCreatedAt == null || _cursorId == null) {
      await loadNotifications(limit: limit);
      return;
    }

    var requestCreatedAt = _cursorCreatedAt;
    var requestId = _cursorId;
    var changed = false;

    for (var page = 0; page < 5; page++) {
      try {
        final response = await _api.getNotificationsIncremental(
          afterCreatedAt: requestCreatedAt,
          afterId: requestId,
          limit: limit,
        );

        final itemsRaw = (response['items'] as List?) ?? const [];
        final nextCursor = response['nextCursor'] as Map<String, dynamic>?;
        final hasMore = response['hasMore'] == true;

        if (itemsRaw.isEmpty) {
          break;
        }

        for (final item in itemsRaw) {
          final notification =
              AppNotification.fromJson(Map<String, dynamic>.from(item as Map));
          _notifications.removeWhere((n) => n.id == notification.id);
          _notifications.insert(0, notification);
          _maybeShowCriticalSnackbar(notification);
          _updateCursor(notification);
          changed = true;
        }

        if (!hasMore || nextCursor == null) {
          break;
        }

        requestCreatedAt = nextCursor['createdAt']?.toString();
        requestId = nextCursor['id']?.toString();
      } catch (error) {
        debugPrint('Incremental notification sync failed: $error');
        break;
      }
    }

    if (changed) {
      _unreadCount = _notifications.where((n) => !n.read).length;
      notifyListeners();
    }
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

  Future<void> markReadMany(Iterable<String> ids) async {
    final uniqueIds = ids.where((id) => id.trim().isNotEmpty).toSet();
    for (final id in uniqueIds) {
      await markRead(id);
    }
  }

  NotificationDisplaySections _buildDisplaySections() {
    if (_notifications.isEmpty) {
      return const NotificationDisplaySections(
        critical: <NotificationSingleItem>[],
        latest: <NotificationSingleItem>[],
        grouped: <NotificationListItem>[],
      );
    }

    final ordered = [..._notifications]..sort((a, b) {
        final dateCompare = b.createdAt.compareTo(a.createdAt);
        if (dateCompare != 0) return dateCompare;
        return b.id.compareTo(a.id);
      });

    final critical = <NotificationSingleItem>[];
    final nonCritical = <AppNotification>[];
    for (final notification in ordered) {
      if (notification.isCritical) {
        critical.add(NotificationSingleItem(notification));
      } else {
        nonCritical.add(notification);
      }
    }

    final latest = nonCritical
        .take(_latestIndividualNotificationsLimit)
        .map(NotificationSingleItem.new)
        .toList();

    final remainder = nonCritical.skip(_latestIndividualNotificationsLimit);
    final groupedBuckets = <String, List<AppNotification>>{};
    final groupedSectionItems = <NotificationListItem>[];

    for (final notification in remainder) {
      if (!_groupableNotificationTypes.contains(notification.type)) {
        groupedSectionItems.add(NotificationSingleItem(notification));
        continue;
      }

      final groupKey = _groupKeyFor(notification);
      groupedBuckets.putIfAbsent(groupKey, () => <AppNotification>[]);
      groupedBuckets[groupKey]!.add(notification);
    }

    for (final entry in groupedBuckets.entries) {
      final bucket = entry.value
        ..sort((a, b) {
          final dateCompare = b.createdAt.compareTo(a.createdAt);
          if (dateCompare != 0) return dateCompare;
          return b.id.compareTo(a.id);
        });

      if (bucket.length <= 1) {
        groupedSectionItems.add(NotificationSingleItem(bucket.first));
        continue;
      }

      groupedSectionItems.add(
        NotificationGroupItem(
          groupKey: entry.key,
          type: bucket.first.type,
          poolId: _poolIdFor(bucket.first),
          notifications: bucket,
        ),
      );
    }

    groupedSectionItems.sort((a, b) {
      final dateCompare = b.latestCreatedAt.compareTo(a.latestCreatedAt);
      if (dateCompare != 0) return dateCompare;
      if (a is NotificationSingleItem && b is NotificationSingleItem) {
        return b.notification.id.compareTo(a.notification.id);
      }
      return 0;
    });

    return NotificationDisplaySections(
      critical: critical,
      latest: latest,
      grouped: groupedSectionItems,
    );
  }

  String _groupKeyFor(AppNotification notification) {
    final poolId = _poolIdFor(notification);
    if (poolId == null || poolId.isEmpty) {
      return notification.type;
    }
    return '${notification.type}::$poolId';
  }

  String? _poolIdFor(AppNotification notification) {
    final raw = notification.metadata?['poolId'];
    if (raw == null) return null;
    final value = raw.toString().trim();
    return value.isEmpty ? null : value;
  }

  void _connectSse() {
    if (!_sessionActive || !_appInForeground) return;
    _sseSubscription?.cancel();
    _sseSubscription = null;
    _reconnectTimer?.cancel();

    unawaited(_connectSseInternal());
  }

  Future<void> _connectSseInternal() async {
    if (!_sessionActive || !_appInForeground) return;

    try {
      final lineStream = await _api.openNotificationEventStream();
      _reconnectAttempts = 0;

      _sseSubscription = lineStream.listen(
        _handleSseLine,
        onError: (error) {
          debugPrint('Notification SSE error: $error');
          _scheduleReconnect();
        },
        onDone: _scheduleReconnect,
        cancelOnError: true,
      );
    } catch (error) {
      debugPrint('Notification SSE connect failed: $error');
      _scheduleReconnect();
    }
  }

  void _handleSseLine(String line) {
    if (!_sessionActive) return;

    final trimmed = line.trim();
    if (trimmed.isEmpty || trimmed.startsWith(':')) return;
    if (!trimmed.startsWith('data:')) return;

    final rawPayload = trimmed.substring(5).trim();
    if (rawPayload.isEmpty) return;

    try {
      dynamic decoded = jsonDecode(rawPayload);
      if (decoded is String) {
        decoded = jsonDecode(decoded);
      }
      if (decoded is! Map) {
        return;
      }

      final notification =
          AppNotification.fromJson(Map<String, dynamic>.from(decoded));

      _notifications.removeWhere((n) => n.id == notification.id);
      _notifications.insert(0, notification);
      _updateCursor(notification);
      _unreadCount = _notifications.where((n) => !n.read).length;
      _maybeShowCriticalSnackbar(notification);
      notifyListeners();
    } catch (error) {
      debugPrint('Failed to parse SSE notification: $error');
    }
  }

  void _maybeShowCriticalSnackbar(AppNotification notification) {
    if (notification.read) return;
    if (!notification.isCritical) return;

    final dedupeKey = 'critical:${notification.id}';
    if (_shownCriticalSnackbarKeys.contains(dedupeKey)) return;

    _shownCriticalSnackbarKeys.add(dedupeKey);
    if (_onCriticalNotification != null) {
      _onCriticalNotification.call(notification);
      return;
    }

    AppSnackbarService.instance.warning(
      title: notification.title,
      message: notification.body,
      dedupeKey: dedupeKey,
      duration: const Duration(seconds: 6),
    );
  }

  void _scheduleReconnect() {
    _sseSubscription?.cancel();
    _sseSubscription = null;
    if (!_sessionActive || !_appInForeground) return;

    unawaited(_syncIncremental(limit: 20));
    unawaited(refreshUnreadCount());

    _reconnectTimer?.cancel();
    _reconnectAttempts += 1;
    final seconds = math.min(30, math.pow(2, _reconnectAttempts).toInt());

    _reconnectTimer = Timer(Duration(seconds: seconds), () {
      _connectSse();
    });
  }

  void _stopSession({required bool clearState}) {
    _sessionActive = false;
    stopPolling();
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _fastSyncStopTimer?.cancel();
    _fastSyncStopTimer = null;
    _fastSyncPulseTimer?.cancel();
    _fastSyncPulseTimer = null;
    _sseSubscription?.cancel();
    _sseSubscription = null;
    _reconnectAttempts = 0;

    if (clearState) {
      _notifications = [];
      _unreadCount = 0;
      _cursorCreatedAt = null;
      _cursorId = null;
      _shownCriticalSnackbarKeys.clear();
      notifyListeners();
    }
  }

  void _rebuildCursor() {
    _cursorCreatedAt = null;
    _cursorId = null;
    for (final notification in _notifications) {
      _updateCursor(notification);
    }
  }

  void _updateCursor(AppNotification notification) {
    final currentCreatedAt = _cursorCreatedAt;
    final currentId = _cursorId;
    if (currentCreatedAt == null || currentId == null) {
      _cursorCreatedAt = notification.createdAt.toIso8601String();
      _cursorId = notification.id;
      return;
    }

    final currentDate = DateTime.tryParse(currentCreatedAt);
    if (currentDate == null || notification.createdAt.isAfter(currentDate)) {
      _cursorCreatedAt = notification.createdAt.toIso8601String();
      _cursorId = notification.id;
      return;
    }

    if (notification.createdAt.isAtSameMomentAs(currentDate) &&
        notification.id.compareTo(currentId) > 0) {
      _cursorId = notification.id;
    }
  }

  @override
  void dispose() {
    _stopSession(clearState: false);
    super.dispose();
  }
}
