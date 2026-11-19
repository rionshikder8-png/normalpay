package store.adverune.aps

import java.util.Locale

/**
 * Conservative on-device classifier. The backend remains the source of truth for parsing and
 * matching; this only decides whether an SMS is a plausible INCOMING payment worth uploading,
 * and which gateway it belongs to. It never uploads OTP/PIN/promotional/outgoing/failed SMS.
 */
object SmsParser {
    private val otp = Regex("(?i)\\b(otp|pin|password|passcode|verification code|one[- ]time|login code|secret code)\\b")
    private val outgoing = Regex("(?i)(you have (sent|paid|transferred)|payment (to|of) .* successful|cash ?out|sent money|send money|bill pay|mobile recharge|recharge|withdraw|you paid|purchase|merchant payment to)")
    private val failed = Regex("(?i)(fail(ed|ure)?|unsuccessful|declined|cancel(l)?ed|reversed|insufficient|invalid|could not|unable to|rejected|expired)")
    private val promo = Regex("(?i)(offer|cashback|bonus|discount|win |lucky|congratulations|campaign|promo|dial \\*|download the app|use code)")
    private val incoming = Regex("(?i)(you have received|received (tk|bdt|৳)|cash ?in|money received|payment received|received payment|received money|পেয়েছেন|জমা হয়েছে)")
    private val trx = Regex("(?i)(trx\\s?id|txn\\s?id|transaction\\s?id|ref(erence)?)[:\\s.#-]*([A-Z0-9]{6,20})")
    private val amount = Regex("(?i)(tk\\.?|bdt|৳)\\s?([0-9][0-9,]*(\\.[0-9]{1,2})?)")

    data class Parsed(val provider: String)

    fun classify(sender: String, body: String): Parsed? {
        val b = body.trim()
        if (b.isBlank() || b.length > 600) return null
        if (otp.containsMatchIn(b)) return null
        if (failed.containsMatchIn(b)) return null
        if (outgoing.containsMatchIn(b) && !incoming.containsMatchIn(b)) return null
        if (promo.containsMatchIn(b) && !trx.containsMatchIn(b)) return null
        if (!incoming.containsMatchIn(b)) return null
        if (!trx.containsMatchIn(b)) return null
        if (!amount.containsMatchIn(b)) return null
        val all = (sender + " " + b).lowercase(Locale.ROOT)
        val provider = when {
            all.contains("bkash") || all.contains("b-kash") || sender == "16247" -> "bkash"
            all.contains("nagad") || sender == "16167" -> "nagad"
            all.contains("upay") || sender == "16268" -> "upay"
            all.contains("rocket") || all.contains("dutch-bangla") || all.contains("dbbl") || sender == "16216" -> "rocket"
            else -> return null
        }
        return Parsed(provider)
    }
}
