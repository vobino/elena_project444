import 'package:flutter/material.dart';
import '../theme.dart';

/// Bascule jour/nuit à placer dans `AppBar.actions`.
/// Soleil en thème clair, lune en thème sombre, transition animée.
class ThemeToggleButton extends StatelessWidget {
  const ThemeToggleButton({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final isDark = p.brightness == Brightness.dark;
    final accent = isDark ? p.feeding : p.heroGradient.first;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: p.surface,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: ThemeScope.of(context).toggle,
          child: SizedBox(
            width: 42,
            height: 42,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 350),
              switchInCurve: Curves.easeOutBack,
              switchOutCurve: Curves.easeIn,
              transitionBuilder: (child, anim) => RotationTransition(
                turns: Tween<double>(begin: 0.6, end: 1.0).animate(anim),
                child: ScaleTransition(
                  scale: anim,
                  child: FadeTransition(opacity: anim, child: child),
                ),
              ),
              child: Icon(
                isDark ? Icons.nights_stay_rounded : Icons.wb_sunny_rounded,
                key: ValueKey<bool>(isDark),
                color: accent,
                size: 22,
              ),
            ),
          ),
        ),
      ),
    );
  }
}