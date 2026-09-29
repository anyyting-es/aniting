package com.edde746.plezy.libass.media.parser

import androidx.annotation.OptIn
import androidx.media3.common.Format
import androidx.media3.common.util.UnstableApi

@OptIn(UnstableApi::class)
object AssHeaderParser {

  private const val ASS_EVENTS_HEADER =
    "\n[Events]\nFormat: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text\n"
  private val assEventsSuffix = ASS_EVENTS_HEADER.toByteArray(Charsets.UTF_8)

  /**
   * Matroska CodecPrivate data may omit the events section and end with one or more NUL
   * terminators. It may also contain a non-standard or missing Format line.
   * Strip any existing [Events] section and append our canonical [Events] header with
   * guaranteed column ordering for libass' ass_process_chunk.
   */
  fun normalizeHeader(buffer: ByteArray): ByteArray {
    var contentLength = buffer.size
    while (contentLength > 0 && buffer[contentLength - 1] == 0.toByte()) {
      contentLength--
    }
    if (contentLength <= 0) {
      return assEventsSuffix
    }

    val header = String(buffer, 0, contentLength, Charsets.UTF_8)
    val eventsIdx = header.indexOf("[Events]", ignoreCase = true)
    val baseHeader = if (eventsIdx >= 0) {
      header.substring(0, eventsIdx).trimEnd()
    } else {
      header.trimEnd()
    }

    return (baseHeader + ASS_EVENTS_HEADER).toByteArray(Charsets.UTF_8)
  }

  /**
   * Parses and normalizes the ASS header from the initialization data of the given [format].
   */
  fun parse(format: Format): ByteArray {
    if (format.initializationData.isEmpty()) {
      return assEventsSuffix
    }

    // In MatroskaExtractor, initializationData[0] is Media3's SSA_DIALOGUE_FORMAT,
    // and initializationData[1] is the MKV CodecPrivate containing [Script Info] & [V4+ Styles].
    // If only 1 element exists or if initializationData[0] contains the script info, prefer it.
    for (data in format.initializationData) {
      if (data.isNotEmpty()) {
        val str = try { String(data, Charsets.UTF_8) } catch (_: Exception) { "" }
        if (str.contains("[Script Info]", ignoreCase = true) ||
            str.contains("[V4", ignoreCase = true) ||
            str.contains("ScriptType", ignoreCase = true)) {
          return normalizeHeader(data)
        }
      }
    }

    // Fallback: if size > 1, take index 1, otherwise index 0
    val rawBytes = if (format.initializationData.size > 1) {
      format.initializationData[1]
    } else {
      format.initializationData[0]
    }
    return normalizeHeader(rawBytes)
  }
}
