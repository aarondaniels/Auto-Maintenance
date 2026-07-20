import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models.dart';
import '../providers.dart';
import 'schedule_sync_screen.dart';

final _dateFmt = DateFormat('MMM d, yyyy');
final _milesFmt = NumberFormat.decimalPattern();

class RemindersScreen extends ConsumerWidget {
  const RemindersScreen({super.key, required this.vehicle});
  final Vehicle vehicle;

  void _invalidate(WidgetRef ref) {
    ref.invalidate(remindersProvider(vehicle.id));
    ref.invalidate(reminderRulesProvider(vehicle.id));
  }

  void _openSync(BuildContext context, WidgetRef ref) {
    Navigator.of(context)
        .push<bool>(
          MaterialPageRoute(
            builder: (_) => ScheduleSyncScreen(vehicle: vehicle),
          ),
        )
        .then((imported) {
          if (imported == true) _invalidate(ref);
        });
  }

  void _showRuleSheet(BuildContext context, WidgetRef ref, {ReminderStatus? existing}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _RuleSheet(vehicle: vehicle, existing: existing),
    ).then((changed) {
      if (changed == true) _invalidate(ref);
    });
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final remindersAsync = ref.watch(remindersProvider(vehicle.id));

    return Scaffold(
      body: remindersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (reminders) {
          final syncTile = Card(
            child: ListTile(
              leading: const Icon(Icons.factory_outlined),
              title: const Text('Sync manufacturer schedule'),
              subtitle: const Text(
                'Import recommended intervals for this vehicle',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _openSync(context, ref),
            ),
          );
          if (reminders.isEmpty) {
            return ListView(
              padding: const EdgeInsets.all(8),
              children: [
                syncTile,
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(
                    child: Text('No reminders yet. Tap + to add one.'),
                  ),
                ),
              ],
            );
          }
          return RefreshIndicator(
            onRefresh: () async => _invalidate(ref),
            child: ListView.separated(
              padding: const EdgeInsets.all(8),
              itemCount: reminders.length + 1,
              separatorBuilder: (_, _) => const SizedBox(height: 4),
              itemBuilder: (_, i) {
                if (i == 0) return syncTile;
                final r = reminders[i - 1];
                return Dismissible(
                  key: ValueKey(r.ruleId),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    color: Colors.red,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 16),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  onDismissed: (_) async {
                    await ref
                        .read(apiProvider)
                        .deleteReminderRule(vehicle.id, r.ruleId);
                    _invalidate(ref);
                  },
                  child: _ReminderCard(
                    r,
                    onTap: () => _showRuleSheet(context, ref, existing: r),
                  ),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showRuleSheet(context, ref),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _ReminderCard extends StatelessWidget {
  const _ReminderCard(this.r, {required this.onTap});
  final ReminderStatus r;
  final VoidCallback onTap;

  ({Color color, IconData icon, String label}) get _style {
    switch (r.status) {
      case 'overdue':
        return (color: Colors.red, icon: Icons.warning, label: 'Overdue');
      case 'due_soon':
        return (color: Colors.orange, icon: Icons.schedule, label: 'Due soon');
      case 'ok':
        return (color: Colors.green, icon: Icons.check_circle, label: 'OK');
      case 'done':
        return (color: Colors.teal, icon: Icons.task_alt, label: 'Done');
      default:
        return (
          color: Colors.grey,
          icon: Icons.help_outline,
          label: 'No data'
        );
    }
  }

  String get _sourceLabel => switch (r.source) {
    'manufacturer' => 'manufacturer',
    'defaults' => 'default',
    _ => 'custom',
  };

  @override
  Widget build(BuildContext context) {
    final s = _style;
    final details = r.kind == 'milestone'
        ? [
            if (r.dueOdometer != null)
              'once at ${_milesFmt.format(r.dueOdometer)} mi',
          ].join()
        : [
            if (r.intervalMiles != null)
              'every ${_milesFmt.format(r.intervalMiles)} mi',
            if (r.intervalMonths != null) 'every ${r.intervalMonths} mo',
          ].join(' / ');

    final remaining = <String>[
      if (r.milesUntilDue != null)
        r.milesUntilDue! >= 0
            ? '${_milesFmt.format(r.milesUntilDue)} mi left'
            : '${_milesFmt.format(-r.milesUntilDue!)} mi over',
      if (r.daysUntilDue != null)
        r.daysUntilDue! >= 0
            ? '${r.daysUntilDue} days left'
            : '${-r.daysUntilDue!} days over',
    ].join(' · ');

    return Card(
      child: ListTile(
        onTap: onTap,
        leading: Icon(s.icon, color: s.color),
        title: Text(r.serviceType),
        subtitle: Text([
          [if (details.isNotEmpty) details, _sourceLabel].join(' · '),
          if (r.lastServiceDate != null)
            'last: ${_dateFmt.format(r.lastServiceDate!)} @ ${r.lastServiceOdometer} mi',
          if (remaining.isNotEmpty) remaining,
        ].join('\n')),
        isThreeLine: true,
        trailing: Chip(
          label: Text(s.label, style: TextStyle(color: s.color)),
          backgroundColor: s.color.withValues(alpha: 0.12),
          side: BorderSide(color: s.color),
        ),
      ),
    );
  }
}

/// Bottom sheet for adding a new reminder rule or editing an existing one.
class _RuleSheet extends ConsumerStatefulWidget {
  const _RuleSheet({required this.vehicle, this.existing});
  final Vehicle vehicle;
  final ReminderStatus? existing;

  @override
  ConsumerState<_RuleSheet> createState() => _RuleSheetState();
}

class _RuleSheetState extends ConsumerState<_RuleSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _type = TextEditingController(
    text: widget.existing?.serviceType ?? '',
  );
  late String _kind = widget.existing?.kind ?? 'recurring';
  late final _intervalMiles = TextEditingController(
    text: widget.existing?.intervalMiles?.toString() ?? '',
  );
  late final _intervalMonths = TextEditingController(
    text: widget.existing?.intervalMonths?.toString() ?? '',
  );
  late final _dueOdometer = TextEditingController(
    text: widget.existing?.dueOdometer?.toString() ?? '',
  );
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _type.dispose();
    _intervalMiles.dispose();
    _intervalMonths.dispose();
    _dueOdometer.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final body = {
      'service_type': _type.text.trim(),
      'kind': _kind,
      'interval_miles': _kind == 'recurring'
          ? int.tryParse(_intervalMiles.text.trim())
          : null,
      'interval_months': _kind == 'recurring'
          ? int.tryParse(_intervalMonths.text.trim())
          : null,
      'due_odometer': _kind == 'milestone'
          ? int.tryParse(_dueOdometer.text.trim())
          : null,
    };
    try {
      final api = ref.read(apiProvider);
      if (widget.existing != null) {
        await api.updateReminderRule(
          widget.vehicle.id,
          widget.existing!.ruleId,
          body,
        );
      } else {
        await api.createReminderRule(widget.vehicle.id, body);
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, bottomInset + 16),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.existing != null ? 'Edit reminder' : 'Add reminder',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _type,
              decoration: const InputDecoration(
                labelText: 'Service type',
                hintText: 'e.g. oil change, spark plugs',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Enter a type' : null,
            ),
            const SizedBox(height: 12),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'recurring', label: Text('Recurring')),
                ButtonSegment(value: 'milestone', label: Text('One-time')),
              ],
              selected: {_kind},
              onSelectionChanged: (s) => setState(() => _kind = s.first),
            ),
            const SizedBox(height: 12),
            if (_kind == 'recurring') ...[
              TextFormField(
                controller: _intervalMiles,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Every X miles',
                  border: OutlineInputBorder(),
                ),
                validator: (_) =>
                    (int.tryParse(_intervalMiles.text.trim()) == null &&
                        int.tryParse(_intervalMonths.text.trim()) == null)
                    ? 'Enter miles and/or months'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _intervalMonths,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Every X months',
                  border: OutlineInputBorder(),
                ),
              ),
            ] else
              TextFormField(
                controller: _dueOdometer,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Due at odometer (mi)',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v == null || int.tryParse(v.trim()) == null)
                    ? 'Enter miles'
                    : null,
              ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}
