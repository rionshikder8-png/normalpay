# APS Reader (Adverune Payment System)

Payment monitoring and real-time alerts. Upgraded from the Normal Pay SMS Reader. Powered by Adverune.

- Android package: `store.adverune.aps` (app name **APS Reader**)
- Backend: `https://aps.adverune.store` (existing APIs). Hosted checkout: `https://pay.adverune.store`.
- Flutter 3.35.7, Material 3. CI: `.github/workflows/build.yml` (analyze, tests, signed release APK).

## Screens
Login / Device Pairing, then Dashboard, Transactions (history + APS reference IDs), Notifications, Gateways, Settings.

## What talks to the backend today
Existing and verified: `device-register.php`, `device-ping.php`, `sms-ingest.php` (HMAC-SHA256 signed).
Everything else (stats, transaction feed, notifications feed, FCM token, reference IDs, FCM sending) is specified in
[`docs/BACKEND-CONTRACT.md`](docs/BACKEND-CONTRACT.md). Until those exist, the app shows "not available yet" states and never fake data.

## Build
CI builds on every push. Locally: `flutter pub get && flutter analyze && flutter test && flutter build apk --release`.
Release signing uses GitHub secrets `APS_KEYSTORE_BASE64`, `APS_KEYSTORE_PASSWORD`, `APS_KEY_ALIAS`, `APS_KEY_PASSWORD`.
Never commit keystores or Firebase service-account keys.

## Install
1. Download `APS-Reader-release.apk` from the Actions run artifact `aps-reader-apk`.
2. Copy to the phone, allow "install unknown apps", install.
3. In the APS dashboard create a device and copy the 8-character code.
4. Open APS Reader, keep server `https://aps.adverune.store`, enter the code, tap Connect Device, allow SMS and notifications.
5. Settings > Battery Optimization > allow unrestricted so background sync is reliable.

## Limits
Android may delay or stop background work under aggressive battery saving or after Force Stop. SMS permission is sensitive: distribute the APK directly or complete Google Play's SMS permission declaration.
