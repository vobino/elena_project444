import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/app_settings.dart';
import '../models/entries.dart';
import '../theme.dart';

/// Popup biberon / tétée.
/// - quantité par pas de 10 ml (gros + / -)
/// - sein gauche / droite (pour les tétées)
/// - prochain repas en heures et minutes, pré-rempli avec le dernier interval encodé
/// - case Vitamine D
Future<FeedingEntry?> showFeedingSheet(BuildContext context) {
  return showModalBottomSheet<FeedingEntry>(
    context: context,
    isScrollControlled: true,
    builder: (_) => const _FeedingSheet(),
  );
}

class _FeedingSheet extends StatefulWidget {
  const _FeedingSheet();

  @override
  State<_FeedingSheet> createState() => _FeedingSheetState();
}

class _FeedingSheetState extends State<_FeedingSheet> {
  late bool isBottle;
  late int amountMl;
  String? side;
  late int intervalHours;
  late int intervalMins;
  bool vitaminD = false;

  @override
  void initState() {
    super.initState();
    final s = AppSettings.instance;
    isBottle = s.lastIsBottle;
    amountMl = s.lastAmountMl;
    side = s.lastSide;
    intervalHours = s.lastIntervalHours;
    intervalMins = s.lastIntervalMins;
  }

  void _save() {
    final s = AppSettings.instance;
    final now = DateTime.now();
    final entry = FeedingEntry(
      at: now,
      amountMl: isBottle ? amountMl : null,
      side: isBottle ? null : side,
      vitaminD: vitaminD,
      nextAt: now.add(Duration(hours: intervalHours, minutes: intervalMins)),
    );
    s.setLastIsBottle(isBottle);
    if (isBottle) s.setLastAmountMl(amountMl);
    s.setLastSide(side);
    s.setLastIntervalHours(intervalHours);
    s.setLastIntervalMins(intervalMins);
    Navigator.of(context).pop(entry);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Biberon ou tétée
          SegmentedButton<bool>(
            style: ButtonStyle(
              textStyle: const WidgetStatePropertyAll(
                TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
              ),
              padding: const WidgetStatePropertyAll(
                EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              ),
              visualDensity: VisualDensity.standard,
              tapTargetSize: MaterialTapTargetSize.padded,
            ),
            segments: const [
              ButtonSegment(
                value: true,
                label: Text('Biberon'),
                icon: Icon(Icons.water_drop, size: 20),
              ),
              ButtonSegment(
                value: false,
                label: Text('Tétée'),
                icon: Icon(Icons.favorite_outline, size: 20),
              ),
            ],
            selected: {isBottle},
            onSelectionChanged: (v) => setState(() => isBottle = v.first),
          ),

          const SizedBox(height: 15),

          if (isBottle) ...[
            // Vitamine D (gauche) + Quantité (droite)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Flexible(
                  child: GestureDetector(
                    onTap: () => setState(() => vitaminD = !vitaminD),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 10),
                      decoration: BoxDecoration(
                        color: vitaminD
                            ? p.feeding.withValues(alpha: 0.18)
                            : p.text.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(
                          color: vitaminD
                              ? p.feeding
                              : p.text.withValues(alpha: 0.15),
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            child: Icon(
                              vitaminD
                                  ? Icons.check_circle
                                  : Icons.water_drop_outlined,
                              key: ValueKey(vitaminD),
                              size: 20,
                              color: vitaminD
                                  ? p.feeding
                                  : p.text.withValues(alpha: 0.5),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Vitamine D',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: vitaminD
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: vitaminD
                                  ? p.feeding
                                  : p.text.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Quantité
            Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text('$amountMl ml',
                    style: const TextStyle(
                        fontSize: 34, fontWeight: FontWeight.w800)),
                const SizedBox(width: 12),
                _RoundButton(
                  icon: Icons.remove,
                  small: true,
                  onTap: () => setState(
                          () => amountMl = (amountMl - 10).clamp(10, 600)),
                ),
                const SizedBox(width: 8),
                _RoundButton(
                  icon: Icons.add,
                  small: true,
                  onTap: () => setState(
                          () => amountMl = (amountMl + 10).clamp(10, 600)),
                ),
              ],
            ),
          ] else ...[
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'G', label: Text('Gauche')),
                ButtonSegment(value: 'D', label: Text('Droite')),
              ],
              selected: {side ?? 'G'},
              onSelectionChanged: (v) => setState(() => side = v.first),
            ),
          ],

          const SizedBox(height: 12),

          // Prochain repas (heures), pré-rempli avec le dernier intervalle
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Icon(Icons.schedule, color: p.feeding),
              const SizedBox(width: 12),
              const Text('Prochain dans'),
              const SizedBox(width: 8),
              SizedBox(
                width: 52,
                child: Text('$intervalHours h',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w700)),
              ),
              _RoundButton(
                icon: Icons.remove,
                small: true,
                onTap: () => setState(
                        () => intervalHours = (intervalHours - 1).clamp(1, 12)),
              ),
              const SizedBox(width: 4),
              _RoundButton(
                icon: Icons.add,
                small: true,
                onTap: () => setState(
                        () => intervalHours = (intervalHours + 1).clamp(1, 12)),
              ),
            ],
          ),

          const SizedBox(height: 5),

          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              const Text('et'),
              SizedBox(
                width: 60,
                child: Text('$intervalMins m',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w700)),
              ),
              _RoundButton(
                icon: Icons.remove,
                small: true,
                onTap: () => setState(
                        () => intervalMins = (intervalMins - 1).clamp(0, 59)),
              ),
              const SizedBox(width: 4),
              _RoundButton(
                icon: Icons.add,
                small: true,
                onTap: () => setState(
                        () => intervalMins = (intervalMins + 1).clamp(0, 59)),
              ),
            ],
          ),

          const SizedBox(height: 28),

          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: p.feeding,
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

class _RoundButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool small;
  const _RoundButton(
      {required this.icon, required this.onTap, this.small = false});

  @override
  Widget build(BuildContext context) {
    final size = small ? 44.0 : 64.0;
    return SizedBox(
      width: size,
      height: size,
      child: IconButton.filledTonal(
        onPressed: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        icon: Icon(icon, size: small ? 22 : 30),
      ),
    );
  }
}