# BibiTrack 🍼

Application Flutter minimaliste pour parents fatigués : suivi des biberons/tétées, couches et sommeil. **Offline-first** (SQLite local), synchronisation différée vers un backend Spring Boot via REST.

## Lancer le projet

Le dossier contient `pubspec.yaml` et `lib/`. Pour générer les dossiers de plateforme (android/, ios/) :

```bash
flutter create . --project-name bibitrack --org com.tondomaine
flutter pub get
flutter run
```

> Sur l'émulateur Android, l'URL du backend local est `http://10.0.2.2:8080` (configurable dans Paramètres). Pour autoriser le HTTP en clair en dev, ajoute `android:usesCleartextTraffic="true"` dans le `<application>` du AndroidManifest.

## Fonctionnalités

- **Écran d'accueil** : 5 gros boutons — Biberon, Couche, Sommeil, Historique, Tchat.
- **Popup biberon** : quantité par pas de 10 ml, sein gauche/droite (tétée), prochain repas en heures **pré-rempli avec le dernier intervalle encodé**, case Vitamine D.
- **Popup couche** : choix du type (pipi / caca / mixte) en un tap.
- **Popup sommeil** : heure de début et de fin (fin optionnelle = sommeil en cours).
- **Mode fatigue extrême** (icône ⚡ en haut) : plus aucune popup, un tap = une entrée immédiate en DB avec les dernières valeurs connues. Pour le sommeil : tap 1 = début, tap 2 = fin. Snackbar avec « Annuler ».
- **Historique** : 3 tabs (Biberon / Couche / Sommeil), logs groupés par jour, swipe pour supprimer.
- **Bandeau « prochain repas »** sur l'accueil, calculé depuis la dernière entrée.
- **Offline-first** : tout fonctionne sans réseau. Le Tchat et les Paramètres exigent une connexion.
- **Paramètres (en ligne)** : activation d'abonnement → débloque uniquement le champ « Nom de l'enfant ». URL du serveur configurable.
- **Sync REST** : chaque entrée porte un UUID client + un flag `synced`. Push en batch, silencieux, à chaque enregistrement et au lancement de l'app.

## Contrat REST attendu (backend Spring Boot)

Toutes les dates sont en ISO-8601 UTC. Les `id` sont des UUID générés côté client → **upsert idempotent** côté serveur (clé primaire = id).

### `POST /api/v1/sync/batch`

```json
{
  "feedings": [
    { "id": "uuid", "at": "2026-06-13T03:12:00Z", "amountMl": 120,
      "side": null, "vitaminD": true, "nextAt": "2026-06-13T06:12:00Z" }
  ],
  "diapers": [
    { "id": "uuid", "at": "2026-06-13T04:00:00Z", "type": "pipi" }
  ],
  "sleeps": [
    { "id": "uuid", "start": "2026-06-13T20:30:00Z", "end": "2026-06-14T02:10:00Z" }
  ]
}
```

Réponse : `200 OK` (corps libre). Tout code 2xx ⇒ le client marque toutes les entrées comme synchronisées. Notes pour l'implémentation Spring Boot :

- `@PostMapping("/api/v1/sync/batch")` avec un DTO `SyncBatchRequest` contenant 3 listes.
- Upsert via `saveAll` après `findAllById`, ou `ON CONFLICT (id) DO UPDATE` (PostgreSQL).
- `amountMl == null` ⇒ tétée ; `side` ∈ {"G","D",null} ; `type` ∈ {"pipi","caca","mixte"} ; `end == null` ⇒ sommeil en cours.
- Sécurité : prévoir `Authorization: Bearer <JWT>` — le client a un TODO prêt dans `SyncService`.

### `POST /api/v1/subscription/activate`

Réponse `200` ⇒ abonnement actif côté client (à raffiner plus tard avec un vrai flux de paiement / vérification de reçu).

### `POST /api/v1/chat`

```json
{ "message": "Mon bébé a bu 90 ml, c'est normal ?" }
```

Réponse : `{ "reply": "..." }`.

### Évolutions prévues côté sync

- `GET /api/v1/sync?since={iso}` pour le pull multi-appareils (les modèles ont déjà `fromMap`/`toJson`, il restera à ajouter un `fromJson`).
- Marquage `synced` par entrée (réponse listant les id acceptés) plutôt que global, si tu veux des échecs partiels.

## Structure

```
lib/
├── main.dart
├── theme.dart                     # design "3h du matin" (sombre, gros contrastes)
├── models/entries.dart            # FeedingEntry, DiaperEntry, SleepEntry (+ toJson API)
├── data/
│   ├── app_database.dart          # SQLite (sqflite), flags synced, requêtes
│   └── app_settings.dart          # prefs : mode fatigue, dernières valeurs, abo, nom
├── services/sync_service.dart     # push batch REST, silencieux, offline-safe
├── screens/
│   ├── home_screen.dart           # 5 boutons + mode fatigue + bandeau prochain repas
│   ├── history_screen.dart        # tabs Biberon / Couche / Sommeil
│   ├── chat_screen.dart           # tchat (online) + SettingsScreen (online)
│   └── settings_screen.dart       # ré-export
└── widgets/
    ├── big_action_button.dart
    ├── feeding_sheet.dart
    └── diaper_sleep_sheets.dart
```
