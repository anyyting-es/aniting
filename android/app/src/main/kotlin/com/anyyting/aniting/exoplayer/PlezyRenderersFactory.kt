package com.anyyting.aniting.exoplayer

import android.content.Context
import android.os.Handler
import android.util.Log
import android.os.Looper
import androidx.annotation.OptIn
import androidx.media3.common.MimeTypes
import androidx.media3.common.audio.ChannelMixingAudioProcessor
import androidx.media3.common.audio.ChannelMixingMatrix
import androidx.media3.common.util.UnstableApi
import androidx.media3.decoder.DecoderInputBuffer
import androidx.media3.exoplayer.DefaultRenderersFactory
import androidx.media3.exoplayer.Renderer
import androidx.media3.exoplayer.audio.AudioRendererEventListener
import androidx.media3.exoplayer.audio.AudioSink
import androidx.media3.exoplayer.audio.DefaultAudioSink
import androidx.media3.exoplayer.mediacodec.MediaCodecAdapter
import androidx.media3.exoplayer.mediacodec.MediaCodecSelector
import androidx.media3.exoplayer.text.TextOutput
import androidx.media3.exoplayer.text.TextRenderer
import androidx.media3.exoplayer.video.MediaCodecVideoRenderer
import androidx.media3.exoplayer.video.VideoRendererEventListener

@OptIn(UnstableApi::class)
class PlezyRenderersFactory(context: Context) : DefaultRenderersFactory(context) {

  companion object {
    private const val TAG = "PlezyRenderersFactory"
  }

  private val identityChannelMixingMatrices = Array(DownmixMatrices.MAX_MIXING_CHANNELS) { index ->
    val channelCount = index + 1
    ChannelMixingMatrix(
      channelCount,
      channelCount,
      DownmixMatrices.identityCoefficients(channelCount)
    )
  }

  val channelMixProcessor = ChannelMixingAudioProcessor().apply {
    for (matrix in identityChannelMixingMatrices) putChannelMixingMatrix(matrix)
  }

  fun enableStereoDownmix(centerBoostDb: Int = 3, normalize: Boolean = true) {
    for (inputChannels in DownmixMatrices.MIN_DOWNMIX_INPUT_CHANNELS..DownmixMatrices.MAX_DOWNMIX_INPUT_CHANNELS) {
      val coefficients = DownmixMatrices.stereoCoefficients(inputChannels, centerBoostDb, normalize) ?: continue
      channelMixProcessor.putChannelMixingMatrix(ChannelMixingMatrix(inputChannels, 2, coefficients))
    }
  }

  override fun buildVideoRenderers(
    context: Context,
    extensionRendererMode: Int,
    mediaCodecSelector: MediaCodecSelector,
    enableDecoderFallback: Boolean,
    eventHandler: Handler,
    eventListener: VideoRendererEventListener,
    allowedVideoJoiningTimeMs: Long,
    out: ArrayList<Renderer>
  ) {
    super.buildVideoRenderers(
      context,
      extensionRendererMode,
      mediaCodecSelector,
      enableDecoderFallback,
      eventHandler,
      eventListener,
      allowedVideoJoiningTimeMs,
      out
    )
    val index = out.indexOfFirst { it.javaClass == MediaCodecVideoRenderer::class.java }
    if (index < 0) return
    out[index] = DvSanitizingVideoRenderer(
      context,
      codecAdapterFactory,
      mediaCodecSelector,
      allowedVideoJoiningTimeMs,
      enableDecoderFallback,
      eventHandler,
      eventListener,
      50
    )
  }

  override fun buildAudioSink(
    context: Context,
    enableFloatOutput: Boolean,
    enableAudioOutputPlaybackParams: Boolean
  ): AudioSink {
    enableStereoDownmix(centerBoostDb = 3, normalize = true)
    return DefaultAudioSink.Builder(context)
      .setEnableFloatOutput(enableFloatOutput)
      .setEnableAudioTrackPlaybackParams(enableAudioOutputPlaybackParams)
      .setAudioProcessors(arrayOf(channelMixProcessor))
      .build()
  }

  override fun buildTextRenderers(
    context: Context,
    output: TextOutput,
    outputLooper: Looper,
    extensionRendererMode: Int,
    out: ArrayList<Renderer>
  ) {
    val textRenderer = TextRenderer(output, outputLooper).apply {
      experimentalSetLegacyDecodingEnabled(true)
    }
    out.add(textRenderer)
  }
}

@OptIn(UnstableApi::class)
internal class DvSanitizingVideoRenderer(
  context: Context,
  codecAdapterFactory: MediaCodecAdapter.Factory,
  mediaCodecSelector: MediaCodecSelector,
  allowedJoiningTimeMs: Long,
  enableDecoderFallback: Boolean,
  eventHandler: Handler?,
  eventListener: VideoRendererEventListener?,
  maxDroppedFramesToNotify: Int
) : MediaCodecVideoRenderer(
  context,
  codecAdapterFactory,
  mediaCodecSelector,
  allowedJoiningTimeMs,
  enableDecoderFallback,
  eventHandler,
  eventListener,
  maxDroppedFramesToNotify
) {

  private companion object {
    private const val TAG = "DvSanitizingRenderer"
  }

  private val sanitizer = DvBitstreamSanitizer()
  private var stripHdr10PlusSei = false
  private var stripDvRpu = false

  override fun onCodecInitialized(
    name: String,
    configuration: MediaCodecAdapter.Configuration,
    initializedTimestampMs: Long,
    initializationDurationMs: Long
  ) {
    super.onCodecInitialized(name, configuration, initializedTimestampMs, initializationDurationMs)
    val codecs = configuration.format.codecs?.lowercase() ?: ""
    val isDvFormat = configuration.format.sampleMimeType == MimeTypes.VIDEO_DOLBY_VISION ||
      codecs.startsWith("dvhe.") || codecs.startsWith("dvh1.") || codecs.startsWith("dav1.")
    val codecMimeType = configuration.codecInfo.codecMimeType

    // If using a native DV codec, strip in-band HDR10+ SEI which crashes many chipsets
    stripHdr10PlusSei = isDvFormat && codecMimeType == MimeTypes.VIDEO_DOLBY_VISION

    // If using an HEVC or standard codec for a DV video, strip DV RPU/EL so standard HEVC decoders can play it smoothly
    stripDvRpu = isDvFormat && (codecMimeType == MimeTypes.VIDEO_H265 || codecMimeType != MimeTypes.VIDEO_DOLBY_VISION)

    Log.i(
      TAG,
      "Codec initialized: $name (mime=$codecMimeType, format=${configuration.format.sampleMimeType}, " +
        "codecs=${configuration.format.codecs}, stripDvRpu=$stripDvRpu, stripHdr10PlusSei=$stripHdr10PlusSei)"
    )
  }

  override fun onQueueInputBuffer(buffer: DecoderInputBuffer) {
    if (stripHdr10PlusSei || stripDvRpu) {
      val data = buffer.data
      if (data != null && data.hasRemaining() && !buffer.isEncrypted) {
        sanitizer.sanitize(data, stripHdr10PlusSei, stripDvRpu)
      }
    }
    super.onQueueInputBuffer(buffer)
  }
}
