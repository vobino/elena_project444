import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:convert';

import 'package:http/http.dart' as http;
import '../data/app_database.dart';
import '../data/app_settings.dart';
import '../data/family_prefs.dart';
import '../models/entries.dart';
import '../services/sync_service.dart';
import '../theme.dart';
import '../widgets/action_card.dart';
import '../widgets/hero_card.dart';
import '../widgets/theme_toggle_button.dart';
import '../widgets/diaper_sleep_sheets.dart';
import '../widgets/feeding_sheet.dart';
import '../widgets/bath_sheet.dart';
import 'chat_screen.dart' show ChatScreen;
import 'history_screen.dart';
import 'settings_screen.dart';
import 'family_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _db = AppDatabase.instance;
  late bool fatigueMode;
  DateTime? nextFeedingAt;
  SleepEntry? ongoingSleep;
  BathEntry? lastBath;
  bool _notifying = false;

  @override
  void initState() {
    super.initState();
    fatigueMode = AppSettings.instance.fatigueMode;
    _refresh();
    SyncService.instance.pushPending();
  }

  Future<void> _refresh() async {
    final last = await _db.lastFeeding();
    final sleep = await _db.ongoingSleep();
    final bath = await _db.lastBath();
    if (!mounted) return;
    setState(() {
      nextFeedingAt = last?.nextAt;
      ongoingSleep = sleep;
      lastBath = bath;
    });
  }

  void _toast(String msg, {VoidCallback? onUndo}) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontSize: 16)),
      duration: const Duration(seconds: 3),
      action: onUndo == null
          ? null
          : SnackBarAction(label: 'Annuler', onPressed: onUndo),
    ));
  }

  // ---------- Alerter l'autre parent (SOS) ----------
  Future<void> _notifyPartner() async {
    setState(() => _notifying = true);
    bool ok = false;
    try {
      final base = AppSettings.instance.apiBaseUrl;
      final res = await http
          .post(
            Uri.parse('$base/api/v1/help/notify'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'childName': AppSettings.instance.childName.isEmpty
                  ? 'Mon bébé'
                  : AppSettings.instance.childName,
            }),
          )
          .timeout(const Duration(seconds: 10));
      ok = res.statusCode >= 200 && res.statusCode < 300;
    } catch (_) {
      ok = false;
    }
    if (!mounted) return;
    setState(() => _notifying = false);
    _toast(ok
        ? "L'autre parent a été notifié ✓"
        : 'Notification impossible (hors ligne ?)');
  }

  // ---------- Biberon ----------
  Future<void> _onFeeding() async {
    final s = AppSettings.instance;
    if (fatigueMode) {
      final now = DateTime.now();
      final entry = FeedingEntry(
        at: now,
        amountMl: s.lastIsBottle ? s.lastAmountMl : null,
        side: s.lastIsBottle ? null : s.lastSide,
        nextAt: now.add(Duration(
            hours: s.lastIntervalHours, minutes: s.lastIntervalMins)),
      );
      await _db.insertFeeding(entry);
      _toast(
        s.lastIsBottle
            ? 'Biberon ${s.lastAmountMl} ml enregistré'
            : 'Tétée enregistrée',
        onUndo: () async {
          await _db.deleteFeeding(entry.id);
          _refresh();
        },
      );
    } else {
      final entry = await showFeedingSheet(context);
      if (entry == null) return;
      await _db.insertFeeding(entry);
      _toast('Enregistré ✓');
    }
    _refresh();
    SyncService.instance.pushPending();
  }

  // ---------- Couche ----------
  Future<void> _onDiaper() async {
    if (fatigueMode) {
      final entry = DiaperEntry(at: DateTime.now(), type: DiaperType.pipi);
      await _db.insertDiaper(entry);
      _toast('Couche enregistrée', onUndo: () async {
        await _db.deleteDiaper(entry.id);
        _refresh();
      });
    } else {
      final entry = await showDiaperSheet(context);
      if (entry == null) return;
      await _db.insertDiaper(entry);
      _toast('Enregistré ✓');
    }
    _refresh();
    SyncService.instance.pushPending();
  }

  // ---------- Sommeil ----------
  Future<void> _onSleep() async {
    if (fatigueMode) {
      if (ongoingSleep == null) {
        final entry = SleepEntry(start: DateTime.now());
        await _db.upsertSleep(entry);
        _toast('Sommeil démarré 😴', onUndo: () async {
          await _db.deleteSleep(entry.id);
          _refresh();
        });
      } else {
        await _db.upsertSleep(ongoingSleep!.copyWith(end: DateTime.now()));
        _toast('Sommeil terminé ✓');
      }
    } else {
      final entry = await showSleepSheet(context);
      if (entry == null) return;
      await _db.upsertSleep(entry);
      _toast('Enregistré ✓');
    }
    _refresh();
    SyncService.instance.pushPending();
  }

  // ---------- Bain / Rinçage du bébé ----------
  Future<void> _onBath() async {
    if (fatigueMode) {
      final entry = BathEntry(at: DateTime.now(), type: BathType.bain);
      await _db.insertBath(entry);
      _toast('Bain enregistré 🛁', onUndo: () async {
        await _db.deleteBath(entry.id);
        _refresh();
      });
    } else {
      final entry = await showBathSheet(context);
      if (entry == null) return;
      await _db.insertBath(entry);
      _toast('Enregistré ✓');
    }
    _refresh();
    SyncService.instance.pushPending();
  }

  String? _bathSubtitle() {
    final b = lastBath;
    if (b == null) return null;
    final diff = DateTime.now().difference(b.at);
    final prefix = b.type == BathType.rincage ? 'Rinçage' : 'Bain';
    if (diff.inDays >= 1) return '$prefix il y a ${diff.inDays}j';
    if (diff.inHours >= 1) return '$prefix il y a ${diff.inHours}h';
    return '$prefix il y a ${diff.inMinutes}min';
  }

  // Sous-titre du bouton biberon = compte à rebours prochain repas.
  String? _feedingSubtitle() {
    final next = nextFeedingAt;
    if (next == null) return null;
    final diff = next.difference(DateTime.now());
    if (diff.isNegative) return 'Maintenant';
    final h = diff.inHours;
    final m = diff.inMinutes % 60;
    return h > 0 ? 'dans ${h}h ${m}m' : 'dans ${m}m';
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final fmt = DateFormat.Hm();
    final isDark = p.brightness == Brightness.dark;
    final greeting = isDark ? 'Bonsoir ✨' : 'Bonjour ✨';//🌊
    final childName = AppSettings.instance.childName;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(greeting, style: TextStyle(fontSize: 11, color: p.textMuted)),
            const SizedBox(height: 2),
            Text(
              childName.isEmpty ? 'Elena' : childName,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
                color: p.text,
              ),
            ),
          ],
        ),
        actions: [
          // SOS — alerter l'autre parent
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Material(
              color: p.feeding.withValues(alpha: 0.12),
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: _notifyPartner,
                child: SizedBox(
                  width: 42,
                  height: 42,
                  child: _notifying
                      ? Padding(
                          padding: const EdgeInsets.all(11),
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: p.feeding),
                        )
                      : Icon(Icons.sos, size: 22, color: p.feeding),
                ),
              ),
            ),
          ),
          // Mode zen / fatigue : 1 tap = 1 entrée, zéro popup.
          IconButton(
            tooltip: 'Mode zen (1 tap = 1 entrée)',
            iconSize: 26,
            icon: Icon(
              fatigueMode ? Icons.bolt : Icons.self_improvement,
              color: fatigueMode ? p.feeding : p.textMuted,
            ),
            onPressed: () async {
              setState(() => fatigueMode = !fatigueMode);
              await AppSettings.instance.setFatigueMode(fatigueMode);
              _toast(fatigueMode
                  ? 'Mode zen : 1 tap = 1 entrée'
                  : 'Mode normal');
            },
          ),
          // Bascule jour / nuit
          const ThemeToggleButton(),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  HeroCard(nextFeedingAt: nextFeedingAt),
                  const SizedBox(height: 18),

                  // ── Grille 2×2 des actions principales ──
                  GridView.count(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      ActionCard(
                        label: 'Biberon / Tétée',
                        subtitle: _feedingSubtitle(),
                        iconAsset: 'assets/icons/baby_bottle.svg',
                        gradient: p.feedingGradient,
                        glowColor: p.feeding,
                        onTap: _onFeeding,
                      ),
                      ActionCard(
                        label: 'Sommeil',
                        subtitle: ongoingSleep != null
                            ? 'depuis ${fmt.format(ongoingSleep!.start)}'
                            : (fatigueMode ? '1 tap' : null),
                        iconAsset: 'assets/icons/moon.svg',
                        gradient: p.sleepGradient,
                        glowColor: p.sleep,
                        onTap: _onSleep,
                      ),
                      ActionCard(
                        label: 'Couche',
                        subtitle: fatigueMode ? '1 tap' : null,
                        iconAsset: 'assets/icons/change_rouleau.svg',
                        gradient: p.diaperGradient,
                        glowColor: p.diaper,
                        onTap: _onDiaper,
                      ),
                      ActionCard(
                        label: 'Bain',
                        subtitle: _bathSubtitle(),
                        iconAsset: 'assets/icons/bath.svg',
                        gradient: p.measureGradient,
                        glowColor: p.measure,
                        onTap: _onBath,
                      ),
                    ],
                  ),

                  const SizedBox(height: 22),
                  Text('PLUS',
                      style: TextStyle(
                          fontSize: 11,
                          letterSpacing: 1,
                          fontWeight: FontWeight.w600,
                          color: p.textMuted)),
                  const SizedBox(height: 10),

                  // ── Actions secondaires ──
                  Row(
                    children: [
                      _SecondaryButton(
                        label: 'Tchat',
                        icon: Icons.forum,
                        color: p.chat,
                        onTap: () => Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => FamilyPrefs.instance.hasFamily
                              ? const ChatScreen()
                              : const FamilyScreen(),
                        )),
                      ),
                      const SizedBox(width: 12),
                      _SecondaryButton(
                        label: 'Historique',
                        icon: Icons.history,
                        color: p.history,
                        onTap: () => Navigator.of(context)
                            .push(MaterialPageRoute(
                                builder: (_) => const HistoryScreen()))
                            .then((_) => _refresh()),
                      ),
                      const SizedBox(width: 12),
                      _SecondaryButton(
                        label: 'Réglages',
                        icon: Icons.settings,
                        color: p.textMuted,
                        onTap: () => Navigator.of(context)
                            .push(MaterialPageRoute(
                                builder: (_) => const SettingsScreen()))
                            .then((_) => setState(() {})),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Bouton secondaire compact (Tchat / Historique / Réglages).
class _SecondaryButton extends StatelessWidget {
  const _SecondaryButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Expanded(
      child: Material(
        color: p.surface,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              children: [
                Icon(icon, size: 24, color: color),
                const SizedBox(height: 6),
                Text(label,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: p.text)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
