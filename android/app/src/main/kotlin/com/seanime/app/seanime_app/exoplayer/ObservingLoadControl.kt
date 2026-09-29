package com.seanime.app.seanime_app.exoplayer

import androidx.annotation.OptIn
import androidx.media3.common.Timeline
import androidx.media3.common.util.UnstableApi
import androidx.media3.exoplayer.LoadControl
import androidx.media3.exoplayer.analytics.PlayerId
import androidx.media3.exoplayer.source.MediaSource
import androidx.media3.exoplayer.source.TrackGroupArray
import androidx.media3.exoplayer.trackselection.ExoTrackSelection
import androidx.media3.exoplayer.upstream.Allocator

@OptIn(UnstableApi::class)
@Suppress("DEPRECATION")
class ObservingLoadControl(private val delegate: LoadControl) : LoadControl {

  @Volatile
  var startPlaybackVerdict: Boolean? = null
    private set

  fun reset() {
    startPlaybackVerdict = null
  }

  override fun shouldStartPlayback(parameters: LoadControl.Parameters): Boolean {
    val verdict = delegate.shouldStartPlayback(parameters)
    startPlaybackVerdict = verdict
    return verdict
  }

  override fun shouldContinueLoading(parameters: LoadControl.Parameters): Boolean = delegate.shouldContinueLoading(parameters)

  override fun shouldContinuePreloading(
    timeline: Timeline,
    mediaPeriodId: MediaSource.MediaPeriodId,
    bufferedDurationUs: Long
  ): Boolean = delegate.shouldContinuePreloading(timeline, mediaPeriodId, bufferedDurationUs)

  override fun onPrepared(playerId: PlayerId) {
    delegate.onPrepared(playerId)
  }

  @Deprecated("Deprecated in Java")
  override fun onPrepared() {
    delegate.onPrepared(PlayerId.UNSET)
  }

  override fun onTracksSelected(
    parameters: LoadControl.Parameters,
    trackGroups: TrackGroupArray,
    trackSelections: Array<out ExoTrackSelection?>
  ) = delegate.onTracksSelected(parameters, trackGroups, trackSelections)

  override fun onStopped(playerId: PlayerId) {
    delegate.onStopped(playerId)
  }

  @Deprecated("Deprecated in Java")
  override fun onStopped() {
    delegate.onStopped(PlayerId.UNSET)
  }

  override fun onReleased(playerId: PlayerId) {
    delegate.onReleased(playerId)
  }

  @Deprecated("Deprecated in Java")
  override fun onReleased() {
    delegate.onReleased(PlayerId.UNSET)
  }

  override fun getAllocator(): Allocator = delegate.allocator

  override fun getBackBufferDurationUs(playerId: PlayerId): Long = delegate.getBackBufferDurationUs(playerId)

  @Deprecated("Deprecated in Java")
  override fun getBackBufferDurationUs(): Long = delegate.getBackBufferDurationUs(PlayerId.UNSET)

  override fun retainBackBufferFromKeyframe(playerId: PlayerId): Boolean = delegate.retainBackBufferFromKeyframe(playerId)

  @Deprecated("Deprecated in Java")
  override fun retainBackBufferFromKeyframe(): Boolean = delegate.retainBackBufferFromKeyframe(PlayerId.UNSET)
}
