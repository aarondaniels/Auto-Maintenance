// Tests for the bundled manufacturer-schedule dataset and matcher.
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:auto_maint_client/models.dart';
import 'package:auto_maint_client/schedules.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final repo = ScheduleRepository();

  Vehicle vehicle({
    String? make,
    String? model,
    int? year,
    String? trim,
    String? engine,
  }) => Vehicle(
    id: 1,
    label: 'test',
    make: make,
    model: model,
    year: year,
    trim: trim,
    engine: engine,
  );

  test('every bundled schedule parses and is consistent with the index',
      () async {
    final index =
        jsonDecode(await rootBundle.loadString('assets/schedules/index.json'))
            as Map<String, dynamic>;
    final entries = (index['schedules'] as List).cast<Map<String, dynamic>>();
    expect(entries, isNotEmpty);

    for (final entry in entries) {
      final doc =
          jsonDecode(
                await rootBundle.loadString(
                  'assets/schedules/${entry['file']}',
                ),
              )
              as Map<String, dynamic>;
      expect(doc['make'], entry['make'], reason: '${entry['file']} make');
      expect(doc['model'], entry['model'], reason: '${entry['file']} model');
      expect(doc['years'], entry['years'], reason: '${entry['file']} years');
      expect(doc['conditions'], 'normal');
      expect(doc['source'], isA<String>());

      final variants = (doc['variants'] as List).cast<Map<String, dynamic>>();
      expect(
        variants.any((v) => (v['match'] as Map).isEmpty),
        isTrue,
        reason: '${entry['file']} needs a default (empty-match) variant',
      );
      for (final variant in variants) {
        for (final item in (variant['recurring'] as List? ?? [])
            .cast<Map<String, dynamic>>()) {
          expect(item['service_type'], isA<String>());
          expect(
            item['interval_miles'] ?? item['interval_months'],
            isNotNull,
            reason: 'recurring item needs miles and/or months',
          );
        }
        for (final item in (variant['milestones'] as List? ?? [])
            .cast<Map<String, dynamic>>()) {
          expect(item['service_type'], isA<String>());
          expect(item['odometer'], isPositive);
        }
      }
    }
  });

  test('matches a 6th-gen Bronco by make/model/year', () async {
    final m = await repo.findFor(
      vehicle(make: 'Ford', model: 'Bronco', year: 2023),
    );
    expect(m, isNotNull);
    expect(m!.generation, '6th gen');
    expect(m.variantLabel, 'default');
    expect(m.items.where((i) => i.kind == 'recurring'), isNotEmpty);
    expect(m.items.where((i) => i.kind == 'milestone'), isNotEmpty);
  });

  test('selects the engine variant when the vehicle engine matches',
      () async {
    final m = await repo.findFor(
      vehicle(make: 'jeep', model: 'Wrangler', year: 2010, engine: '3.8L V6'),
    );
    expect(m, isNotNull);
    expect(m!.variantLabel, 'engine: 3.8L');
    final plugs = m.items.firstWhere((i) => i.serviceType == 'spark plugs');
    expect(plugs.dueOdometer, 30000);
  });

  test('falls back to the default variant for an unmatched engine',
      () async {
    final m = await repo.findFor(
      vehicle(make: 'Jeep', model: 'Wrangler', year: 2015, engine: '3.6L V6'),
    );
    expect(m, isNotNull);
    expect(m!.variantLabel, 'default');
    final plugs = m.items.firstWhere((i) => i.serviceType == 'spark plugs');
    expect(plugs.dueOdometer, 100000);
  });

  test('returns null when nothing matches', () async {
    expect(
      await repo.findFor(vehicle(make: 'Honda', model: 'Civic', year: 1999)),
      isNull,
    );
    expect(
      await repo.findFor(vehicle(make: 'Ford', model: 'Bronco', year: 1996)),
      isNull,
    );
    expect(await repo.findFor(vehicle(year: 2023)), isNull,
        reason: 'make/model missing');
  });
}
