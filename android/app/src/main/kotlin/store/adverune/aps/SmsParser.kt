package store.adverune.aps

/**
 * Strict, allow-list classifier for INCOMING payment SMS.
 *
 * Security rule (owner decision): a message is only considered if its sender ID is EXACTLY the
 * official alphanumeric sender of the gateway. Phone numbers, short codes and body keywords are
 * never trusted, so a spoofed or fake SMS from any other sender is ignored.
 *
 *   bKash -> sender "bKash"      Nagad -> sender "NAGAD"
 *
 * Then the body must match the exact structure of the real operator template. Anything else
 * (OTP, outgoing, cash-out, failed, promotional, unknown format) is dropped and never uploaded.
 * The backend remains the source of truth for parsing and matching.
 */
object SmsParser {
    private const val BKASH_SENDER = "bKash"
    private const val NAGAD_SENDER = "NAGAD"

    private const val AMT = "Tk\\s?[0-9][0-9,]*(?:\\.[0-9]{1,2})?"
    private const val TRX = "[A-Z0-9]{6,20}"

    // bKash: "You have received Tk 80.00 from 01754621712. Fee Tk 0.00. Balance Tk 80.00. TrxID DH869CQW1Q at 08/08/2026"
    private val bkashReceived = Regex(
        "^You have received $AMT from 01[0-9]{9}\\. Fee $AMT\\. Balance $AMT\\. TrxID $TRX at [0-9/]{8,10}(?: [0-9:]{4,5})?\\.?\\s*$"
    )

    // bKash: "Cash In Tk 100.00 from 01602375064 successful. Fee Tk 0.00. Balance Tk 130.39. TrxID DJR0MBTV8E at 27/10/2026 16:17. Download App: https://bKa.sh/8app"
    private val bkashCashIn = Regex(
        "^Cash In $AMT from 01[0-9]{9} successful\\. Fee $AMT\\. Balance $AMT\\. TrxID $TRX at [0-9/]{8,10}(?: [0-9:]{4,5})?\\.?(?: Download App: https://bKa\\.sh/[A-Za-z0-9]+)?\\s*$"
    )

    // Nagad agent cash in:
    // "Cash In Received.\nAmount: Tk 100.00\nUddokta: 01929699145\nTxnID: 75AD33IM\nBalance: 109.00\n01/05/2026 13:08"
    private val nagadCashIn = Regex(
        "^Cash In Received\\.\\s*Amount: $AMT\\s*Uddokta: 01[0-9]{9}\\s*TxnID: $TRX\\s*Balance: (?:Tk\\s?)?[0-9][0-9,]*(?:\\.[0-9]{1,2})?\\s*[0-9/]{8,10}(?: [0-9:]{4,5})?\\s*$"
    )

    // Nagad personal:
    // "Money Received.\nAmount: Tk 52.00\nSender: 01343128329\nRef: N/A\nTxnID: 755WJUBV\nBalance: Tk 52.95\n02/04/2026 19:00"
    private val nagadReceived = Regex(
        "^Money Received\\.\\s*Amount: $AMT\\s*Sender: 01[0-9]{9}\\s*(?:Ref: [^\\n]{0,40}\\s*)?TxnID: $TRX\\s*Balance: (?:Tk\\s?)?[0-9][0-9,]*(?:\\.[0-9]{1,2})?\\s*[0-9/]{8,10}(?: [0-9:]{4,5})?\\s*$"
    )

    data class Parsed(val provider: String)

    fun classify(sender: String, body: String): Parsed? {
        val b = body.trim()
        if (b.isEmpty() || b.length > 400) return null
        return when (sender) {
            BKASH_SENDER -> if (bkashReceived.matches(b) || bkashCashIn.matches(b)) Parsed("bkash") else null
            NAGAD_SENDER -> if (nagadCashIn.matches(b) || nagadReceived.matches(b)) Parsed("nagad") else null
            else -> null // exact, case-sensitive match only: "Bkash", "BKASH", numbers and short codes are rejected
        }
    }
}
