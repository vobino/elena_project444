import 'dart:convert';

import 'package:http/http.dart' as http;

import '../data/app_settings.dart';
import '../data/family_prefs.dart';
import '../models/family_models.dart';

/// Appels REST liés à la famille. Voir API_CONTRACT.md pour le backend.
class FamilyService {
  FamilyService._();
  static final FamilyService instance = FamilyService._();

  String get _base => AppSettings.instance.apiBaseUrl;
  FamilyPrefs get _prefs => FamilyPrefs.instance;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'X-Device-Id': _prefs.deviceId,
        if (_prefs.authToken != null)
          'Authorization': 'Bearer ${_prefs.authToken}',
      };

  /// Crée une famille. L'appareil devient CREATOR.
  Future<void> createFamily({
    required String familyName,
    required String displayName,
  }) async {
    final res = await http
        .post(
          Uri.parse('$_base/api/v1/families'),
          headers: _headers,
          body: jsonEncode({
            'name': familyName,
            'deviceId': _prefs.deviceId,
            'displayName': displayName,
          }),
        )
        .timeout(const Duration(seconds: 15));
    _ensureOk(res);
    final j = jsonDecode(res.body) as Map<String, dynamic>;
    final family = j['family'] as Map<String, dynamic>;
    await _prefs.setDisplayName(displayName);
    await _prefs.joinFamily(
      familyId: family['id'] as String,
      familyName: family['name'] as String,
      role: j['role'] as String,
      authToken: j['token'] as String,
    );
  }

  /// Rejoint une famille via un token d'invitation (collé ou extrait
  /// d'un lien https://.../join/<token> ou bibitrack://join?token=<token>).
  Future<void> joinFamily({
    required String inviteToken,
    required String displayName,
  }) async {
    final res = await http
        .post(
          Uri.parse('$_base/api/v1/families/join'),
          headers: _headers,
          body: jsonEncode({
            'inviteToken': _extractToken(inviteToken),
            'deviceId': _prefs.deviceId,
            'displayName': displayName,
          }),
        )
        .timeout(const Duration(seconds: 15));
    _ensureOk(res);
    final j = jsonDecode(res.body) as Map<String, dynamic>;
    final family = j['family'] as Map<String, dynamic>;
    await _prefs.setDisplayName(displayName);
    await _prefs.joinFamily(
      familyId: family['id'] as String,
      familyName: family['name'] as String,
      role: j['role'] as String,      // le rôle reste à la racine
      authToken: j['token'] as String,
    );
  }

  /// Accepte le token brut, un lien complet, ou un lien app.
  String _extractToken(String raw) {
    final t = raw.trim();
    final joinPath = RegExp(r'/join/([A-Za-z0-9\-_]+)').firstMatch(t);
    if (joinPath != null) return joinPath.group(1)!;
    final query = RegExp(r'[?&]token=([A-Za-z0-9\-_]+)').firstMatch(t);
    if (query != null) return query.group(1)!;
    return t;
  }

  Future<List<FamilyMember>> members() async {
    final res = await http
        .get(
          Uri.parse('$_base/api/v1/families/${_prefs.familyId}/members'),
          headers: _headers,
        )
        .timeout(const Duration(seconds: 15));
    _ensureOk(res);
    final list = jsonDecode(res.body) as List<dynamic>;
    return list
        .map((e) => FamilyMember.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Retire un membre (réservé au créateur, contrôlé côté serveur).
  Future<void> removeMember(String deviceId) async {
    final res = await http
        .delete(
          Uri.parse(
              '$_base/api/v1/families/${_prefs.familyId}/members/$deviceId'),
          headers: _headers,
        )
        .timeout(const Duration(seconds: 15));
    _ensureOk(res);
  }

  /// Quitte la famille (pour un membre non créateur).
  Future<void> leave() async {
    await removeMember(_prefs.deviceId);
    await _prefs.leaveFamily();
  }

  Future<FamilyInvitation> createInvitation() async {
    final res = await http
        .post(
          Uri.parse('$_base/api/v1/families/${_prefs.familyId}/invitations'),
          headers: _headers,
        )
        .timeout(const Duration(seconds: 15));
    _ensureOk(res);
    return FamilyInvitation.fromJson(
        jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<List<FamilyInvitation>> invitations() async {
    final res = await http
        .get(
          Uri.parse('$_base/api/v1/families/${_prefs.familyId}/invitations'),
          headers: _headers,
        )
        .timeout(const Duration(seconds: 15));
    _ensureOk(res);
    final list = jsonDecode(res.body) as List<dynamic>;
    return list
        .map((e) => FamilyInvitation.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Révoque un lien d'invitation (réservé au créateur).
  Future<void> revokeInvitation(String token) async {
    final res = await http
        .delete(
          Uri.parse(
              '$_base/api/v1/families/${_prefs.familyId}/invitations/$token'),
          headers: _headers,
        )
        .timeout(const Duration(seconds: 15));
    _ensureOk(res);
  }

  /// Historique du tchat (les nouveaux messages arrivent via WebSocket).
  Future<List<ChatMessage>> messageHistory({int limit = 50}) async {
    final res = await http
        .get(
          Uri.parse(
              '$_base/api/v1/families/${_prefs.familyId}/messages?limit=$limit'),
          headers: _headers,
        )
        .timeout(const Duration(seconds: 15));
    _ensureOk(res);
    final list = jsonDecode(res.body) as List<dynamic>;
    return list
        .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  void _ensureOk(http.Response res) {
    if (res.statusCode < 200 || res.statusCode >= 300) {
      String msg = 'Erreur ${res.statusCode}';
      try {
        final j = jsonDecode(res.body) as Map<String, dynamic>;
        msg = j['message'] as String? ?? msg;
      } catch (_) {}
      throw FamilyApiException(msg, res.statusCode);
    }
  }
}

class FamilyApiException implements Exception {
  final String message;
  final int statusCode;
  FamilyApiException(this.message, this.statusCode);
  @override
  String toString() => message;
}
