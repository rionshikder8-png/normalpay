package store.adverune.aps

import android.content.Context
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey
import org.json.JSONArray
import org.json.JSONObject

/** All device credentials, the offline queue and monitoring health live here, encrypted at rest. */
object SecureStore {
    private const val PREFS = "aps_secure_device_v1"
    private const val MAX_QUEUE = 500
    val PROVIDERS = listOf("bkash", "nagad", "rocket", "upay")

    private fun prefs(context: Context) = EncryptedSharedPreferences.create(
        context,
        PREFS,
        MasterKey.Builder(context).setKeyScheme(MasterKey.KeyScheme.AES256_GCM).build(),
        EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
        EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM
    )

    fun saveConfig(context: Context, baseUrl: String, deviceId: Int, secret: String) {
        prefs(context).edit().putString("base_url", baseUrl).putInt("device_id", deviceId).putString("device_secret", secret).apply()
    }

    fun config(context: Context): JSONObject? {
        val p = prefs(context)
        val id = p.getInt("device_id", 0)
        val secret = p.getString("device_secret", null)
        val url = p.getString("base_url", null)
        if (id <= 0 || secret.isNullOrBlank() || url.isNullOrBlank()) return null
        return JSONObject().put("baseUrl", url).put("deviceId", id).put("deviceSecret", secret)
    }

    fun clearAll(context: Context) {
        prefs(context).edit().clear().apply()
    }

    // ---- gateway monitoring toggles (default enabled) ----
    fun gatewayEnabled(context: Context, provider: String): Boolean = prefs(context).getBoolean("gw_$provider", true)
    fun setGatewayEnabled(context: Context, provider: String, enabled: Boolean) {
        prefs(context).edit().putBoolean("gw_$provider", enabled).apply()
    }

    // ---- offline queue ----
    @Synchronized
    fun enqueue(context: Context, provider: String, body: String, sender: String, receivedAt: String): Boolean {
        val p = prefs(context)
        val arr = try { JSONArray(p.getString("sms_queue", "[]")) } catch (_: Exception) { JSONArray() }
        if (arr.length() >= MAX_QUEUE) return false
        // Local duplicate guard: same provider + body + received time never queues twice.
        val fp = fingerprint(provider, body, receivedAt)
        for (i in 0 until arr.length()) {
            if (arr.optJSONObject(i)?.optString("fp") == fp) return false
        }
        if (recentlySeen(p, fp)) return false
        arr.put(
            JSONObject().put("local_id", java.util.UUID.randomUUID().toString()).put("fp", fp)
                .put("provider", provider).put("body", body.take(600)).put("sender", sender.take(80)).put("received_at", receivedAt)
        )
        p.edit().putString("sms_queue", arr.toString())
            .putLong("last_sms_at", System.currentTimeMillis())
            .putLong("last_sms_$provider", System.currentTimeMillis())
            .apply()
        return true
    }

    private fun fingerprint(provider: String, body: String, receivedAt: String): String {
        val md = java.security.MessageDigest.getInstance("SHA-256")
        return md.digest("$provider|$receivedAt|$body".toByteArray()).joinToString("") { "%02x".format(it) }
    }

    /** Remember the last 200 fingerprints already uploaded so a repeat broadcast cannot re-queue them. */
    private fun recentlySeen(p: android.content.SharedPreferences, fp: String): Boolean {
        val arr = try { JSONArray(p.getString("seen_fp", "[]")) } catch (_: Exception) { JSONArray() }
        for (i in 0 until arr.length()) if (arr.optString(i) == fp) return true
        return false
    }

    @Synchronized
    fun queue(context: Context): JSONArray = try { JSONArray(prefs(context).getString("sms_queue", "[]")) } catch (_: Exception) { JSONArray() }

    @Synchronized
    fun pendingCount(context: Context): Int = queue(context).length()

    @Synchronized
    fun removeUploaded(context: Context, localIds: Set<String>) {
        if (localIds.isEmpty()) return
        val p = prefs(context)
        val old = queue(context)
        val next = JSONArray()
        val seen = try { JSONArray(p.getString("seen_fp", "[]")) } catch (_: Exception) { JSONArray() }
        for (i in 0 until old.length()) {
            val item = old.optJSONObject(i) ?: continue
            if (localIds.contains(item.optString("local_id"))) {
                seen.put(item.optString("fp"))
            } else next.put(item)
        }
        val trimmed = JSONArray()
        val start = maxOf(0, seen.length() - 200)
        for (i in start until seen.length()) trimmed.put(seen.get(i))
        p.edit().putString("sms_queue", next.toString()).putString("seen_fp", trimmed.toString())
            .putInt("uploaded_total", p.getInt("uploaded_total", 0) + localIds.size).apply()
    }

    // ---- health ----
    fun markSyncOk(context: Context) {
        prefs(context).edit().putLong("last_sync_ok", System.currentTimeMillis()).putString("last_sync_error", "").apply()
    }

    fun markSyncError(context: Context, message: String) {
        prefs(context).edit().putLong("last_sync_err", System.currentTimeMillis()).putString("last_sync_error", message.take(120)).apply()
    }

    fun health(context: Context): Map<String, Any> {
        val p = prefs(context)
        val by = HashMap<String, Long>()
        for (pr in PROVIDERS) by[pr] = p.getLong("last_sms_$pr", 0L)
        return mapOf(
            "pending" to pendingCount(context),
            "lastSmsAt" to p.getLong("last_sms_at", 0L),
            "lastSyncOkAt" to p.getLong("last_sync_ok", 0L),
            "lastSyncErrorAt" to p.getLong("last_sync_err", 0L),
            "lastSyncError" to (p.getString("last_sync_error", "") ?: ""),
            "uploadedTotal" to p.getInt("uploaded_total", 0),
            "lastSmsByProvider" to by
        )
    }
}
