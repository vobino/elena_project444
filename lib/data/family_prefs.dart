import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// Identité locale et appartenance à la famille.
///
/// Fichier autonome (SharedPreferences direct) pour ne pas toucher
/// AppSettings. L'appareil EST l'identité : un deviceId généré au premier
/// lancement + un prénom choisi par l'utilisateur. Zéro mot de passe.
class FamilyPrefs {
  FamilyPrefs._();
  static final FamilyPrefs instance = FamilyPrefs._();

  static const _kDeviceId = 'family.deviceId';
  static const _kDisplayName = 'family.displayName';
  static const _kFamilyId = 'family.familyId';
  static const _kFamilyName = 'family.familyName';
  static const _kRole = 'family.role'; // 'CREATOR' | 'MEMBER'
  static const _kAuthToken = 'family.authToken'; // JWT émis par le serveur

  late SharedPreferences _p;

  String get deviceId => _p.getString(_kDeviceId)!;
  String get displayName => _p.getString(_kDisplayName) ?? '';
  String? get familyId => _p.getString(_kFamilyId);
  String? get familyName => _p.getString(_kFamilyName);
  String? get role => _p.getString(_kRole);
  String? get authToken => _p.getString(_kAuthToken);

  bool get hasFamily => familyId != null;
  bool get isCreator => role == 'CREATOR';

  Future<void> load() async {
    _p = await SharedPreferences.getInstance();
    // Génère l'identité de l'appareil au tout premier lancement.
    if (_p.getString(_kDeviceId) == null) {
      await _p.setString(_kDeviceId, const Uuid().v4());
    }
  }

  Future<void> setDisplayName(String v) => _p.setString(_kDisplayName, v);

  Future<void> joinFamily({
    required String familyId,
    required String familyName,
    required String role,
    required String authToken,
  }) async {
    await _p.setString(_kFamilyId, familyId);
    await _p.setString(_kFamilyName, familyName);
    await _p.setString(_kRole, role);
    await _p.setString(_kAuthToken, authToken);
  }

  Future<void> leaveFamily() async {
    await _p.remove(_kFamilyId);
    await _p.remove(_kFamilyName);
    await _p.remove(_kRole);
    await _p.remove(_kAuthToken);
  }
}
