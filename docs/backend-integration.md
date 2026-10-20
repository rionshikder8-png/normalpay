# Backend integration verification

Reviewed against the uploaded `normal_Pay.zip` source:

- `api/device-register.php`: one-time pairing code redemption, returns a generated device secret once.
- `api/device-ping.php`: signed device authentication and heartbeat.
- `api/sms-ingest.php`: signed batches up to 25 messages; parses payment SMS server-side; stores extracted provider, amount, TrxID, sender number and timestamp; duplicate fingerprint protection; transaction matching.
- `modules/sms-reader/device-security.php`: request signature canonical string is `METHOD\nPATH\nTIMESTAMP\nNONCE\nsha256(raw body)`, HMAC-SHA256; timestamp must be within 300 seconds; nonce is one-use.
- `sms-reader.php`: merchant dashboard generates the pairing code and supports revoke.

The app uses only these main-site APIs. The hosted checkout ZIP is not used directly by the mobile app.

## Manual acceptance test checklist

- [ ] Pair with a valid code; confirm device is active on dashboard.
- [ ] Reuse the same code; server must reject it.
- [ ] Test connection; `last_seen_at` should update.
- [ ] Revoke device in dashboard; subsequent requests must fail.
- [ ] Receive a supported wallet payment SMS; only a payment-like SMS with amount and TrxID should enter the local queue.
- [ ] Receive a generic OTP/PIN SMS; it should not be queued.
- [ ] Go offline then online; queue should retry and clear only after server success.
- [ ] Submit the same SMS twice; server duplicate protection should avoid duplicate records.
- [ ] Confirm dashboard marks SMS match/review appropriately; never assume SMS alone means official verification.
