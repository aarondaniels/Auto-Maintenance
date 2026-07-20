// Basic smoke test: the app builds and shows the welcome screen when no
// vehicles exist yet.
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:auto_maint_client/main.dart';

void main() {
  late Directory tempDir;

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    // path_provider has no plugin registered in unit tests, so point its
    // documents-directory call at a real temp dir the app can read/write.
    tempDir = Directory.systemTemp.createTempSync('auto_maint_test');
    TestDefaultBinaryMessengerBinding
        .instance
        .defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => tempDir.path,
        );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding
        .instance
        .defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          null,
        );
    tempDir.deleteSync(recursive: true);
  });

  testWidgets('shows welcome screen when no vehicles exist', (tester) async {
    // The vehicle list loads from real on-device storage (dart:io + a
    // platform channel), which only advances on the real event loop, so drive
    // the initial load inside runAsync. A plain pump() then flushes the
    // resolved state (pumpAndSettle would spin forever on the loading
    // indicator).
    await tester.runAsync(() async {
      await tester.pumpWidget(const ProviderScope(child: AutoMaintApp()));
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pump();

    expect(
      find.text('Add your first vehicle to get started.'),
      findsOneWidget,
    );
  });
}
