# APS Reader architecture (contract between modules)

Package: `aps_reader` (Dart), Android `store.adverune.aps`. Flutter 3.35.7 / Dart 3.9. Material 3, no extra state package (use ChangeNotifier + ListenableBuilder / InheritedNotifier).

## Verified backend (existing, inspected)
- POST /api/device-register.php  {pair_code, device_uid, device_model, app_version} -> {ok, device_id, device_secret, server_time}
- POST /api/device-ping.php (signed) -> {ok, device_id, label}
- POST /api/sms-ingest.php (signed) {messages:[{provider, body, received_at}]} (max 25)
Signature: HMAC_SHA256(secret, METHOD\nPATH\nTS\nNONCE\nsha256(body)); headers X-Device-Id, X-Timestamp, X-Nonce, X-Signature.

## NOT existing (must be documented, never faked): stats, transaction list, notifications feed, FCM token register, reference-id.
Contract for these is in docs/BACKEND-CONTRACT.md. The app calls them through `ApsApi`, and when the server returns 404/not_found the UI shows
"Not available on server yet" states (never demo data). Locally-known data (queue, uploads accepted, sync times) is always real.

## Layout
lib/
  main.dart                      bootstrap + providers
  core/theme.dart                colors, text styles, ThemeData (design system)
  core/config.dart               baseUrl default https://aps.adverune.store, endpoints, checkoutUrl
  core/models.dart               Gateway, TxItem, NotifItem, DeviceHealth, ApiResult
  data/native_bridge.dart        MethodChannel store.adverune.aps/device
  data/api.dart                  ApsApi: signed requests
  data/local_store.dart          shared_preferences for NON-secret prefs & local history (ref ids, notif inbox cache, settings)
  state/app_state.dart           AppState ChangeNotifier (session, health, gateways, tx, notifs)
  ui/widgets/*.dart              shared widgets
  ui/screens/{login,shell,dashboard,transactions,notifications,gateways,settings}.dart
