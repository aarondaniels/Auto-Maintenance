import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models.dart';
import '../providers.dart';
import '../schedules.dart';
import '../widgets/glass.dart';

final _milesFmt = NumberFormat.decimalPattern();

/// Review-and-import screen for a bundled manufacturer schedule.
/// Pops `true` after importing.
class ScheduleSyncScreen extends ConsumerStatefulWidget {
  const ScheduleSyncScreen({super.key, required this.vehicle});
  final Vehicle vehicle;

  @override
  ConsumerState<ScheduleSyncScreen> createState() => _ScheduleSyncScreenState();
}

class _ScheduleSyncScreenState extends ConsumerState<ScheduleSyncScreen> {
  late final Future<MatchedSchedule?> _lookup;
  final _selected = <ScheduleItem>{};
  bool _initialized = false;
  bool _importing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _lookup = ref.read(scheduleRepositoryProvider).findFor(widget.vehicle);
  }

  Future<void> _import(MatchedSchedule schedule) async {
    setState(() {
      _importing = true;
      _error = null;
    });
    try {
      await ref.read(apiProvider).importManufacturerRules(widget.vehicle.id, [
        for (final item in schedule.items)
          if (_selected.contains(item)) item.toRuleBody(),
      ]);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: GlassAppBar(
        title: const Text('Manufacturer schedule'),
        leading: GlassIconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: FutureBuilder<MatchedSchedule?>(
        future: _lookup,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final schedule = snapshot.data;
          if (schedule == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.search_off, size: 48),
                    const SizedBox(height: 12),
                    const Text(
                      'No manufacturer schedule is available for this '
                      'vehicle yet.\n\nYou can still add reminders manually '
                      'from the Reminders tab.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Back'),
                    ),
                  ],
                ),
              ),
            );
          }

          // Pre-select everything on first build with data.
          if (!_initialized) {
            _initialized = true;
            _selected.addAll(schedule.items);
          }

          final recurring = schedule.items
              .where((i) => i.kind == 'recurring')
              .toList();
          final milestones = schedule.items
              .where((i) => i.kind == 'milestone')
              .toList();

          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    glassTopInset(context) + 16,
                    16,
                    16,
                  ),
                  children: [
                    Text(
                      'Found: ${schedule.title}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Variant: ${schedule.variantLabel} · '
                      '${schedule.conditions} conditions',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${schedule.source}. Intervals are transcribed from '
                      'public documentation — verify against your owner\'s '
                      'manual.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Importing replaces previously imported manufacturer '
                      'reminders and the default reminders they supersede. '
                      'Custom reminders are kept.',
                    ),
                    if (recurring.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text(
                        'Recurring',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      for (final item in recurring) _itemTile(item),
                    ],
                    if (milestones.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text(
                        'Milestones',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      for (final item in milestones) _itemTile(item),
                    ],
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(_error!, style: const TextStyle(color: Colors.red)),
                    ],
                  ],
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: FilledButton(
                    onPressed: _importing || _selected.isEmpty
                        ? null
                        : () => _import(schedule),
                    child: _importing
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text('Import ${_selected.length} reminders'),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _itemTile(ScheduleItem item) {
    final subtitle = item.kind == 'milestone'
        ? 'once at ${_milesFmt.format(item.dueOdometer)} mi'
        : [
            if (item.intervalMiles != null)
              'every ${_milesFmt.format(item.intervalMiles)} mi',
            if (item.intervalMonths != null) 'every ${item.intervalMonths} mo',
          ].join(' / ');
    return CheckboxListTile(
      value: _selected.contains(item),
      onChanged: (checked) => setState(() {
        checked == true ? _selected.add(item) : _selected.remove(item);
      }),
      title: Text(item.serviceType),
      subtitle: Text(subtitle),
      controlAffinity: ListTileControlAffinity.leading,
      contentPadding: EdgeInsets.zero,
    );
  }
}
