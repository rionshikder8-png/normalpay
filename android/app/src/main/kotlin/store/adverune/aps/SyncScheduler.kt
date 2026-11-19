package store.adverune.aps

import android.content.Context
import androidx.work.Constraints
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.NetworkType
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import java.util.concurrent.TimeUnit

object SyncScheduler {
    private fun net() = Constraints.Builder().setRequiredNetworkType(NetworkType.CONNECTED).build()

    fun schedulePeriodic(context: Context) {
        val periodic = PeriodicWorkRequestBuilder<SmsSyncWorker>(15, TimeUnit.MINUTES).setConstraints(net()).build()
        WorkManager.getInstance(context).enqueueUniquePeriodicWork("aps-periodic-sms-sync", ExistingPeriodicWorkPolicy.UPDATE, periodic)
    }

    fun cancelAll(context: Context) {
        WorkManager.getInstance(context).cancelUniqueWork("aps-periodic-sms-sync")
    }

    fun syncNow(context: Context) {
        WorkManager.getInstance(context).enqueue(OneTimeWorkRequestBuilder<SmsSyncWorker>().setConstraints(net()).build())
    }
}
