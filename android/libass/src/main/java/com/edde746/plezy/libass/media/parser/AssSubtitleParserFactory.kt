package com.edde746.plezy.libass.media.parser

import androidx.media3.common.Format
import androidx.media3.common.MimeTypes
import androidx.media3.common.util.UnstableApi
import androidx.media3.extractor.text.DefaultSubtitleParserFactory
import androidx.media3.extractor.text.SubtitleParser
import com.edde746.plezy.libass.media.AssHandler

@UnstableApi
class AssSubtitleParserFactory(private val assHandler: AssHandler) : SubtitleParser.Factory {

  private val defaultSubtitleParserFactory = DefaultSubtitleParserFactory()

  override fun supportsFormat(format: Format): Boolean = defaultSubtitleParserFactory.supportsFormat(format)

  override fun getCueReplacementBehavior(format: Format): Int = defaultSubtitleParserFactory.getCueReplacementBehavior(format)

  override fun create(format: Format): SubtitleParser {
    val isSsa = format.sampleMimeType == MimeTypes.TEXT_SSA ||
      format.codecs == MimeTypes.TEXT_SSA ||
      format.sampleMimeType?.contains("ssa", ignoreCase = true) == true ||
      format.codecs?.contains("ssa", ignoreCase = true) == true ||
      format.sampleMimeType?.contains("ass", ignoreCase = true) == true ||
      format.codecs?.contains("ass", ignoreCase = true) == true ||
      format.id?.contains("ass", ignoreCase = true) == true ||
      format.id?.contains("ssa", ignoreCase = true) == true

    if (isSsa) {
      val track = assHandler.createTrack(format)
      val embeddedSubtitles = format.initializationData.size >= 2 ||
        MimeTypes.VIDEO_MATROSKA.contentEquals(format.containerMimeType) ||
        format.containerMimeType == null

      return if (embeddedSubtitles) {
        // Embedded dialogue lines reach libass via AssTrackOutput; nothing to parse here.
        AssNoOpSubtitleParser()
      } else {
        AssFullSubtitleParser(track)
      }
    }
    return defaultSubtitleParserFactory.create(format)
  }
}
