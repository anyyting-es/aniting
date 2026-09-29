package com.edde746.plezy.libass.media.text

import androidx.media3.common.C
import androidx.media3.common.Format
import androidx.media3.common.MimeTypes
import androidx.media3.common.util.UnstableApi
import androidx.media3.common.util.Util
import androidx.media3.extractor.TrackOutput
import com.edde746.plezy.libass.media.AssHandler
import com.edde746.plezy.libass.media.extractor.AssMatroskaExtractor
import java.util.regex.Pattern

/**
 * This class is only used by the overlay renderer. It's needed to get the start time of the subtitles.
 */
@UnstableApi
class AssTrackOutput(
  private val delegate: TrackOutput,
  private val assHandler: AssHandler,
  private val extractor: AssMatroskaExtractor
) : TrackOutput by delegate {

  private var isAss = false

  private var trackId: String? = null

  override fun format(format: Format) {
    if (format.sampleMimeType == MimeTypes.TEXT_SSA ||
        format.codecs == MimeTypes.TEXT_SSA ||
        format.sampleMimeType?.contains("ssa", ignoreCase = true) == true ||
        format.codecs?.contains("ssa", ignoreCase = true) == true ||
        format.sampleMimeType?.contains("ass", ignoreCase = true) == true ||
        format.codecs?.contains("ass", ignoreCase = true) == true ||
        format.id?.contains("ass", ignoreCase = true) == true ||
        format.id?.contains("ssa", ignoreCase = true) == true) {
      isAss = true
      trackId = format.id
    }
    delegate.format(format)
  }

  override fun sampleMetadata(
    timeUs: Long,
    flags: Int,
    size: Int,
    offset: Int,
    cryptoData: TrackOutput.CryptoData?
  ) {
    if (isAss && timeUs.isValidTs) {
      val sample = extractor.subtitleSample
      val endIndex = findTokenIndex(sample.data, 1)
      val lineIndex = findTokenIndex(sample.data, 2)

      if (lineIndex > 0 && lineIndex < sample.limit()) {
        val rawDuration = if (endIndex > 0 && lineIndex > endIndex) {
          sample.data.decodeToString(endIndex, lineIndex - 1)
        } else {
          ""
        }
        val durationUs = parseTimecodeUs(rawDuration)
        val durationMs: Long = if (durationUs != C.TIME_UNSET && durationUs > 0) {
          durationUs / 1000
        } else {
          0L
        }

        assHandler.readTrackDialogue(
          trackId = trackId,
          start = timeUs / 1000,
          duration = durationMs,
          data = sample.data,
          offset = lineIndex,
          length = sample.limit() - lineIndex
        )
      }
    }
    delegate.sampleMetadata(timeUs, flags, size, offset, cryptoData)
  }

  private fun parseTimecodeUs(timeString: String): Long {
    val trimmed = timeString.trim { it <= ' ' }
    if (trimmed.isEmpty()) return C.TIME_UNSET
    val matcher = SSA_TIMECODE_PATTERN.matcher(trimmed)
    if (!matcher.matches()) {
      return C.TIME_UNSET
    }
    val hours = matcher.group(1)?.toLongOrNull() ?: 0L
    val minutes = matcher.group(2)?.toLongOrNull() ?: 0L
    val seconds = matcher.group(3)?.toLongOrNull() ?: 0L
    val centiseconds = matcher.group(4)?.toLongOrNull() ?: 0L

    var timestampUs = hours * 60 * 60 * C.MICROS_PER_SECOND
    timestampUs += minutes * 60 * C.MICROS_PER_SECOND
    timestampUs += seconds * C.MICROS_PER_SECOND
    timestampUs += centiseconds * 10000
    return timestampUs
  }

  private fun findTokenIndex(array: ByteArray, tokenNumber: Int): Int {
    if (tokenNumber == 0) return 0
    var tokensFound = 0
    array.forEachIndexed { index, byte ->
      if (byte == COMMA && ++tokensFound == tokenNumber) {
        return index + 1
      }
    }
    return 0
  }

  private val Long.isValidTs
    get() = this != C.TIME_UNSET

  private companion object {
    val SSA_TIMECODE_PATTERN: Pattern =
      Pattern.compile("""(?:(\d+):)?(\d+):(\d+)[:.](\d+)""")

    const val COMMA = ','.code.toByte()
  }
}
