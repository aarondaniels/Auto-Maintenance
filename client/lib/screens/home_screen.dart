import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models.dart';
import '../providers.dart';
import 'fillups_screen.dart';
import 'reminders_screen.dart';
import 'services_screen.dart';
import 'stats_screen.dart';
import 'vehicle_form.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final vehiclesAsync = ref.watch(vehiclesProvider);

    return vehiclesAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: const Text('Auto Maintenance')),
        body: _ErrorView(
          message: '$e',
          onRetry: () => ref.invalidate(vehiclesProvider),
        ),
      ),
      data: (vehicles) {
        if (vehicles.isEmpty) {
          return _NoVehiclesScreen(
            onAdded: () => ref.invalidate(vehiclesProvider),
          );
        }

        // Resolve the selected vehicle, defaulting to the first.
        final selectedId = ref.watch(selectedVehicleIdProvider);
        final vehicle = vehicles.firstWhere(
          (v) => v.id == selectedId,
          orElse: () => vehicles.first,
        );

        final pages = [
          FillupsScreen(vehicle: vehicle),
          ServicesScreen(vehicle: vehicle),
          RemindersScreen(vehicle: vehicle),
          StatsScreen(vehicle: vehicle),
        ];

        return Scaffold(
          appBar: AppBar(
            title: _VehicleSelector(vehicles: vehicles, selected: vehicle),
            actions: [
              IconButton(
                tooltip: 'Add vehicle',
                icon: const Icon(Icons.add),
                onPressed: () async {
                  final added = await Navigator.of(context).push<bool>(
                    MaterialPageRoute(builder: (_) => const VehicleForm()),
                  );
                  if (added == true) ref.invalidate(vehiclesProvider);
                },
              ),
              IconButton(
                tooltip: 'Log out',
                icon: const Icon(Icons.logout),
                onPressed: () => ref.read(authProvider.notifier).logout(),
              ),
            ],
          ),
          body: pages[_tab],
          bottomNavigationBar: NavigationBar(
            selectedIndex: _tab,
            onDestinationSelected: (i) => setState(() => _tab = i),
            destinations: const [
              NavigationDestination(
                  icon: Icon(Icons.local_gas_station), label: 'Fillups'),
              NavigationDestination(
                  icon: Icon(Icons.build), label: 'Service'),
              NavigationDestination(
                  icon: Icon(Icons.notifications), label: 'Reminders'),
              NavigationDestination(
                  icon: Icon(Icons.insights), label: 'Stats'),
            ],
          ),
        );
      },
    );
  }
}

class _VehicleSelector extends ConsumerWidget {
  const _VehicleSelector({required this.vehicles, required this.selected});

  final List<Vehicle> vehicles;
  final Vehicle selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DropdownButtonHideUnderline(
      child: DropdownButton<int>(
        value: selected.id,
        isExpanded: true,
        items: vehicles
            .map((v) => DropdownMenuItem(
                  value: v.id,
                  child: Text(v.displayName, overflow: TextOverflow.ellipsis),
                ))
            .toList(),
        onChanged: (id) =>
            ref.read(selectedVehicleIdProvider.notifier).select(id),
      ),
    );
  }
}

class _NoVehiclesScreen extends StatelessWidget {
  const _NoVehiclesScreen({required this.onAdded});
  final VoidCallback onAdded;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Welcome')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.directions_car, size: 72),
            const SizedBox(height: 16),
            const Text('Add your first vehicle to get started.'),
            const SizedBox(height: 16),
            FilledButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Add vehicle'),
              onPressed: () async {
                final added = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(builder: (_) => const VehicleForm()),
                );
                if (added == true) onAdded();
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
