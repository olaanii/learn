import 'package:diaspora_equb_frontend/services/app_snackbar_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppSnackbarService', () {
    testWidgets('dedupes snackbar messages with same dedupeKey',
        (WidgetTester tester) async {
      final service = AppSnackbarService.instance;
      service.resetForTest();
      service.dedupeWindow = const Duration(seconds: 5);

      await tester.pumpWidget(
        MaterialApp(
          scaffoldMessengerKey: service.messengerKey,
          home: const Scaffold(body: SizedBox.shrink()),
        ),
      );

      service.info(
        message: 'First message',
        dedupeKey: 'dup-key',
        duration: const Duration(milliseconds: 120),
      );
      service.info(
        message: 'Second message',
        dedupeKey: 'dup-key',
        duration: const Duration(milliseconds: 120),
      );

      await tester.pump();
      expect(find.text('First message'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Second message'), findsNothing);
    });
  });
}
