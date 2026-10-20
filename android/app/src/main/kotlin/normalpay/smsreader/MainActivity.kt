package com.normalpay.smsreader

import android.os.Bundle
import androidx.work.Constraints
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.NetworkType
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.OneTimeWorkRequestBuilder
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.TimeUnit

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val constraints = Constraints.Builder().setRequiredNetworkType(NetworkType.CONNECTED).build()
        val periodic = PeriodicWorkRequestBuilder<SmsSyncWorker>(15, TimeUnit.MINUTES).setConstraints(constraints).build()
        WorkManager.getInstance(this).enqueueUniquePeriodicWork("normalpay-periodic-sms-sync", ExistingPeriodicWorkPolicy.UPDATE, periodic)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.normalpay.smsreader/device").setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "saveConfig" -> {
                        val base = call.argument<String>("baseUrl") ?: throw IllegalArgumentException("Missing base URL")
                        val id = call.argument<Number>("deviceId")?.toInt() ?: throw IllegalArgumentException("Missing device ID")
                        val secret = call.argument<String>("deviceSecret") ?: throw IllegalArgumentException("Missing device secret")
                        if (!base.startsWith("https://") || id <= 0 || secret.length < 32) throw IllegalArgumentException("Invalid device configuration")
                        SecureStore.saveConfig(this, base, id, secret); result.success(true)
                    }
                    "loadConfig" -> {
                        val c = SecureStore.config(this)
                        if (c == null) result.success(null) else result.success(mapOf("baseUrl" to c.getString("baseUrl"), "deviceId" to c.getInt("deviceId"), "deviceSecret" to c.getString("deviceSecret")))
                    }
                    "clearConfig" -> { SecureStore.clearConfig(this); result.success(true) }
                    "pendingCount" -> result.success(SecureStore.pendingCount(this))
                    "syncNow" -> {
                        val req = OneTimeWorkRequestBuilder<SmsSyncWorker>().setConstraints(Constraints.Builder().setRequiredNetworkType(NetworkType.CONNECTED).build()).build()
                        WorkManager.getInstance(this).enqueue(req); result.success(true)
                    }
                    else -> result.notImplemented()
                }
            } catch (e: Exception) { result.error("device_config_error", e.message, null) }
        }
    }
}
