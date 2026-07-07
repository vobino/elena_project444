import 'package:flutter/material.dart';

/// Palette d'une variante de thème (jour ou nuit).
///
/// Toutes les couleurs qui changent selon le moment de la journée vivent ici.
/// On garde exactement les mêmes noms que ton ancien [AppColors] pour limiter
/// les changements dans le reste de l'app :
///   bg, surface, feeding, diaper, sleep, history, chat, text, actionButton.
class AppPalette {
  const AppPalette({
    required this.brightness,
    required this.bg,
    required this.surface,
    required this.text,
    required this.textMuted,
    required this.actionButton,
    required this.heroGradient,
    required this.feeding,
    required this.sleep,
    required this.diaper,
    required this.measure,
    required this.chat,
    required this.history,
    required this.feedingGradient,
    required this.sleepGradient,
    required this.diaperGradient,
    required this.measureGradient,
    required this.onAccent,
    required this.glowOpacity,
  });

  final Brightness brightness;

  final Color bg;
  final Color surface;
  final Color text;
  final Color textMuted;
  final Color actionButton;
  final List<Color> heroGradient;

  // Accents par action — pour teinter tes SVG via ColorFilter.mode(...).
  final Color feeding;
  final Color sleep;
  final Color diaper;
  final Color measure;
  final Color chat;
  final Color history;

  // Dégradés de fond des cartes (style candy).
  final List<Color> feedingGradient;
  final List<Color> sleepGradient;
  final List<Color> diaperGradient;
  final List<Color> measureGradient;

  final Color onAccent;
  final double glowOpacity;

  // ───────────────────────── JOUR — P2 "Brume & menthe" ─────────────────────
  // ───────────────── JOUR — Néon candy sur coquille d'œuf ─────────────────
  static const AppPalette light = AppPalette(
    brightness: Brightness.light,
    bg: Color(0xFFFCB85E),          // coquille d'œuf
    surface: Color(0xFFFFFFFF),
    text: Color(0xFF2E2430),        // gris foncé chaud
    textMuted: Color(0xFFA08C90),
    actionButton: Color(0xFFFFFFFF),
    heroGradient: [Color(0xFFFF50B4), Color(0xFF7040FF)],
    feeding: Color(0xFFEB3282),     // légèrement assombri pour lisibilité sur clair
    sleep: Color(0xFF6A3BE8),
    diaper: Color(0xFFE89010),
    measure: Color(0xFF10B888),
    chat: Color(0xFFE85AB0),
    history: Color(0xFF9A70E8),
    feedingGradient: [Color(0xFFFF5090), Color(0xFFFF8040)],
    sleepGradient: [Color(0xFF6040FF), Color(0xFFB040FF)],
    diaperGradient: [Color(0xFFFFB020), Color(0xFFFF6040)],
    measureGradient: [Color(0xFF20DDA0), Color(0xFF20AAFF)],
    onAccent: Color(0xFFFFFFFF),
    glowOpacity: 0.30,              // ombre douce, pas de glow néon en plein jour
  );

  // ───────────────────────── NUIT — F2 "Neon candy" ─────────────────────────
  static const AppPalette dark = AppPalette(
    brightness: Brightness.dark,
    bg: Color(0xFF130B1F),
    surface: Color(0xFF1E1430),
    text: Color(0xFFF4EEFF),
    textMuted: Color(0xFF8B6AAA),
    actionButton: Color(0xFF1E1430),
    heroGradient: [Color(0xFFFF50B4), Color(0xFF7040FF)],
    feeding: Color(0xFFFF5090),
    sleep: Color(0xFF8A5BFF),
    diaper: Color(0xFFFFB020),
    measure: Color(0xFF20DDA0),
    chat: Color(0xFFFF6AC0),
    history: Color(0xFFB48AFF),
    feedingGradient: [Color(0xFFFF5090), Color(0xFFFF8040)],
    sleepGradient: [Color(0xFF6040FF), Color(0xFFB040FF)],
    diaperGradient: [Color(0xFFFFB020), Color(0xFFFF6040)],
    measureGradient: [Color(0xFF20DDA0), Color(0xFF20AAFF)],
    onAccent: Color(0xFFFFFFFF),
    glowOpacity: 0.45,
  );
}

/// Accès à la palette active depuis n'importe quel widget : `context.palette`.
///
/// Remplace les anciens `AppColors.feeding` par `context.palette.feeding`.
extension PaletteX on BuildContext {
  AppPalette get palette => Theme.of(this).brightness == Brightness.dark
      ? AppPalette.dark
      : AppPalette.light;
}

/// Construit le [ThemeData] à partir d'une palette.
ThemeData buildTheme(AppPalette p) {
  final scheme = ColorScheme.fromSeed(
    seedColor: p.heroGradient.first,
    brightness: p.brightness,
    surface: p.surface,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: p.bg,
    fontFamily: 'Roboto',
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: p.text,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    textTheme: TextTheme(
      headlineMedium: TextStyle(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
        color: p.text,
      ),
      titleLarge: TextStyle(fontWeight: FontWeight.w600, color: p.text),
    ).apply(bodyColor: p.text, displayColor: p.text),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: p.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
    ),
  );
}

ThemeData get lightTheme => buildTheme(AppPalette.light);
ThemeData get darkTheme => buildTheme(AppPalette.dark);

/// Détermine le thème de départ selon l'heure locale.
/// Nuit entre 19h et 7h → thème sombre (F2), sinon clair (P2).
ThemeMode initialThemeModeByHour([DateTime? now]) {
  final h = (now ?? DateTime.now()).hour;
  final isNight = h >= 19 || h < 7;
  return isNight ? ThemeMode.dark : ThemeMode.light;
}

/// Contrôleur de thème minimal, partagé via [ThemeScope.of].
/// Pas de package externe : un InheritedWidget suffit pour le toggle.
class ThemeScope extends InheritedWidget {
  const ThemeScope({
    super.key,
    required this.mode,
    required this.toggle,
    required super.child,
  });

  final ThemeMode mode;
  final VoidCallback toggle;

  static ThemeScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<ThemeScope>();
    assert(scope != null, 'ThemeScope introuvable dans l\'arbre de widgets');
    return scope!;
  }

  @override
  bool updateShouldNotify(ThemeScope oldWidget) => oldWidget.mode != mode;
}