import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/entries.dart';
import '../theme.dart';

/// Popup couche : un seul choix, trois gros boutons, fermeture immédiate.
Future<DiaperEntry?> showDiaperSheet(BuildContext context) {
  return showModalBottomSheet<DiaperEntry>(
    context: context,
    builder: (ctx) {
      final p = ctx.palette;
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Type de couche',
                textAlign: TextAlign.center,
                style: Theme.of(ctx).textTheme.titleLarge),
            const SizedBox(height: 16),
            for (final t in DiaperType.values) ...[
              FilledButton.tonalIcon(
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(64),
                  backgroundColor: p.diaper.withValues(alpha: 0.18),
                  foregroundColor: p.diaper,
                  textStyle: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w700),
                ),/*
                icon: Icon(switch (t) {
                  DiaperType.pipi => Icons.water_drop,
                  DiaperType.caca => Icons.cloud,
                  DiaperType.mixte => Icons.all_inclusive,
                }),*/
                label: Text(switch (t) {
                  DiaperType.pipi => 'Pipi',
                  DiaperType.caca => 'Caca',
                  DiaperType.mixte => 'Mixte',
                }),
                onPressed: () {
                  HapticFeedback.lightImpact();
                  Navigator.of(ctx)
                      .pop(DiaperEntry(at: DateTime.now(), type: t));
                },
              ),
              const SizedBox(height: 12),
            ],
          ],
        ),
      );
    },
  );
}

/// Popup sommeil : heure de début et de fin.
Future<SleepEntry?> showSleepSheet(BuildContext context) {
  return showModalBottomSheet<SleepEntry>(
    context: context,
    isScrollControlled: true,
    builder: (_) => const _SleepSheet(),
  );
}

class _SleepSheet extends StatefulWidget {
  const _SleepSheet();

  @override
  State<_SleepSheet> createState() => _SleepSheetState();
}

class _SleepSheetState extends State<_SleepSheet> {
  late TimeOfDay start;
  TimeOfDay? end;

  @override
  void initState() {
    super.initState();
    start = TimeOfDay.now();
  }

  DateTime _toDateTime(TimeOfDay t, {DateTime? after}) {
    final now = DateTime.now();
    var dt = DateTime(now.year, now.month, now.day, t.hour, t.minute);
    // Si la fin est "avant" le début, on suppose que le début était hier
    // (sieste qui traverse minuit) — on garde simple : fin > début.
    if (after != null && dt.isBefore(after)) {
      dt = dt.add(const Duration(days: 1));
    }
    return dt;
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Sommeil',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          _TimeRow(
            label: 'Début',
            icon: Icons.bedtime_outlined,     // 🌙 on s'endort
            value: start,
            onPick: (t) => setState(() => start = t),
          ),
          const SizedBox(height: 8),
          _TimeRow(
            label: 'Fin',
            icon: Icons.wb_sunny_outlined,    // ☀️ on se réveille
            value: end,
            optionalHint: 'En cours…',
            onPick: (t) => setState(() => end = t),
          ),
          const SizedBox(height: 20),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: p.sleep,
              foregroundColor: p.onAccent,
              minimumSize: const Size.fromHeight(60),
              textStyle:
              const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            onPressed: () {
              HapticFeedback.lightImpact();
              final startDt = _toDateTime(start);
              final endDt =
              end == null ? null : _toDateTime(end!, after: startDt);
              Navigator.of(context)
                  .pop(SleepEntry(start: startDt, end: endDt));
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
  }
}

class _TimeRow extends StatelessWidget {
  final String label;
  final TimeOfDay? value;
  final String? optionalHint;
  final ValueChanged<TimeOfDay> onPick;
  final IconData icon;

  const _TimeRow({
    required this.label,
    required this.value,
    required this.onPick,
    required this.icon,
    this.optionalHint,
  });

  Future<void> _pick(BuildContext context) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: value ?? TimeOfDay.now(),
      initialEntryMode: TimePickerEntryMode.input,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked != null) onPick(picked);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      onTap: () => _pick(context),
      leading: Icon(icon, color: p.sleep),
      title: Text(label),
      trailing: Text(
        value?.format(context) ?? optionalHint ?? '--:--',
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: value != null ? p.text : p.textMuted,
        ),
      ),
    );
  }
}