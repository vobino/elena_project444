import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../theme.dart';

/// Carte d'action carrée style "candy" : fond en dégradé, icône monochrome
/// (SVG via [iconAsset] ou Material via [icon]), glow coloré en thème sombre.
///
/// Utilisée dans la grille 2×2 de l'écran d'accueil.
class ActionCard extends StatelessWidget {
  const ActionCard({
    super.key,
    required this.label,
    required this.gradient,
    required this.glowColor,
    required this.onTap,
    this.iconAsset,
    this.icon,
    this.subtitle,
  }) : assert(iconAsset != null || icon != null,
  'Fournis soit iconAsset (SVG) soit icon (Material)');

  final String label;
  final String? subtitle;
  final List<Color> gradient;
  final Color glowColor;
  final VoidCallback onTap;

  /// Chemin d'un SVG monochrome, ex. 'assets/icons/baby_bottle.svg'.
  final String? iconAsset;

  /// Alternative Material si pas de SVG dispo.
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final isDark = p.brightness == Brightness.dark;

    final Widget iconWidget = iconAsset != null
        ? SvgPicture.asset(
      iconAsset!,
      width: 44,
      height: 44,
      colorFilter: ColorFilter.mode(p.onAccent, BlendMode.srcIn),
    )
        : Icon(icon, size: 44, color: p.onAccent);

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradient,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: glowColor.withValues(alpha: p.glowOpacity),
            blurRadius: isDark ? 18 : 16,
            spreadRadius: isDark ? 1 : 0,
            offset: Offset(0, isDark ? 0 : 8),
          ),
        ],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                iconWidget,
                const SizedBox(height: 10),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: p.onAccent,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 10.5,
                      color: p.onAccent.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
