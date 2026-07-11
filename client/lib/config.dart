/// App-wide configuration.
///
/// The API base URL differs per platform when developing locally:
/// - Android emulator reaches the host machine at 10.0.2.2
/// - iOS simulator can use localhost
///
/// Override at build/run time with:
///   flutter run --dart-define=API_BASE_URL=http://192.168.1.10:8000
library;

import 'dart:io' show Platform;

const String _override = String.fromEnvironment('API_BASE_URL');

String resolveApiBaseUrl() {
  if (_override.isNotEmpty) return _override;
  if (Platform.isAndroid) return 'http://10.0.2.2:8000';
  return 'http://localhost:8000';
}
