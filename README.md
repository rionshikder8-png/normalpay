# Normal Pay SMS Reader — Private Android App

Flutter/Dart app + Android native SMS receiver and WorkManager sync worker. This is a private APK for the owner and merchants who explicitly authorize the device. It is designed to use the APIs in the uploaded `normal_Pay.zip` main website; the hosted checkout package does not need a direct app integration.

## Important status

- Source project is supplied. An APK is **not** included because this build environment does not have Flutter/Android SDK installed, so a real Android build could not be run here.
- The app targets the API contracts found in the uploaded merchant project:
  - `POST /api/device-register.php`
  - signed `POST /api/device-ping.php`
  - signed `POST /api/sms-ingest.php`
- The default URL in the app is `https://normal.com`. Change it to the actual HTTPS origin where your merchant platform is installed before pairing.
- Provider SMS formats can change. Test against your own legitimate sample messages before relying on the reader. Unrecognized formats are ignored.
- An SMS match is not official payment verification. The backend itself documents this and can leave matches in review.

## Features

- White, responsive Flutter UI; English/Bangla toggle.
- One-time 8-character pairing code generated in `Dashboard → SMS Reader`.
- Device secret saved in Android encrypted shared preferences backed by Android Keystore.
- HMAC-SHA256 request signing compatible with `modules/sms-reader/device-security.php`.
- Incoming SMS broadcast receiver; it does not scan/read the historical inbox.
- Conservative detection for bKash, Nagad, Upay and Rocket payment-like SMS; excludes common OTP/PIN messages.
- Encrypted local queue (up to 100 items), duplicate handling on the server, retryable background upload using WorkManager, and network constraints.
- Raw SMS body is held temporarily in the encrypted on-device queue until a successful upload. The uploaded backend parses it in memory and says it does not persist raw body text. Queue is cleared only for successfully accepted batches.
- Test connection, sync now, pending queue count, disconnect and clear local credentials.

## Requirements to build

- Flutter stable SDK (Dart 3.4+; use a current stable Flutter release)
- Android Studio / Android SDK and JDK 17
- A computer is recommended for building. Termux on Android is not the recommended build environment.
- A live HTTPS Normal Pay main website with the uploaded merchant package installed and database configured.

## Build the APK

1. Extract this ZIP on a computer.
2. Install Flutter stable and Android Studio, then accept Android SDK licenses:

   ```bash
   flutter doctor
   flutter doctor --android-licenses
   ```

3. **If `android/gradlew` or `android/gradle/wrapper/gradle-wrapper.jar` is missing** (the wrapper JAR cannot be redistributed from this build environment), create a temporary Flutter Android scaffold and copy the standard wrapper files:

   ```bash
   flutter create --platforms=android --project-name normal_pay_sms_reader /tmp/normal_pay_wrapper_seed
   cp /tmp/normal_pay_wrapper_seed/android/gradlew android/gradlew
   cp /tmp/normal_pay_wrapper_seed/android/gradlew.bat android/gradlew.bat
   mkdir -p android/gradle/wrapper
   cp /tmp/normal_pay_wrapper_seed/android/gradle/wrapper/gradle-wrapper.jar android/gradle/wrapper/gradle-wrapper.jar
   chmod +x android/gradlew
   ```

   Keep this project's `android/gradle/wrapper/gradle-wrapper.properties` and app Kotlin/Gradle files.

4. From the project root, run:

   ```bash
   flutter pub get
   flutter analyze
   flutter build apk --release
   ```

5. APK output:

   `build/app/outputs/flutter-apk/app-release.apk`

6. Copy the APK to your Android phone and install it. If prompted, allow installing apps from that file manager/browser. Only install builds you trust.

## Connect the app to Normal Pay

1. Install and configure `normal_Pay.zip` on your main domain first. The site must be HTTPS.
2. Sign in to the merchant dashboard, open **SMS Reader**, add a device with a recognizable label, and copy the one-time code. The code expires after 15 minutes and can be used once.
3. Open Normal Pay SMS Reader on the Android phone.
4. Set the Main Website URL to the exact origin, e.g. `https://normal.com` (no subdirectory and no trailing slash needed).
5. Enter the 8-character pairing code and tap **Pair device securely**.
6. Grant SMS permission when Android asks. This permission is needed to receive new SMS broadcasts; the app does not import old inbox messages.
7. Tap **Test connection**. Confirm that the device is shown as active in the website dashboard.
8. Send a legitimate test payment or use a safe test environment and confirm the transaction appears in the merchant dashboard as SMS-matched/review, not falsely as official verification.

## Security and operational notes

- Pairing codes are short-lived and single-use. Treat them as credentials; do not share screenshots of them.
- Device secret is shown once by the API and stored using Android encrypted preferences. Disconnecting clears the phone's local credentials, but **you must also revoke the device in the web dashboard** to invalidate it server-side.
- HTTPS is mandatory; cleartext HTTP is disabled.
- Only use this on a device/account you own or have explicit authorization to administer. Explain SMS permission and collection to the phone owner.
- SMS text can contain sensitive financial details. This app filters to payment-like messages, but detection is heuristic and cannot guarantee every message is classified correctly. Review the queue and backend logs during initial testing.
- Android may delay background jobs due to battery optimization. WorkManager is best-effort, not real-time guaranteed. Keep the app updated and check dashboard `last seen` status.
- Do not use SMS contents alone to automatically release goods or treat a transaction as officially verified. A sender can spoof messages; authoritative provider verification or human review may still be required.
- The current parser is conservative and should be adjusted only after inspecting redacted, legitimate examples from each wallet. Do not send OTP/PIN/password messages into the platform.

## API compatibility notes

### Pairing request

`POST /api/device-register.php` JSON body:

```json
{
  "pair_code": "ABCD2345",
  "device_uid": "android-installation-unique-value",
  "device_model": "Android phone",
  "app_version": "1.0.0"
}
```

Success returns `ok`, `device_id`, `device_secret`, `server_time`. The app stores the secret securely and never displays it.

### Signed request headers

The app computes:

`HMAC_SHA256(secret, METHOD + "\n" + PATH + "\n" + TIMESTAMP + "\n" + NONCE + "\n" + SHA256(rawBody))`

Headers: `X-Device-Id`, `X-Timestamp`, `X-Nonce`, `X-Signature`.

### SMS upload

`POST /api/sms-ingest.php` JSON body:

```json
{
  "messages": [
    {
      "provider": "bkash",
      "body": "payment SMS text",
      "received_at": "2026-10-20T10:15:00Z"
    }
  ]
}
```

Maximum 25 messages per request. The backend is the source of truth for parsing and transaction matching.

## Troubleshooting

- **Invalid/expired code:** generate a new code from the SMS Reader page and pair within 15 minutes.
- **Bad signature / timestamp error:** confirm phone date/time is automatic, website HTTPS works, and you did not modify the API path.
- **Subscription required (HTTP 402):** enable an eligible plan/device allowance in Normal Pay; queued messages remain on the phone until successfully accepted or manually cleared.
- **No SMS detected:** check Android app permissions, confirm the SMS sender/body includes a supported wallet identifier and payment-like text, and verify a TrxID plus amount exists. Current matching is intentionally strict.
- **Device active but no uploads:** open app and tap Sync now, check internet and merchant plan, then review the website dashboard.
- **Device revoked:** create a new device/code in the dashboard and pair again.
- **Android Studio build error:** run `flutter doctor`, accept licenses, ensure JDK 17, then `flutter clean`, `flutter pub get`, `flutter build apk --release`.
