# APS backend contract (what the Reader needs from https://aps.adverune.store)

All endpoints live on the EXISTING main backend (no new domain). All use the existing device HMAC-SHA256 scheme
(`X-Device-Id`, `X-Timestamp`, `X-Nonce`, `X-Signature` over `METHOD\nPATH\nTS\nNONCE\nsha256(body)`).
GET requests sign an empty body. Query strings are NOT part of the signed PATH (PATH is the URL path only).

## Already existing (inspected, used as-is)
| Endpoint | Use |
|---|---|
| POST /api/device-register.php | one-time pairing |
| POST /api/device-ping.php | heartbeat / connection check |
| POST /api/sms-ingest.php | signed batch upload (max 25), server-side parsing + de-dup |

## Required for full app functionality (NOT present; the Reader shows an honest "not available yet" state until they exist)

### 1. GET /api/reader-stats.php
Response `{ "ok": true, "total_payments": int, "today_payments": int, "total_amount": number, "pending": int,
"gateways": [ { "provider": "bkash|nagad|rocket|upay", "total_transactions": int, "total_amount": number, "last_transaction_at": "ISO8601" } ] }`

### 2. GET /api/reader-transactions.php?page=1&per_page=30[&status=&provider=&q=&from=&to=]
Response `{ "ok": true, "has_more": bool, "items": [ { "id": "str", "provider": "bkash", "amount": 2500.00,
"provider_trx_id": "AB12CD34", "sender": "01XXXXXXXXX", "aps_reference": null|"APS-...", "sms_received_at": "ISO8601",
"verified_at": null|"ISO8601", "status": "verified|pending|unmatched|duplicate", "match_info": null|"str" } ] }`
Only fields the backend actually has should be returned; the app hides missing ones.

### 3. POST /api/device-fcm-token.php   body `{ "token": "...", "platform": "android", "action": "register|remove" }`
Associates the FCM registration token with the authenticated device (table e.g. `device_push_tokens(device_id, token, updated_at, invalid_at)`).
`remove` is called on logout. Response `{ "ok": true }`. Server must mark a token invalid when FCM returns UNREGISTERED / NOT_FOUND.

### 4. FCM sending (server side, PHP) — REQUIRED for real push
After `sms-ingest.php` parses/matches a transaction (and on verification, duplicate, unmatched, reader offline/online events), the PHP backend
sends an FCM **HTTP v1** message using a Google service account stored ONLY on the server (never in the app, never in git):
`POST https://fcm.googleapis.com/v1/projects/aps-gateway-e7d66/messages:send` with an OAuth2 bearer from the service-account JWT.
Recommended payload (data + notification so the system tray shows it when the app is closed, and the app can dedupe/deep-link):
```json
{ "message": { "token": "<device token>",
  "notification": { "title": "New Payment Received", "body": "৳2,500 received via bKash | TrxID: AB12CD34" },
  "data": { "type": "payment_received", "event_id": "<unique per event>", "gateway": "bkash", "amount": "2500",
            "trx_id": "AB12CD34", "tx": "<transaction id>", "at": "2026-11-19T09:00:00Z" },
  "android": { "priority": "HIGH", "notification": { "channel_id": "aps_payments" } } } }
```
Allowed `type` values: payment_received, payment_verified, unmatched_transaction, duplicate_sms, reader_disconnected,
reader_reconnected, server_connection_lost, server_connection_restored. Channel ids: `aps_payments`, `aps_verification`, `aps_device`.
`event_id` MUST be stable per event; the app drops repeats with the same id.
Reader-offline detection: a server cron that compares `devices.last_seen_at` with a threshold and emits reader_disconnected / reader_reconnected.

### 5. GET /api/reader-notifications.php?page=1
Response `{ "ok": true, "items": [ { "id": "event_id", "type": "payment_received", "title": "...", "body": "...", "gateway": "bkash",
"amount": 2500, "trx_id": "...", "tx": "...", "at": "ISO8601", "read": false } ] }` — lets the inbox backfill events missed while offline.

### 6. POST /api/reader-reference.php   body `{ "transaction_id": null|"..." }`
Issues a persistent, globally unique APS reference (e.g. `APS-20261119-000125`) using a DB sequence/UNIQUE constraint and optionally links it to a
transaction/order. Response `{ "ok": true, "reference": "APS-20261119-000125" }`. Without it the app produces a clearly labelled
LOCAL reference that is NOT globally unique and is never a provider TrxID.

## Security notes
- Firebase service-account private key: server only, outside the web root, `chmod 600`, never committed.
- `google-services.json` in the app is public client configuration (not a secret).
- Rate-limit the new endpoints and reuse the existing nonce/timestamp replay protection.
