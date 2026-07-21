import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'models.dart';

const _defaultReminderIntervals = {
  'oil change': {'interval_miles': 5000, 'interval_months': 6},
  'tires': {'interval_miles': 50000, 'interval_months': 72},
  'brakes': {'interval_miles': 25000, 'interval_months': 36},
  'filters': {'interval_miles': 15000, 'interval_months': 12},
};

const _dueSoonMiles = 500;
const _dueSoonDays = 30;

/// Gives [vehicleId] the standard starter set of recurring reminder rules.
void _seedDefaultRules(_AppData data, int vehicleId) {
  for (final entry in _defaultReminderIntervals.entries) {
    data.reminderRules.add(
      ReminderRule(
        id: data.nextRuleId++,
        vehicleId: vehicleId,
        serviceType: entry.key,
        kind: 'recurring',
        intervalMiles: entry.value['interval_miles'],
        intervalMonths: entry.value['interval_months'],
        source: 'defaults',
      ),
    );
  }
}

class ApiClient {
  ApiClient();

  _AppData? _cache;

  /// Serializes mutations so overlapping read-modify-write cycles (and their
  /// file writes) can't interleave and lose data.
  Future<void> _writeQueue = Future.value();

  Future<T> _mutate<T>(Future<T> Function() action) {
    final result = _writeQueue.then((_) => action());
    _writeQueue = result.then((_) {}, onError: (_) {});
    return result;
  }

  Future<File> get _storageFile async {
    // If the documents directory is unavailable, let the error propagate to
    // the UI rather than silently writing to a volatile location.
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/auto_maint_data.json');
  }

  Future<_AppData> _load() async {
    if (_cache != null) return _cache!;
    final file = await _storageFile;
    if (await file.exists()) {
      try {
        final contents = await file.readAsString();
        final data = jsonDecode(contents) as Map<String, dynamic>;
        _cache = _AppData.fromJson(data);
      } catch (_) {
        // Never silently discard user data: set the unreadable file aside
        // for manual recovery, then start fresh.
        final backupPath =
            '${file.path}.corrupt-${DateTime.now().millisecondsSinceEpoch}';
        await file.rename(backupPath);
        _cache = _AppData.empty();
        await _persist();
      }
    } else {
      _cache = _AppData.empty();
      await _persist();
    }
    return _cache!;
  }

  Future<void> _persist() async {
    final data = _cache;
    if (data == null) return;
    final file = await _storageFile;
    // Atomic write: flush to a temp file, then rename over the live file so
    // a crash mid-write can never leave it truncated.
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsString(jsonEncode(data.toJson()), flush: true);
    await tmp.rename(file.path);
  }

  Future<List<Vehicle>> listVehicles() async {
    final data = await _load();
    return List.of(data.vehicles);
  }

  /// Writes a dated, pretty-printed export of all data to a temp file and
  /// returns it, ready to hand to the platform share sheet.
  Future<File> writeExportFile() async {
    final data = await _load();
    final dir = await getTemporaryDirectory();
    final stamp = DateTime.now().toIso8601String().split('T').first;
    final file = File('${dir.path}/auto-maintenance-export-$stamp.json');
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(data.toJson()),
      flush: true,
    );
    return file;
  }

  Future<Vehicle> createVehicle(Map<String, dynamic> body) => _mutate(() async {
    final data = await _load();
    final vehicle = Vehicle(
      id: data.nextVehicleId++,
      label: body['label'] as String,
      make: body['make'] as String?,
      model: body['model'] as String?,
      year: body['year'] as int?,
      trim: body['trim'] as String?,
      engine: body['engine'] as String?,
      currentOdometer: body['current_odometer'] as int?,
    );
    data.vehicles.add(vehicle);
    _seedDefaultRules(data, vehicle.id);
    await _persist();
    return vehicle;
  });

  Future<void> deleteVehicle(int id) => _mutate(() async {
    final data = await _load();
    data.vehicles.removeWhere((v) => v.id == id);
    data.fillups.removeWhere((f) => f.vehicleId == id);
    data.services.removeWhere((s) => s.vehicleId == id);
    data.reminderRules.removeWhere((r) => r.vehicleId == id);
    await _persist();
  });

  Future<List<Fillup>> listFillups(int vehicleId) async {
    final data = await _load();
    final fillups = data.fillups.where((f) => f.vehicleId == vehicleId).toList()
      ..sort((a, b) => a.odometer.compareTo(b.odometer));
    return fillups;
  }

  Future<void> createFillup(int vehicleId, Map<String, dynamic> body) =>
      _mutate(() async {
        final data = await _load();
        final fillup = Fillup(
          id: data.nextFillupId++,
          vehicleId: vehicleId,
          date: DateTime.parse(body['date'] as String),
          odometer: body['odometer'] as int,
          gallons: (body['gallons'] as num).toDouble(),
          priceTotal: (body['price_total'] as num?)?.toDouble(),
          location: body['location'] as String?,
          notes: body['notes'] as String?,
          mpg: null,
        );
        data.fillups.add(fillup);
        _updateVehicleOdometer(data, vehicleId, fillup.odometer);
        await _persist();
      });

  Future<void> deleteFillup(int vehicleId, int fillupId) => _mutate(() async {
    final data = await _load();
    data.fillups.removeWhere(
      (f) => f.id == fillupId && f.vehicleId == vehicleId,
    );
    await _persist();
  });

  Future<List<ServiceRecord>> listServices(int vehicleId) async {
    final data = await _load();
    return data.services.where((s) => s.vehicleId == vehicleId).toList();
  }

  Future<void> createService(int vehicleId, Map<String, dynamic> body) =>
      _mutate(() async {
        final data = await _load();
        final service = ServiceRecord(
          id: data.nextServiceId++,
          vehicleId: vehicleId,
          date: DateTime.parse(body['date'] as String),
          odometer: body['odometer'] as int,
          serviceType: body['service_type'] as String,
          cost: (body['cost'] as num?)?.toDouble(),
          notes: body['notes'] as String?,
        );
        data.services.add(service);
        _updateVehicleOdometer(data, vehicleId, service.odometer);
        await _persist();
      });

  Future<void> deleteService(int vehicleId, int serviceId) => _mutate(() async {
    final data = await _load();
    data.services.removeWhere(
      (s) => s.id == serviceId && s.vehicleId == vehicleId,
    );
    await _persist();
  });

  Future<List<ReminderRule>> listReminderRules(int vehicleId) async {
    final data = await _load();
    return data.reminderRules.where((r) => r.vehicleId == vehicleId).toList();
  }

  Future<ReminderRule> createReminderRule(
    int vehicleId,
    Map<String, dynamic> body,
  ) => _mutate(() async {
    final data = await _load();
    final rule = ReminderRule(
      id: data.nextRuleId++,
      vehicleId: vehicleId,
      serviceType: (body['service_type'] as String).trim(),
      kind: body['kind'] as String? ?? 'recurring',
      intervalMiles: body['interval_miles'] as int?,
      intervalMonths: body['interval_months'] as int?,
      dueOdometer: body['due_odometer'] as int?,
      source: body['source'] as String? ?? 'custom',
      notes: body['notes'] as String?,
    );
    data.reminderRules.add(rule);
    await _persist();
    return rule;
  });

  Future<void> updateReminderRule(
    int vehicleId,
    int ruleId,
    Map<String, dynamic> body,
  ) => _mutate(() async {
    final data = await _load();
    final index = data.reminderRules.indexWhere(
      (r) => r.id == ruleId && r.vehicleId == vehicleId,
    );
    if (index == -1) return;
    final old = data.reminderRules[index];
    data.reminderRules[index] = ReminderRule(
      id: old.id,
      vehicleId: old.vehicleId,
      serviceType: (body['service_type'] as String?)?.trim() ?? old.serviceType,
      kind: body['kind'] as String? ?? old.kind,
      intervalMiles: body.containsKey('interval_miles')
          ? body['interval_miles'] as int?
          : old.intervalMiles,
      intervalMonths: body.containsKey('interval_months')
          ? body['interval_months'] as int?
          : old.intervalMonths,
      dueOdometer: body.containsKey('due_odometer')
          ? body['due_odometer'] as int?
          : old.dueOdometer,
      source: old.source,
      notes: body.containsKey('notes') ? body['notes'] as String? : old.notes,
    );
    await _persist();
  });

  Future<void> deleteReminderRule(int vehicleId, int ruleId) =>
      _mutate(() async {
        final data = await _load();
        data.reminderRules.removeWhere(
          (r) => r.id == ruleId && r.vehicleId == vehicleId,
        );
        await _persist();
      });

  /// Imports manufacturer-schedule items as reminder rules.
  ///
  /// Idempotent: replaces any previously imported manufacturer rules for
  /// this vehicle. Default rules for the same service types are superseded
  /// (removed); custom rules are never touched.
  Future<void> importManufacturerRules(
    int vehicleId,
    List<Map<String, dynamic>> items,
  ) => _mutate(() async {
    final data = await _load();
    data.reminderRules.removeWhere(
      (r) => r.vehicleId == vehicleId && r.source == 'manufacturer',
    );
    final types = items
        .map((i) => (i['service_type'] as String).trim().toLowerCase())
        .toSet();
    data.reminderRules.removeWhere(
      (r) =>
          r.vehicleId == vehicleId &&
          r.source == 'defaults' &&
          types.contains(r.serviceType.toLowerCase()),
    );
    for (final item in items) {
      data.reminderRules.add(
        ReminderRule(
          id: data.nextRuleId++,
          vehicleId: vehicleId,
          serviceType: (item['service_type'] as String).trim(),
          kind: item['kind'] as String? ?? 'recurring',
          intervalMiles: item['interval_miles'] as int?,
          intervalMonths: item['interval_months'] as int?,
          dueOdometer: item['due_odometer'] as int?,
          source: 'manufacturer',
          notes: item['notes'] as String?,
        ),
      );
    }
    await _persist();
  });

  Future<List<ReminderStatus>> reminderStatus(int vehicleId) async {
    final data = await _load();
    final vehicle = data.vehicles.firstWhere((v) => v.id == vehicleId);
    final now = DateTime.now();
    return [
      for (final rule in data.reminderRules)
        if (rule.vehicleId == vehicleId)
          _statusForRule(rule, data, vehicle, now),
    ];
  }

  Future<VehicleStats> stats(int vehicleId) async {
    final data = await _load();
    final fillups = data.fillups.where((f) => f.vehicleId == vehicleId).toList()
      ..sort((a, b) => a.odometer.compareTo(b.odometer));
    final services = data.services
        .where((s) => s.vehicleId == vehicleId)
        .toList();

    final totalFuelCost = fillups.fold<double>(
      0.0,
      (sum, f) => sum + (f.priceTotal ?? 0.0),
    );
    final totalServiceCost = services.fold<double>(
      0.0,
      (sum, s) => sum + (s.cost ?? 0.0),
    );

    final mpgSeries = <MpgPoint>[];
    var totalMiles = 0;
    var totalGallonsUsed = 0.0;
    int? prevOdometer;
    for (final f in fillups) {
      if (prevOdometer != null && f.gallons > 0) {
        final miles = f.odometer - prevOdometer;
        if (miles > 0) {
          final mpg = miles / f.gallons;
          mpgSeries.add(
            MpgPoint(
              date: f.date,
              odometer: f.odometer,
              mpg: double.parse(mpg.toStringAsFixed(2)),
            ),
          );
          totalMiles += miles;
          totalGallonsUsed += f.gallons;
        }
      }
      prevOdometer = f.odometer;
    }

    final avgMpg = totalGallonsUsed > 0
        ? double.parse((totalMiles / totalGallonsUsed).toStringAsFixed(2))
        : null;
    final totalSpend = totalFuelCost + totalServiceCost;
    final costPerMile = totalMiles > 0
        ? double.parse((totalSpend / totalMiles).toStringAsFixed(4))
        : null;

    final monthlyBuckets = <String, Map<String, double>>{};
    for (final f in fillups) {
      final month =
          '${f.date.year.toString().padLeft(4, '0')}-${f.date.month.toString().padLeft(2, '0')}';
      monthlyBuckets.putIfAbsent(month, () => {'fuel': 0.0, 'service': 0.0});
      monthlyBuckets[month]!['fuel'] =
          monthlyBuckets[month]!['fuel']! + (f.priceTotal ?? 0.0);
    }
    for (final s in services) {
      final month =
          '${s.date.year.toString().padLeft(4, '0')}-${s.date.month.toString().padLeft(2, '0')}';
      monthlyBuckets.putIfAbsent(month, () => {'fuel': 0.0, 'service': 0.0});
      monthlyBuckets[month]!['service'] =
          monthlyBuckets[month]!['service']! + (s.cost ?? 0.0);
    }

    final monthlySpendList = monthlyBuckets.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return VehicleStats(
      totalFillups: fillups.length,
      totalServices: services.length,
      totalFuelCost: double.parse(totalFuelCost.toStringAsFixed(2)),
      totalServiceCost: double.parse(totalServiceCost.toStringAsFixed(2)),
      totalSpend: double.parse(totalSpend.toStringAsFixed(2)),
      avgMpg: avgMpg,
      costPerMile: costPerMile,
      mpgSeries: mpgSeries,
      monthlySpend: monthlySpendList
          .map(
            (entry) => MonthlySpend(
              month: entry.key,
              fuel: double.parse(entry.value['fuel']!.toStringAsFixed(2)),
              service: double.parse(entry.value['service']!.toStringAsFixed(2)),
            ),
          )
          .toList(),
    );
  }

  void _updateVehicleOdometer(_AppData data, int vehicleId, int odometer) {
    final index = data.vehicles.indexWhere((v) => v.id == vehicleId);
    if (index == -1) return;
    final vehicle = data.vehicles[index];
    if (vehicle.currentOdometer == null ||
        odometer > vehicle.currentOdometer!) {
      data.vehicles[index] = vehicle.copyWith(currentOdometer: odometer);
    }
  }

  ReminderStatus _statusForRule(
    ReminderRule rule,
    _AppData data,
    Vehicle vehicle,
    DateTime today,
  ) {
    final matching =
        data.services
            .where(
              (s) =>
                  s.vehicleId == rule.vehicleId &&
                  s.serviceType.toLowerCase() == rule.serviceType.toLowerCase(),
            )
            .toList()
          ..sort((a, b) => b.odometer.compareTo(a.odometer));
    final last = matching.isNotEmpty ? matching.first : null;

    if (rule.kind == 'milestone') {
      return _milestoneStatus(rule, matching, last, vehicle.currentOdometer);
    }

    // Recurring: due interval_miles/months after the last matching service.
    int? milesUntil;
    int? daysUntil;
    if (last != null) {
      if (rule.intervalMiles != null && vehicle.currentOdometer != null) {
        milesUntil =
            last.odometer + rule.intervalMiles! - vehicle.currentOdometer!;
      }
      if (rule.intervalMonths != null) {
        final dueDate = DateTime(
          last.date.year,
          last.date.month + rule.intervalMonths!,
          last.date.day,
        );
        daysUntil = dueDate.difference(today).inDays;
      }
    }

    var status = 'unknown';
    if (last != null) {
      final overdue =
          (milesUntil != null && milesUntil < 0) ||
          (daysUntil != null && daysUntil < 0);
      final dueSoon =
          (milesUntil != null && milesUntil <= _dueSoonMiles) ||
          (daysUntil != null && daysUntil <= _dueSoonDays);
      status = overdue
          ? 'overdue'
          : dueSoon
          ? 'due_soon'
          : 'ok';
    }

    return ReminderStatus(
      ruleId: rule.id,
      serviceType: rule.serviceType,
      kind: rule.kind,
      source: rule.source,
      intervalMiles: rule.intervalMiles,
      intervalMonths: rule.intervalMonths,
      lastServiceDate: last?.date,
      lastServiceOdometer: last?.odometer,
      milesUntilDue: milesUntil,
      daysUntilDue: daysUntil,
      status: status,
    );
  }

  ReminderStatus _milestoneStatus(
    ReminderRule rule,
    List<ServiceRecord> matching,
    ServiceRecord? last,
    int? currentOdometer,
  ) {
    final due = rule.dueOdometer;
    int? milesUntil;
    String status;
    if (due == null) {
      status = 'unknown';
    } else if (matching.any((s) => s.odometer >= due - _dueSoonMiles)) {
      // A matching service at/near the milestone odometer satisfies it.
      status = 'done';
    } else if (currentOdometer == null) {
      status = 'unknown';
    } else {
      milesUntil = due - currentOdometer;
      status = milesUntil < 0
          ? 'overdue'
          : milesUntil <= _dueSoonMiles
          ? 'due_soon'
          : 'ok';
    }

    return ReminderStatus(
      ruleId: rule.id,
      serviceType: rule.serviceType,
      kind: rule.kind,
      source: rule.source,
      dueOdometer: due,
      lastServiceDate: last?.date,
      lastServiceOdometer: last?.odometer,
      milesUntilDue: milesUntil,
      status: status,
    );
  }
}

class _AppData {
  _AppData({
    required this.nextVehicleId,
    required this.nextFillupId,
    required this.nextServiceId,
    required this.nextRuleId,
    required this.vehicles,
    required this.fillups,
    required this.services,
    required this.reminderRules,
  });

  factory _AppData.empty() => _AppData(
    nextVehicleId: 1,
    nextFillupId: 1,
    nextServiceId: 1,
    nextRuleId: 1,
    vehicles: [],
    fillups: [],
    services: [],
    reminderRules: [],
  );

  factory _AppData.fromJson(Map<String, dynamic> json) {
    // Files written before versioning carry no marker; treat them as v1.
    final version = json['schema_version'] as int? ?? 1;
    if (version > schemaVersion) {
      // Written by a newer app version; refuse to parse so _load() sets the
      // file aside instead of mangling it.
      throw FormatException('unsupported schema version $version');
    }
    final data = _AppData(
      nextVehicleId: json['next_vehicle_id'] as int,
      nextFillupId: json['next_fillup_id'] as int,
      nextServiceId: json['next_service_id'] as int,
      nextRuleId: json['next_rule_id'] as int? ?? 1,
      vehicles: (json['vehicles'] as List)
          .map((e) => Vehicle.fromJson(e as Map<String, dynamic>))
          .toList(),
      fillups: (json['fillups'] as List)
          .map((e) => Fillup.fromJson(e as Map<String, dynamic>))
          .toList(),
      services: (json['services'] as List)
          .map((e) => ServiceRecord.fromJson(e as Map<String, dynamic>))
          .toList(),
      reminderRules: (json['reminder_rules'] as List? ?? [])
          .map((e) => ReminderRule.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
    if (version < 2) {
      // v1 predates persisted reminder rules: seed every vehicle with the
      // defaults that were previously hardcoded.
      for (final vehicle in data.vehicles) {
        _seedDefaultRules(data, vehicle.id);
      }
    }
    return data;
  }

  int nextVehicleId;
  int nextFillupId;
  int nextServiceId;
  int nextRuleId;
  List<Vehicle> vehicles;
  List<Fillup> fillups;
  List<ServiceRecord> services;
  List<ReminderRule> reminderRules;

  /// Version of the on-disk JSON layout. Bump on breaking changes and
  /// migrate older files in [_AppData.fromJson].
  ///
  /// v2: added persisted [reminderRules] + [nextRuleId].
  static const schemaVersion = 2;

  Map<String, dynamic> toJson() => {
    'schema_version': schemaVersion,
    'next_vehicle_id': nextVehicleId,
    'next_fillup_id': nextFillupId,
    'next_service_id': nextServiceId,
    'next_rule_id': nextRuleId,
    'vehicles': vehicles.map((v) => v.toJson()).toList(),
    'fillups': fillups.map((f) => f.toJson()).toList(),
    'services': services.map((s) => s.toJson()).toList(),
    'reminder_rules': reminderRules.map((r) => r.toJson()).toList(),
  };
}
