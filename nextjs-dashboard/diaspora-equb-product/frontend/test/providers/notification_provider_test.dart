import 'dart:async';
import 'dart:convert';

import 'package:diaspora_equb_frontend/providers/notification_provider.dart';
import 'package:diaspora_equb_frontend/services/api_client.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeApiClient extends ApiClient {
  List<Map<String, dynamic>> notificationsPayload = <Map<String, dynamic>>[];
  int unreadCountValue = 0;
  final List<String> markedReadIds = <String>[];
  bool markAllReadCalled = false;
  int incrementalCalls = 0;
  Map<String, dynamic> incrementalResponse = <String, dynamic>{
    'items': <Map<String, dynamic>>[],
    'nextCursor': null,
    'hasMore': false,
  };
  final List<StreamController<String>> _sseControllers =
      <StreamController<String>>[];
  int streamOpenCount = 0;

  @override
  Future<List<dynamic>> getNotifications(
      {int limit = 50, int offset = 0}) async {
    return notificationsPayload;
  }

  @override
  Future<int> getUnreadNotificationCount() async {
    return unreadCountValue;
  }

  @override
  Future<void> markNotificationRead(String id) async {
    markedReadIds.add(id);
  }

  @override
  Future<void> markAllNotificationsRead() async {
    markAllReadCalled = true;
  }

  @override
  Future<Stream<String>> openNotificationEventStream() async {
    streamOpenCount += 1;
    final controller = StreamController<String>.broadcast();
    _sseControllers.add(controller);
    return controller.stream;
  }

  @override
  Future<Map<String, dynamic>> getNotificationsIncremental({
    String? afterCreatedAt,
    String? afterId,
    int limit = 50,
  }) async {
    incrementalCalls += 1;
    return incrementalResponse;
  }

  Future<void> close() async {
    for (final controller in _sseControllers) {
      if (!controller.isClosed) {
        await controller.close();
      }
    }
  }

  StreamController<String>? controllerAt(int index) {
    if (index < 0 || index >= _sseControllers.length) return null;
    return _sseControllers[index];
  }
}

void main() {
  group('NotificationProvider', () {
    test('loads notifications and marks one as read', () async {
      final api = FakeApiClient()
        ..notificationsPayload = <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'n1',
            'type': 'system',
            'title': 'One',
            'body': 'Body',
            'read': false,
            'createdAt': DateTime.now().toIso8601String(),
          },
          <String, dynamic>{
            'id': 'n2',
            'type': 'system',
            'title': 'Two',
            'body': 'Body',
            'read': true,
            'createdAt': DateTime.now().toIso8601String(),
          },
        ];

      final provider = NotificationProvider(api);

      await provider.loadNotifications();
      expect(provider.notifications.length, 2);
      expect(provider.unreadCount, 1);

      await provider.markRead('n1');
      expect(api.markedReadIds, contains('n1'));
      expect(provider.unreadCount, 0);

      provider.dispose();
      await api.close();
    });

    test('critical SSE notification triggers callback once per id', () async {
      final api = FakeApiClient();
      int criticalCallbackCount = 0;

      final provider = NotificationProvider(
        api,
        onCriticalNotification: (_) {
          criticalCallbackCount += 1;
        },
      );

      provider.handleAuthStateChanged(true);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      final payload = jsonEncode(<String, dynamic>{
        'id': 'critical-1',
        'type': 'default_triggered',
        'title': 'Default',
        'body': 'Default happened',
        'read': false,
        'createdAt': DateTime.now().toIso8601String(),
      });

      final stream = api.controllerAt(0)!;
      stream.add('data: $payload');
      stream.add('data: $payload');
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(provider.notifications.first.id, 'critical-1');
      expect(provider.unreadCount, 1);
      expect(criticalCallbackCount, 1);

      provider.dispose();
      await api.close();
    });

    test('logout clears notifications and unread count', () async {
      final api = FakeApiClient()
        ..notificationsPayload = <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'n1',
            'type': 'system',
            'title': 'One',
            'body': 'Body',
            'read': false,
            'createdAt': DateTime.now().toIso8601String(),
          },
        ]
        ..unreadCountValue = 1;

      final provider = NotificationProvider(api);

      provider.handleAuthStateChanged(true);
      await Future<void>.delayed(const Duration(milliseconds: 30));
      await provider.loadNotifications();
      expect(provider.unreadCount, 1);
      expect(provider.notifications, isNotEmpty);

      provider.handleAuthStateChanged(false);
      expect(provider.unreadCount, 0);
      expect(provider.notifications, isEmpty);

      provider.dispose();
      await api.close();
    });

    test('resume sync keeps unread/list consistent after background', () async {
      final oldCreatedAt = DateTime.now().subtract(const Duration(minutes: 1));
      final newCreatedAt = DateTime.now();

      final api = FakeApiClient()
        ..notificationsPayload = <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'n1',
            'type': 'transfer_built',
            'title': 'Transfer submitted',
            'body': 'Pending transfer',
            'read': false,
            'createdAt': oldCreatedAt.toIso8601String(),
            'metadata': <String, dynamic>{
              'kind': 'transaction',
              'status': 'pending',
            },
          },
        ]
        ..unreadCountValue = 2
        ..incrementalResponse = <String, dynamic>{
          'items': <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 'n2',
              'type': 'faucet_credited',
              'title': 'Faucet credited',
              'body': 'Funds received',
              'read': false,
              'createdAt': newCreatedAt.toIso8601String(),
              'metadata': <String, dynamic>{
                'kind': 'transaction',
                'status': 'confirmed',
              },
            },
          ],
          'nextCursor': <String, dynamic>{
            'createdAt': newCreatedAt.toIso8601String(),
            'id': 'n2',
          },
          'hasMore': false,
        };

      final provider = NotificationProvider(api);

      provider.handleAuthStateChanged(true);
      await Future<void>.delayed(const Duration(milliseconds: 30));
      await provider.loadNotifications();

      provider.handleAppLifecycleChanged(AppLifecycleState.paused);
      provider.handleAppLifecycleChanged(AppLifecycleState.resumed);
      await Future<void>.delayed(const Duration(milliseconds: 60));

      expect(api.incrementalCalls, greaterThan(0));
      expect(provider.notifications.first.id, 'n2');
      expect(provider.unreadCount, 2);

      provider.dispose();
      await api.close();
    });

    test('reconnect recovery opens a new stream and receives new events',
        () async {
      final api = FakeApiClient();
      final provider = NotificationProvider(api);

      provider.handleAuthStateChanged(true);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(api.streamOpenCount, 1);

      await api.controllerAt(0)!.close();

      await Future<void>.delayed(const Duration(milliseconds: 2200));
      expect(api.streamOpenCount, greaterThanOrEqualTo(2));

      final payload = jsonEncode(<String, dynamic>{
        'id': 'after-reconnect',
        'type': 'system',
        'title': 'Recovered',
        'body': 'stream resumed',
        'read': false,
        'createdAt': DateTime.now().toIso8601String(),
      });

      api.controllerAt(1)!.add('data: $payload');
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(provider.notifications.first.id, 'after-reconnect');

      provider.dispose();
      await api.close();
    });

    test('mixed SSE and incremental timing does not duplicate notifications',
        () async {
      final now = DateTime.now();
      final api = FakeApiClient()
        ..notificationsPayload = <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'n1',
            'type': 'system',
            'title': 'Baseline',
            'body': 'base',
            'read': false,
            'createdAt':
                now.subtract(const Duration(minutes: 1)).toIso8601String(),
          },
        ]
        ..unreadCountValue = 2;

      final provider = NotificationProvider(api);
      provider.handleAuthStateChanged(true);
      await Future<void>.delayed(const Duration(milliseconds: 40));
      await provider.loadNotifications();

      final ssePayload = jsonEncode(<String, dynamic>{
        'id': 'n2',
        'type': 'system',
        'title': 'From SSE',
        'body': 'first arrival',
        'read': false,
        'createdAt': now.toIso8601String(),
      });
      api.controllerAt(0)!.add('data: $ssePayload');
      await Future<void>.delayed(const Duration(milliseconds: 40));

      api.incrementalResponse = <String, dynamic>{
        'items': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'n2',
            'type': 'system',
            'title': 'From SSE',
            'body': 'duplicate via incremental',
            'read': false,
            'createdAt': now.toIso8601String(),
          },
          <String, dynamic>{
            'id': 'n3',
            'type': 'system',
            'title': 'From incremental',
            'body': 'new arrival',
            'read': false,
            'createdAt': now.add(const Duration(seconds: 1)).toIso8601String(),
          },
        ],
        'nextCursor': <String, dynamic>{
          'createdAt': now.add(const Duration(seconds: 1)).toIso8601String(),
          'id': 'n3',
        },
        'hasMore': false,
      };

      provider.handleAppLifecycleChanged(AppLifecycleState.resumed);
      await Future<void>.delayed(const Duration(milliseconds: 70));

      final ids = provider.notifications.map((n) => n.id).toList();
      expect(ids.where((id) => id == 'n2').length, 1);
      expect(ids, contains('n3'));
      expect(provider.unreadCount, 2);

      provider.dispose();
      await api.close();
    });

    test('builds grouped display sections with critical-first and grouped tail',
        () async {
      final now = DateTime.now();
      final payload = <Map<String, dynamic>>[];

      payload.add(<String, dynamic>{
        'id': 'crit-1',
        'type': 'default_triggered',
        'title': 'Critical',
        'body': 'Critical body',
        'read': false,
        'createdAt': now.toIso8601String(),
      });

      for (var i = 0; i < 12; i++) {
        payload.add(<String, dynamic>{
          'id': 'latest-$i',
          'type': 'system',
          'title': 'Latest $i',
          'body': 'Latest body $i',
          'read': true,
          'createdAt': now.subtract(Duration(minutes: i + 1)).toIso8601String(),
        });
      }

      payload.addAll(<Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'grp-1',
          'type': 'round_closed',
          'title': 'Round closed',
          'body': 'r1',
          'read': false,
          'createdAt':
              now.subtract(const Duration(minutes: 20)).toIso8601String(),
          'metadata': <String, dynamic>{'poolId': '5'},
        },
        <String, dynamic>{
          'id': 'grp-2',
          'type': 'round_closed',
          'title': 'Round closed',
          'body': 'r2',
          'read': true,
          'createdAt':
              now.subtract(const Duration(minutes: 21)).toIso8601String(),
          'metadata': <String, dynamic>{'poolId': '5'},
        },
      ]);

      final api = FakeApiClient()..notificationsPayload = payload;
      final provider = NotificationProvider(api);
      await provider.loadNotifications(limit: 40);

      final sections = provider.displaySections;
      expect(sections.critical.length, 1);
      expect(sections.latest.length, 12);
      expect(sections.grouped.whereType<NotificationGroupItem>().length, 1);

      final grouped = sections.grouped.whereType<NotificationGroupItem>().first;
      expect(grouped.count, 2);
      expect(grouped.hasUnread, true);

      provider.dispose();
      await api.close();
    });
  });
}
