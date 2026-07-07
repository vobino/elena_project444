import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/app_settings.dart';

/// Veilleuse plein écran : couleur douce, luminosité réglable,
/// interface qui s'efface pour ne pas réveiller bébé.
class NightlightScreen extends StatefulWidget {
  const NightlightScreen({super.key});

  @override
  State<NightlightScreen> createState() => _NightlightScreenState();
}

class _NightlightScreenState extends State<NightlightScreen> {
  double _brightness = 0.4;
  bool _showControls = true;

  @override
  void initState() {
    super.initState();
    // Plein écran immersif (cache barres système).
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    // Restaure l'UI système en quittant.
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = Color(AppSettings.instance.nightlightColor);

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        child: Stack(
          children: [
            // L'écran de couleur, dont la luminosité dépend du curseur.
            Positioned.fill(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                color: Color.lerp(Colors.black, color, _brightness),
              ),
            ),

            // Bouton fermer (en haut), visible seulement si contrôles affichés.
            AnimatedOpacity(
              opacity: _showControls ? 1 : 0,
              duration: const Duration(milliseconds: 250),
              child: SafeArea(
                child: Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: IconButton(
                      icon: Icon(Icons.close,
                          color: Colors.white.withOpacity(0.5), size: 28),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                ),
              ),
            ),

            // Curseur d'intensité en bas.
            AnimatedOpacity(
              opacity: _showControls ? 1 : 0,
              duration: const Duration(milliseconds: 250),
              child: SafeArea(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                    child: Row(
                      children: [
                        Icon(Icons.brightness_low,
                            color: Colors.white.withOpacity(0.4)),
                        Expanded(
                          child: SliderTheme(
                            data: SliderThemeData(
                              activeTrackColor: Colors.white.withOpacity(0.6),
                              inactiveTrackColor:
                              Colors.white.withOpacity(0.15),
                              thumbColor: Colors.white,
                              overlayColor: Colors.white.withOpacity(0.1),
                            ),
                            child: Slider(
                              value: _brightness,
                              min: 0.02, // jamais totalement noir
                              max: 1,
                              onChanged: (v) =>
                                  setState(() => _brightness = v),
                            ),
                          ),
                        ),
                        Icon(Icons.brightness_high,
                            color: Colors.white.withOpacity(0.4)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}