// Tests for the on-device storage layer: durability, atomicity, and
// corrupt-file handling.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:auto_maint_client/api_client.dart';
import 'package:auto_maint_client/models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('auto_maint_store');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => tempDir.path,
        );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          null,
        );
    tempDir.deleteSync(recursive: true);
  });

  File dataFile() => File('${tempDir.path}/auto_maint_data.json');

  test('fresh store starts empty and creates a versioned data file', () async {
    final client = ApiClient();
    expect(await client.listVehicles(), isEmpty);

    final json = jsonDecode(dataFile().readAsStringSync());
    expect(json['schema_version'], 2);
  });

  test('data persists across client instances', () async {
    await ApiClient().createVehicle({'label': 'Truck'});

    final vehicles = await ApiClient().listVehicles();
    expect(vehicles.single.label, 'Truck');
  });

  test('persist leaves no temp file behind', () async {
    await ApiClient().createVehicle({'label': 'Truck'});

    expect(File('${dataFile().path}.tmp').existsSync(), isFalse);
    expect(dataFile().existsSync(), isTrue);
  });

  test('corrupt data file is set aside for recovery, not discarded', () async {
    dataFile().writeAsStringSync('{definitely not json');

    final client = ApiClient();
    expect(await client.listVehicles(), isEmpty);

    final corrupt = tempDir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.contains('.corrupt-'))
        .toList();
    expect(corrupt, hasLength(1));
    expect(corrupt.single.readAsStringSync(), '{definitely not json');
    // A fresh, valid file replaces it.
    expect(jsonDecode(dataFile().readAsStringSync()), isA<Map>());
  });

  test('file from a newer schema version is set aside, not mangled', () async {
    dataFile().writeAsStringSync(jsonEncode({'schema_version': 999}));

    final client = ApiClient();
    expect(await client.listVehicles(), isEmpty);

    final setAside = tempDir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.contains('.corrupt-'));
    expect(setAside, hasLength(1));
  });

  group('reminder rules', () {
    test('new vehicle is seeded with default recurring rules', () async {
      final client = ApiClient();
      final v = await client.createVehicle({'label': 'Truck'});

      final rules = await client.listReminderRules(v.id);
      expect(rules, hasLength(4));
      expect(
        rules.every((r) => r.source == 'defaults' && r.kind == 'recurring'),
        isTrue,
      );
      // Statuses are computed per rule; nothing serviced yet -> unknown.
      final statuses = await client.reminderStatus(v.id);
      expect(statuses, hasLength(4));
      expect(statuses.every((s) => s.status == 'unknown'), isTrue);
    });

    test('v1 data file is migrated: vehicles get default rules', () async {
      dataFile().writeAsStringSync(
        jsonEncode({
          'schema_version': 1,
          'next_vehicle_id': 2,
          'next_fillup_id': 1,
          'next_service_id': 1,
          'vehicles': [
            {'id': 1, 'label': 'Old', 'current_odometer': 42000},
          ],
          'fillups': [],
          'services': [],
        }),
      );

      final rules = await ApiClient().listReminderRules(1);
      expect(rules, hasLength(4));
      expect(rules.every((r) => r.source == 'defaults'), isTrue);
    });

    test('milestone lifecycle: ok -> due soon -> overdue -> done', () async {
      final client = ApiClient();
      final v = await client.createVehicle({
        'label': 'Bronco',
        'current_odometer': 50000,
      });
      final rule = await client.createReminderRule(v.id, {
        'service_type': 'spark plugs',
        'kind': 'milestone',
        'due_odometer': 100000,
      });

      Future<ReminderStatus> status() async => (await client.reminderStatus(
        v.id,
      )).firstWhere((s) => s.ruleId == rule.id);

      var s = await status();
      expect(s.status, 'ok');
      expect(s.milesUntilDue, 50000);

      await client.createFillup(v.id, {
        'date': '2026-07-01',
        'odometer': 99600,
        'gallons': 10,
      });
      s = await status();
      expect(s.status, 'due_soon');

      await client.createFillup(v.id, {
        'date': '2026-07-05',
        'odometer': 100100,
        'gallons': 10,
      });
      s = await status();
      expect(s.status, 'overdue');

      // A matching service at/near the milestone satisfies it — matching is
      // case-insensitive.
      await client.createService(v.id, {
        'date': '2026-07-06',
        'odometer': 100200,
        'service_type': 'Spark Plugs',
      });
      s = await status();
      expect(s.status, 'done');
    });

    test('rules can be updated and deleted', () async {
      final client = ApiClient();
      final v = await client.createVehicle({'label': 'Truck'});
      final rules = await client.listReminderRules(v.id);
      final oil = rules.firstWhere((r) => r.serviceType == 'oil change');

      await client.updateReminderRule(v.id, oil.id, {'interval_miles': 7500});
      final updated = (await client.listReminderRules(
        v.id,
      )).firstWhere((r) => r.id == oil.id);
      expect(updated.intervalMiles, 7500);
      expect(updated.intervalMonths, oil.intervalMonths, reason: 'unchanged');

      await client.deleteReminderRule(v.id, oil.id);
      expect(await client.listReminderRules(v.id), hasLength(3));
    });

    test('manufacturer import supersedes defaults and is idempotent',
        () async {
      final client = ApiClient();
      final v = await client.createVehicle({'label': 'Bronco'});
      await client.createReminderRule(v.id, {
        'service_type': 'wiper blades',
        'kind': 'recurring',
        'interval_months': 12,
      });

      final items = [
        {
          'service_type': 'oil change',
          'kind': 'recurring',
          'interval_miles': 10000,
          'interval_months': 12,
        },
        {
          'service_type': 'spark plugs',
          'kind': 'milestone',
          'due_odometer': 100000,
        },
      ];
      await client.importManufacturerRules(v.id, items);

      var rules = await client.listReminderRules(v.id);
      // 4 defaults - 1 superseded (oil change) + 1 custom + 2 imported.
      expect(rules, hasLength(6));
      expect(rules.where((r) => r.source == 'manufacturer'), hasLength(2));
      final oil = rules.where((r) => r.serviceType == 'oil change').toList();
      expect(oil, hasLength(1));
      expect(oil.single.source, 'manufacturer');
      expect(oil.single.intervalMiles, 10000);
      expect(
        rules.where((r) => r.serviceType == 'wiper blades'),
        hasLength(1),
        reason: 'custom rules are kept',
      );

      // Re-import must not duplicate.
      await client.importManufacturerRules(v.id, items);
      rules = await client.listReminderRules(v.id);
      expect(rules, hasLength(6));
    });

    test('deleting a vehicle cascades to its rules', () async {
      final client = ApiClient();
      final v = await client.createVehicle({'label': 'Truck'});
      await client.deleteVehicle(v.id);
      expect(await client.listReminderRules(v.id), isEmpty);
    });
  });

  test('export file is complete, valid JSON', () async {
    final client = ApiClient();
    final v = await client.createVehicle({'label': 'Truck'});
    await client.createFillup(v.id, {
      'date': '2026-07-01',
      'odometer': 10000,
      'gallons': 12.5,
    });

    final file = await client.writeExportFile();
    expect(file.path, contains('auto-maintenance-export-'));
    expect(file.path, endsWith('.json'));

    final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    expect(json['schema_version'], 2);
    expect(json['vehicles'], hasLength(1));
    expect(json['fillups'], hasLength(1));
    expect(json['reminder_rules'], hasLength(4), reason: 'seeded defaults');
  });

  test('concurrent mutations are serialized without losing writes', () async {
    final client = ApiClient();
    await Future.wait([
      client.createVehicle({'label': 'A'}),
      client.createVehicle({'label': 'B'}),
      client.createVehicle({'label': 'C'}),
    ]);

    // Re-read from disk with a fresh instance.
    final vehicles = await ApiClient().listVehicles();
    expect(vehicles.map((v) => v.label).toSet(), {'A', 'B', 'C'});
    expect(vehicles.map((v) => v.id).toSet(), hasLength(3), reason: 'unique ids');
  });
}
