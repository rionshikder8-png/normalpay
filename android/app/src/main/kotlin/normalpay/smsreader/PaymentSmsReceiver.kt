package com.normalpay.smsreader

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.provider.Telephony
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
        if (messages.isEmpty()) return
        val body = messages.joinToString("") { it.messageBody ?: "" }.trim()
        if (body.isBlank() || body.length > 600) return
        if (Regex("(?i)\\b(otp|pin|password|verification code|one[- ]time|login code)\\b").containsMatchIn(body)) return
        if (!Regex("(?i)(received|receive|cash ?in|payment|পেয়েছেন|পেয়েছেন)").containsMatchIn(body)) return
        if (!Regex("(?i)(trx\\s?id|txn\\s?id)[:\\s]*[A-Z0-9]{6,20}").containsMatchIn(body)) return
        if (!Regex("(?i)(tk|bdt|৳)\\s?[0-9][0-9,]*(\\.[0-9]{1,2})?").containsMatchIn(body)) return
        val sender = messages.first().originatingAddress.orEmpty()
        val all = (sender + " " + body).lowercase(Locale.ROOT)
        val provider = when {
            all.contains("bkash") || all.contains("b-kash") || all.contains("16247") -> "bkash"
            all.contains("nagad") || all.contains("16167") -> "nagad"
            all.contains("upay") || all.contains("16268") -> "upay"
            all.contains("rocket") || all.contains("dutch-bangla") || all.contains("16216") -> "rocket"
            else -> return
        }
        val ts = messages.first().timestampMillis.takeIf { it > 0 } ?: System.currentTimeMillis()
        val iso = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss'Z'", Locale.US).apply { timeZone = TimeZone.getTimeZone("UTC") }.format(Date(ts))
        SecureStore.enqueue(context, provider, body, sender, iso)
        WorkManager.getInstance(context).enqueue(OneTimeWorkRequestBuilder<SmsSyncWorker>().build())
    }
}
