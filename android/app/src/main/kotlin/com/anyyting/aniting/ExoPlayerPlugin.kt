package com.anyyting.aniting

import android.app.Activity
import android.content.Context
import android.media.audiofx.LoudnessEnhancer
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.SurfaceView
import android.view.View
import android.view.ViewGroup
import android.view.ViewTreeObserver
import android.widget.FrameLayout
import androidx.annotation.OptIn
import androidx.media3.common.AudioAttributes
import androidx.media3.common.C
import androidx.media3.common.MediaItem
import androidx.media3.common.MimeTypes
import androidx.media3.common.PlaybackException
import androidx.media3.common.PlaybackParameters
import androidx.media3.common.Player
import androidx.media3.common.TrackGroup
import androidx.media3.common.TrackSelectionOverride
import androidx.media3.common.Tracks
import androidx.media3.common.VideoSize
import androidx.media3.common.text.CueGroup
import androidx.media3.common.util.UnstableApi
import android.graphics.Color
import android.graphics.Typeface
import androidx.media3.ui.CaptionStyleCompat
import androidx.media3.ui.SubtitleView
import androidx.media3.datasource.DataSource
import androidx.media3.datasource.DefaultDataSource
import androidx.media3.datasource.DefaultHttpDataSource
import androidx.media3.exoplayer.DefaultLoadControl
import androidx.media3.exoplayer.DefaultRenderersFactory
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.exoplayer.SeekParameters
import androidx.media3.exoplayer.hls.DefaultHlsExtractorFactory
import androidx.media3.exoplayer.hls.HlsMediaSource
import androidx.media3.exoplayer.source.DefaultMediaSourceFactory
import androidx.media3.exoplayer.source.MediaSource
import androidx.media3.exoplayer.source.MergingMediaSource
import androidx.media3.exoplayer.source.SingleSampleMediaSource
import androidx.media3.exoplayer.trackselection.DefaultTrackSelector
import androidx.media3.extractor.DefaultExtractorsFactory
import androidx.media3.extractor.ExtractorsFactory
import androidx.media3.extractor.mkv.MatroskaExtractor
import com.edde746.plezy.libass.media.AssHandler
import com.edde746.plezy.libass.media.extractor.AssMatroskaExtractor
import com.edde746.plezy.libass.media.parser.AssSubtitleParserFactory
import com.edde746.plezy.libass.media.widget.AssSubtitleSurfaceView
import com.anyyting.aniting.exoplayer.CuelessSeekExtractorWrapper
import com.anyyting.aniting.exoplayer.LoadControlPolicy
import com.anyyting.aniting.exoplayer.ObservingLoadControl
import com.anyyting.aniting.exoplayer.PgsSubtitleParserFactory
import com.anyyting.aniting.exoplayer.PlezyRenderersFactory
import com.anyyting.aniting.exoplayer.VideoDecoderRecoveryPolicy
import com.anyyting.aniting.exoplayer.ZlibMatroskaExtractor
import android.app.ActivityManager
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

@OptIn(UnstableApi::class)
class ExoPlayerPlugin :
    FlutterPlugin,
    MethodChannel.MethodCallHandler,
    EventChannel.StreamHandler,
    ActivityAware,
    Player.Listener {

    companion object {
        private const val TAG = "ExoPlayerPlugin"
        private const val METHOD_CHANNEL = "com.anyyting.aniting/exo_player"
        private const val EVENT_CHANNEL = "com.anyyting.aniting/exo_player/events"

        init {
            try {
                System.loadLibrary("asskt")
                Log.i(TAG, "Successfully loaded libasskt.so")
            } catch (e: Throwable) {
                Log.w(TAG, "Could not load libasskt.so: ${e.message}")
            }
        }
    }

    private var activity: Activity? = null
    private var methodChannel: MethodChannel? = null
    private var eventChannel: EventChannel? = null
    private var eventSink: EventChannel.EventSink? = null

    private val mainHandler = Handler(Looper.getMainLooper())
    private var exoPlayer: ExoPlayer? = null
    private var trackSelector: DefaultTrackSelector? = null
    private var assHandler: AssHandler? = null
    private var loudnessEnhancer: LoudnessEnhancer? = null

    private var surfaceContainer: FrameLayout? = null
    private var videoSurfaceView: SurfaceView? = null
    private var assSubtitleView: AssSubtitleSurfaceView? = null
    private var standardSubtitleView: SubtitleView? = null

    private var positionPollRunnable: Runnable? = null
    private var isDisposed = false

    private var lastUri: Uri? = null
    private var lastDataSourceFactory: DataSource.Factory? = null
    private var lastStartPositionMs: Long = 0L
    private var attemptedHlsFallback: Boolean = false
    private var videoDecoderRecoveryAttempts: Int = 0
    private var hasRenderedFirstFrame: Boolean = false
    private var lastChapters: List<Map<String, Any?>> = emptyList()

    private var lastVideoWidth: Int = 0
    private var lastVideoHeight: Int = 0
    private var lastPixelWidthHeightRatio: Float = 1.0f
    private var currentFitMode: String = "contain"
    private var containerLayoutChangeListener: View.OnLayoutChangeListener? = null

    private data class TrackRef(val trackGroup: TrackGroup, val trackIndex: Int)
    private val audioTrackRefs = mutableListOf<TrackRef>()
    private val subtitleTrackRefs = mutableListOf<TrackRef>()
    private var isCurrentSubAss: Boolean = false
    private var subtitleDelayMs: Long = 0L

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel = MethodChannel(binding.binaryMessenger, METHOD_CHANNEL).apply {
            setMethodCallHandler(this@ExoPlayerPlugin)
        }
        eventChannel = EventChannel(binding.binaryMessenger, EVENT_CHANNEL).apply {
            setStreamHandler(this@ExoPlayerPlugin)
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel?.setMethodCallHandler(null)
        methodChannel = null
        eventChannel?.setStreamHandler(null)
        eventChannel = null
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivityForConfigChanges() {
        // Retain state across configuration changes
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivity() {
        teardown()
        activity = null
    }

    // EventChannel.StreamHandler
    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }

    // MethodChannel.MethodCallHandler
    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "initialize" -> {
                val top = (call.argument<Number>("top"))?.toInt() ?: 0
                val height = (call.argument<Number>("height"))?.toInt() ?: -1
                ensureInitialized(top, height)
                result.success(true)
            }
            "open" -> {
                val uri = call.argument<String>("uri") ?: ""
                val headers = call.argument<Map<String, String>>("headers")
                val mimeType = call.argument<String>("mimeType")
                val startPositionMs = (call.argument<Number>("startPositionMs"))?.toLong() ?: 0L
                val autoPlay = call.argument<Boolean>("autoPlay") ?: true
                val subtitles = call.argument<List<Map<String, Any?>>>("subtitles")
                openMedia(uri, headers, mimeType, startPositionMs, autoPlay, subtitles, result)
            }
            "play" -> {
                exoPlayer?.play()
                result.success(null)
            }
            "pause" -> {
                exoPlayer?.pause()
                assSubtitleView?.invalidateSubtitles()
                result.success(null)
            }
            "stop" -> {
                exoPlayer?.stop()
                result.success(null)
            }
            "seek" -> {
                val positionMs = (call.argument<Number>("positionMs"))?.toLong() ?: 0L
                exoPlayer?.seekTo(positionMs)
                assSubtitleView?.invalidateSubtitles()
                result.success(null)
            }
            "getChapters" -> {
                result.success(lastChapters)
            }
            "setSubtitleDelay" -> {
                subtitleDelayMs = (call.argument<Number>("delayMs"))?.toLong() ?: 0L
                assSubtitleView?.invalidateSubtitles()
                result.success(null)
            }
            "setVolume" -> {
                val volume = (call.argument<Number>("volume"))?.toFloat() ?: 1.0f
                applyVolume(volume)
                result.success(null)
            }
            "setRate" -> {
                val rate = (call.argument<Number>("rate"))?.toFloat() ?: 1.0f
                exoPlayer?.playbackParameters = PlaybackParameters(rate)
                result.success(null)
            }
            "selectAudioTrack" -> {
                val index = call.argument<Int>("index") ?: -1
                selectTrack(C.TRACK_TYPE_AUDIO, index)
                result.success(null)
            }
            "selectSubtitleTrack" -> {
                val index = call.argument<Int>("index") ?: -1
                selectTrack(C.TRACK_TYPE_TEXT, index)
                result.success(null)
            }
            "setSubtitleStyle" -> {
                val fontFamily = call.argument<String>("fontFamily") ?: "sans-serif"
                val fontSizeMultiplier = (call.argument<Number>("fontSizeMultiplier"))?.toFloat() ?: 1.0f
                val bold = call.argument<Boolean>("bold") ?: true
                val italic = call.argument<Boolean>("italic") ?: false
                val textColor = (call.argument<Number>("textColor"))?.toInt() ?: Color.WHITE
                val backgroundColor = (call.argument<Number>("backgroundColor"))?.toInt() ?: Color.TRANSPARENT
                val borderStyle = call.argument<String>("borderStyle") ?: "outline"
                val borderColor = (call.argument<Number>("borderColor"))?.toInt() ?: Color.BLACK
                val borderSize = (call.argument<Number>("borderSize"))?.toFloat() ?: 3.0f
                val overrideAss = call.argument<Boolean>("overrideAss") ?: false

                applySubtitleStyle(
                    fontFamily,
                    fontSizeMultiplier,
                    bold,
                    italic,
                    textColor,
                    backgroundColor,
                    borderStyle,
                    borderColor,
                    borderSize,
                    overrideAss
                )
                result.success(null)
            }
            "setVisible" -> {
                val visible = call.argument<Boolean>("visible") ?: true
                surfaceContainer?.visibility = if (visible) View.VISIBLE else View.GONE
                result.success(null)
            }
            "setBrightness" -> {
                val brightness = (call.argument<Number>("brightness"))?.toFloat() ?: -1.0f
                val act = activity
                if (act != null) {
                    act.runOnUiThread {
                        val lp = act.window.attributes
                        lp.screenBrightness = if (brightness < 0f) {
                            android.view.WindowManager.LayoutParams.BRIGHTNESS_OVERRIDE_NONE
                        } else {
                            brightness.coerceIn(0.01f, 1.0f)
                        }
                        act.window.attributes = lp
                    }
                }
                result.success(null)
            }
            "getBrightness" -> {
                val act = activity
                if (act != null) {
                    val lp = act.window.attributes
                    val cur = if (lp.screenBrightness >= 0f) {
                        lp.screenBrightness
                    } else {
                        try {
                            android.provider.Settings.System.getInt(
                                act.contentResolver,
                                android.provider.Settings.System.SCREEN_BRIGHTNESS
                            ) / 255f
                        } catch (_: Exception) {
                            0.5f
                        }
                    }
                    result.success(cur.toDouble())
                } else {
                    result.success(0.5)
                }
            }
            "setSurfaceBounds" -> {
                val top = (call.argument<Number>("top"))?.toInt() ?: 0
                val height = (call.argument<Number>("height"))?.toInt() ?: -1
                val act = activity
                if (act != null) {
                    act.runOnUiThread {
                        val container = surfaceContainer
                        if (container != null) {
                            val lp = container.layoutParams as? FrameLayout.LayoutParams
                            if (lp != null) {
                                if (height > 0) {
                                    lp.topMargin = top
                                    lp.height = height
                                    lp.width = FrameLayout.LayoutParams.MATCH_PARENT
                                    lp.gravity = android.view.Gravity.TOP
                                } else {
                                    lp.topMargin = 0
                                    lp.height = FrameLayout.LayoutParams.MATCH_PARENT
                                    lp.width = FrameLayout.LayoutParams.MATCH_PARENT
                                    lp.gravity = android.view.Gravity.FILL
                                }
                                container.layoutParams = lp
                                container.requestLayout()
                            }
                            val surface = videoSurfaceView
                            if (surface != null && lastVideoWidth > 0 && lastVideoHeight > 0) {
                                fitSurface(container, surface, lastVideoWidth, lastVideoHeight, lastPixelWidthHeightRatio)
                            }
                            // Post surface refit after container layout pass as secondary stabilization
                            container.post {
                                val surf = videoSurfaceView
                                if (surf != null && lastVideoWidth > 0 && lastVideoHeight > 0) {
                                    fitSurface(container, surf, lastVideoWidth, lastVideoHeight, lastPixelWidthHeightRatio)
                                }
                            }
                        }
                    }
                }
                result.success(null)
            }
            "setFitMode" -> {
                val mode = call.argument<String>("mode") ?: "contain"
                currentFitMode = mode
                activity?.runOnUiThread {
                    val container = surfaceContainer
                    val surface = videoSurfaceView
                    if (container != null && surface != null && lastVideoWidth > 0 && lastVideoHeight > 0) {
                        fitSurface(container, surface, lastVideoWidth, lastVideoHeight, lastPixelWidthHeightRatio)
                    }
                }
                result.success(null)
            }
            "dispose" -> {
                teardown()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun ensureInitialized(initialTop: Int = 0, initialHeight: Int = -1) {
        if (exoPlayer != null) {
            // Player already initialized: only update bounds if an explicit positive height is provided.
            // Never reset to MATCH_PARENT when openMedia calls ensureInitialized() with default parameters.
            if (initialHeight > 0) {
                surfaceContainer?.let { container ->
                    val lp = container.layoutParams as? FrameLayout.LayoutParams
                    if (lp != null) {
                        lp.topMargin = initialTop
                        lp.height = initialHeight
                        lp.width = FrameLayout.LayoutParams.MATCH_PARENT
                        lp.gravity = android.view.Gravity.TOP
                        container.layoutParams = lp
                        container.requestLayout()
                        videoSurfaceView?.let { surf ->
                            if (lastVideoWidth > 0 && lastVideoHeight > 0) {
                                fitSurface(container, surf, lastVideoWidth, lastVideoHeight, lastPixelWidthHeightRatio)
                            }
                        }
                    }
                }
            }
            return
        }
        val currentActivity = activity ?: return

        isDisposed = false
        val selector = DefaultTrackSelector(currentActivity).apply {
            parameters = buildUponParameters()
                .setPreferredTextLanguages("es", "spa", "en", "eng")
                .setSelectUndeterminedTextLanguage(true)
                .build()
        }
        trackSelector = selector

        val handler = AssHandler().apply {
            chaptersCallback = { chs ->
                mainHandler.post {
                    lastChapters = chs
                    eventSink?.success(
                        mapOf(
                            "event" to "chapters",
                            "chapters" to chs
                        )
                    )
                }
            }
        }
        assHandler = handler

        val pgsAndAssSubtitleParserFactory = PgsSubtitleParserFactory(AssSubtitleParserFactory(handler))
        val wrappedExtractorsFactory = ExtractorsFactory {
            val defaultExtractors = DefaultExtractorsFactory()
                .setSubtitleParserFactory(pgsAndAssSubtitleParserFactory)
                .createExtractors()
            defaultExtractors.map { extractor ->
                if (extractor is MatroskaExtractor) {
                    CuelessSeekExtractorWrapper(ZlibMatroskaExtractor(pgsAndAssSubtitleParserFactory, handler))
                } else {
                    extractor
                }
            }.toTypedArray()
        }

        val renderersFactory = PlezyRenderersFactory(currentActivity).apply {
            setExtensionRendererMode(DefaultRenderersFactory.EXTENSION_RENDERER_MODE_ON)
            setEnableDecoderFallback(true)
        }

        val activityManager = currentActivity.getSystemService(Context.ACTIVITY_SERVICE) as? ActivityManager
        val memoryInfo = ActivityManager.MemoryInfo()
        activityManager?.getMemoryInfo(memoryInfo)
        val availableMB = if (memoryInfo != null && memoryInfo.availMem > 0) (memoryInfo.availMem / (1024 * 1024)).toInt() else 2048
        val largeHeapMB = activityManager?.largeMemoryClass ?: 256

        val targetBufferBytes = LoadControlPolicy.autoTargetBufferBytes(largeHeapMB, availableMB)
        val bufferDurations = LoadControlPolicy.bufferDurations(availableMB)

        val baseLoadControl = DefaultLoadControl.Builder()
            .setTargetBufferBytes(targetBufferBytes)
            .setBufferDurationsMs(
                bufferDurations.minBufferMs,
                bufferDurations.maxBufferMs,
                LoadControlPolicy.BUFFER_FOR_PLAYBACK_MS,
                LoadControlPolicy.BUFFER_FOR_PLAYBACK_AFTER_REBUFFER_MS
            )
            .setBackBuffer(15_000, true)
            .setPrioritizeTimeOverSizeThresholds(false)
            .build()
        val loadControl = ObservingLoadControl(baseLoadControl)

        val player = ExoPlayer.Builder(currentActivity)
            .setTrackSelector(selector)
            .setRenderersFactory(renderersFactory)
            .setLoadControl(loadControl)
            .setSeekParameters(SeekParameters.CLOSEST_SYNC)
            .setAudioAttributes(
                AudioAttributes.Builder()
                    .setContentType(C.AUDIO_CONTENT_TYPE_MOVIE)
                    .setUsage(C.USAGE_MEDIA)
                    .build(),
                true
            )
            .build()

        exoPlayer = player

        // Build SurfaceViews
        val container = FrameLayout(currentActivity).apply {
            val lp = if (initialHeight > 0) {
                FrameLayout.LayoutParams(
                    FrameLayout.LayoutParams.MATCH_PARENT,
                    initialHeight,
                    android.view.Gravity.TOP
                ).apply {
                    topMargin = initialTop
                }
            } else {
                FrameLayout.LayoutParams(
                    FrameLayout.LayoutParams.MATCH_PARENT,
                    FrameLayout.LayoutParams.MATCH_PARENT,
                    android.view.Gravity.FILL
                )
            }
            layoutParams = lp
            visibility = View.VISIBLE
        }
        val layoutListener = View.OnLayoutChangeListener { _, left, top, right, bottom, oldLeft, oldTop, oldRight, oldBottom ->
            val newW = right - left
            val newH = bottom - top
            val oldW = oldRight - oldLeft
            val oldH = oldBottom - oldTop
            if (newW > 0 && newH > 0 && (newW != oldW || newH != oldH)) {
                val surface = videoSurfaceView
                if (surface != null && lastVideoWidth > 0 && lastVideoHeight > 0) {
                    fitSurface(container, surface, lastVideoWidth, lastVideoHeight, lastPixelWidthHeightRatio)
                }
            }
        }
        container.addOnLayoutChangeListener(layoutListener)
        containerLayoutChangeListener = layoutListener
        surfaceContainer = container

        val videoSurface = SurfaceView(currentActivity).apply {
            layoutParams = FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT,
                android.view.Gravity.CENTER
            )
            setZOrderOnTop(false)
            setZOrderMediaOverlay(false)
            FlutterOverlayHelper.applyCompositionOrder(this, -2)
        }
        videoSurfaceView = videoSurface
        container.addView(videoSurface)

        val standardSubView = SubtitleView(currentActivity).apply {
            layoutParams = FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT
            )
            visibility = View.VISIBLE
        }
        standardSubtitleView = standardSubView
        container.addView(standardSubView)

        val assView = AssSubtitleSurfaceView(currentActivity, handler).apply {
            layoutParams = FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT
            )
            setZOrderOnTop(false)
            setZOrderMediaOverlay(true)
            FlutterOverlayHelper.applyCompositionOrder(this, -1)
        }
        assSubtitleView = assView
        container.addView(assView)

        val content = currentActivity.findViewById<ViewGroup>(android.R.id.content)
        content?.addView(container, 0) // Behind transparent Flutter view
        content?.let {
            val flutterContainer = FlutterOverlayHelper.findFlutterContainer(it, container)
            if (flutterContainer != null && it.getChildAt(it.childCount - 1) !== flutterContainer) {
                FlutterOverlayHelper.configureFlutterZOrder(it, flutterContainer, compositionOrder = 1)
            }
        }

        player.setVideoSurfaceView(videoSurface)
        handler.init(player)
        handler.videoFrameCallback = { presentationTimeUs, releaseTimeNs ->
            val delayUs = subtitleDelayMs * 1000L
            assSubtitleView?.requestRender(presentationTimeUs - delayUs, releaseTimeNs)
        }
        player.addListener(this)

        startPositionPolling()
    }

    private fun isHlsStream(uri: Uri, uriString: String, mimeType: String?): Boolean {
        if (mimeType == MimeTypes.APPLICATION_M3U8 ||
            mimeType?.contains("mpegurl", ignoreCase = true) == true ||
            mimeType?.contains("m3u8", ignoreCase = true) == true) {
            return true
        }
        val path = uri.path?.lowercase() ?: ""
        if (path.endsWith(".m3u8") || path.endsWith(".m3u")) return true
        val lower = uriString.lowercase()
        return lower.contains(".m3u8") ||
               lower.contains("/segs/") ||
               lower.contains("/hls/") ||
               lower.contains("master.m3u8")
    }

    private fun openMedia(
        uriString: String,
        headers: Map<String, String>?,
        mimeType: String?,
        startPositionMs: Long,
        autoPlay: Boolean,
        subtitles: List<Map<String, Any?>>?,
        result: MethodChannel.Result
    ) {
        val currentActivity = activity ?: run {
            result.error("NO_ACTIVITY", "Activity not attached", null)
            return
        }
        ensureInitialized()
        val player = exoPlayer ?: run {
            result.error("NO_PLAYER", "ExoPlayer not initialized", null)
            return
        }

        try {
            val uri = Uri.parse(uriString)
            val isTorrent = uriString.contains("torrentstream", ignoreCase = true) ||
                uriString.contains("/torrent", ignoreCase = true)
            val connectTimeout = if (isTorrent) 60_000 else 15_000
            val readTimeout = if (isTorrent) 60_000 else 15_000

            val httpFactory = DefaultHttpDataSource.Factory()
                .setConnectTimeoutMs(connectTimeout)
                .setReadTimeoutMs(readTimeout)
                .setKeepPostFor302Redirects(true)
                .setAllowCrossProtocolRedirects(true)
                .setUserAgent("SeanimeApp/1.0 (Android; ExoPlayer+libass)")

            if (!headers.isNullOrEmpty()) {
                val reqHeaders = mutableMapOf<String, String>()
                for ((k, v) in headers) {
                    if (k.equals("User-Agent", ignoreCase = true)) {
                        httpFactory.setUserAgent(v)
                    } else {
                        reqHeaders[k] = v
                    }
                }
                if (reqHeaders.isNotEmpty()) {
                    httpFactory.setDefaultRequestProperties(reqHeaders)
                }
            }

            val dataSourceFactory = DefaultDataSource.Factory(currentActivity, httpFactory)
            val handler = (assHandler ?: AssHandler().also { assHandler = it }).apply {
                chaptersCallback = { chs ->
                    mainHandler.post {
                        lastChapters = chs
                        eventSink?.success(
                            mapOf(
                                "event" to "chapters",
                                "chapters" to chs
                            )
                        )
                    }
                }
            }
            lastChapters = emptyList()
            val subtitleParserFactory = PgsSubtitleParserFactory(AssSubtitleParserFactory(handler))
            val extractorsFactory = ExtractorsFactory {
                val def = DefaultExtractorsFactory()
                    .setSubtitleParserFactory(subtitleParserFactory)
                    .createExtractors()
                def.map { ext ->
                    if (ext is MatroskaExtractor) {
                        CuelessSeekExtractorWrapper(ZlibMatroskaExtractor(subtitleParserFactory, handler))
                    } else {
                        ext
                    }
                }.toTypedArray()
            }

            // Build external subtitle media sources if provided
            val subMediaSources = mutableListOf<MediaSource>()
            if (!subtitles.isNullOrEmpty()) {
                val singleSampleFactory = SingleSampleMediaSource.Factory(dataSourceFactory)
                for (sub in subtitles) {
                    val subUrl = sub["url"] as? String ?: continue
                    val subUri = Uri.parse(subUrl)
                    val lang = sub["language"] as? String
                    val label = (sub["label"] as? String)?.takeIf { it.isNotBlank() } ?: lang ?: "Subtítulo"
                    val isDefault = (sub["isDefault"] as? Boolean) == true

                    val subMimeType = when {
                        subUrl.contains(".vtt", ignoreCase = true) -> MimeTypes.TEXT_VTT
                        subUrl.contains(".srt", ignoreCase = true) -> MimeTypes.APPLICATION_SUBRIP
                        subUrl.contains(".ass", ignoreCase = true) || subUrl.contains(".ssa", ignoreCase = true) -> MimeTypes.TEXT_SSA
                        else -> MimeTypes.TEXT_VTT
                    }

                    val subConfig = MediaItem.SubtitleConfiguration.Builder(subUri)
                        .setMimeType(subMimeType)
                        .setLanguage(lang)
                        .setLabel(label)
                        .setSelectionFlags(if (isDefault) C.SELECTION_FLAG_DEFAULT else 0)
                        .build()

                    try {
                        val subSource = singleSampleFactory.createMediaSource(subConfig, C.TIME_UNSET)
                        subMediaSources.add(subSource)
                    } catch (e: Exception) {
                        Log.w(TAG, "Failed to create MediaSource for external subtitle: $subUrl", e)
                    }
                }
            }

            val isHls = isHlsStream(uri, uriString, mimeType)
            val primarySource: MediaSource = if (isHls) {
                val mediaItem = MediaItem.Builder()
                    .setUri(uri)
                    .setMimeType(MimeTypes.APPLICATION_M3U8)
                    .build()
                val hlsExtractorFactory = DefaultHlsExtractorFactory()
                    .setSubtitleParserFactory(subtitleParserFactory)
                HlsMediaSource.Factory(dataSourceFactory)
                    .setExtractorFactory(hlsExtractorFactory)
                    .setAllowChunklessPreparation(false)
                    .createMediaSource(mediaItem)
            } else {
                val mediaSourceFactory = DefaultMediaSourceFactory(dataSourceFactory, extractorsFactory)
                    .setSubtitleParserFactory(subtitleParserFactory)
                if (isTorrent) {
                    mediaSourceFactory.setLoadErrorHandlingPolicy(
                        androidx.media3.exoplayer.upstream.DefaultLoadErrorHandlingPolicy(6)
                    )
                }
                val mediaItem = MediaItem.fromUri(uri)
                mediaSourceFactory.createMediaSource(mediaItem)
            }

            val finalSource: MediaSource = if (subMediaSources.isNotEmpty()) {
                MergingMediaSource(primarySource, *subMediaSources.toTypedArray())
            } else {
                primarySource
            }

            lastUri = uri
            lastDataSourceFactory = dataSourceFactory
            lastStartPositionMs = startPositionMs
            attemptedHlsFallback = isHls
            videoDecoderRecoveryAttempts = 0
            hasRenderedFirstFrame = false

            // Reset track selector text parameters so text isn't disabled from previous playback
            trackSelector?.let { sel ->
                val builder = sel.parameters.buildUpon()
                builder.setTrackTypeDisabled(C.TRACK_TYPE_TEXT, false)
                builder.clearOverridesOfType(C.TRACK_TYPE_TEXT)
                sel.parameters = builder.build()
            }

            surfaceContainer?.visibility = View.VISIBLE
            player.setMediaSource(finalSource)
            player.prepare()

            if (startPositionMs > 0) {
                player.seekTo(startPositionMs)
            }
            player.playWhenReady = autoPlay

            result.success(true)
        } catch (e: Exception) {
            Log.e(TAG, "Error opening media: ${e.message}", e)
            result.error("OPEN_FAILED", e.message, null)
        }
    }

    private fun selectTrack(trackType: @C.TrackType Int, index: Int) {
        val player = exoPlayer ?: return
        val selector = trackSelector ?: return

        val refs = if (trackType == C.TRACK_TYPE_AUDIO) audioTrackRefs else subtitleTrackRefs

        if (index < 0) {
            // Explicitly disable track
            val builder = selector.parameters.buildUpon()
            builder.setTrackTypeDisabled(trackType, true)
            builder.clearOverridesOfType(trackType)
            selector.parameters = builder.build()
            if (trackType == C.TRACK_TYPE_TEXT) {
                isCurrentSubAss = false
                mainHandler.post {
                    standardSubtitleView?.setCues(emptyList())
                    assSubtitleView?.invalidateSubtitles()
                    eventSink?.success(
                        mapOf(
                            "event" to "cues",
                            "text" to ""
                        )
                    )
                }
            }
            return
        }

        if (index >= refs.size) {
            // Track refs not ready yet (e.g. called before onTracksChanged); do NOT disable
            Log.w(TAG, "selectTrack: index $index out of bounds (size ${refs.size}), ignoring without disabling")
            return
        }

        val targetRef = refs[index]
        val builder = selector.parameters.buildUpon()
        builder.setTrackTypeDisabled(trackType, false)
        builder.clearOverridesOfType(trackType)
        builder.addOverride(TrackSelectionOverride(targetRef.trackGroup, targetRef.trackIndex))
        selector.parameters = builder.build()

        if (trackType == C.TRACK_TYPE_TEXT) {
            mainHandler.post {
                updateCurrentSubtitleType()
                assSubtitleView?.invalidateSubtitles()
            }
        }
    }

    private fun isAssSubtitleFormat(fmt: androidx.media3.common.Format): Boolean {
        return fmt.sampleMimeType == MimeTypes.TEXT_SSA ||
            fmt.codecs == MimeTypes.TEXT_SSA ||
            fmt.sampleMimeType?.contains("ssa", ignoreCase = true) == true ||
            fmt.codecs?.contains("ssa", ignoreCase = true) == true ||
            fmt.sampleMimeType?.contains("ass", ignoreCase = true) == true ||
            fmt.codecs?.contains("ass", ignoreCase = true) == true ||
            fmt.id?.contains("ass", ignoreCase = true) == true ||
            fmt.id?.contains("ssa", ignoreCase = true) == true
    }

    private fun updateCurrentSubtitleType() {
        val player = exoPlayer ?: return
        val currentTracks = player.currentTracks
        var assActive = false
        for (group in currentTracks.groups) {
            if (group.type == C.TRACK_TYPE_TEXT && group.isSelected) {
                for (i in 0 until group.length) {
                    if (group.isTrackSelected(i)) {
                        val fmt = group.getTrackFormat(i)
                        if (isAssSubtitleFormat(fmt)) {
                            assActive = true
                            break
                        }
                    }
                }
            }
        }
        isCurrentSubAss = assActive
        if (assActive) {
            mainHandler.post {
                standardSubtitleView?.setCues(emptyList())
                eventSink?.success(
                    mapOf(
                        "event" to "cues",
                        "text" to ""
                    )
                )
            }
        }
    }

    private fun startPositionPolling() {
        positionPollRunnable?.let { mainHandler.removeCallbacks(it) }
        val poll = object : Runnable {
            override fun run() {
                if (isDisposed) return
                val player = exoPlayer
                if (player != null && player.playbackState != Player.STATE_IDLE) {
                    val pos = player.currentPosition
                    val dur = player.duration
                    val buf = player.bufferedPosition
                    eventSink?.success(
                        mapOf(
                            "event" to "position",
                            "position" to pos,
                            "duration" to (if (dur > 0) dur else 0L),
                            "buffer" to buf
                        )
                    )
                }
                mainHandler.postDelayed(this, 350)
            }
        }
        positionPollRunnable = poll
        mainHandler.post(poll)
    }

    // Player.Listener Callbacks
    override fun onPlaybackStateChanged(playbackState: Int) {
        val isBuffering = playbackState == Player.STATE_BUFFERING
        val isEnded = playbackState == Player.STATE_ENDED
        eventSink?.success(mapOf("event" to "buffering", "value" to isBuffering))
        if (isEnded) {
            eventSink?.success(mapOf("event" to "ended"))
        }
    }

    override fun onIsPlayingChanged(isPlaying: Boolean) {
        eventSink?.success(mapOf("event" to "playing", "value" to isPlaying))
    }

    override fun onVideoSizeChanged(videoSize: VideoSize) {
        if (videoSize.width > 0 && videoSize.height > 0) {
            lastVideoWidth = videoSize.width
            lastVideoHeight = videoSize.height
            lastPixelWidthHeightRatio = if (videoSize.pixelWidthHeightRatio > 0f) videoSize.pixelWidthHeightRatio else 1.0f

            mainHandler.post {
                eventSink?.success(
                    mapOf(
                        "event" to "videoSize",
                        "width" to videoSize.width,
                        "height" to videoSize.height
                    )
                )
                // Resize SurfaceView to maintain video aspect ratio (contain / letterbox)
                applySurfaceAspectRatio(lastVideoWidth, lastVideoHeight, lastPixelWidthHeightRatio)
            }
        }
    }

    override fun onCues(cueGroup: CueGroup) {
        if (isCurrentSubAss) {
            mainHandler.post {
                eventSink?.success(
                    mapOf(
                        "event" to "cues",
                        "text" to ""
                    )
                )
            }
            return
        }
        val text = cueGroup.cues
            .mapNotNull { it.text?.toString() }
            .filter { it.isNotBlank() }
            .joinToString("\n")
        mainHandler.post {
            eventSink?.success(
                mapOf(
                    "event" to "cues",
                    "text" to text
                )
            )
        }
    }

    private fun applySubtitleStyle(
        fontFamily: String,
        fontSizeMultiplier: Float,
        bold: Boolean,
        italic: Boolean,
        textColor: Int,
        backgroundColor: Int,
        borderStyle: String,
        borderColor: Int,
        borderSize: Float,
        overrideAss: Boolean
    ) {
        val edgeType = when (borderStyle) {
            "none" -> CaptionStyleCompat.EDGE_TYPE_NONE
            "outline" -> CaptionStyleCompat.EDGE_TYPE_OUTLINE
            "dropShadow" -> CaptionStyleCompat.EDGE_TYPE_DROP_SHADOW
            "raised" -> CaptionStyleCompat.EDGE_TYPE_RAISED
            "depressed" -> CaptionStyleCompat.EDGE_TYPE_DEPRESSED
            else -> CaptionStyleCompat.EDGE_TYPE_OUTLINE
        }

        val typefaceStyle = when {
            bold && italic -> Typeface.BOLD_ITALIC
            bold -> Typeface.BOLD
            italic -> Typeface.ITALIC
            else -> Typeface.NORMAL
        }

        val baseTypeface = when (fontFamily.lowercase()) {
            "serif" -> Typeface.SERIF
            "monospace" -> Typeface.MONOSPACE
            else -> Typeface.SANS_SERIF
        }
        val customTypeface = Typeface.create(baseTypeface, typefaceStyle)

        val customStyle = CaptionStyleCompat(
            textColor,
            backgroundColor,
            Color.TRANSPARENT,
            edgeType,
            borderColor,
            customTypeface
        )

        mainHandler.post {
            standardSubtitleView?.setStyle(customStyle)
            val fraction = (38f * fontSizeMultiplier) / 720f
            standardSubtitleView?.setFractionalTextSize(fraction)
            standardSubtitleView?.setBottomPaddingFraction(0.05f)
        }
    }

    /**
     * Resizes the video SurfaceView to fit within the container while preserving
     * the original video aspect ratio (letterbox / pillarbox) or fitting mode.
     */
    private fun applySurfaceAspectRatio(videoWidth: Int, videoHeight: Int, pixelWidthHeightRatio: Float) {
        val container = surfaceContainer ?: return
        val surface = videoSurfaceView ?: return

        val lp = container.layoutParams as? FrameLayout.LayoutParams
        // Call fitSurface immediately if dimensions are available or explicit in LayoutParams
        fitSurface(container, surface, videoWidth, videoHeight, pixelWidthHeightRatio)
        if (container.width <= 0 || container.height <= 0) {
            container.post {
                fitSurface(container, surface, videoWidth, videoHeight, pixelWidthHeightRatio)
            }
        }
    }

    private fun fitSurface(
        container: FrameLayout,
        surface: SurfaceView,
        videoWidth: Int,
        videoHeight: Int,
        pixelWidthHeightRatio: Float
    ) {
        val containerLp = container.layoutParams as? FrameLayout.LayoutParams
        val displayMetrics = container.context.resources.displayMetrics
        val containerW = if (container.width > 0) {
            container.width.toFloat()
        } else if (containerLp != null && containerLp.width > 0) {
            containerLp.width.toFloat()
        } else {
            displayMetrics.widthPixels.toFloat()
        }
        val containerH = if (containerLp != null && containerLp.height > 0) {
            containerLp.height.toFloat()
        } else if (container.height > 0) {
            container.height.toFloat()
        } else {
            displayMetrics.heightPixels.toFloat()
        }
        if (containerW <= 0f || containerH <= 0f) return

        if (videoWidth <= 0 || videoHeight <= 0) {
            val emptySurfaceLp = FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT,
                android.view.Gravity.CENTER
            )
            surface.layoutParams = emptySurfaceLp
            assSubtitleView?.layoutParams = FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT
            )
            standardSubtitleView?.layoutParams = FrameLayout.LayoutParams(emptySurfaceLp).apply {
                gravity = android.view.Gravity.CENTER
            }
            assHandler?.setMargins(0, 0, 0, 0)
            assSubtitleView?.invalidateSubtitles()
            return
        }

        val pixelRatio = if (pixelWidthHeightRatio > 0f) pixelWidthHeightRatio else 1.0f
        val effectiveVideoWidth = (videoWidth * pixelRatio).coerceAtLeast(1f)
        val effectiveVideoHeight = videoHeight.toFloat().coerceAtLeast(1f)
        val videoAspect = effectiveVideoWidth / effectiveVideoHeight
        val containerAspect = containerW / containerH

        val targetW: Int
        val targetH: Int

        when (currentFitMode) {
            "fill" -> {
                targetW = containerW.toInt()
                targetH = containerH.toInt()
            }
            "cover" -> {
                if (videoAspect > containerAspect) {
                    targetH = containerH.toInt()
                    targetW = (containerH * videoAspect).toInt()
                } else {
                    targetW = containerW.toInt()
                    targetH = (containerW / videoAspect).toInt()
                }
            }
            else -> { // "contain"
                if (videoAspect > containerAspect) {
                    // Video is wider — fit to width, pillarbox vertically
                    targetW = containerW.toInt()
                    targetH = (containerW / videoAspect).toInt()
                } else {
                    // Video is taller — fit to height, letterbox horizontally
                    targetH = containerH.toInt()
                    targetW = (containerH * videoAspect).toInt()
                }
            }
        }

        val surfaceLp = FrameLayout.LayoutParams(
            targetW,
            targetH,
            android.view.Gravity.CENTER
        )
        surface.layoutParams = surfaceLp

        // assSubtitleView MUST stay MATCH_PARENT full-screen to prevent BLASTBufferQueue resizing rejections!
        // Video destination margins are passed to libass via assHandler.setMargins() matching Plezy.
        val leftMargin = ((containerW - targetW) / 2).toInt().coerceAtLeast(0)
        val topMargin = ((containerH - targetH) / 2).toInt().coerceAtLeast(0)
        val rightMargin = (containerW - targetW - leftMargin).toInt().coerceAtLeast(0)
        val bottomMargin = (containerH - targetH - topMargin).toInt().coerceAtLeast(0)

        assSubtitleView?.layoutParams = FrameLayout.LayoutParams(
            FrameLayout.LayoutParams.MATCH_PARENT,
            FrameLayout.LayoutParams.MATCH_PARENT
        )
        assHandler?.setMargins(topMargin, bottomMargin, leftMargin, rightMargin)
        assSubtitleView?.invalidateSubtitles()

        standardSubtitleView?.layoutParams = FrameLayout.LayoutParams(surfaceLp).apply {
            gravity = android.view.Gravity.CENTER
        }
    }

    private fun getReadableLanguage(lang: String?): String? {
        if (lang.isNullOrBlank()) return null
        val trimmed = lang.trim()
        val esLocale = java.util.Locale("es")

        try {
            val loc = java.util.Locale.forLanguageTag(trimmed)
            val name = loc.getDisplayLanguage(esLocale)
            if (!name.isNullOrBlank() && !name.equals(trimmed, ignoreCase = true)) {
                return name.replaceFirstChar { it.uppercase() }
            }
        } catch (_: Exception) {}

        try {
            val loc = java.util.Locale(trimmed)
            val name = loc.getDisplayLanguage(esLocale)
            if (!name.isNullOrBlank() && !name.equals(trimmed, ignoreCase = true)) {
                return name.replaceFirstChar { it.uppercase() }
            }
        } catch (_: Exception) {}

        return trimmed.uppercase()
    }

    override fun onTracksChanged(tracks: Tracks) {
        val audioList = mutableListOf<Map<String, Any?>>()
        val subList = mutableListOf<Map<String, Any?>>()

        audioTrackRefs.clear()
        subtitleTrackRefs.clear()

        var audioIdx = 0
        var subIdx = 0

        for (group in tracks.groups) {
            when (group.type) {
                C.TRACK_TYPE_AUDIO -> {
                    for (i in 0 until group.length) {
                        val format = group.getTrackFormat(i)
                        val isSelected = group.isTrackSelected(i)
                        audioTrackRefs.add(TrackRef(group.mediaTrackGroup, i))

                        val langDisplay = getReadableLanguage(format.language)
                        val label = format.label?.takeIf { it.isNotBlank() }
                        val title = when {
                            label != null && langDisplay != null && !label.contains(langDisplay, ignoreCase = true) ->
                                "$label ($langDisplay)"
                            label != null -> label
                            langDisplay != null -> langDisplay
                            else -> "Audio ${audioIdx + 1}"
                        }

                        audioList.add(
                            mapOf(
                                "id" to audioIdx.toString(),
                                "index" to audioIdx,
                                "title" to title,
                                "language" to (format.language ?: ""),
                                "selected" to isSelected
                            )
                        )
                        audioIdx++
                    }
                }
                C.TRACK_TYPE_TEXT -> {
                    for (i in 0 until group.length) {
                        val format = group.getTrackFormat(i)
                        val isSelected = group.isTrackSelected(i)
                        subtitleTrackRefs.add(TrackRef(group.mediaTrackGroup, i))

                        val langDisplay = getReadableLanguage(format.language)
                        val label = format.label?.takeIf { it.isNotBlank() }
                        val title = when {
                            label != null && langDisplay != null && !label.contains(langDisplay, ignoreCase = true) ->
                                "$label ($langDisplay)"
                            label != null -> label
                            langDisplay != null -> langDisplay
                            else -> "Subtítulo ${subIdx + 1}"
                        }

                        val isAss = isAssSubtitleFormat(format)

                        subList.add(
                            mapOf(
                                "id" to subIdx.toString(),
                                "index" to subIdx,
                                "title" to title,
                                "language" to (format.language ?: ""),
                                "selected" to isSelected,
                                "isAss" to isAss
                            )
                        )
                        subIdx++
                    }
                }
            }
        }

        updateCurrentSubtitleType()
        assSubtitleView?.invalidateSubtitles()

        eventSink?.success(
            mapOf(
                "event" to "tracks",
                "audio" to audioList,
                "subtitles" to subList
            )
        )
    }

    override fun onRenderedFirstFrame() {
        hasRenderedFirstFrame = true
        videoDecoderRecoveryAttempts = 0
    }

    override fun onPlayerError(error: PlaybackException) {
        Log.e(TAG, "ExoPlayer PlaybackException: ${error.message}", error)

        val isTorrent = lastUri?.toString()?.contains("torrentstream", ignoreCase = true) == true ||
            lastUri?.toString()?.contains("/torrent", ignoreCase = true) == true

        // For torrent streams buffering initial pieces, retry prepare with a short delay
        if (isTorrent && !hasRenderedFirstFrame && videoDecoderRecoveryAttempts < 3) {
            videoDecoderRecoveryAttempts++
            Log.w(TAG, "Torrent stream buffering initial pieces, retrying prepare in 1.5s (attempt $videoDecoderRecoveryAttempts/3)...")
            mainHandler.postDelayed({
                val player = exoPlayer ?: return@postDelayed
                player.prepare()
                player.playWhenReady = true
            }, 1500)
            return
        }

        // Automatic retry with HlsMediaSource if format was unrecognized by progressive extractors (for online streams, never torrents)
        if (!isTorrent && error.errorCode == PlaybackException.ERROR_CODE_PARSING_CONTAINER_UNSUPPORTED && !attemptedHlsFallback) {
            attemptedHlsFallback = true
            val uri = lastUri
            val dsFactory = lastDataSourceFactory
            if (uri != null && dsFactory != null) {
                Log.i(TAG, "Progressive parser failed on stream. Retrying immediately with HlsMediaSource...")
                mainHandler.post {
                    try {
                        val hlsItem = MediaItem.Builder()
                            .setUri(uri)
                            .setMimeType(MimeTypes.APPLICATION_M3U8)
                            .build()
                        val hlsHandler = assHandler ?: AssHandler().also { assHandler = it }
                        val hlsSubtitleParserFactory = PgsSubtitleParserFactory(AssSubtitleParserFactory(hlsHandler))
                        val hlsExtractorFactory = DefaultHlsExtractorFactory()
                            .setSubtitleParserFactory(hlsSubtitleParserFactory)
                        val hlsSource = HlsMediaSource.Factory(dsFactory)
                            .setExtractorFactory(hlsExtractorFactory)
                            .setAllowChunklessPreparation(false)
                            .createMediaSource(hlsItem)
                        val player = exoPlayer ?: return@post
                        player.setMediaSource(hlsSource)
                        player.prepare()
                        if (lastStartPositionMs > 0) {
                            player.seekTo(lastStartPositionMs)
                        }
                        player.playWhenReady = true
                    } catch (e: Exception) {
                        Log.e(TAG, "Failed HLS retry: ${e.message}", e)
                        notifyPlayerError(error)
                    }
                }
                return
            }
        }

        // Retry transient decoder errors (VideoDecoderRecoveryPolicy)
        val isTransientDecoderError = VideoDecoderRecoveryPolicy.isTransientVideoDecoderError(
            error.errorCode,
            isVideoRenderer = true
        )
        if (isTransientDecoderError && videoDecoderRecoveryAttempts < VideoDecoderRecoveryPolicy.MAX_CONSECUTIVE_ATTEMPTS) {
            videoDecoderRecoveryAttempts++
            Log.w(TAG, "Attempting transient decoder recovery in ExoPlayer (attempt $videoDecoderRecoveryAttempts/${VideoDecoderRecoveryPolicy.MAX_CONSECUTIVE_ATTEMPTS})...")
            mainHandler.post {
                val player = exoPlayer ?: return@post
                val currentPos = if (player.currentPosition > 0) player.currentPosition else lastStartPositionMs
                player.prepare()
                if (currentPos > 0) {
                    player.seekTo(currentPos)
                }
                player.playWhenReady = true
            }
            return
        }

        notifyPlayerError(error)
    }

    private fun notifyPlayerError(error: PlaybackException) {
        val isCodecOrFormatError = error.errorCode == PlaybackException.ERROR_CODE_DECODER_INIT_FAILED ||
            error.errorCode == PlaybackException.ERROR_CODE_DECODING_FAILED ||
            error.errorCode == PlaybackException.ERROR_CODE_DECODING_FORMAT_UNSUPPORTED ||
            error.errorCode == PlaybackException.ERROR_CODE_PARSING_CONTAINER_UNSUPPORTED ||
            error.errorCode == PlaybackException.ERROR_CODE_PARSING_MANIFEST_UNSUPPORTED ||
            error.errorCodeName.contains("DECOD") ||
            error.errorCodeName.contains("UNSUPPORTED") ||
            error.errorCodeName.contains("PARSER")

        eventSink?.success(
            mapOf(
                "event" to "error",
                "message" to (error.message ?: "Playback error"),
                "errorCode" to error.errorCode,
                "isCodecOrFormatError" to isCodecOrFormatError
            )
        )
    }

    private fun applyVolume(volume: Float) {
        val player = exoPlayer ?: return
        if (volume <= 1.0f) {
            player.volume = volume.coerceIn(0.0f, 1.0f)
            try {
                loudnessEnhancer?.enabled = false
            } catch (e: Exception) {
                Log.w(TAG, "Error disabling LoudnessEnhancer: ${e.message}")
            }
        } else {
            // Amplification (> 100%): unity gain on player + hardware LoudnessEnhancer boost
            player.volume = 1.0f
            try {
                val sessionId = player.audioSessionId
                if (loudnessEnhancer == null && sessionId != C.AUDIO_SESSION_ID_UNSET && sessionId > 0) {
                    loudnessEnhancer = LoudnessEnhancer(sessionId)
                }
                if (loudnessEnhancer != null) {
                    // volume 1.0 -> 0 mB; volume 2.0 -> 1200 mB (+12 dB boost)
                    val gainMb = ((volume - 1.0f) * 1200).toInt().coerceIn(0, 2000)
                    loudnessEnhancer?.setTargetGain(gainMb)
                    loudnessEnhancer?.enabled = true
                }
            } catch (e: Exception) {
                Log.w(TAG, "Error applying LoudnessEnhancer: ${e.message}")
            }
        }
    }

    private fun teardown() {
        isDisposed = true
        lastChapters = emptyList()
        positionPollRunnable?.let { mainHandler.removeCallbacks(it) }
        positionPollRunnable = null

        try {
            loudnessEnhancer?.release()
        } catch (_: Exception) {}
        loudnessEnhancer = null

        val player = exoPlayer
        exoPlayer = null
        player?.removeListener(this)
        player?.stop()
        player?.release()

        val currentActivity = activity
        currentActivity?.let { act ->
            act.runOnUiThread {
                val lp = act.window.attributes
                lp.screenBrightness = android.view.WindowManager.LayoutParams.BRIGHTNESS_OVERRIDE_NONE
                act.window.attributes = lp
            }
        }
        surfaceContainer?.let { container ->
            containerLayoutChangeListener?.let { container.removeOnLayoutChangeListener(it) }
            currentActivity?.runOnUiThread {
                val content = currentActivity.findViewById<ViewGroup>(android.R.id.content)
                content?.removeView(container)
            }
        }
        containerLayoutChangeListener = null
        lastVideoWidth = 0
        lastVideoHeight = 0
        lastPixelWidthHeightRatio = 1.0f
        currentFitMode = "contain"
        surfaceContainer = null
        videoSurfaceView = null
        assSubtitleView = null
        standardSubtitleView = null
        assHandler?.let {
            it.videoFrameCallback = null
            it.release()
        }
        assHandler = null
        trackSelector = null
        audioTrackRefs.clear()
        subtitleTrackRefs.clear()
    }
}
