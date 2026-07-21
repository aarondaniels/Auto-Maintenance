import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models.dart';
import '../providers.dart';
import '../widgets/glass.dart';

class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key, required this.vehicle});
  final Vehicle vehicle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(statsProvider(vehicle.id));

    return statsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
      data: (stats) {
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(statsProvider(vehicle.id)),
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              16,
              glassTopInset(context) + 16,
              16,
              glassBottomInset(context) + 16,
            ),
            children: [
              _SummaryGrid(stats: stats),
              const SizedBox(height: 20),
              Text(
                'MPG over time',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              SizedBox(height: 220, child: _MpgChart(points: stats.mpgSeries)),
              const SizedBox(height: 20),
              Text(
                'Monthly spend (fuel vs. service)',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              _MonthlySpendList(items: stats.monthlySpend),
            ],
          ),
        );
      },
    );
  }
}

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({required this.stats});
  final VehicleStats stats;

  @override
  Widget build(BuildContext context) {
    final tiles = <({String label, String value})>[
      (label: 'Avg MPG', value: stats.avgMpg?.toStringAsFixed(1) ?? '—'),
      (
        label: 'Cost / mile',
        value: stats.costPerMile != null
            ? '\$${stats.costPerMile!.toStringAsFixed(3)}'
            : '—',
      ),
      (label: 'Total spend', value: '\$${stats.totalSpend.toStringAsFixed(0)}'),
      (
        label: 'Fuel cost',
        value: '\$${stats.totalFuelCost.toStringAsFixed(0)}',
      ),
      (
        label: 'Service cost',
        value: '\$${stats.totalServiceCost.toStringAsFixed(0)}',
      ),
      (
        label: 'Records',
        value: '${stats.totalFillups}f / ${stats.totalServices}s',
      ),
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 2.2,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      children: tiles
          .map(
            (t) => Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.value,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(t.label, style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _MpgChart extends StatelessWidget {
  const _MpgChart({required this.points});
  final List<MpgPoint> points;

  @override
  Widget build(BuildContext context) {
    if (points.length < 2) {
      return const Center(
        child: Text('Add at least two fillups to see an MPG trend.'),
      );
    }
    final spots = <FlSpot>[
      for (var i = 0; i < points.length; i++)
        FlSpot(i.toDouble(), points[i].mpg),
    ];
    final color = Theme.of(context).colorScheme.primary;

    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: true, drawVerticalLine: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: true, reservedSize: 36),
          ),
          bottomTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: color,
            barWidth: 3,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(
              show: true,
              color: color.withValues(alpha: 0.15),
            ),
          ),
        ],
      ),
    );
  }
}

class _MonthlySpendList extends StatelessWidget {
  const _MonthlySpendList({required this.items});
  final List<MonthlySpend> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Text('No spend recorded yet.');
    }
    final maxTotal = items
        .map((m) => m.fuel + m.service)
        .fold<double>(0, (a, b) => b > a ? b : a);

    return Column(
      children: items.map((m) {
        final total = m.fuel + m.service;
        final fuelFrac = maxTotal == 0 ? 0.0 : m.fuel / maxTotal;
        final serviceFrac = maxTotal == 0 ? 0.0 : m.service / maxTotal;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(m.month),
                  Text('\$${total.toStringAsFixed(2)}'),
                ],
              ),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Row(
                  children: [
                    Expanded(
                      flex: (fuelFrac * 1000).round().clamp(0, 1000),
                      child: Container(height: 12, color: Colors.blue),
                    ),
                    Expanded(
                      flex: (serviceFrac * 1000).round().clamp(0, 1000),
                      child: Container(height: 12, color: Colors.orange),
                    ),
                    // Spacer remainder so bars are proportional to the max month.
                    Expanded(
                      flex: ((1 - fuelFrac - serviceFrac) * 1000).round().clamp(
                        0,
                        1000,
                      ),
                      child: const SizedBox(height: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
