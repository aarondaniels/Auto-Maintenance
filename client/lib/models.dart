/// Plain data models mirroring the FastAPI response schemas.
library;

class Vehicle {
  final int id;
  final String label;
  final String? make;
  final String? model;
  final int? year;
  final int? currentOdometer;

  Vehicle({
    required this.id,
    required this.label,
    this.make,
    this.model,
    this.year,
    this.currentOdometer,
  });

  factory Vehicle.fromJson(Map<String, dynamic> j) => Vehicle(
        id: j['id'] as int,
        label: j['label'] as String,
        make: j['make'] as String?,
        model: j['model'] as String?,
        year: j['year'] as int?,
        currentOdometer: j['current_odometer'] as int?,
      );

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
  final DateTime date;
  final int odometer;
  final double gallons;
  final double? priceTotal;
  final String? location;
  final String? notes;
  final double? mpg;

  Fillup({
    required this.id,
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
        date: DateTime.parse(j['date'] as String),
        odometer: j['odometer'] as int,
        gallons: (j['gallons'] as num).toDouble(),
        priceTotal: (j['price_total'] as num?)?.toDouble(),
        location: j['location'] as String?,
        notes: j['notes'] as String?,
        mpg: (j['mpg'] as num?)?.toDouble(),
      );
}

class ServiceRecord {
  final int id;
  final DateTime date;
  final int odometer;
  final String serviceType;
  final double? cost;
  final String? notes;

  ServiceRecord({
    required this.id,
    required this.date,
    required this.odometer,
    required this.serviceType,
    this.cost,
    this.notes,
  });

  factory ServiceRecord.fromJson(Map<String, dynamic> j) => ServiceRecord(
        id: j['id'] as int,
        date: DateTime.parse(j['date'] as String),
        odometer: j['odometer'] as int,
        serviceType: j['service_type'] as String,
        cost: (j['cost'] as num?)?.toDouble(),
        notes: j['notes'] as String?,
      );
}

class ReminderStatus {
  final String serviceType;
  final int? intervalMiles;
  final int? intervalMonths;
  final DateTime? lastServiceDate;
  final int? lastServiceOdometer;
  final int? milesUntilDue;
  final int? daysUntilDue;
  final String status; // ok | due_soon | overdue | unknown

  ReminderStatus({
    required this.serviceType,
    this.intervalMiles,
    this.intervalMonths,
    this.lastServiceDate,
    this.lastServiceOdometer,
    this.milesUntilDue,
    this.daysUntilDue,
    required this.status,
  });

  factory ReminderStatus.fromJson(Map<String, dynamic> j) => ReminderStatus(
        serviceType: j['service_type'] as String,
        intervalMiles: j['interval_miles'] as int?,
        intervalMonths: j['interval_months'] as int?,
        lastServiceDate: j['last_service_date'] != null
            ? DateTime.parse(j['last_service_date'] as String)
            : null,
        lastServiceOdometer: j['last_service_odometer'] as int?,
        milesUntilDue: j['miles_until_due'] as int?,
        daysUntilDue: j['days_until_due'] as int?,
        status: j['status'] as String,
      );
}

class MpgPoint {
  final DateTime date;
  final int odometer;
  final double mpg;

  MpgPoint({required this.date, required this.odometer, required this.mpg});

  factory MpgPoint.fromJson(Map<String, dynamic> j) => MpgPoint(
        date: DateTime.parse(j['date'] as String),
        odometer: j['odometer'] as int,
        mpg: (j['mpg'] as num).toDouble(),
      );
}

class MonthlySpend {
  final String month;
  final double fuel;
  final double service;

  MonthlySpend({required this.month, required this.fuel, required this.service});

  factory MonthlySpend.fromJson(Map<String, dynamic> j) => MonthlySpend(
        month: j['month'] as String,
        fuel: (j['fuel'] as num).toDouble(),
        service: (j['service'] as num).toDouble(),
      );
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

  factory VehicleStats.fromJson(Map<String, dynamic> j) => VehicleStats(
        totalFillups: j['total_fillups'] as int,
        totalServices: j['total_services'] as int,
        totalFuelCost: (j['total_fuel_cost'] as num).toDouble(),
        totalServiceCost: (j['total_service_cost'] as num).toDouble(),
        totalSpend: (j['total_spend'] as num).toDouble(),
        avgMpg: (j['avg_mpg'] as num?)?.toDouble(),
        costPerMile: (j['cost_per_mile'] as num?)?.toDouble(),
        mpgSeries: (j['mpg_series'] as List)
            .map((e) => MpgPoint.fromJson(e as Map<String, dynamic>))
            .toList(),
        monthlySpend: (j['monthly_spend'] as List)
            .map((e) => MonthlySpend.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
