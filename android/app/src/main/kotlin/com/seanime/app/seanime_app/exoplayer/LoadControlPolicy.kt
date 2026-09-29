package com.seanime.app.seanime_app.exoplayer

/**
 * Auto sizing for [androidx.media3.exoplayer.DefaultLoadControl]'s `targetBufferBytes`.
 */
internal object LoadControlPolicy {
  private const val MIB = 1024 * 1024

  const val MEDIA3_DEFAULT_TARGET_BYTES = 2200 * 64 * 1024
  const val MIN_TARGET_BYTES = 32 * MIB

  const val BUFFER_FOR_PLAYBACK_MS = 1_000
  const val BUFFER_FOR_PLAYBACK_AFTER_REBUFFER_MS = 3_000

  private const val BUDGET_DIVISOR = 4
  private const val LOW_MEMORY_MB = 2048

  private const val AUTO_MIN_BUFFER_LOW_MEMORY_MS = 15_000
  private const val AUTO_MAX_BUFFER_LOW_MEMORY_MS = 50_000
  private const val AUTO_MIN_BUFFER_MS = 30_000
  private const val AUTO_MAX_BUFFER_MS = 60_000

  data class BufferDurations(val minBufferMs: Int, val maxBufferMs: Int)

  fun bufferDurations(availableMB: Int): BufferDurations {
    val playStartFloor = maxOf(BUFFER_FOR_PLAYBACK_MS, BUFFER_FOR_PLAYBACK_AFTER_REBUFFER_MS)
    val (rawMin, rawMax) = if (availableMB <= LOW_MEMORY_MB) {
      AUTO_MIN_BUFFER_LOW_MEMORY_MS to AUTO_MAX_BUFFER_LOW_MEMORY_MS
    } else {
      AUTO_MIN_BUFFER_MS to AUTO_MAX_BUFFER_MS
    }
    val minBufferMs = rawMin.coerceAtLeast(playStartFloor)
    return BufferDurations(minBufferMs, rawMax.coerceAtLeast(minBufferMs))
  }

  fun autoTargetBufferBytes(largeHeapMB: Int, availableMB: Int): Int {
    var budget = MEDIA3_DEFAULT_TARGET_BYTES.toLong()
    if (largeHeapMB > 0) budget = minOf(budget, largeHeapMB.toLong() / BUDGET_DIVISOR * MIB)
    if (availableMB > 0) budget = minOf(budget, availableMB.toLong() / BUDGET_DIVISOR * MIB)
    return maxOf(budget, MIN_TARGET_BYTES.toLong()).toInt()
  }
}
