package store.adverune.aps

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/** Re-arms the periodic sync after a reboot or app update. */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED || intent.action == Intent.ACTION_MY_PACKAGE_REPLACED) {
            if (SecureStore.config(context) != null) SyncScheduler.schedulePeriodic(context)
        }
    }
}
