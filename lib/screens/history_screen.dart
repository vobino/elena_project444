import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/app_database.dart';
import '../models/entries.dart';
import '../theme.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final _db = AppDatabase.instance;
  List<FeedingEntry> feedings = [];
  List<DiaperEntry> diapers = [];
  List<SleepEntry> sleeps = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final f = await _db.feedings();
    final d = await _db.diapers();
    final s = await _db.sleeps();
    if (!mounted) return;
    setState(() {
      feedings = f;
      diapers = d;
      sleeps = s;
    });
  }

  String _day(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(dt.year, dt.month, dt.day);
    if (day == today) return "Aujourd'hui";
    if (day == today.subtract(const Duration(days: 1))) return 'Hier';
    return DateFormat('EEE d MMM', 'fr').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final hm = DateFormat.Hm();
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Historique'),
          bottom: const TabBar(tabs: [
            Tab(icon: Icon(Icons.water_drop), text: 'Biberon'),
            Tab(icon: Icon(Icons.baby_changing_station), text: 'Couche'),
            Tab(icon: Icon(Icons.bedtime), text: 'Sommeil'),
          ]),
        ),
        body: TabBarView(children: [
          // ---- Biberons / tétées ----
          _LogList(
            isEmpty: feedings.isEmpty,
            emptyText:
            'Aucun repas encodé.\nAppuie sur Biberon pour commencer.',
            itemCount: feedings.length,
            builder: (i) {
              final e = feedings[i];
              return Dismissible(
                key: ValueKey(e.id),
                background: _deleteBg(),
                onDismissed: (_) async {
                  await _db.deleteFeeding(e.id);
                  _load();
                },
                child: ListTile(
                  leading:
                  Icon(Icons.water_drop, color: p.feeding, size: 30),
                  title: Text(
                    e.amountMl != null
                        ? 'Biberon ${e.amountMl} ml'
                        : 'Tétée ${e.side == 'G' ? 'gauche' : e.side == 'D' ? 'droite' : ''}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text('${_day(e.at)} · ${hm.format(e.at)}'
                      '${e.vitaminD ? '  ·  Vit. D ✓' : ''}'),
                  trailing: e.nextAt != null
                      ? Text('→ ${hm.format(e.nextAt!)}',
                      style: TextStyle(color: p.feeding))
                      : null,
                ),
              );
            },
          ),
          // ---- Couches ----
          _LogList(
            isEmpty: diapers.isEmpty,
            emptyText: 'Aucune couche encodée.',
            itemCount: diapers.length,
            builder: (i) {
              final e = diapers[i];
              return Dismissible(
                key: ValueKey(e.id),
                background: _deleteBg(),
                onDismissed: (_) async {
                  await _db.deleteDiaper(e.id);
                  _load();
                },
                child: ListTile(
                  leading: Icon(Icons.baby_changing_station,
                      color: p.diaper, size: 30),
                  title: Text(
                    switch (e.type) {
                      DiaperType.pipi => 'Pipi',
                      DiaperType.caca => 'Caca',
                      DiaperType.mixte => 'Mixte',
                    },
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text('${_day(e.at)} · ${hm.format(e.at)}'),
                ),
              );
            },
          ),
          // ---- Sommeil ----
          _LogList(
            isEmpty: sleeps.isEmpty,
            emptyText: 'Aucun sommeil encodé.',
            itemCount: sleeps.length,
            builder: (i) {
              final e = sleeps[i];
              final dur = e.duration;
              return Dismissible(
                key: ValueKey(e.id),
                background: _deleteBg(),
                onDismissed: (_) async {
                  await _db.deleteSleep(e.id);
                  _load();
                },
                child: ListTile(
                  leading: Icon(Icons.bedtime, color: p.sleep, size: 30),
                  title: Text(
                    e.end == null
                        ? 'En cours depuis ${hm.format(e.start)}'
                        : '${hm.format(e.start)} → ${hm.format(e.end!)}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(_day(e.start)),
                  trailing: dur != null
                      ? Text(
                      '${dur.inHours}h${(dur.inMinutes % 60).toString().padLeft(2, '0')}',
                      style: TextStyle(
                          color: p.sleep,
                          fontWeight: FontWeight.w700))
                      : null,
                ),
              );
            },
          ),
        ]),
      ),
    );
  }

  Widget _deleteBg() => Container(
    color: Colors.red.withValues(alpha: 0.7),
    alignment: Alignment.centerRight,
    padding: const EdgeInsets.only(right: 24),
    child: const Icon(Icons.delete, color: Colors.white),
  );
}

class _LogList extends StatelessWidget {
  final bool isEmpty;
  final String emptyText;
  final int itemCount;
  final Widget Function(int) builder;

  const _LogList({
    required this.isEmpty,
    required this.emptyText,
    required this.itemCount,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    if (isEmpty) {
      return Center(
        child: Text(emptyText,
            textAlign: TextAlign.center,
            style: TextStyle(color: p.text.withValues(alpha: 0.5))),
      );
    }
    return ListView.separated(
      itemCount: itemCount,
      separatorBuilder: (_, __) =>
          Divider(height: 1, color: p.text.withValues(alpha: 0.06)),
      itemBuilder: (_, i) => builder(i),
    );
  }
}