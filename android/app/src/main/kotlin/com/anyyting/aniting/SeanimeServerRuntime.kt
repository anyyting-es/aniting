package com.anyyting.aniting

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.os.PowerManager
import android.provider.Settings
import java.io.File

object SeanimeServerRuntime {
    const val host = "127.0.0.1"
    const val defaultPort = 43211
    const val actionStart = "com.anyyting.aniting.action.START"
    const val actionStop = "com.anyyting.aniting.action.STOP"
    const val actionOpen = "com.anyyting.aniting.action.OPEN"
    const val extraPort = "port"
    const val notificationId = 43211
    const val notificationChannelId = "aniting-server"

    private const val prefsName = "aniting-server"
    private const val keyState = "state"
    private const val keyPort = "port"
    private const val keyStartedAt = "startedAt"
    private const val keyLastError = "lastError"
    private const val keyDataDir = "dataDir"

    private val defaultConfig = """
version = ''

[server]
host = '$host'
port = $defaultPort
offline = false
useBinaryPath = false
systray = false
password = ''
secureMode = 'lax'

[database]
name = 'seanime'

[web]
assetDir = '${'$'}SEANIME_DATA_DIR/assets'

[logs]
dir = '${'$'}SEANIME_DATA_DIR/logs'

[cache]
dir = '${'$'}SEANIME_DATA_DIR/cache'
transcodeDir = '${'$'}SEANIME_DATA_DIR/cache/transcode'

[offline]
dir = '${'$'}SEANIME_DATA_DIR/offline'
assetDir = '${'$'}SEANIME_DATA_DIR/offline/assets'

[manga]
downloadDir = '${'$'}SEANIME_DATA_DIR/manga'
localDir = '${'$'}SEANIME_DATA_DIR/manga-local'

[extensions]
dir = '${'$'}SEANIME_DATA_DIR/extensions'

[experimental]
builtintorrentclient = true
""".trimIndent() + "\n"

    fun start(context: Context, port: Int = defaultPort): Map<String, Any?> {
        val appContext = context.applicationContext
        ensureConfigFile(appContext)
        setState(appContext, "starting", null)
        prefs(appContext).edit()
            .putInt(keyPort, port)
            .putLong(keyStartedAt, System.currentTimeMillis())
            .apply()

        val intent = Intent(appContext, SeanimeServerService::class.java)
            .setAction(actionStart)
            .putExtra(extraPort, port)

        runCatching {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                appContext.startForegroundService(intent)
            } else {
                appContext.startService(intent)
            }
        }.onFailure { e ->
            setState(appContext, "error", e.message ?: e.toString())
        }

        return status(appContext)
    }

    fun stop(context: Context): Map<String, Any?> {
        val appContext = context.applicationContext
        setState(appContext, "stopping", null)
        val intent = Intent(appContext, SeanimeServerService::class.java)
            .setAction(actionStop)
        runCatching { appContext.startService(intent) }
        setState(appContext, "stopped", null)
        prefs(appContext).edit().remove(keyStartedAt).apply()
        return status(appContext)
    }

    fun setRunning(context: Context) {
        setState(context.applicationContext, "running", null)
    }

    fun setError(context: Context, error: Throwable) {
        setState(context.applicationContext, "error", error.message ?: error.toString())
    }

    fun setStopped(context: Context) {
        setState(context.applicationContext, "stopped", null)
        prefs(context.applicationContext).edit().remove(keyStartedAt).apply()
    }

    fun status(context: Context): Map<String, Any?> {
        val appContext = context.applicationContext
        val preferences = prefs(appContext)
        val port = preferences.getInt(keyPort, defaultPort)
        val state = preferences.getString(keyState, "stopped") ?: "stopped"
        val dataDir = dataDir(appContext)
        val configFile = configFile(appContext)

        return mapOf(
            "state" to state,
            "isRunning" to (state == "running" || state == "starting"),
            "url" to "http://$host:$port",
            "host" to host,
            "port" to port,
            "dataDir" to dataDir.absolutePath,
            "cacheDir" to File(dataDir, "cache").absolutePath,
            "configPath" to configFile.absolutePath,
            "startedAt" to preferences.getLong(keyStartedAt, 0L).takeIf { it > 0L },
            "lastError" to preferences.getString(keyLastError, null),
            "batteryOptimizationIgnored" to isBatteryOptimizationIgnored(appContext),
            "manageStorageGranted" to isManageStorageGranted()
        )
    }

    fun createNotification(context: Context): Notification {
        val appContext = context.applicationContext
        ensureNotificationChannel(appContext)

        val launchIntent = appContext.packageManager.getLaunchIntentForPackage(appContext.packageName)
            ?.setAction(actionOpen)
            ?: Intent()
        val openIntent = PendingIntent.getActivity(
            appContext,
            1,
            launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val stopIntent = PendingIntent.getService(
            appContext,
            2,
            Intent(appContext, SeanimeServerService::class.java).setAction(actionStop),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val port = prefs(appContext).getInt(keyPort, defaultPort)

        val iconRes = if (appContext.applicationInfo.icon != 0) {
            appContext.applicationInfo.icon
        } else {
            android.R.drawable.stat_notify_sync
        }

        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(appContext, notificationChannelId)
        } else {
            Notification.Builder(appContext)
        }

        return builder
            .setContentTitle("Aniting Server")
            .setContentText("Servidor activo en http://$host:$port")
            .setSmallIcon(iconRes)
            .setOngoing(true)
            .setContentIntent(openIntent)
            .addAction(android.R.drawable.ic_menu_close_clear_cancel, "Detener", stopIntent)
            .apply {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                    setCategory(Notification.CATEGORY_SERVICE)
                }
            }
            .build()
    }

    fun isBatteryOptimizationIgnored(context: Context): Boolean {
        val powerManager = context.getSystemService(Context.POWER_SERVICE) as PowerManager
        return Build.VERSION.SDK_INT < Build.VERSION_CODES.M || powerManager.isIgnoringBatteryOptimizations(context.packageName)
    }

    fun requestIgnoreBatteryOptimization(context: Context): Boolean {
        val appContext = context.applicationContext
        val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS)
            .setData(Uri.parse("package:${appContext.packageName}"))
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        return runCatching {
            appContext.startActivity(intent)
            true
        }.getOrDefault(false)
    }

    fun isManageStorageGranted(): Boolean {
        return Build.VERSION.SDK_INT < Build.VERSION_CODES.R || Environment.isExternalStorageManager()
    }

    fun requestManageStorage(context: Context): Boolean {
        val appContext = context.applicationContext
        val uri = Uri.parse("package:${appContext.packageName}")
        val intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            Intent(Settings.ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION, uri)
        } else {
            Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, uri)
        }.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        return runCatching {
            appContext.startActivity(intent)
            true
        }.getOrDefault(false)
    }

    fun acquireWakeLock(context: Context): PowerManager.WakeLock {
        val powerManager = context.getSystemService(Context.POWER_SERVICE) as PowerManager
        return powerManager.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "SeanimeServer:WakeLock").apply {
            setReferenceCounted(false)
            acquire()
        }
    }

    private fun prefs(context: Context) = context.getSharedPreferences(prefsName, Context.MODE_PRIVATE)

    fun dataDir(context: Context): File {
        val appContext = context.applicationContext
        val customPath = prefs(appContext).getString(keyDataDir, null)
        if (!customPath.isNullOrBlank()) {
            return File(customPath)
        }

        // Default to Seanime directory on external storage if available, else internal files dir
        return if (isManageStorageGranted()) {
            val extDir = File(Environment.getExternalStorageDirectory(), "Seanime")
            if (!extDir.exists()) extDir.mkdirs()
            extDir
        } else {
            val dir = File(appContext.filesDir, "seanime")
            if (!dir.exists()) dir.mkdirs()
            dir
        }
    }

    private fun setState(context: Context, state: String, error: String?) {
        prefs(context).edit()
            .putString(keyState, state)
            .putString(keyLastError, error)
            .apply()
    }

    private fun configFile(context: Context) = File(dataDir(context), "config.toml")

    private fun ensureConfigFile(context: Context): File {
        val file = configFile(context)
        if (!file.exists()) {
            file.parentFile?.mkdirs()
            file.writeText(defaultConfig)
        }
        return file
    }

    fun readConfig(context: Context): Map<String, Any?> {
        val file = ensureConfigFile(context.applicationContext)
        return mapOf(
            "path" to file.absolutePath,
            "content" to file.readText(),
            "exists" to file.exists()
        )
    }

    fun writeConfig(context: Context, content: String): Map<String, Any?> {
        val file = configFile(context.applicationContext)
        file.parentFile?.mkdirs()
        file.writeText(content)
        return readConfig(context.applicationContext)
    }

    fun resetConfig(context: Context): Map<String, Any?> {
        return writeConfig(context.applicationContext, defaultConfig)
    }

    private fun ensureNotificationChannel(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return

        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (manager.getNotificationChannel(notificationChannelId) != null) return

        val channel = NotificationChannel(
            notificationChannelId,
            "Servidor Aniting",
            NotificationManager.IMPORTANCE_LOW
        ).apply {
            description = "Mantiene activo el servidor de Aniting y descargas en segundo plano."
            setShowBadge(false)
        }
        manager.createNotificationChannel(channel)
    }
}
