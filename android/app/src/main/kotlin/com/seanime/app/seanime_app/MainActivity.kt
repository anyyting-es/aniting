package com.seanime.app.seanime_app

import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.view.Display
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.android.RenderMode
import io.flutter.embedding.android.TransparencyMode
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.seanime.app/server"

    override fun getRenderMode(): RenderMode = RenderMode.texture

    override fun getTransparencyMode(): TransparencyMode = TransparencyMode.transparent

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableHighRefreshRate()
    }

    override fun onResume() {
        super.onResume()
        enableHighRefreshRate()
    }

    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        if (hasFocus) {
            enableHighRefreshRate()
        }
    }

    private fun enableHighRefreshRate() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            try {
                val win = window ?: return
                val currentDisplay = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                    display
                } else {
                    @Suppress("DEPRECATION")
                    windowManager.defaultDisplay
                } ?: return

                val modes = currentDisplay.supportedModes ?: return
                var maxMode: Display.Mode? = null
                var maxRate = 0.0f
                for (mode in modes) {
                    if (mode.refreshRate > maxRate) {
                        maxRate = mode.refreshRate
                        maxMode = mode
                    }
                }
                if (maxMode != null && maxRate > 60.0f) {
                    val params = win.attributes
                    params.preferredDisplayModeId = maxMode.modeId
                    win.attributes = params
                }
            } catch (_: Throwable) {}
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        flutterEngine.plugins.add(ExoPlayerPlugin())

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startServer" -> {
                    val port = call.argument<Int>("port") ?: SeanimeServerRuntime.defaultPort
                    val status = SeanimeServerRuntime.start(applicationContext, port)
                    result.success(status)
                }
                "stopServer" -> {
                    val status = SeanimeServerRuntime.stop(applicationContext)
                    result.success(status)
                }
                "getStatus" -> {
                    val status = SeanimeServerRuntime.status(applicationContext)
                    result.success(status)
                }
                "getDataDir" -> {
                    result.success(SeanimeServerRuntime.dataDir(applicationContext).absolutePath)
                }
                "readConfig" -> {
                    result.success(SeanimeServerRuntime.readConfig(applicationContext))
                }
                "writeConfig" -> {
                    val content = call.argument<String>("content") ?: ""
                    result.success(SeanimeServerRuntime.writeConfig(applicationContext, content))
                }
                "resetConfig" -> {
                    result.success(SeanimeServerRuntime.resetConfig(applicationContext))
                }
                "isBatteryOptimizationIgnored" -> {
                    result.success(SeanimeServerRuntime.isBatteryOptimizationIgnored(applicationContext))
                }
                "requestIgnoreBatteryOptimization" -> {
                    result.success(SeanimeServerRuntime.requestIgnoreBatteryOptimization(applicationContext))
                }
                "isManageStorageGranted" -> {
                    result.success(SeanimeServerRuntime.isManageStorageGranted())
                }
                "requestManageStorage" -> {
                    result.success(SeanimeServerRuntime.requestManageStorage(applicationContext))
                }
                else -> result.notImplemented()
            }
        }
    }
}
