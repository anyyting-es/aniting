package com.seanime.app.seanime_app

import android.app.Service
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import android.util.Log
import go.Seq
import mobile.Mobile
import java.io.File
import java.util.concurrent.atomic.AtomicBoolean

class SeanimeServerService : Service() {
    private var wakeLock: PowerManager.WakeLock? = null

    override fun onBind(intent: Intent?): IBinder? {
        return null
    }

    override fun onCreate() {
        super.onCreate()
        runCatching { System.loadLibrary("c++_shared") }
        runCatching { System.loadLibrary("asskt") }
        runCatching { System.loadLibrary("gojni") }
        runCatching { Seq.setContext(applicationContext) }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == SeanimeServerRuntime.actionStop) {
            handleStop()
            return START_NOT_STICKY
        }

        val port = intent?.getIntExtra(SeanimeServerRuntime.extraPort, SeanimeServerRuntime.defaultPort)
            ?: SeanimeServerRuntime.defaultPort

        runCatching {
            val notification = SeanimeServerRuntime.createNotification(applicationContext)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                startForeground(
                    SeanimeServerRuntime.notificationId,
                    notification,
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC
                )
            } else {
                startForeground(
                    SeanimeServerRuntime.notificationId,
                    notification
                )
            }
        }.onFailure { e ->
            Log.e("SeanimeServerService", "startForeground error: ${e.message}", e)
        }

        runCatching { ensureWakeLock() }
        startGoServer(port)

        return START_STICKY
    }

    override fun onDestroy() {
        releaseWakeLock()
        super.onDestroy()
    }

    private fun ensureWakeLock() {
        if (wakeLock?.isHeld == true) return
        wakeLock = SeanimeServerRuntime.acquireWakeLock(applicationContext)
    }

    private fun releaseWakeLock() {
        runCatching {
            if (wakeLock?.isHeld == true) {
                wakeLock?.release()
            }
        }
        wakeLock = null
    }

    private fun startGoServer(port: Int) {
        if (!serverStarted.compareAndSet(false, true)) {
            SeanimeServerRuntime.setRunning(applicationContext)
            return
        }

        Thread {
            runCatching {
                Seq.setContext(applicationContext)
                val dataDir = SeanimeServerRuntime.dataDir(applicationContext)
                val cacheDir = File(dataDir, "cache")
                if (!cacheDir.exists()) cacheDir.mkdirs()

                Mobile.startServer(dataDir.absolutePath, cacheDir.absolutePath, port.toLong())
                SeanimeServerRuntime.setRunning(applicationContext)
            }.onFailure { error ->
                serverStarted.set(false)
                SeanimeServerRuntime.setError(applicationContext, error)
            }
        }.apply {
            name = "SeanimeGoServer"
            isDaemon = false
            start()
        }
    }

    private fun handleStop() {
        releaseWakeLock()
        runCatching {
            Mobile.stopServer()
        }
        serverStarted.set(false)
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
        SeanimeServerRuntime.setStopped(applicationContext)
    }

    companion object {
        private val serverStarted = AtomicBoolean(false)
    }
}
