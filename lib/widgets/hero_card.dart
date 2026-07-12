import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme.dart';

/// Bandeau d'en-tête : date + horloge en direct à gauche,
/// heure du prochain repas à droite.
class HeroCard extends StatefulWidget {
  const HeroCard({super.key, this.nextFeedingAt});

  /// Heure du prochain repas prévu, ou null si rien d'encodé.
  final DateTime? nextFeedingAt;

  @override
  State<HeroCard> createState() => _HeroCardState();
}

class _HeroCardState extends State<HeroCard> {
  late final Timer _timer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    // Rafraîchit l'horloge toutes les 20 s (assez pour ne jamais
    // afficher une minute périmée, négligeable en ressources).
    _timer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final hm = DateFormat.Hm();
    final dayFmt = DateFormat('EEEE dd', 'fr');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: p.heroGradient,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: p.heroGradient.last.withValues(alpha: p.glowOpacity),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ── Gauche : date + horloge en direct ──
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                dayFmt.format(_now), // ex. "mardi 07"
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.85),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                hm.format(_now),
                style: const TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const Spacer(),
          // ── Droite : prochain repas ──
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'PROCHAIN REPAS',
                style: TextStyle(
                  fontSize: 10,
                  letterSpacing: 1,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.85),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                widget.nextFeedingAt != null
                    ? hm.format(widget.nextFeedingAt!)
                    : '—',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}