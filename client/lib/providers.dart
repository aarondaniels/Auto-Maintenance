import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api_client.dart';
import 'models.dart';

/// Single shared API client.
final apiProvider = Provider<ApiClient>((ref) => ApiClient());

/// Auth state: `true` when a JWT is present. The token itself lives in secure
/// storage inside ApiClient; this just tracks logged-in/out for routing.
class AuthNotifier extends Notifier<bool> {
  late final ApiClient _api;

  @override
  bool build() {
    _api = ref.watch(apiProvider);
    // Resolve any stored token asynchronously after first build.
    _bootstrap();
    return false;
  }

  Future<void> _bootstrap() async {
    final token = await _api.readToken();
    if (token != null) state = true;
  }

  Future<void> login(String email, String password) async {
    await _api.login(email, password);
    state = true;
  }

  Future<void> signup(String email, String password) async {
    await _api.signup(email, password);
    state = true;
  }

  Future<void> logout() async {
    await _api.clearToken();
    state = false;
  }
}

final authProvider =
    NotifierProvider<AuthNotifier, bool>(AuthNotifier.new);

/// List of the user's vehicles.
final vehiclesProvider = FutureProvider<List<Vehicle>>((ref) async {
  // Re-fetch whenever auth flips on.
  ref.watch(authProvider);
  return ref.watch(apiProvider).listVehicles();
});

/// Currently selected vehicle id (for switching between vehicles).
class SelectedVehicleId extends Notifier<int?> {
  @override
  int? build() => null;

  void select(int? id) => state = id;
}

final selectedVehicleIdProvider =
    NotifierProvider<SelectedVehicleId, int?>(SelectedVehicleId.new);

final fillupsProvider =
    FutureProvider.family<List<Fillup>, int>((ref, vehicleId) async {
  return ref.watch(apiProvider).listFillups(vehicleId);
});

final servicesProvider =
    FutureProvider.family<List<ServiceRecord>, int>((ref, vehicleId) async {
  return ref.watch(apiProvider).listServices(vehicleId);
});

final remindersProvider =
    FutureProvider.family<List<ReminderStatus>, int>((ref, vehicleId) async {
  return ref.watch(apiProvider).reminderStatus(vehicleId);
});

final statsProvider =
    FutureProvider.family<VehicleStats, int>((ref, vehicleId) async {
  return ref.watch(apiProvider).stats(vehicleId);
});
