# Ajout du scan QR — mobile_scanner

## 1. pubspec.yaml
```yaml
dependencies:
  mobile_scanner: ^5.2.3
```
Puis `flutter pub get`.

## 2. Fichiers
| Fichier | Destination |
|---|---|
| `qr_scan_screen.dart` | `lib/screens/` (nouveau) |
| `family_screen.dart`  | `lib/screens/` (remplace — ajoute l'import + bouton scan) |

## 3. Permissions caméra

### iOS — ios/Runner/Info.plist
```xml
<key>NSCameraUsageDescription</key>
<string>Pour scanner le QR code d'invitation à votre famille.</string>
```

### Android — android/app/src/main/AndroidManifest.xml
```xml
<uses-permission android:name="android.permission.CAMERA"/>
```
minSdkVersion 21 requis (mobile_scanner). Vérifier android/app/build.gradle.

### macOS — macos/Runner/*.entitlements (DebugProfile ET Release)
```xml
<key>com.apple.security.device.camera</key>
<true/>
```
Ajouter dans les DEUX fichiers .entitlements.

## Comportement
- Le dialogue "Rejoindre" garde le champ où COLLER le lien.
- Un bouton "Scanner le QR code" ouvre la caméra ; le résultat remplit
  le même champ (collage et scan cohabitent).
- Si la caméra est indisponible (ex. macOS sans webcam), un message
  invite à revenir en arrière et coller le lien.
- Le QrScanScreen renvoie la valeur brute du QR ; FamilyService en
  extrait le token (lien complet ou token nu, déjà géré).
