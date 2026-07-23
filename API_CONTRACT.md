# BibiTrack — Contrat d'API Famille & Tchat

Base : `{apiBaseUrl}/api/v1` — WebSocket : `{ws|wss}://{host}/ws`

## Authentification

Identité légère, sans mot de passe. L'appareil **est** l'identité.

- `deviceId` : UUID v4 généré au premier lancement, stocké en local.
- Le serveur émet un **JWT** à la création/adhésion, avec en claims :
  `sub = deviceId`, `familyId`, `role` (`CREATOR` | `MEMBER`).
- Toutes les requêtes portent :
  - `Authorization: Bearer <jwt>`
  - `X-Device-Id: <deviceId>`

**Règle de sécurité clé** : quand un membre est retiré, son JWT doit
cesser de fonctionner immédiatement. Le JWT seul ne suffit donc pas :
chaque requête (et le handshake WebSocket) doit vérifier en base que la
`Membership(familyId, deviceId)` existe toujours et n'est pas révoquée.
Une simple validation de signature laisserait une gardienne retirée
accéder au tchat jusqu'à expiration du token.

## Entités

```
Family        : id, name, creatorDeviceId, createdAt
Membership    : familyId, deviceId, displayName, role, joinedAt, revokedAt?
Invitation    : token, familyId, createdBy, expiresAt, revokedAt?, usedAt?
ChatMessage   : id, familyId, senderId, senderName, text, sentAt
```

## Endpoints REST

### POST /families
Crée une famille. L'appelant devient `CREATOR`.
```json
// req
{ "name": "Famille Dupont", "deviceId": "uuid", "displayName": "Vincent" }
// res 201
{ "familyId": "uuid", "familyName": "Famille Dupont", "token": "jwt" }
```

### POST /families/join
Rejoint via un token d'invitation. Rôle `MEMBER`.
```json
// req
{ "inviteToken": "abc123", "deviceId": "uuid", "displayName": "Mamy" }
// res 200
{ "familyId": "uuid", "familyName": "Famille Dupont", "role": "MEMBER", "token": "jwt" }
// 410 si invitation expirée ou révoquée
```

### GET /families/{familyId}/members
```json
// res 200
[{ "deviceId": "uuid", "displayName": "Vincent", "role": "CREATOR", "joinedAt": "2026-07-12T10:00:00Z" }]
```

### DELETE /families/{familyId}/members/{deviceId}
Retire un membre. **Créateur uniquement** — sauf si `deviceId` == l'appelant
(un membre peut toujours quitter la famille lui-même).
Le créateur ne peut pas se retirer. → `403` sinon.
Effet : `revokedAt = now()`, et **fermeture de la session WebSocket** du membre.

### POST /families/{familyId}/invitations
**Créateur uniquement.** Génère un lien à usage unique.
```json
// res 201
{ "token": "abc123", "url": "https://app.bibitrack.be/join/abc123", "expiresAt": "2026-07-19T10:00:00Z" }
```
Suggestion : token aléatoire 128 bits en base64url, TTL 7 jours.

### GET /families/{familyId}/invitations
**Créateur uniquement.** Liste les invitations actives (non expirées, non révoquées).

### DELETE /families/{familyId}/invitations/{token}
**Créateur uniquement.** Révoque un lien avant usage.

### GET /families/{familyId}/messages?limit=50
Historique du tchat, ordre chronologique (le plus ancien en premier).
```json
[{ "id": "uuid", "senderId": "uuid", "senderName": "Vincent", "text": "Bib pris à 14h", "sentAt": "2026-07-12T14:02:00Z" }]
```

### Erreurs
```json
{ "message": "Vous n'êtes plus membre de cette famille." }
```
Le client affiche directement `message`. Codes : `403` (pas créateur / plus membre),
`404`, `410` (invitation morte).

## WebSocket STOMP

Endpoint : `/ws` (WebSocket natif, pas SockJS).

- **Handshake** : header `Authorization: Bearer <jwt>`. Valider dans un
  `ChannelInterceptor` sur `CONNECT` + vérifier la Membership en base.
- **Abonnement** : `/topic/families/{familyId}/chat`
  Vérifier que le `familyId` du topic == celui du JWT (sinon un membre
  pourrait écouter le tchat d'une autre famille).
- **Envoi** : `/app/families/{familyId}/chat`
  ```json
  { "text": "Bib pris à 14h", "senderId": "uuid", "senderName": "Vincent" }
  ```
  Le serveur ignore `senderId`/`senderName` du payload et utilise ceux du
  JWT (sinon usurpation triviale). Il persiste, puis diffuse sur le topic
  le `ChatMessage` complet (avec `id` et `sentAt` serveur).

## Synchro du suivi bébé (déjà en place côté Flutter)

`unsyncedPayload()` envoie déjà `{ feedings, diapers, sleeps, baths }`.
Comme la famille partage les données, ces entités portent désormais un
`familyId` côté serveur (pris du JWT, jamais du payload). Le pull
(récupérer ce que les autres ont encodé) reste à concevoir — piste :
`GET /families/{id}/entries?since=<iso>`.
