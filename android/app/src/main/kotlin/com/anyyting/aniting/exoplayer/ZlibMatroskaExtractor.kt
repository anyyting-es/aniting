package com.anyyting.aniting.exoplayer

import android.util.Log
import androidx.media3.common.C
import androidx.media3.common.DataReader
import androidx.media3.extractor.DefaultExtractorInput
import androidx.media3.extractor.ExtractorInput
import androidx.media3.extractor.ExtractorOutput
import androidx.media3.extractor.SeekMap
import androidx.media3.extractor.TrackOutput
import androidx.media3.extractor.text.SubtitleParser
import com.edde746.plezy.libass.media.AssHandler
import com.edde746.plezy.libass.media.extractor.AssMatroskaExtractor
import java.io.EOFException
import java.util.zip.DataFormatException
import java.util.zip.Inflater

/**
 * Extends AssMatroskaExtractor to add support for MKV quirks media3 rejects:
 *
 * ContentCompAlgo 0 (zlib) — media3 only supports ContentCompAlgo 3 (header
 * stripping). This subclass intercepts the compression algorithm during track
 * header parsing:
 * - Tells the parent it's header stripping (algo 3) to avoid the ParserException
 * - Skips ContentCompSettings for zlib tracks (not applicable)
 * - For text subtitle tracks, inflates the block payload *before* the parent
 *   parses it. For every other zlib track, wraps TrackOutputs with
 *   ZlibInflatingTrackOutput to decompress per-sample data.
 *
 * LOAS/LATM AAC as A_MS/ACM — media3 sets audio/x-unknown for non-PCM ACM
 * tracks (silent playback). Detected tracks are wrapped with LatmTrackOutput,
 * which unwraps LOAS frames to raw AAC for direct-playing Matroska files.
 */
class ZlibMatroskaExtractor(
  subtitleParserFactory: SubtitleParser.Factory,
  assHandler: AssHandler
) : AssMatroskaExtractor(subtitleParserFactory, assHandler) {

  companion object {
    private const val TAG = "ZlibMkvExtractor"

    private const val ID_SEGMENT = 0x18538067
    private const val ID_TRACK_ENTRY = 0xAE
    private const val ID_CONTENT_COMPRESSION_ALGORITHM = 0x4254
    private const val ID_CONTENT_COMPRESSION_SETTINGS = 0x4255
    private const val ID_CONTENT_COMPRESSION = 0x5034
    private const val ID_SIMPLE_BLOCK = 0xA3
    private const val ID_BLOCK = 0xA1

    private val TEXT_SUBTITLE_CODEC_IDS = setOf("S_TEXT/UTF8", "S_TEXT/ASS", "S_TEXT/SSA", "S_TEXT/WEBVTT")
    private const val MAX_TEXT_BLOCK_BYTES = 16 * 1024 * 1024
  }

  private var zlibOutput: ZlibExtractorOutputWrapper? = null
  private var latmOutput: LatmExtractorOutputWrapper? = null
  private var currentTrackUsesZlib = false

  private val zlibTextTrackNumbers = mutableSetOf<Int>()
  private val blockInflater = Inflater()
  private var blockBuf = ByteArray(0)
  private val peekBuf = ByteArray(8)

  override fun startMasterElement(id: Int, contentPosition: Long, contentSize: Long) {
    super.startMasterElement(id, contentPosition, contentSize)

    if (id == ID_CONTENT_COMPRESSION) {
      currentTrackUsesZlib = true
      Log.i(TAG, "Track has ContentCompression, assuming ContentCompAlgo 0 (zlib) until told otherwise")
    }

    if (id == ID_SEGMENT && zlibOutput == null) {
      val currentOutput = matroskaExtractorOutputField.get(this) as ExtractorOutput
      val latmWrapper = LatmExtractorOutputWrapper(currentOutput)
      latmOutput = latmWrapper
      val wrapper = ZlibExtractorOutputWrapper(latmWrapper)
      zlibOutput = wrapper
      matroskaExtractorOutputField.set(this, wrapper)
      Log.d(TAG, "Installed zlib+LATM ExtractorOutput wrapper")
    }
  }

  override fun integerElement(id: Int, value: Long) {
    if (id == ID_CONTENT_COMPRESSION_ALGORITHM) {
      if (value == 0L) {
        currentTrackUsesZlib = true
        Log.i(TAG, "Track uses explicit ContentCompAlgo 0 (zlib), will inflate samples")
        super.integerElement(id, 3)
        return
      }
      currentTrackUsesZlib = false
    }
    super.integerElement(id, value)
  }

  override fun binaryElement(id: Int, contentSize: Int, input: ExtractorInput) {
    if (id == ID_CONTENT_COMPRESSION_SETTINGS && currentTrackUsesZlib) {
      input.skipFully(contentSize)
      return
    }
    if ((id == ID_SIMPLE_BLOCK || id == ID_BLOCK) &&
      zlibTextTrackNumbers.isNotEmpty() &&
      contentSize in MIN_BLOCK_BYTES..MAX_TEXT_BLOCK_BYTES &&
      peekBlockTrackNumber(input) in zlibTextTrackNumbers
    ) {
      inflateTextBlock(id, contentSize, input)
      return
    }
    super.binaryElement(id, contentSize, input)
  }

  override fun endMasterElement(id: Int) {
    var zlibTextTrackNumber: Int? = null
    if (id == ID_TRACK_ENTRY) {
      val track = getCurrentTrack(id)
      if (isLoasAcmTrack(track.codecId, track.codecPrivate)) {
        Log.i(TAG, "Track ${track.number} is LOAS/LATM AAC, unwrapping to raw AAC")
        latmOutput?.markNextTrackLatm()
      }
      if (currentTrackUsesZlib && track.codecId in TEXT_SUBTITLE_CODEC_IDS) {
        zlibTextTrackNumber = track.number
      }
    }

    val wasZlib = currentTrackUsesZlib
    super.endMasterElement(id)

    if (id == ID_TRACK_ENTRY && wasZlib) {
      currentTrackUsesZlib = false
      if (zlibTextTrackNumber != null) {
        zlibTextTrackNumbers.add(zlibTextTrackNumber)
        Log.i(TAG, "Track $zlibTextTrackNumber is a zlib text subtitle track, inflating at block level")
      } else {
        zlibOutput?.activateLast()
        Log.i(TAG, "Activated zlib inflation for track")
      }
    }
  }

  override fun seek(position: Long, timeUs: Long) {
    latmOutput?.resetTracks()
    zlibOutput?.resetTracks()
    super.seek(position, timeUs)
  }

  private fun peekBlockTrackNumber(input: ExtractorInput): Int? {
    try {
      input.peekFully(peekBuf, 0, 1)
      val first = peekBuf[0].toInt() and 0xFF
      if (first == 0) return null
      val length = Integer.numberOfLeadingZeros(first) - 23
      var value = (first and (0xFF ushr length)).toLong()
      if (length > 1) {
        input.peekFully(peekBuf, 1, length - 1)
        for (i in 1 until length) {
          value = (value shl 8) or (peekBuf[i].toLong() and 0xFF)
        }
      }
      return if (value <= Int.MAX_VALUE) value.toInt() else null
    } catch (_: EOFException) {
      return null
    } finally {
      input.resetPeekPosition()
    }
  }

  private fun inflateTextBlock(id: Int, contentSize: Int, input: ExtractorInput) {
    val basePosition = input.position
    if (blockBuf.size < contentSize) blockBuf = ByteArray(maxOf(contentSize, blockBuf.size * 2))
    input.readFully(blockBuf, 0, contentSize)
    val rewritten = rewriteZlibTextBlock(blockBuf, contentSize, blockInflater)
    if (rewritten == null) {
      Log.w(TAG, "Passing zlib text block through uninflated (laced, corrupt, or over-bound)")
      super.binaryElement(id, contentSize, bufferedInput(blockBuf, contentSize, basePosition))
    } else {
      super.binaryElement(id, rewritten.size, bufferedInput(rewritten, rewritten.size, basePosition))
    }
  }

  private fun bufferedInput(data: ByteArray, limit: Int, position: Long): ExtractorInput = DefaultExtractorInput(ByteRangeDataReader(data, limit), position, position + limit)

  private class ByteRangeDataReader(private val data: ByteArray, private val limit: Int) : DataReader {
    private var position = 0

    override fun read(buffer: ByteArray, offset: Int, length: Int): Int {
      if (position == limit) return C.RESULT_END_OF_INPUT
      val count = minOf(length, limit - position)
      System.arraycopy(data, position, buffer, offset, count)
      position += count
      return count
    }
  }

  private class ZlibExtractorOutputWrapper(
    private val delegate: ExtractorOutput
  ) : ExtractorOutput {

    private var lastCreatedWrapper: ZlibInflatingTrackOutput? = null
    private val trackOutputs = mutableListOf<ZlibInflatingTrackOutput>()

    override fun track(id: Int, type: Int): TrackOutput {
      val original = delegate.track(id, type)
      return ZlibInflatingTrackOutput(original).also {
        trackOutputs.add(it)
        lastCreatedWrapper = it
      }
    }

    fun activateLast() {
      lastCreatedWrapper?.active = true
    }

    fun resetTracks() {
      trackOutputs.forEach { it.resetBufferedData() }
    }

    override fun endTracks() = delegate.endTracks()
    override fun seekMap(seekMap: SeekMap) = delegate.seekMap(seekMap)
  }
}

internal const val MIN_BLOCK_BYTES = 5

internal fun rewriteZlibTextBlock(data: ByteArray, limit: Int, inflater: Inflater): ByteArray? {
  if (limit < MIN_BLOCK_BYTES) return null
  val first = data[0].toInt() and 0xFF
  if (first == 0) return null
  val varintLength = Integer.numberOfLeadingZeros(first) - 23
  val headerLength = varintLength + 3
  if (limit <= headerLength) return null
  if (data[headerLength - 1].toInt() and 0x06 != 0) return null

  val payloadLength = limit - headerLength
  val ratioBound = maxOf(1024L * 1024, payloadLength.toLong() * 1024)
  val maxInflatedBytes = 16 * 1024 * 1024
  inflater.reset()
  inflater.setInput(data, headerLength, payloadLength)
  var buf = ByteArray(maxOf(4096, payloadLength * 4))
  var written = 0
  try {
    while (true) {
      if (written == buf.size) {
        if (buf.size >= maxInflatedBytes) return null
        buf = buf.copyOf(minOf(maxInflatedBytes, buf.size * 2))
      }
      val count = inflater.inflate(buf, written, buf.size - written)
      written += count
      if (written.toLong() > ratioBound) return null
      if (inflater.finished()) break
      if (count == 0) return null
    }
  } catch (_: DataFormatException) {
    return null
  }
  return ByteArray(headerLength + written).also {
    System.arraycopy(data, 0, it, 0, headerLength)
    System.arraycopy(buf, 0, it, headerLength, written)
  }
}
