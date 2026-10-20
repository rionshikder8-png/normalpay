package com.normalpay.smsreader

import android.content.Context
import android.util.Base64
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey
import org.json.JSONArray
import org.json.JSONObject

object SecureStore {
    private const val PREFS = "normalpay_secure_device_v1"
    private fun prefs(context: Context) = EncryptedSharedPreferences.create(
        context,
        PREFS,
        MasterKey.Builder(context).setKeyScheme(MasterKey.KeyScheme.AES256_GCM).build(),
        EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
        EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM
    )
    fun get(context: Context, key: String, fallback: String = ""): String = prefs(context).getString(key, fallback) ?: fallback
    fun saveConfig(context: Context, baseUrl: String, deviceId: Int, secret: String) {
        prefs(context).edit().putString("base_url", baseUrl).putInt("device_id", deviceId).putString("device_secret", secret).apply()
    }
    fun config(context: Context): JSONObject? {
        val p = prefs(context); val id = p.getInt("device_id", 0); val secret = p.getString("device_secret", null); val url = p.getString("base_url", null)
        if (id <= 0 || secret.isNullOrBlank() || url.isNullOrBlank()) return null
        return JSONObject().put("baseUrl", url).put("deviceId", id).put("deviceSecret", secret)
    }
    fun clearConfig(context: Context) { prefs(context).edit().remove("base_url").remove("device_id").remove("device_secret").apply() }
    @Synchronized fun enqueue(context: Context, provider: String, body: String, sender: String, receivedAt: String) {
        val p = prefs(context); val arr = try { JSONArray(p.getString("sms_queue", "[]")) } catch (_: Exception) { JSONArray() }
        if (arr.length() >= 100) return
        arr.put(JSONObject().put("local_id", java.util.UUID.randomUUID().toString()).put("provider", provider).put("body", body.take(600)).put("sender", sender.take(80)).put("received_at", receivedAt))
        p.edit().putString("sms_queue", arr.toString()).apply()
    }
    @Synchronized fun queue(context: Context): JSONArray = try { JSONArray(prefs(context).getString("sms_queue", "[]")) } catch (_: Exception) { JSONArray() }
    @Synchronized fun pendingCount(context: Context): Int = queue(context).length()
    @Synchronized fun removeUploaded(context: Context, localIds: Set<String>) {
        if (localIds.isEmpty()) return
        val old = queue(context); val next = JSONArray()
        for (i in 0 until old.length()) { val item = old.optJSONObject(i) ?: continue; if (!localIds.contains(item.optString("local_id"))) next.put(item) }
        prefs(context).edit().putString("sms_queue", next.toString()).apply()
    }
}
