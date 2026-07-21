import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models.dart';
import '../providers.dart';
import '../widgets/glass.dart';

final _dateFmt = DateFormat('MMM d, yyyy');

class ServicesScreen extends ConsumerWidget {
  const ServicesScreen({super.key, required this.vehicle});
  final Vehicle vehicle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final servicesAsync = ref.watch(servicesProvider(vehicle.id));

    return Scaffold(
      body: servicesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (services) {
          if (services.isEmpty) {
            return Center(
              child: Padding(
                padding: EdgeInsets.only(
                  top: glassTopInset(context),
                  bottom: glassBottomInset(context),
                  left: 24,
                  right: 24,
                ),
                child: const Text('No service records yet. Tap + to add one.'),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(servicesProvider(vehicle.id)),
            child: ListView.separated(
              padding: EdgeInsets.only(
                top: glassTopInset(context),
                bottom: glassBottomInset(context),
              ),
              itemCount: services.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final s = services[i];
                return Dismissible(
                  key: ValueKey(s.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    color: Colors.red,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 16),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  onDismissed: (_) async {
                    await ref.read(apiProvider).deleteService(vehicle.id, s.id);
                    ref.invalidate(servicesProvider(vehicle.id));
                    ref.invalidate(remindersProvider(vehicle.id));
                    ref.invalidate(statsProvider(vehicle.id));
                  },
                  child: ListTile(
                    leading: const Icon(Icons.build),
                    title: Text(
                      '${s.serviceType}'
                      '${s.cost != null ? ' · \$${s.cost!.toStringAsFixed(2)}' : ''}',
                    ),
                    subtitle: Text(
                      '${_dateFmt.format(s.date)} · ${s.odometer} mi'
                      '${s.notes != null ? '\n${s.notes}' : ''}',
                    ),
                    isThreeLine: s.notes != null,
                  ),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: Padding(
        padding: EdgeInsets.only(bottom: glassBottomInset(context)),
        child: GlassButton(
          icon: const Icon(Icons.add),
          onTap: () => _showAddSheet(context, ref),
        ),
      ),
    );
  }

  void _showAddSheet(BuildContext context, WidgetRef ref) {
    GlassModalSheet.show<bool>(
      context: context,
      builder: (_) => _AddServiceSheet(vehicle: vehicle),
    ).then((added) {
      if (added == true) {
        ref.invalidate(servicesProvider(vehicle.id));
        ref.invalidate(remindersProvider(vehicle.id));
        ref.invalidate(statsProvider(vehicle.id));
      }
    });
  }
}

class _AddServiceSheet extends ConsumerStatefulWidget {
  const _AddServiceSheet({required this.vehicle});
  final Vehicle vehicle;

  @override
  ConsumerState<_AddServiceSheet> createState() => _AddServiceSheetState();
}

class _AddServiceSheetState extends ConsumerState<_AddServiceSheet> {
  final _formKey = GlobalKey<FormState>();
  DateTime _date = DateTime.now();
  String _type = serviceTypes.first;
  final _odometer = TextEditingController();
  final _cost = TextEditingController();
  final _notes = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.vehicle.currentOdometer != null) {
      _odometer.text = '${widget.vehicle.currentOdometer}';
    }
  }

  @override
  void dispose() {
    _odometer.dispose();
    _cost.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(apiProvider).createService(widget.vehicle.id, {
        'date': DateFormat('yyyy-MM-dd').format(_date),
        'odometer': int.parse(_odometer.text.trim()),
        'service_type': _type,
        if (_cost.text.trim().isNotEmpty)
          'cost': double.tryParse(_cost.text.trim()),
        if (_notes.text.trim().isNotEmpty) 'notes': _notes.text.trim(),
      });
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
            Text('Add service', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            Builder(
              builder: (context) {
                // Offer the standard types plus any types this vehicle's
                // reminder rules use (e.g. imported manufacturer items).
                final ruleTypes =
                    ref
                        .watch(reminderRulesProvider(widget.vehicle.id))
                        .value
                        ?.map((r) => r.serviceType.toLowerCase()) ??
                    const Iterable<String>.empty();
                final types = {...serviceTypes, ...ruleTypes}.toList();
                return DropdownButtonFormField<String>(
                  initialValue: _type,
                  decoration: const InputDecoration(
                    labelText: 'Service type',
                    border: OutlineInputBorder(),
                  ),
                  items: types
                      .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                      .toList(),
                  onChanged: (v) => setState(() => _type = v ?? _type),
                );
              },
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Date'),
              trailing: Text(_dateFmt.format(_date)),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _date,
                  firstDate: DateTime(2000),
                  lastDate: DateTime.now(),
                );
                if (picked != null) setState(() => _date = picked);
              },
            ),
            TextFormField(
              controller: _odometer,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Odometer (mi)',
                border: OutlineInputBorder(),
              ),
              validator: (v) => (v == null || int.tryParse(v.trim()) == null)
                  ? 'Enter miles'
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _cost,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Cost (\$)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notes,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
                border: OutlineInputBorder(),
              ),
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
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}
