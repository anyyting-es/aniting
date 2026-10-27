package com.anyyting.aniting

import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import android.util.Log
import java.io.File
import java.io.InputStream
import java.io.OutputStream
import java.net.InetSocketAddress
import java.net.ServerSocket
import java.net.Socket
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean

class SeanimeServerService : Service() {
    private var wakeLock: PowerManager.WakeLock? = null
    private var lanForwarder: LanTcpForwarder? = null

    override fun onBind(intent: Intent?): IBinder? {
        return null
    }

    override fun onCreate() {
        super.onCreate()
        runCatching { System.loadLibrary("c++_shared") }
        runCatching { System.loadLibrary("asskt") }
        runCatching { System.loadLibrary("gojni") }
        runCatching {
            val seqClass = Class.forName("go.Seq")
            val setContextMethod = seqClass.getMethod("setContext", Context::class.java)
            setContextMethod.invoke(null, applicationContext)
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == SeanimeServerRuntime.actionStop) {
            handleStop()
            return START_NOT_STICKY
        }

        val port = intent?.getIntExtra(SeanimeServerRuntime.extraPort, SeanimeServerRuntime.defaultPort)
            ?: SeanimeServerRuntime.defaultPort
        val host = intent?.getStringExtra(SeanimeServerRuntime.extraHost)
            ?: SeanimeServerRuntime.host

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
        startGoServer(port, host)

        return START_STICKY
    }

    override fun onDestroy() {
        releaseWakeLock()
        lanForwarder?.stop()
        lanForwarder = null
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

    private fun startGoServer(port: Int, host: String) {
        if (!serverStarted.compareAndSet(false, true)) {
            SeanimeServerRuntime.setRunning(applicationContext)
            return
        }

        // Si se pide compartir en LAN (0.0.0.0), arrancamos Go en un puerto interno (loopback)
        // y un reenviador TCP nativo de alto rendimiento en 0.0.0.0:$port para permitir acceso externo.
        val isLanMode = host == "0.0.0.0"
        val goPort = if (isLanMode) {
            if (port == 43311) 43310 else port + 10
        } else {
            port
        }

        if (isLanMode) {
            lanForwarder?.stop()
            lanForwarder = LanTcpForwarder(listenPort = port, targetPort = goPort).apply {
                start()
            }
        }

        Thread {
            runCatching {
                val mobileClass = try {
                    Class.forName("mobile.Mobile")
                } catch (e: ClassNotFoundException) {
                    Log.w("SeanimeServerService", "Go backend (seanime.aar) is not bundled in this build.")
                    SeanimeServerRuntime.setError(
                        applicationContext,
                        IllegalStateException("Embedded Go server is not included in this build (standalone/remote client build).")
                    )
                    serverStarted.set(false)
                    lanForwarder?.stop()
                    lanForwarder = null
                    return@Thread
                }

                runCatching {
                    val seqClass = Class.forName("go.Seq")
                    val setContextMethod = seqClass.getMethod("setContext", Context::class.java)
                    setContextMethod.invoke(null, applicationContext)
                }

                val dataDir = SeanimeServerRuntime.dataDir(applicationContext)
                val cacheDir = File(dataDir, "cache")
                if (!cacheDir.exists()) cacheDir.mkdirs()
                val logsDir = File(dataDir, "logs")
                if (!logsDir.exists()) logsDir.mkdirs()
                val assetsDir = File(dataDir, "assets")
                if (!assetsDir.exists()) assetsDir.mkdirs()
                val extensionsDir = File(dataDir, "extensions")
                if (!extensionsDir.exists()) extensionsDir.mkdirs()

                val startMethod = mobileClass.getMethod(
                    "startServer",
                    String::class.java,
                    String::class.java,
                    Long::class.javaPrimitiveType
                )
                startMethod.invoke(null, dataDir.absolutePath, cacheDir.absolutePath, goPort.toLong())
                SeanimeServerRuntime.setRunning(applicationContext)
            }.onFailure { error ->
                serverStarted.set(false)
                lanForwarder?.stop()
                lanForwarder = null
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
        lanForwarder?.stop()
        lanForwarder = null
        runCatching {
            val mobileClass = Class.forName("mobile.Mobile")
            val stopMethod = mobileClass.getMethod("stopServer")
            stopMethod.invoke(null)
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

/**
 * Reenviador TCP bidireccional nativo en Android.
 * Permite que clientes de la red LAN (como una Smart TV o PC) se conecten al puerto
 * público 43311 aun cuando el backend Go de seanime.aar esté limitado al loopback 127.0.0.1.
 */
class LanTcpForwarder(private val listenPort: Int, private val targetPort: Int) {
    private var serverSocket: ServerSocket? = null
    private val executor = Executors.newCachedThreadPool()
    private val isRunning = AtomicBoolean(false)

    fun start() {
        if (!isRunning.compareAndSet(false, true)) return
        Thread {
            try {
                val ss = ServerSocket()
                ss.reuseAddress = true
                ss.bind(InetSocketAddress("0.0.0.0", listenPort))
                serverSocket = ss
                Log.i("LanTcpForwarder", "Listening on 0.0.0.0:$listenPort forwarding to 127.0.0.1:$targetPort")
                while (isRunning.get()) {
                    val clientSocket = ss.accept()
                    executor.submit { handleClient(clientSocket) }
                }
            } catch (e: Exception) {
                if (isRunning.get()) {
                    Log.e("LanTcpForwarder", "Forwarder error: ${e.message}")
                }
            }
        }.apply {
            name = "LanForwarderThread"
            isDaemon = true
            start()
        }
    }

    private fun handleClient(clientSocket: Socket) {
        try {
            clientSocket.tcpNoDelay = true
            val targetSocket = Socket("127.0.0.1", targetPort)
            targetSocket.tcpNoDelay = true

            executor.submit { pipe(clientSocket.getInputStream(), targetSocket.getOutputStream(), clientSocket, targetSocket) }
            executor.submit { pipe(targetSocket.getInputStream(), clientSocket.getOutputStream(), targetSocket, clientSocket) }
        } catch (e: Exception) {
            runCatching { clientSocket.close() }
        }
    }

    private fun pipe(input: InputStream, output: OutputStream, s1: Socket, s2: Socket) {
        try {
            val buffer = ByteArray(32768)
            var bytesRead: Int
            while (input.read(buffer).also { bytesRead = it } != -1) {
                output.write(buffer, 0, bytesRead)
                output.flush()
            }
        } catch (_: Exception) {} finally {
            runCatching { s1.close() }
            runCatching { s2.close() }
        }
    }

    fun stop() {
        isRunning.set(false)
        runCatching { serverSocket?.close() }
        serverSocket = null
        executor.shutdownNow()
    }
}
