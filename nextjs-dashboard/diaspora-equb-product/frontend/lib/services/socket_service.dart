import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../config/app_config.dart';

class EqubSocketEvent {
  final String type;
  final String? poolId;
  final int? onChainPoolId;
  final Map<String, dynamic> data;
  final int timestamp;

  EqubSocketEvent({
    required this.type,
    this.poolId,
    this.onChainPoolId,
    required this.data,
    required this.timestamp,
  });

  factory EqubSocketEvent.fromMap(Map<String, dynamic> map) {
    return EqubSocketEvent(
      type: map['type']?.toString() ?? '',
      poolId: map['poolId']?.toString(),
      onChainPoolId: map['onChainPoolId'] as int?,
      data: Map<String, dynamic>.from(map['data'] as Map? ?? {}),
      timestamp:
          map['timestamp'] as int? ?? DateTime.now().millisecondsSinceEpoch,
    );
  }
}

class SocketService {
  static SocketService? _instance;
  static SocketService get instance => _instance ??= SocketService._();

  io.Socket? _socket;
  String? _currentPoolId;
  bool _connected = false;

  final _eventController = StreamController<EqubSocketEvent>.broadcast();
  Stream<EqubSocketEvent> get events => _eventController.stream;

  bool get isConnected => _connected;

  SocketService._();

  String get _baseUrl {
    String base = AppConfig.apiBaseUrl;
    if (base.endsWith('/')) {
      base = base.substring(0, base.length - 1);
    }
    if (base.endsWith('/api')) {
      base = base.substring(0, base.length - 4);
    }
    return base;
  }

  void connect() {
    if (_socket != null) return;

    _socket = io.io(
      '$_baseUrl/events',
      io.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .enableReconnection()
          .setReconnectionDelay(2000)
          .setReconnectionAttempts(10)
          .build(),
    );

    _socket!.onConnect((_) {
      _connected = true;
      debugPrint('[SocketService] Connected');
      if (_currentPoolId != null) {
        _socket!.emit('subscribe:pool', _currentPoolId);
      }
    });

    _socket!.onDisconnect((_) {
      _connected = false;
      debugPrint('[SocketService] Disconnected');
    });

    _socket!.onConnectError((err) {
      debugPrint('[SocketService] Connection error: $err');
    });

    for (final eventType in [
      'winner:randomizing',
      'winner:picked',
      'contribution:received',
      'round:closed',
      'payout:sent',
      'member:joined',
    ]) {
      _socket!.on(eventType, (data) {
        if (data is Map) {
          _eventController.add(
            EqubSocketEvent.fromMap(Map<String, dynamic>.from(data)),
          );
        }
      });
    }

    _socket!.connect();
  }

  void subscribeToPool(String poolId) {
    _currentPoolId = poolId;
    if (_connected && _socket != null) {
      _socket!.emit('subscribe:pool', poolId);
    }
  }

  void unsubscribeFromPool(String poolId) {
    if (_connected && _socket != null) {
      _socket!.emit('unsubscribe:pool', poolId);
    }
    if (_currentPoolId == poolId) {
      _currentPoolId = null;
    }
  }

  Stream<EqubSocketEvent> poolEvents(String poolId) {
    return events.where((e) => e.poolId == poolId);
  }

  void dispose() {
    _socket?.dispose();
    _socket = null;
    _connected = false;
    _currentPoolId = null;
  }
}
