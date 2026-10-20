package com.normalpay.smsreader

import android.content.Context
import androidx.work.Worker
import androidx.work.WorkerParameters
import org.json.JSONArray
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.security.MessageDigest
import javax.crypto.Mac
import javax.crypto.spec.SecretKeySpec
import java.security.SecureRandom

class SmsSyncWorker(context: Context, params: WorkerParameters) : Worker(context, params) {
    override fun doWork(): Result {
        val cfg = SecureStore.config(applicationContext) ?: return Result.success()
        val queue = SecureStore.queue(applicationContext)
        if (queue.length() == 0) return Result.success()
        val selected = JSONArray(); val ids = mutableSetOf<String>()
        for (i in 0 until minOf(queue.length(), 25)) {
            val item = queue.optJSONObject(i) ?: continue
            selected.put(JSONObject().put("provider", item.optString("provider")).put("body", item.optString("body")).put("received_at", item.optString("received_at")))
            ids.add(item.optString("local_id"))
        }
        if (selected.length() == 0) return Result.success()
        val body = JSONObject().put("messages", selected).toString()
        val path = "/api/sms-ingest.php"
        val timestamp = System.currentTimeMillis() / 1000L
        val nonceBytes = ByteArray(24); SecureRandom().nextBytes(nonceBytes)
        val nonce = nonceBytes.joinToString("") { "%02x".format(it) }
        val bodyHash = sha256(body.toByteArray(Charsets.UTF_8))
        val signText = "POST\n$path\n$timestamp\n$nonce\n$bodyHash"
        val signature = hmac(cfg.getString("deviceSecret"), signText)
        var conn: HttpURLConnection? = null
        return try {
            conn = (URL(cfg.getString("baseUrl") + path).openConnection() as HttpURLConnection).apply {
                requestMethod = "POST"; connectTimeout = 15000; readTimeout = 20000; doOutput = true
                setRequestProperty("Content-Type", "application/json; charset=utf-8")
                setRequestProperty("Accept", "application/json")
                setRequestProperty("X-Device-Id", cfg.getInt("deviceId").toString())
                setRequestProperty("X-Timestamp", timestamp.toString())
                setRequestProperty("X-Nonce", nonce)
                setRequestProperty("X-Signature", signature)
            }
            conn.outputStream.use { it.write(body.toByteArray(Charsets.UTF_8)) }
            val status = conn.responseCode
            val responseText = (if (status in 200..299) conn.inputStream else conn.errorStream)?.bufferedReader()?.use { it.readText() }.orEmpty()
            val json = try { JSONObject(responseText) } catch (_: Exception) { JSONObject() }
            if (status in 200..299 && json.optBoolean("ok", false)) {
                SecureStore.removeUploaded(applicationContext, ids)
                if (SecureStore.pendingCount(applicationContext) > 0) Result.retry() else Result.success()
            } else if (status == 401 || status == 403 || status == 402 || status == 409 || status == 422) {
                // Keep queued data for the user to resolve credentials, plan, or server configuration.
                Result.failure()
            } else Result.retry()
        } catch (_: Exception) { Result.retry() }
        finally { conn?.disconnect() }
    }

    private fun sha256(bytes: ByteArray): String = MessageDigest.getInstance("SHA-256").digest(bytes).joinToString("") { "%02x".format(it) }
    private fun hmac(secret: String, text: String): String {
        val mac = Mac.getInstance("HmacSHA256")
        mac.init(SecretKeySpec(secret.toByteArray(Charsets.UTF_8), "HmacSHA256"))
        return mac.doFinal(text.toByteArray(Charsets.UTF_8)).joinToString("") { "%02x".format(it) }
    }
}
