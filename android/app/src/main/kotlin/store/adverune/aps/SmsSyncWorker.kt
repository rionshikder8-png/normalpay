package store.adverune.aps

import android.content.Context
import androidx.work.Worker
import androidx.work.WorkerParameters
import org.json.JSONArray
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.security.MessageDigest
import java.security.SecureRandom
import javax.crypto.Mac
import javax.crypto.spec.SecretKeySpec

/**
 * Uploads queued payment SMS in signed batches of up to 25. Items are removed from the local
 * queue ONLY after the server confirms acceptance, so nothing is lost offline or on app close.
 */
class SmsSyncWorker(context: Context, params: WorkerParameters) : Worker(context, params) {
    override fun doWork(): Result {
        val ctx = applicationContext
        val cfg = SecureStore.config(ctx) ?: return Result.success()
        val queue = SecureStore.queue(ctx)
        if (queue.length() == 0) {
            // Nothing to upload: still prove the link to the server is alive.
            return heartbeat(cfg)
        }
        val selected = JSONArray()
        val ids = mutableSetOf<String>()
        for (i in 0 until minOf(queue.length(), 25)) {
            val item = queue.optJSONObject(i) ?: continue
            selected.put(JSONObject().put("provider", item.optString("provider")).put("body", item.optString("body")).put("received_at", item.optString("received_at")))
            ids.add(item.optString("local_id"))
        }
        if (selected.length() == 0) return Result.success()
        val body = JSONObject().put("messages", selected).toString()
        return when (val r = post(cfg, "/api/sms-ingest.php", body)) {
            is Resp.Net -> { SecureStore.markSyncError(ctx, "offline"); Result.retry() }
            is Resp.Http -> {
                val ok = r.status in 200..299 && (try { JSONObject(r.text).optBoolean("ok", false) } catch (_: Exception) { false })
                when {
                    ok -> {
                        SecureStore.removeUploaded(ctx, ids)
                        SecureStore.markSyncOk(ctx)
                        if (SecureStore.pendingCount(ctx) > 0) Result.retry() else Result.success()
                    }
                    r.status == 401 || r.status == 403 -> { SecureStore.markSyncError(ctx, "device_revoked"); Result.failure() }
                    r.status == 402 -> { SecureStore.markSyncError(ctx, "subscription_required"); Result.failure() }
                    r.status == 409 || r.status == 422 -> { SecureStore.markSyncError(ctx, "rejected_${r.status}"); Result.failure() }
                    else -> { SecureStore.markSyncError(ctx, "http_${r.status}"); Result.retry() }
                }
            }
        }
    }

    private fun heartbeat(cfg: JSONObject): Result {
        val ctx = applicationContext
        return when (val r = post(cfg, "/api/device-ping.php", "")) {
            is Resp.Net -> { SecureStore.markSyncError(ctx, "offline"); Result.retry() }
            is Resp.Http -> when {
                r.status in 200..299 -> { SecureStore.markSyncOk(ctx); Result.success() }
                r.status == 401 || r.status == 403 -> { SecureStore.markSyncError(ctx, "device_revoked"); Result.failure() }
                else -> { SecureStore.markSyncError(ctx, "http_${r.status}"); Result.retry() }
            }
        }
    }

    private sealed class Resp {
        object Net : Resp()
        data class Http(val status: Int, val text: String) : Resp()
    }

    private fun post(cfg: JSONObject, path: String, body: String): Resp {
        val timestamp = System.currentTimeMillis() / 1000L
        val nonceBytes = ByteArray(24); SecureRandom().nextBytes(nonceBytes)
        val nonce = nonceBytes.joinToString("") { "%02x".format(it) }
        val signText = "POST\n$path\n$timestamp\n$nonce\n${sha256(body.toByteArray(Charsets.UTF_8))}"
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
            val text = (if (status in 200..299) conn.inputStream else conn.errorStream)?.bufferedReader()?.use { it.readText() }.orEmpty()
            Resp.Http(status, text)
        } catch (_: Exception) { Resp.Net } finally { conn?.disconnect() }
    }

    private fun sha256(bytes: ByteArray): String = MessageDigest.getInstance("SHA-256").digest(bytes).joinToString("") { "%02x".format(it) }
    private fun hmac(secret: String, text: String): String {
        val mac = Mac.getInstance("HmacSHA256")
        mac.init(SecretKeySpec(secret.toByteArray(Charsets.UTF_8), "HmacSHA256"))
        return mac.doFinal(text.toByteArray(Charsets.UTF_8)).joinToString("") { "%02x".format(it) }
    }
}
