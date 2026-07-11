import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models.dart';
import '../providers.dart';

final _dateFmt = DateFormat('MMM d, yyyy');

class FillupsScreen extends ConsumerWidget {
  const FillupsScreen({super.key, required this.vehicle});
  final Vehicle vehicle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fillupsAsync = ref.watch(fillupsProvider(vehicle.id));

    return Scaffold(
      body: fillupsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (fillups) {
          if (fillups.isEmpty) {
            return const _Empty(text: 'No fillups yet. Tap + to add one.');
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(fillupsProvider(vehicle.id)),
            child: ListView.separated(
              itemCount: fillups.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final f = fillups[i];
                return Dismissible(
                  key: ValueKey(f.id),
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
                        .deleteFillup(vehicle.id, f.id);
                    ref.invalidate(fillupsProvider(vehicle.id));
                    ref.invalidate(statsProvider(vehicle.id));
                  },
                  child: ListTile(
                    leading: const Icon(Icons.local_gas_station),
                    title: Text(
                      '${f.gallons.toStringAsFixed(1)} gal'
                      '${f.priceTotal != null ? ' · \$${f.priceTotal!.toStringAsFixed(2)}' : ''}',
                    ),
                    subtitle: Text(
                      '${_dateFmt.format(f.date)} · ${f.odometer} mi'
                      '${f.location != null ? ' · ${f.location}' : ''}',
                    ),
                    trailing: f.mpg != null
                        ? Chip(label: Text('${f.mpg!.toStringAsFixed(1)} mpg'))
                        : null,
                  ),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddSheet(context, ref),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showAddSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _AddFillupSheet(vehicle: vehicle),
    ).then((added) {
      if (added == true) {
        ref.invalidate(fillupsProvider(vehicle.id));
        ref.invalidate(statsProvider(vehicle.id));
      }
    });
  }
}

class _AddFillupSheet extends ConsumerStatefulWidget {
  const _AddFillupSheet({required this.vehicle});
  final Vehicle vehicle;

  @override
  ConsumerState<_AddFillupSheet> createState() => _AddFillupSheetState();
}

class _AddFillupSheetState extends ConsumerState<_AddFillupSheet> {
  final _formKey = GlobalKey<FormState>();
  DateTime _date = DateTime.now();
  final _odometer = TextEditingController();
  final _gallons = TextEditingController();
  final _price = TextEditingController();
  final _location = TextEditingController();
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
    _gallons.dispose();
    _price.dispose();
    _location.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(apiProvider).createFillup(widget.vehicle.id, {
        'date': DateFormat('yyyy-MM-dd').format(_date),
        'odometer': int.parse(_odometer.text.trim()),
        'gallons': double.parse(_gallons.text.trim()),
        if (_price.text.trim().isNotEmpty)
          'price_total': double.tryParse(_price.text.trim()),
        if (_location.text.trim().isNotEmpty) 'location': _location.text.trim(),
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
            Text('Add fillup',
                style: Theme.of(context).textTheme.titleLarge),
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
                  labelText: 'Odometer (mi)', border: OutlineInputBorder()),
              validator: (v) =>
                  (v == null || int.tryParse(v.trim()) == null)
                      ? 'Enter miles'
                      : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _gallons,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                  labelText: 'Gallons', border: OutlineInputBorder()),
              validator: (v) {
                final d = double.tryParse((v ?? '').trim());
                return (d == null || d <= 0) ? 'Enter gallons' : null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _price,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                  labelText: 'Total price (\$)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _location,
              decoration: const InputDecoration(
                  labelText: 'Location (optional)',
                  border: OutlineInputBorder()),
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

class _Empty extends StatelessWidget {
  const _Empty({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) =>
      Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(text)));
}
