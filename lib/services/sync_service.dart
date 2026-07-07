import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;

import '../data/app_database.dart';
import '../data/app_settings.dart';

/// Synchronisation différée vers le backend Spring Boot.
/// L'app reste 100 % fonctionnelle offline ; quand une connexion est
/// disponible, on pousse en batch toutes les entrées non synchronisées.
///
/// Contrat REST attendu côté Spring Boot (voir README.md) :
///   POST {base}/api/v1/sync/batch   body = {feedings:[], diapers:[], sleeps:[]}
///   -> 200 OK si tout est persisté (idempotent grâce aux UUID clients).
class SyncService {
  SyncService._();
  static final SyncService instance = SyncService._();

  bool _running = false;

  Future<bool> get isOnline async {
    final result = await Connectivity().checkConnectivity();
    return !result.contains(ConnectivityResult.none);
  }

  /// Pousse les entrées non synchronisées. Retourne true si succès.
  Future<bool> pushPending() async {
    if (_running) return false;
    _running = true;
    try {
      if (!await isOnline) return false;

      final payload = await AppDatabase.instance.unsyncedPayload();
      final isEmpty = payload.values.every((l) => l.isEmpty);
      if (isEmpty) return true;

      final base = AppSettings.instance.apiBaseUrl;
      final res = await http
          .post(
            Uri.parse('$base/api/v1/sync/batch'),
            headers: {
              'Content-Type': 'application/json',
              // TODO: Authorization: 'Bearer <JWT>' une fois l'auth en place.
            },
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 15));

      if (res.statusCode >= 200 && res.statusCode < 300) {
        await AppDatabase.instance.markAllSynced();
        return true;
      }
      return false;
    } catch (_) {
      return false; // silencieux : on réessaiera plus tard
    } finally {
      _running = false;
    }
  }
}
