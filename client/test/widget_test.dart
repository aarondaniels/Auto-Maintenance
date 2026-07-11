// Basic smoke test: the app builds and shows the login screen when logged out.
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:auto_maint_client/main.dart';

void main() {
  testWidgets('shows login screen when logged out', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: AutoMaintApp()));
    await tester.pump();

    expect(find.text('Auto Maintenance Tracker'), findsOneWidget);
    expect(find.text('Log in'), findsWidgets);
  });
}
