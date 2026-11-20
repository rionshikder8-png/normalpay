package store.adverune.aps

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.PowerManager
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (SecureStore.config(this) != null) SyncScheduler.schedulePeriodic(this)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "store.adverune.aps/device").setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "saveConfig" -> {
                        val base = call.argument<String>("baseUrl") ?: throw IllegalArgumentException("Missing base URL")
                        val id = call.argument<Number>("deviceId")?.toInt() ?: throw IllegalArgumentException("Missing device ID")
                        val secret = call.argument<String>("deviceSecret") ?: throw IllegalArgumentException("Missing device secret")
                        if (!base.startsWith("https://") || id <= 0 || secret.length < 32) throw IllegalArgumentException("Invalid device configuration")
                        SecureStore.saveConfig(this, base, id, secret)
                        SyncScheduler.schedulePeriodic(this)
                        result.success(true)
                    }
                    "loadConfig" -> {
                        val c = SecureStore.config(this)
                        if (c == null) result.success(null)
                        else result.success(mapOf("baseUrl" to c.getString("baseUrl"), "deviceId" to c.getInt("deviceId"), "deviceSecret" to c.getString("deviceSecret")))
                    }
                    "clearConfig" -> {
                        SyncScheduler.cancelAll(this)
                        SecureStore.clearAll(this)
                        result.success(true)
                    }
                    "pendingCount" -> result.success(SecureStore.pendingCount(this))
                    "health" -> result.success(SecureStore.health(this))
                    "syncNow" -> { SyncScheduler.syncNow(this); result.success(true) }
                    "setGatewayEnabled" -> {
                        val p = call.argument<String>("provider") ?: throw IllegalArgumentException("Missing provider")
                        if (!SecureStore.PROVIDERS.contains(p)) throw IllegalArgumentException("Unknown provider")
                        SecureStore.setGatewayEnabled(this, p, call.argument<Boolean>("enabled") ?: true)
                        result.success(true)
                    }
                    "gatewayEnabled" -> result.success(SecureStore.PROVIDERS.associateWith { SecureStore.gatewayEnabled(this, it) })
                    "isIgnoringBatteryOptimizations" -> {
                        val pm = getSystemService(POWER_SERVICE) as PowerManager
                        result.success(Build.VERSION.SDK_INT < 23 || pm.isIgnoringBatteryOptimizations(packageName))
                    }
                    "openBatterySettings" -> {
                        val i = Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)
                        try { startActivity(i) } catch (_: Exception) {
                            startActivity(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:$packageName")))
                        }
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            } catch (e: Exception) { result.error("device_config_error", e.message, null) }
        }
    }
}
