import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api_client.dart';
import 'models.dart';
import 'schedules.dart';

/// Single shared in-device storage client.
final apiProvider = Provider<ApiClient>((ref) => ApiClient());

/// List of saved vehicles.
final vehiclesProvider = FutureProvider<List<Vehicle>>((ref) async {
  return ref.watch(apiProvider).listVehicles();
});

/// Currently selected vehicle id (for switching between vehicles).
class SelectedVehicleId extends Notifier<int?> {
  @override
  int? build() => null;

  void select(int? id) => state = id;
}

final selectedVehicleIdProvider = NotifierProvider<SelectedVehicleId, int?>(
  SelectedVehicleId.new,
);

final fillupsProvider = FutureProvider.family<List<Fillup>, int>((
  ref,
  vehicleId,
) async {
  return ref.watch(apiProvider).listFillups(vehicleId);
});

final servicesProvider = FutureProvider.family<List<ServiceRecord>, int>((
  ref,
  vehicleId,
) async {
  return ref.watch(apiProvider).listServices(vehicleId);
});

final remindersProvider = FutureProvider.family<List<ReminderStatus>, int>((
  ref,
  vehicleId,
) async {
  return ref.watch(apiProvider).reminderStatus(vehicleId);
});

final reminderRulesProvider = FutureProvider.family<List<ReminderRule>, int>((
  ref,
  vehicleId,
) async {
  return ref.watch(apiProvider).listReminderRules(vehicleId);
});

/// Bundled manufacturer-schedule lookup.
final scheduleRepositoryProvider = Provider<ScheduleRepository>(
  (ref) => ScheduleRepository(),
);

final statsProvider = FutureProvider.family<VehicleStats, int>((
  ref,
  vehicleId,
) async {
  return ref.watch(apiProvider).stats(vehicleId);
});
