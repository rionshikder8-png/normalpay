package store.adverune.aps

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNotNull
import kotlin.test.assertNull

class SmsParserTest {
    private val bkashReceived = "You have received Tk 80.00 from 01754621712. Fee Tk 0.00. Balance Tk 80.00. TrxID DH869CQW1Q at 08/08/2026"
    private val bkashCashIn = "Cash In Tk 100.00 from 01602375064 successful. Fee Tk 0.00. Balance Tk 130.39. TrxID DJR0MBTV8E at 27/10/2026 16:17. Download App: https://bKa.sh/8app"
    private val nagadAgent = "Cash In Received.\nAmount: Tk 100.00\nUddokta: 01929699145\nTxnID: 75AD33IM\nBalance: 109.00\n01/05/2026 13:08"
    private val nagadPersonal = "Money Received.\nAmount: Tk 52.00\nSender: 01343128329\nRef: N/A\nTxnID: 755WJUBV\nBalance: Tk 52.95\n02/04/2026 19:00"

    @Test fun acceptsRealBkash() {
        assertEquals("bkash", SmsParser.classify("bKash", bkashReceived)?.provider)
        assertEquals("bkash", SmsParser.classify("bKash", bkashCashIn)?.provider)
    }

    @Test fun acceptsRealNagad() {
        assertEquals("nagad", SmsParser.classify("NAGAD", nagadAgent)?.provider)
        assertEquals("nagad", SmsParser.classify("NAGAD", nagadPersonal)?.provider)
        assertNotNull(SmsParser.classify("NAGAD", nagadPersonal.replace("\n", "\r\n")))
    }

    @Test fun rejectsNonOfficialSenders() {
        for (s in listOf("01712345678", "16247", "16167", "Bkash", "BKASH", "bkash", "Nagad", "nagad", "NAGAD ", "bKash ", "")) {
            assertNull(SmsParser.classify(s, bkashReceived), "sender '$s' must be rejected for bKash body")
            assertNull(SmsParser.classify(s, nagadPersonal), "sender '$s' must be rejected for Nagad body")
        }
        // Official bKash sender cannot carry a Nagad-format message, and vice versa.
        assertNull(SmsParser.classify("bKash", nagadPersonal))
        assertNull(SmsParser.classify("NAGAD", bkashReceived))
    }

    @Test fun rejectsTamperedOrNonPaymentBodies() {
        val bad = listOf(
            "Your bKash OTP is 123456. TrxID DH869CQW1Q",
            "Cash Out Tk 500.00 to 01712345678 successful. Fee Tk 9.25. Balance Tk 80.00. TrxID AB12CD34EF at 27/10/2026 16:17",
            "You have sent Tk 500.00 to 01712345678. Fee Tk 0.00. Balance Tk 80.00. TrxID AB12CD34EF at 27/10/2026 16:17",
            "$bkashReceived Visit http://evil.example",
            "Congrats! $bkashReceived",
            bkashCashIn.replace("https://bKa.sh/8app", "https://evil.example/x"),
            "You have received Tk 80.00 from 01754621712. TrxID DH869CQW1Q",
            "",
            "x".repeat(500),
        )
        for (b in bad) assertNull(SmsParser.classify("bKash", b), "must reject: $b")
        val badNagad = listOf(
            "Payment Failed.\nAmount: Tk 52.00\nTxnID: 755WJUBV",
            "Cash Out Successful.\nAmount: Tk 100.00\nTxnID: 75AD33IM\nBalance: 109.00\n01/05/2026 13:08",
            "$nagadPersonal\nClick http://evil.example",
        )
        for (b in badNagad) assertNull(SmsParser.classify("NAGAD", b), "must reject: $b")
    }
}
