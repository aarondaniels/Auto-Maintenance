/// Bundled manufacturer maintenance schedules: models, loader, and matcher.
///
/// Schedules ship as JSON under `assets/schedules/`, indexed by
/// `index.json`. Matching is offline: normalized make/model plus model year
/// select a schedule file; the vehicle's trim/engine (when set) selects a
/// variant, falling back to the default variant.
library;

import 'dart:convert';

import 'package:flutter/services.dart' show AssetBundle, rootBundle;

import 'models.dart';

/// One line item of a manufacturer schedule.
class ScheduleItem {
  final String serviceType;
  final String kind; // recurring | milestone
  final int? intervalMiles;
  final int? intervalMonths;
  final int? dueOdometer;
  final String? notes;

  ScheduleItem({
    required this.serviceType,
    required this.kind,
    this.intervalMiles,
    this.intervalMonths,
    this.dueOdometer,
    this.notes,
  });

  /// Body for [ApiClient.createReminderRule]-shaped import calls.
  Map<String, dynamic> toRuleBody() => {
    'service_type': serviceType,
    'kind': kind,
    'interval_miles': intervalMiles,
    'interval_months': intervalMonths,
    'due_odometer': dueOdometer,
    'notes': notes,
  };
}

/// A schedule resolved for a specific vehicle (variant already selected).
class MatchedSchedule {
  final String make;
  final String model;
  final String generation;
  final int yearFrom;
  final int yearTo;
  final String conditions;
  final String source;

  /// Description of the matched variant ('default' or e.g. 'engine: 3.8L').
  final String variantLabel;
  final List<ScheduleItem> items;

  MatchedSchedule({
    required this.make,
    required this.model,
    required this.generation,
    required this.yearFrom,
    required this.yearTo,
    required this.conditions,
    required this.source,
    required this.variantLabel,
    required this.items,
  });

  String get title =>
      '${_titleCase(make)} ${_titleCase(model)}, $generation '
      '($yearFrom–$yearTo)';

  static String _titleCase(String s) => s
      .split(' ')
      .map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1))
      .join(' ');
}

String _normalize(String? s) => (s ?? '').trim().toLowerCase();

/// Loads and matches bundled schedules. Takes an [AssetBundle] so tests can
/// substitute one; defaults to [rootBundle].
class ScheduleRepository {
  ScheduleRepository({AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;

  final AssetBundle _bundle;
  static const _dir = 'assets/schedules';

  /// Returns the schedule matching [vehicle], or null when the bundle has
  /// no entry for its make/model/year.
  Future<MatchedSchedule?> findFor(Vehicle vehicle) async {
    final make = _normalize(vehicle.make);
    final model = _normalize(vehicle.model);
    final year = vehicle.year;
    if (make.isEmpty || model.isEmpty || year == null) return null;

    final index =
        jsonDecode(await _bundle.loadString('$_dir/index.json'))
            as Map<String, dynamic>;
    for (final raw in index['schedules'] as List) {
      final entry = raw as Map<String, dynamic>;
      final years = (entry['years'] as List).cast<int>();
      if (_normalize(entry['make'] as String) == make &&
          _normalize(entry['model'] as String) == model &&
          year >= years[0] &&
          year <= years[1]) {
        return _loadSchedule(entry['file'] as String, vehicle);
      }
    }
    return null;
  }

  Future<MatchedSchedule> _loadSchedule(String file, Vehicle vehicle) async {
    final json =
        jsonDecode(await _bundle.loadString('$_dir/$file'))
            as Map<String, dynamic>;
    final years = (json['years'] as List).cast<int>();
    final variants = (json['variants'] as List).cast<Map<String, dynamic>>();

    final variant = _selectVariant(variants, vehicle);
    final match = (variant['match'] as Map<String, dynamic>? ?? {});
    final label = match.isEmpty
        ? 'default'
        : match.entries.map((e) => '${e.key}: ${e.value}').join(', ');

    return MatchedSchedule(
      make: json['make'] as String,
      model: json['model'] as String,
      generation: json['generation'] as String,
      yearFrom: years[0],
      yearTo: years[1],
      conditions: json['conditions'] as String,
      source: json['source'] as String,
      variantLabel: label,
      items: [
        for (final item
            in (variant['recurring'] as List? ?? [])
                .cast<Map<String, dynamic>>())
          ScheduleItem(
            serviceType: item['service_type'] as String,
            kind: 'recurring',
            intervalMiles: item['interval_miles'] as int?,
            intervalMonths: item['interval_months'] as int?,
            notes: item['notes'] as String?,
          ),
        for (final item
            in (variant['milestones'] as List? ?? [])
                .cast<Map<String, dynamic>>())
          ScheduleItem(
            serviceType: item['service_type'] as String,
            kind: 'milestone',
            dueOdometer: item['odometer'] as int?,
            notes: item['notes'] as String?,
          ),
      ],
    );
  }

  /// Picks the first variant whose every `match` value appears in the
  /// vehicle's corresponding field (case-insensitive substring); falls back
  /// to the default (empty-match) variant.
  Map<String, dynamic> _selectVariant(
    List<Map<String, dynamic>> variants,
    Vehicle vehicle,
  ) {
    final fields = {
      'trim': _normalize(vehicle.trim),
      'engine': _normalize(vehicle.engine),
    };
    for (final variant in variants) {
      final match = variant['match'] as Map<String, dynamic>? ?? {};
      if (match.isEmpty) continue;
      final hits = match.entries.every((e) {
        final field = fields[e.key] ?? '';
        return field.isNotEmpty &&
            field.contains(_normalize(e.value as String));
      });
      if (hits) return variant;
    }
    return variants.firstWhere(
      (v) => (v['match'] as Map<String, dynamic>? ?? {}).isEmpty,
      orElse: () => variants.first,
    );
  }
}
