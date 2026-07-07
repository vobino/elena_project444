import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Bouton géant : toute la surface est tappable, retour haptique,
/// lisible d'un œil à moitié fermé.
///
/// Fournir SOIT [icon] (icône Material), SOIT [iconAsset] (chemin d'un SVG).
class BigActionButton extends StatelessWidget {
  final IconData? icon;
  final String? iconAsset;
  final String label;
  final Color color;
  final Color colorIcon;
  final VoidCallback onTap;
  final String? subtitle;

  const BigActionButton({
    super.key,
    this.icon,
    this.iconAsset,
    required this.label,
    required this.color,
    required this.colorIcon,
    required this.onTap,
    this.subtitle,
  }) : assert(icon != null || iconAsset != null,
  'Fournir soit icon, soit iconAsset');

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withOpacity(0.44),
      borderRadius: BorderRadius.circular(28),
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        splashColor: color.withOpacity(0.3),
        onTap: () {
          HapticFeedback.mediumImpact();
          onTap();
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icône : SVG si iconAsset fourni, sinon icône Material.
              iconAsset != null
                  ? SvgPicture.asset(
                iconAsset!,
                width: 52,
                height: 52,
                colorFilter:
                ColorFilter.mode(colorIcon, BlendMode.srcIn),
              )
                  : Icon(icon, size: 52, color: colorIcon),
              const SizedBox(height: 10),
              Text(label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: color)),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(subtitle!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 12, color: color.withOpacity(0.75))),
              ],
            ],
          ),
        ),
      ),
    );
  }
}