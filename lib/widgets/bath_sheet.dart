import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/entries.dart';
import '../theme.dart';

/// Popup bain : type (bain complet ou rinçage), heure du lavage,
/// et notes libres pour les parents.
Future<BathEntry?> showBathSheet(BuildContext context) {
  return showModalBottomSheet<BathEntry>(
    context: context,
    isScrollControlled: true,
    builder: (_) => const _BathSheet(),
  );
}

class _BathSheet extends StatefulWidget {
  const _BathSheet();

  @override
  State<_BathSheet> createState() => _BathSheetState();
}

class _BathSheetState extends State<_BathSheet> {
  BathType type = BathType.bain;
  late TimeOfDay time;
  final _notesCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    time = TimeOfDay.now();
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  /// Convertit l'heure choisie en DateTime. Si l'heure est dans le futur
  /// (ex. il est 8h et on encode un bain "à 19h"), on suppose que c'était
  /// hier soir — même logique que le sheet sommeil.
  DateTime _toDateTime(TimeOfDay t) {
    final now = DateTime.now();
    var dt = DateTime(now.year, now.month, now.day, t.hour, t.minute);
    if (dt.isAfter(now)) dt = dt.subtract(const Duration(days: 1));
    return dt;
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: time,
      initialEntryMode: TimePickerEntryMode.input,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked != null) setState(() => time = picked);
  }

  void _save() {
    final notes = _notesCtrl.text.trim();
    Navigator.of(context).pop(BathEntry(
      at: _toDateTime(time),
      type: type,
      notes: notes.isEmpty ? null : notes,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        // Laisse la place au clavier quand le champ notes a le focus.
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Bain',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),

          // ── Bain complet ou simple rinçage ──
          SegmentedButton<BathType>(
            style: ButtonStyle(
              textStyle: const WidgetStatePropertyAll(
                TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              padding: const WidgetStatePropertyAll(
                EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              ),
            ),
            segments: const [
              ButtonSegment(
                value: BathType.bain,
                label: Text('Bain'),
                icon: Icon(Icons.bathtub_outlined, size: 20),
              ),
              ButtonSegment(
                value: BathType.rincage,
                label: Text('Rinçage'),
                icon: Icon(Icons.shower_outlined, size: 20),
              ),
            ],
            selected: {type},
            onSelectionChanged: (v) => setState(() => type = v.first),
          ),

          const SizedBox(height: 16),

          // ── Heure du lavage ──
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.schedule, color: p.measure),
            title: const Text('Heure'),
            trailing: TextButton(
              onPressed: _pickTime,
              child: Text(
                time.format(context),
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
            ),
          ),

          const SizedBox(height: 8),

          // ── Notes libres ──
          TextField(
            controller: _notesCtrl,
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: 'Notes',
              hintText: 'Shampoing, réaction, humeur…',
              alignLabelWithHint: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),

          const SizedBox(height: 20),

          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: p.measure,
              foregroundColor: p.onAccent,
              minimumSize: const Size.fromHeight(60),
              textStyle:
                  const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            onPressed: () {
              HapticFeedback.lightImpact();
              _save();
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
  }
}
