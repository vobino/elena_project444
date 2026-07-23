import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'data/app_settings.dart';
import 'data/family_prefs.dart';
import 'screens/home_screen.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('fr');
  await AppSettings.load();
  await FamilyPrefs.instance.load();
  //await FamilyPrefs.instance.leaveFamily();
  runApp(const BibiTrackApp());
}

class BibiTrackApp extends StatefulWidget {
  const BibiTrackApp({super.key});

  @override
  State<BibiTrackApp> createState() => _BibiTrackAppState();
}

class _BibiTrackAppState extends State<BibiTrackApp> {
  // Auto au démarrage selon l'heure (nuit 19h–7h → sombre).
  // Tu peux remplacer par une valeur mémorisée dans AppSettings si tu veux
  // persister le choix manuel de l'utilisateur entre deux lancements.
  late ThemeMode _mode = initialThemeModeByHour();

  void _toggle() {
    setState(() {
      _mode = _mode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    });
    // Pour persister : AppSettings.instance.setThemeMode(_mode);
  }

  @override
  Widget build(BuildContext context) {
    return ThemeScope(
      mode: _mode,
      toggle: _toggle,
      child: MaterialApp(
        title: 'BibiTrack',
        debugShowCheckedModeBanner: false,
        theme: lightTheme,
        darkTheme: darkTheme,
        themeMode: _mode,
        home: const HomeScreen(),
      ),
    );
  }
}