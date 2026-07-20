/// Plain data models for on-device storage.
library;

/// Well-known service types offered in pickers. Free-form types are allowed
/// anywhere a service type is stored (e.g. rules imported from a
/// manufacturer schedule).
const List<String> serviceTypes = [
  'oil change',
  'tires',
  'brakes',
  'filters',
  'battery',
  'inspection',
  'other',
];

class Vehicle {
  final int id;
  final String label;
  final String? make;
  final String? model;
  final int? year;

  /// Optional trim/engine spec (e.g. 'Badlands', '2.7L V6') used to match
  /// variant-specific manufacturer schedules.
  final String? trim;
  final String? engine;
  final int? currentOdometer;

  Vehicle({
    required this.id,
    required this.label,
    this.make,
    this.model,
    this.year,
    this.trim,
    this.engine,
    this.currentOdometer,
  });

  factory Vehicle.fromJson(Map<String, dynamic> j) => Vehicle(
    id: j['id'] as int,
    label: j['label'] as String,
    make: j['make'] as String?,
    model: j['model'] as String?,
    year: j['year'] as int?,
    trim: j['trim'] as String?,
    engine: j['engine'] as String?,
    currentOdometer: j['current_odometer'] as int?,
  );

  Vehicle copyWith({
    int? id,
    String? label,
    String? make,
    String? model,
    int? year,
    String? trim,
    String? engine,
    int? currentOdometer,
  }) {
    return Vehicle(
      id: id ?? this.id,
      label: label ?? this.label,
      make: make ?? this.make,
      model: model ?? this.model,
      year: year ?? this.year,
      trim: trim ?? this.trim,
      engine: engine ?? this.engine,
      currentOdometer: currentOdometer ?? this.currentOdometer,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'label': label,
    'make': make,
    'model': model,
    'year': year,
    'trim': trim,
    'engine': engine,
    'current_odometer': currentOdometer,
  };

  String get displayName {
    final parts = [
      if (year != null) '$year',
      if (make != null) make,
      if (model != null) model,
    ].whereType<String>().join(' ');
    return parts.isNotEmpty ? '$label ($parts)' : label;
  }
}

class Fillup {
  final int id;
  final int vehicleId;
  final DateTime date;
  final int odometer;
  final double gallons;
  final double? priceTotal;
  final String? location;
  final String? notes;
  final double? mpg;

  Fillup({
    required this.id,
    required this.vehicleId,
    required this.date,
    required this.odometer,
    required this.gallons,
    this.priceTotal,
    this.location,
    this.notes,
    this.mpg,
  });

  factory Fillup.fromJson(Map<String, dynamic> j) => Fillup(
    id: j['id'] as int,
    vehicleId: j['vehicle_id'] as int,
    date: DateTime.parse(j['date'] as String),
    odometer: j['odometer'] as int,
    gallons: (j['gallons'] as num).toDouble(),
    priceTotal: (j['price_total'] as num?)?.toDouble(),
    location: j['location'] as String?,
    notes: j['notes'] as String?,
    mpg: (j['mpg'] as num?)?.toDouble(),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'vehicle_id': vehicleId,
    'date': date.toIso8601String(),
    'odometer': odometer,
    'gallons': gallons,
    'price_total': priceTotal,
    'location': location,
    'notes': notes,
    'mpg': mpg,
  };
}

class ServiceRecord {
  final int id;
  final int vehicleId;
  final DateTime date;
  final int odometer;
  final String serviceType;
  final double? cost;
  final String? notes;

  ServiceRecord({
    required this.id,
    required this.vehicleId,
    required this.date,
    required this.odometer,
    required this.serviceType,
    this.cost,
    this.notes,
  });

  factory ServiceRecord.fromJson(Map<String, dynamic> j) => ServiceRecord(
    id: j['id'] as int,
    vehicleId: j['vehicle_id'] as int,
    date: DateTime.parse(j['date'] as String),
    odometer: j['odometer'] as int,
    serviceType: j['service_type'] as String,
    cost: (j['cost'] as num?)?.toDouble(),
    notes: j['notes'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'vehicle_id': vehicleId,
    'date': date.toIso8601String(),
    'odometer': odometer,
    'service_type': serviceType,
    'cost': cost,
    'notes': notes,
  };
}

/// A persisted reminder rule for one vehicle.
///
/// Recurring rules repeat every [intervalMiles] miles and/or
/// [intervalMonths] months after the most recent matching service.
/// Milestone rules come due once, at [dueOdometer].
class ReminderRule {
  final int id;
  final int vehicleId;
  final String serviceType;
  final String kind; // recurring | milestone
  final int? intervalMiles;
  final int? intervalMonths;
  final int? dueOdometer;
  final String source; // defaults | manufacturer | custom
  final String? notes;

  ReminderRule({
    required this.id,
    required this.vehicleId,
    required this.serviceType,
    required this.kind,
    this.intervalMiles,
    this.intervalMonths,
    this.dueOdometer,
    required this.source,
    this.notes,
  });

  factory ReminderRule.fromJson(Map<String, dynamic> j) => ReminderRule(
    id: j['id'] as int,
    vehicleId: j['vehicle_id'] as int,
    serviceType: j['service_type'] as String,
    kind: j['kind'] as String,
    intervalMiles: j['interval_miles'] as int?,
    intervalMonths: j['interval_months'] as int?,
    dueOdometer: j['due_odometer'] as int?,
    source: j['source'] as String,
    notes: j['notes'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'vehicle_id': vehicleId,
    'service_type': serviceType,
    'kind': kind,
    'interval_miles': intervalMiles,
    'interval_months': intervalMonths,
    'due_odometer': dueOdometer,
    'source': source,
    'notes': notes,
  };
}

/// Computed due-state for one [ReminderRule].
class ReminderStatus {
  final int ruleId;
  final String serviceType;
  final String kind; // recurring | milestone
  final String source; // defaults | manufacturer | custom
  final int? intervalMiles;
  final int? intervalMonths;
  final int? dueOdometer;
  final DateTime? lastServiceDate;
  final int? lastServiceOdometer;
  final int? milesUntilDue;
  final int? daysUntilDue;
  final String status; // ok | due_soon | overdue | done | unknown

  ReminderStatus({
    required this.ruleId,
    required this.serviceType,
    required this.kind,
    required this.source,
    this.intervalMiles,
    this.intervalMonths,
    this.dueOdometer,
    this.lastServiceDate,
    this.lastServiceOdometer,
    this.milesUntilDue,
    this.daysUntilDue,
    required this.status,
  });
}

class MpgPoint {
  final DateTime date;
  final int odometer;
  final double mpg;

  MpgPoint({required this.date, required this.odometer, required this.mpg});
}

class MonthlySpend {
  final String month;
  final double fuel;
  final double service;

  MonthlySpend({
    required this.month,
    required this.fuel,
    required this.service,
  });
}

class VehicleStats {
  final int totalFillups;
  final int totalServices;
  final double totalFuelCost;
  final double totalServiceCost;
  final double totalSpend;
  final double? avgMpg;
  final double? costPerMile;
  final List<MpgPoint> mpgSeries;
  final List<MonthlySpend> monthlySpend;

  VehicleStats({
    required this.totalFillups,
    required this.totalServices,
    required this.totalFuelCost,
    required this.totalServiceCost,
    required this.totalSpend,
    this.avgMpg,
    this.costPerMile,
    required this.mpgSeries,
    required this.monthlySpend,
  });
}
