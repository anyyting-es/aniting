package com.anyyting.aniting.exoplayer

import android.util.Log
import androidx.media3.common.C
import androidx.media3.common.DataReader
import androidx.media3.common.Format
import androidx.media3.common.MimeTypes
import androidx.media3.common.util.ParsableByteArray
import androidx.media3.extractor.ExtractorOutput
import androidx.media3.extractor.SeekMap
import androidx.media3.extractor.TrackOutput
import androidx.media3.extractor.ts.LatmReader
import androidx.media3.extractor.ts.TsPayloadReader
import java.io.EOFException

/**
 * TrackOutput wrapper that unwraps LOAS/LATM-framed AAC (MKV A_MS/ACM with
 * WAVEFORMATEX tag 0x1602) into raw AAC access units MediaCodec can decode.
 */
class LatmTrackOutput(
  private val delegate: TrackOutput,
  private val trackId: Int
) : TrackOutput {

  companion object {
    private const val TAG = "LatmTrackOutput"
    private const val INITIAL_BUFFER_SIZE = 4 * 1024
    private const val MAX_LOGGED_ERRORS = 3
  }

  private var latmReader: LatmReader? = null
  private var originalFormat: Format? = null
  private val parsable = ParsableByteArray()

  private var buf = ByteArray(INITIAL_BUFFER_SIZE)
  private var bufLen = 0
  private var readBuf = ByteArray(INITIAL_BUFFER_SIZE)
  private var errorCount = 0

  private val mergeProxy = object : TrackOutput {
    override fun format(format: Format) {
      val original = originalFormat
      val merged = if (original == null) {
        format
      } else {
        format.buildUpon()
          .setId(original.id)
          .setLabel(original.label)
          .setLanguage(original.language ?: format.language)
          .setSelectionFlags(original.selectionFlags)
          .build()
      }
      delegate.format(merged)
    }

    override fun sampleData(input: DataReader, length: Int, allowEndOfInput: Boolean, sampleDataPart: Int): Int = delegate.sampleData(input, length, allowEndOfInput, sampleDataPart)

    override fun sampleData(data: ParsableByteArray, length: Int, sampleDataPart: Int) = delegate.sampleData(data, length, sampleDataPart)

    override fun sampleMetadata(timeUs: Long, flags: Int, size: Int, offset: Int, cryptoData: TrackOutput.CryptoData?) = delegate.sampleMetadata(timeUs, flags, size, offset, cryptoData)
  }

  private val readerExtractorOutput = object : ExtractorOutput {
    override fun track(id: Int, type: Int): TrackOutput = mergeProxy
    override fun endTracks() {}
    override fun seekMap(seekMap: SeekMap) {}
  }

  override fun format(format: Format) {
    originalFormat = format
    if (latmReader == null) {
      latmReader = LatmReader(format.language, format.roleFlags).also {
        it.createTracks(readerExtractorOutput, TsPayloadReader.TrackIdGenerator(trackId, 1))
      }
    }
  }

  override fun sampleData(
    input: DataReader,
    length: Int,
    allowEndOfInput: Boolean,
    sampleDataPart: Int
  ): Int {
    if (readBuf.size < length) readBuf = ByteArray(length)
    val bytesRead = input.read(readBuf, 0, length)
    if (bytesRead == C.RESULT_END_OF_INPUT && !allowEndOfInput) throw EOFException()
    if (bytesRead > 0) append(readBuf, bytesRead)
    return bytesRead
  }

  override fun sampleData(data: ParsableByteArray, length: Int, sampleDataPart: Int) {
    ensureCapacity(bufLen + length)
    data.readBytes(buf, bufLen, length)
    bufLen += length
  }

  override fun sampleMetadata(
    timeUs: Long,
    flags: Int,
    size: Int,
    offset: Int,
    cryptoData: TrackOutput.CryptoData?
  ) {
    val start = bufLen - offset - size
    val reader = latmReader
    if (reader == null || start < 0) {
      if (errorCount++ < MAX_LOGGED_ERRORS) {
        Log.e(TAG, "Dropping sample (reader=${reader != null}, start=$start, size=$size, offset=$offset)")
      }
      if (offset == 0) bufLen = 0
      return
    }
    try {
      reader.packetStarted(timeUs, 0)
      parsable.reset(buf, start + size)
      parsable.position = start
      reader.consume(parsable)
    } catch (e: Exception) {
      if (errorCount++ < MAX_LOGGED_ERRORS) {
        Log.e(TAG, "LATM parse failed (${size}B), dropping sample", e)
      }
      reader.seek()
    }
    if (offset == 0) bufLen = 0
  }

  fun reset() {
    bufLen = 0
  }

  private fun append(src: ByteArray, length: Int) {
    ensureCapacity(bufLen + length)
    System.arraycopy(src, 0, buf, bufLen, length)
    bufLen += length
  }

  private fun ensureCapacity(needed: Int) {
    if (buf.size < needed) buf = buf.copyOf(maxOf(needed, buf.size * 2))
  }
}
