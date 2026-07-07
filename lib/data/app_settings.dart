import 'package:shared_preferences/shared_preferences.dart';

/// Préférences locales : mode fatigue, dernières valeurs encodées,
/// abonnement et nom de l'enfant (paramètres en ligne).
class AppSettings {
  AppSettings._(this._prefs);
  static AppSettings? _instance;
  final SharedPreferences _prefs;

  static Future<AppSettings> load() async {
    _instance ??= AppSettings._(await SharedPreferences.getInstance());
    return _instance!;
  }

  static AppSettings get instance => _instance!;

  // Mode fatigue extrême : tap = enregistrement immédiat, sans popup.
  bool get fatigueMode => _prefs.getBool('fatigue_mode') ?? false;
  Future<void> setFatigueMode(bool v) => _prefs.setBool('fatigue_mode', v);

  // Dernières valeurs pour pré-remplir les popups et le mode fatigue.
  int get lastAmountMl => _prefs.getInt('last_amount_ml') ?? 60;
  Future<void> setLastAmountMl(int v) => _prefs.setInt('last_amount_ml', v);

  String? get lastSide => _prefs.getString('last_side');
  Future<void> setLastSide(String? v) => v == null
      ? _prefs.remove('last_side')
      : _prefs.setString('last_side', v);

  int get lastIntervalHours => _prefs.getInt('last_interval_hours') ?? 3;
  Future<void> setLastIntervalHours(int v) =>
      _prefs.setInt('last_interval_hours', v);

  int get lastIntervalMins => _prefs.getInt('last_interval_mins') ?? 0;
  Future<void> setLastIntervalMins(int v) =>
      _prefs.setInt('last_interval_mins', v);

  bool get lastIsBottle => _prefs.getBool('last_is_bottle') ?? true;
  Future<void> setLastIsBottle(bool v) => _prefs.setBool('last_is_bottle', v);

  // Abonnement (activation en ligne) + nom de l'enfant.
  bool get subscriptionActive => _prefs.getBool('subscription_active') ?? false;
  Future<void> setSubscriptionActive(bool v) =>
      _prefs.setBool('subscription_active', v);

  String get childName => _prefs.getString('child_name') ?? '';
  Future<void> setChildName(String v) => _prefs.setString('child_name', v);

  // Couleur de la veilleuse (ARGB int). Défaut : orangé doux.
  int get nightlightColor =>
      _prefs.getInt('nightlight_color') ?? 0xFFF57400;
  Future<void> setNightlightColor(int v) =>
      _prefs.setInt('nightlight_color', v);

  // URL du backend Spring Boot.
  String get apiBaseUrl =>
      _prefs.getString('api_base_url') ?? 'https://api.example.com';
  Future<void> setApiBaseUrl(String v) => _prefs.setString('api_base_url', v);

  // Voile de luminosité de l'accueil (0 = aucun voile, 0.8 = très sombre)
  double get screenDim => _prefs.getDouble('screen_dim') ?? 0.0;
  Future<void> setScreenDim(double v) => _prefs.setDouble('screen_dim', v);
}
