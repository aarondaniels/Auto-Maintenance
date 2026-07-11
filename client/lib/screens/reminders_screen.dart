import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models.dart';
import '../providers.dart';

final _dateFmt = DateFormat('MMM d, yyyy');

class RemindersScreen extends ConsumerWidget {
  const RemindersScreen({super.key, required this.vehicle});
  final Vehicle vehicle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final remindersAsync = ref.watch(remindersProvider(vehicle.id));

    return remindersAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
      data: (reminders) {
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(remindersProvider(vehicle.id)),
          child: ListView.separated(
            padding: const EdgeInsets.all(8),
            itemCount: reminders.length,
            separatorBuilder: (_, _) => const SizedBox(height: 4),
            itemBuilder: (_, i) => _ReminderCard(reminders[i]),
          ),
        );
      },
    );
  }
}

class _ReminderCard extends StatelessWidget {
  const _ReminderCard(this.r);
  final ReminderStatus r;

  ({Color color, IconData icon, String label}) get _style {
    switch (r.status) {
      case 'overdue':
        return (color: Colors.red, icon: Icons.warning, label: 'Overdue');
      case 'due_soon':
        return (color: Colors.orange, icon: Icons.schedule, label: 'Due soon');
      case 'ok':
        return (color: Colors.green, icon: Icons.check_circle, label: 'OK');
      default:
        return (
          color: Colors.grey,
          icon: Icons.help_outline,
          label: 'No data'
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _style;
    final details = <String>[
      if (r.intervalMiles != null) 'every ${r.intervalMiles} mi',
      if (r.intervalMonths != null) 'every ${r.intervalMonths} mo',
    ].join(' / ');

    final remaining = <String>[
      if (r.milesUntilDue != null)
        r.milesUntilDue! >= 0
            ? '${r.milesUntilDue} mi left'
            : '${-r.milesUntilDue!} mi over',
      if (r.daysUntilDue != null)
        r.daysUntilDue! >= 0
            ? '${r.daysUntilDue} days left'
            : '${-r.daysUntilDue!} days over',
    ].join(' · ');

    return Card(
      child: ListTile(
        leading: Icon(s.icon, color: s.color),
        title: Text(r.serviceType),
        subtitle: Text([
          if (details.isNotEmpty) details,
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
