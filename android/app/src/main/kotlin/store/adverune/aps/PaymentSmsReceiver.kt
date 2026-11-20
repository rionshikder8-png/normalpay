package store.adverune.aps

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.provider.Telephony
import androidx.work.Constraints
import androidx.work.NetworkType
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.WorkManager
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone

class PaymentSmsReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Telephony.Sms.Intents.SMS_RECEIVED_ACTION) return
        if (SecureStore.config(context) == null) return
        val messages = try { Telephony.Sms.Intents.getMessagesFromIntent(intent) } catch (_: Exception) { return }
        if (messages.isNullOrEmpty()) return
        val body = messages.joinToString("") { it.messageBody ?: "" }.trim()
        val sender = messages.first().originatingAddress.orEmpty()
        val parsed = SmsParser.classify(sender, body) ?: return
        if (!SecureStore.gatewayEnabled(context, parsed.provider)) return
        val ts = messages.first().timestampMillis.takeIf { it > 0 } ?: System.currentTimeMillis()
        val iso = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss'Z'", Locale.US).apply { timeZone = TimeZone.getTimeZone("UTC") }.format(Date(ts))
        if (!SecureStore.enqueue(context, parsed.provider, body, sender, iso)) return
        val req = OneTimeWorkRequestBuilder<SmsSyncWorker>()
            .setConstraints(Constraints.Builder().setRequiredNetworkType(NetworkType.CONNECTED).build())
            .build()
        WorkManager.getInstance(context).enqueue(req)
    }
}
