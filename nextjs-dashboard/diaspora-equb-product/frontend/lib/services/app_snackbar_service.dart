import 'dart:collection';
import 'package:flutter/material.dart';
import '../config/theme.dart';

enum AppSnackType { success, error, warning, info }

class AppSnackMessage {
  final AppSnackType type;
  final String message;
  final String? title;
  final Duration duration;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? dedupeKey;

  const AppSnackMessage({
    required this.type,
    required this.message,
    this.title,
    this.duration = const Duration(seconds: 4),
    this.actionLabel,
    this.onAction,
    this.dedupeKey,
  });
}

class AppSnackbarService {
  AppSnackbarService._();

  static final AppSnackbarService instance = AppSnackbarService._();

  final GlobalKey<ScaffoldMessengerState> messengerKey =
      GlobalKey<ScaffoldMessengerState>();

  final Queue<AppSnackMessage> _queue = Queue<AppSnackMessage>();
  final Map<String, DateTime> _dedupeTimestamps = <String, DateTime>{};

  bool _isShowing = false;
  Duration dedupeWindow = const Duration(seconds: 5);

  void success({
    required String message,
    String? title,
    Duration duration = const Duration(seconds: 4),
    String? dedupeKey,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    _enqueue(
      AppSnackMessage(
        type: AppSnackType.success,
        title: title,
        message: message,
        duration: duration,
        dedupeKey: dedupeKey,
        actionLabel: actionLabel,
        onAction: onAction,
      ),
    );
  }

  void error({
    required String message,
    String? title,
    Duration duration = const Duration(seconds: 5),
    String? dedupeKey,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    _enqueue(
      AppSnackMessage(
        type: AppSnackType.error,
        title: title,
        message: message,
        duration: duration,
        dedupeKey: dedupeKey,
        actionLabel: actionLabel,
        onAction: onAction,
      ),
    );
  }

  void warning({
    required String message,
    String? title,
    Duration duration = const Duration(seconds: 5),
    String? dedupeKey,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    _enqueue(
      AppSnackMessage(
        type: AppSnackType.warning,
        title: title,
        message: message,
        duration: duration,
        dedupeKey: dedupeKey,
        actionLabel: actionLabel,
        onAction: onAction,
      ),
    );
  }

  void info({
    required String message,
    String? title,
    Duration duration = const Duration(seconds: 4),
    String? dedupeKey,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    _enqueue(
      AppSnackMessage(
        type: AppSnackType.info,
        title: title,
        message: message,
        duration: duration,
        dedupeKey: dedupeKey,
        actionLabel: actionLabel,
        onAction: onAction,
      ),
    );
  }

  void _enqueue(AppSnackMessage snack) {
    if (_isDeduped(snack)) {
      return;
    }

    _queue.add(snack);
    _drainQueue();
  }

  bool _isDeduped(AppSnackMessage snack) {
    final dedupeKey = snack.dedupeKey;
    if (dedupeKey == null || dedupeKey.isEmpty) return false;

    final now = DateTime.now();
    final lastSeen = _dedupeTimestamps[dedupeKey];
    if (lastSeen != null && now.difference(lastSeen) < dedupeWindow) {
      return true;
    }

    _dedupeTimestamps[dedupeKey] = now;
    _dedupeTimestamps.removeWhere(
      (_, timestamp) => now.difference(timestamp) > const Duration(minutes: 2),
    );
    return false;
  }

  void _drainQueue() {
    if (_isShowing || _queue.isEmpty) return;

    final messenger = messengerKey.currentState;
    if (messenger == null) {
      return;
    }

    _isShowing = true;
    final snack = _queue.removeFirst();
    messenger.showSnackBar(_buildSnackBar(snack)).closed.whenComplete(() {
      _isShowing = false;
      _drainQueue();
    });
  }

  SnackBar _buildSnackBar(AppSnackMessage snack) {
    final accent = _accentForType(snack.type);
    final icon = _iconForType(snack.type);

    return SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: Colors.white,
      duration: snack.duration,
      content: Row(
        children: [
          Icon(icon, color: accent, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (snack.title != null && snack.title!.isNotEmpty)
                  Text(
                    snack.title!,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                Text(
                  snack.message,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      action: snack.actionLabel != null && snack.onAction != null
          ? SnackBarAction(
              label: snack.actionLabel!,
              textColor: accent,
              onPressed: snack.onAction!,
            )
          : null,
    );
  }

  Color _accentForType(AppSnackType type) {
    switch (type) {
      case AppSnackType.success:
        return AppTheme.successColor;
      case AppSnackType.error:
        return AppTheme.dangerColor;
      case AppSnackType.warning:
        return AppTheme.warningColor;
      case AppSnackType.info:
        return AppTheme.primaryColor;
    }
  }

  IconData _iconForType(AppSnackType type) {
    switch (type) {
      case AppSnackType.success:
        return Icons.check_circle_outline;
      case AppSnackType.error:
        return Icons.error_outline;
      case AppSnackType.warning:
        return Icons.warning_amber_rounded;
      case AppSnackType.info:
        return Icons.info_outline;
    }
  }

  void resetForTest() {
    _queue.clear();
    _dedupeTimestamps.clear();
    _isShowing = false;
    messengerKey.currentState
      ?..hideCurrentSnackBar()
      ..removeCurrentSnackBar();
  }
}
