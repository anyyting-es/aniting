package playbackmanager

import (
	"errors"
	"seanime/internal/api/anilist"
	"seanime/internal/api/metadata_provider"
	"seanime/internal/continuity"
	"seanime/internal/database/db"
	"seanime/internal/database/db_bridge"
	"seanime/internal/database/models"
	"seanime/internal/events"
	"seanime/internal/library/anime"
	"seanime/internal/mediaplayers/mediaplayer"
	"seanime/internal/platforms/platform"
	"seanime/internal/testmocks"
	"seanime/internal/testutil"
	"seanime/internal/util"
	"sync"
	"testing"
	"time"

	"github.com/samber/mo"
	"github.com/stretchr/testify/require"
)

func TestPlaybackManagerUnitNewDefaultsAndSetters(t *testing.T) {
	// keep the constructor honest so the rest of the tests can rely on the default state.
	h := newPlaybackManagerTestWrapper(t)

	require.NotNil(t, h.playbackManager.settings)
	require.NotNil(t, h.playbackManager.historyMap)
	require.Empty(t, h.playbackManager.historyMap)
	require.True(t, h.playbackManager.nextEpisodeLocalFile.IsAbsent())
	require.True(t, h.playbackManager.animeCollection.IsAbsent())

	collection := &anilist.AnimeCollection{}
	h.playbackManager.SetAnimeCollection(collection)
	require.True(t, h.playbackManager.animeCollection.IsPresent())
	require.Same(t, collection, h.playbackManager.animeCollection.MustGet())

	settings := &Settings{AutoPlayNextEpisode: true}
	h.playbackManager.SetSettings(settings)
	require.Same(t, settings, h.playbackManager.settings)

	h.playbackManager.SetPlaylistActive(true)
	require.True(t, h.playbackManager.isPlaylistActive.Load())
	h.playbackManager.SetPlaylistActive(false)
	require.False(t, h.playbackManager.isPlaylistActive.Load())
}

func TestPlaybackManagerUnitCheckOrLoadAnimeCollectionCachesResult(t *testing.T) {
	// the first call should hit the platform, and later calls should reuse the cached collection.
	h := newPlaybackManagerTestWrapper(t)
	expectedCollection := &anilist.AnimeCollection{}
	h.platform = testmocks.NewFakePlatformBuilder().WithAnimeCollection(expectedCollection).Build()
	h.playbackManager.platformRef = util.NewRef[platform.Platform](h.platform)

	require.NoError(t, h.playbackManager.checkOrLoadAnimeCollection())
	require.Equal(t, 1, h.platform.AnimeCollectionCalls())
	require.Same(t, expectedCollection, h.playbackManager.animeCollection.MustGet())

	require.NoError(t, h.playbackManager.checkOrLoadAnimeCollection())
	require.Equal(t, 1, h.platform.AnimeCollectionCalls())

	h.playbackManager.animeCollection = mo.None[*anilist.AnimeCollection]()
	h.platform = testmocks.NewFakePlatformBuilder().WithAnimeCollectionError(errors.New("collection failed")).Build()
	h.playbackManager.platformRef = util.NewRef[platform.Platform](h.platform)
	err := h.playbackManager.checkOrLoadAnimeCollection()
	require.EqualError(t, err, "collection failed")
	require.Equal(t, 1, h.platform.AnimeCollectionCalls())
}

func TestPlaybackManagerUnitGetNextEpisodeAndCurrentMediaID(t *testing.T) {
	// these are tiny state readers, so keep them focused on the state machine rules.
	h := newPlaybackManagerTestWrapper(t)
	localFiles := anime.NewTestLocalFiles(anime.TestLocalFileGroup{
		LibraryPath:      "/Anime",
		FilePathTemplate: "/Anime/Frieren/%ep.mkv",
		MediaID:          154587,
		Episodes: []anime.TestLocalFileEpisode{
			{Episode: 1, AniDBEpisode: "1", Type: anime.LocalFileTypeMain},
			{Episode: 2, AniDBEpisode: "2", Type: anime.LocalFileTypeMain},
		},
	})

	_, err := h.playbackManager.GetCurrentMediaID()
	require.EqualError(t, err, "no media is currently playing")
	require.Nil(t, h.playbackManager.GetNextEpisode())

	h.playbackManager.currentLocalFile = mo.Some(localFiles[0])
	h.playbackManager.currentPlaybackType = StreamPlayback
	mediaID, err := h.playbackManager.GetCurrentMediaID()
	require.NoError(t, err)
	require.Equal(t, 154587, mediaID)
	require.Nil(t, h.playbackManager.GetNextEpisode())

	h.playbackManager.currentPlaybackType = LocalFilePlayback
	h.playbackManager.nextEpisodeLocalFile = mo.Some(localFiles[1])
	require.Same(t, localFiles[1], h.playbackManager.GetNextEpisode())
}

func TestPlaybackManagerUnitPlaybackStatusSubscriptionLifecycle(t *testing.T) {
	// subscription cleanup matters because the manager broadcasts on these channels from goroutines.
	h := newPlaybackManagerTestWrapper(t)
	subscriber := h.playbackManager.SubscribeToPlaybackStatus("unit")

	storedSubscriber, ok := h.playbackManager.playbackStatusSubscribers.Get("unit")
	require.True(t, ok)
	require.Same(t, subscriber, storedSubscriber)
	require.False(t, subscriber.Canceled.Load())

	h.playbackManager.UnsubscribeFromPlaybackStatus("unit")
	require.True(t, subscriber.Canceled.Load())
	_, ok = h.playbackManager.playbackStatusSubscribers.Get("unit")
	require.False(t, ok)

	_, channelOpen := <-subscriber.EventCh
	require.False(t, channelOpen)

	// a second unsubscribe should stay quiet instead of panicking.
	h.playbackManager.UnsubscribeFromPlaybackStatus("unit")
}

func TestPlaybackManagerUnitRegisterMediaPlayerCallbackStopsAfterFalse(t *testing.T) {
	// callbacks are just another subscriber under the hood, so we can drive one directly.
	h := newPlaybackManagerTestWrapper(t)
	received := make(chan PlaybackEvent, 1)

	h.playbackManager.RegisterMediaPlayerCallback(func(event PlaybackEvent) bool {
		received <- event
		return false
	})

	var subscriber *PlaybackStatusSubscriber
	require.Eventually(t, func() bool {
		h.playbackManager.playbackStatusSubscribers.Range(func(_ string, value *PlaybackStatusSubscriber) bool {
			subscriber = value
			return false
		})
		return subscriber != nil
	}, time.Second, 10*time.Millisecond)

	subscriber.EventCh <- PlaybackErrorEvent{Reason: "boom"}

	select {
	case event := <-received:
		require.Equal(t, "playback_error", event.Type())
		require.Equal(t, "boom", event.(PlaybackErrorEvent).Reason)
	case <-time.After(time.Second):
		t.Fatal("callback did not receive playback event")
	}

	require.Eventually(t, func() bool {
		return len(h.playbackManager.playbackStatusSubscribers.Keys()) == 0
	}, time.Second, 10*time.Millisecond)
}

func TestPlaybackManagerUnitAutoPlayNextEpisodeBranches(t *testing.T) {
	localFiles := anime.NewTestLocalFiles(anime.TestLocalFileGroup{
		LibraryPath:      "/Anime",
		FilePathTemplate: "/Anime/Frieren/%ep.mkv",
		MediaID:          154587,
		Episodes: []anime.TestLocalFileEpisode{
			{Episode: 1, AniDBEpisode: "1", Type: anime.LocalFileTypeMain},
			{Episode: 2, AniDBEpisode: "2", Type: anime.LocalFileTypeMain},
		},
	})

	t.Run("disabled autoplay is a no-op", func(t *testing.T) {
		// if the setting is off, the queue should stay untouched.
		h := newPlaybackManagerTestWrapper(t)
		h.playbackManager.currentPlaybackType = LocalFilePlayback
		h.playbackManager.nextEpisodeLocalFile = mo.Some(localFiles[1])

		require.NoError(t, h.playbackManager.AutoPlayNextEpisode())
		require.True(t, h.playbackManager.nextEpisodeLocalFile.IsPresent())
	})

	t.Run("missing next episode stays quiet", func(t *testing.T) {
		// multiple clients can race this request, so no-next should just return nil.
		h := newPlaybackManagerTestWrapper(t)
		h.playbackManager.settings.AutoPlayNextEpisode = true
		h.playbackManager.currentPlaybackType = LocalFilePlayback

		require.NoError(t, h.playbackManager.AutoPlayNextEpisode())
		require.True(t, h.playbackManager.nextEpisodeLocalFile.IsAbsent())
	})

	t.Run("play errors get wrapped", func(t *testing.T) {
		// once autoplay is enabled and a next file exists, play-next failures should bubble up with context.
		h := newPlaybackManagerTestWrapper(t)
		h.playbackManager.settings.AutoPlayNextEpisode = true
		h.playbackManager.currentPlaybackType = LocalFilePlayback
		h.playbackManager.nextEpisodeLocalFile = mo.Some(localFiles[1])

		err := h.playbackManager.AutoPlayNextEpisode()
		require.EqualError(t, err, "failed to auto play next episode: could not play next episode")
		require.True(t, h.playbackManager.nextEpisodeLocalFile.IsPresent())
	})
}

func TestPlaybackManagerUnitStartPlayingAndStreamingValidation(t *testing.T) {
	t.Run("local playback fails if collection refresh fails", func(t *testing.T) {
		// this should stop before touching the media player when collection loading fails.
		h := newPlaybackManagerTestWrapper(t)
		h.platform = testmocks.NewFakePlatformBuilder().WithAnimeCollectionError(errors.New("collection failed")).Build()
		h.playbackManager.platformRef = util.NewRef[platform.Platform](h.platform)

		err := h.playbackManager.StartPlayingUsingMediaPlayer(&StartPlayingOptions{Payload: "/Anime/Frieren/1.mkv"})
		require.EqualError(t, err, "collection failed")
	})

	t.Run("stream playback blocks offline mode", func(t *testing.T) {
		// offline mode is a hard stop even when the caller passed a media and episode.
		h := newPlaybackManagerTestWrapper(t)
		h.playbackManager.isOfflineRef.Set(true)

		err := h.playbackManager.StartStreamingUsingMediaPlayer("stream", &StartPlayingOptions{Payload: "https://example.com"}, testmocks.NewBaseAnime(154587, "Frieren"), "1")
		require.EqualError(t, err, "cannot stream when offline")
		require.True(t, h.playbackManager.currentStreamMedia.IsAbsent())
	})

	t.Run("stream playback rejects missing data", func(t *testing.T) {
		// callers need to provide both the media and the anidb episode before we can track a stream.
		media := testmocks.NewBaseAnime(154587, "Frieren")
		h := newPlaybackManagerTestWrapper(t)

		err := h.playbackManager.StartStreamingUsingMediaPlayer("stream", &StartPlayingOptions{Payload: "https://example.com"}, nil, "1")
		require.EqualError(t, err, "cannot start streaming, not enough data provided")

		err = h.playbackManager.StartStreamingUsingMediaPlayer("stream", &StartPlayingOptions{Payload: "https://example.com"}, media, "")
		require.EqualError(t, err, "cannot start streaming, not enough data provided")
	})
}

func TestPlaybackManagerUnitLocalPlaybackStatusAndProgressTracking(t *testing.T) {
	// this drives the local-file tracking handlers directly so state changes and progress syncing stay covered.
	h := newPlaybackManagerTestWrapper(t)
	h.seedAutoUpdateProgress(t, true)

	media := testmocks.NewBaseAnimeBuilder(154587, "Frieren").
		WithUserPreferredTitle("Frieren").
		WithEpisodes(12).
		Build()
	localFiles := anime.NewTestLocalFiles(anime.TestLocalFileGroup{
		LibraryPath:      "/Anime",
		FilePathTemplate: "/Anime/Frieren/%ep.mkv",
		MediaID:          media.ID,
		Episodes: []anime.TestLocalFileEpisode{
			{Episode: 1, AniDBEpisode: "1", Type: anime.LocalFileTypeMain},
			{Episode: 2, AniDBEpisode: "2", Type: anime.LocalFileTypeMain},
			{Episode: 3, AniDBEpisode: "3", Type: anime.LocalFileTypeMain},
		},
	})
	wrapper := anime.NewLocalFileWrapper(localFiles)
	wrapperEntry, ok := wrapper.GetLocalEntryById(media.ID)
	require.True(t, ok)

	h.playbackManager.currentMediaListEntry = mo.Some(&anilist.AnimeListEntry{
		Media:    media,
		Progress: new(1),
	})
	h.playbackManager.currentLocalFile = mo.Some(localFiles[1])
	h.playbackManager.currentLocalFileWrapperEntry = mo.Some(wrapperEntry)
	subscriber := h.playbackManager.SubscribeToPlaybackStatus("unit-local")

	status := &mediaplayer.PlaybackStatus{
		Filename:             "2.mkv",
		Filepath:             localFiles[1].Path,
		CompletionPercentage: 0.5,
		CurrentTimeInSeconds: 600,
		DurationInSeconds:    1200,
		PlaybackType:         mediaplayer.PlaybackTypeFile,
	}

	h.playbackManager.handlePlaybackStatus(status)

	changedEvent := expectPlaybackEvent[PlaybackStatusChangedEvent](t, subscriber.EventCh)
	require.Equal(t, 2, changedEvent.State.EpisodeNumber)
	require.Equal(t, "2", changedEvent.State.AniDbEpisode)
	require.Equal(t, media.ID, changedEvent.State.MediaId)
	require.True(t, changedEvent.State.CanPlayNext)
	require.False(t, changedEvent.State.ProgressUpdated)
	require.Equal(t, events.PlaybackManagerProgressPlaybackState, h.wsEventManager.lastType())

	completedStatus := &mediaplayer.PlaybackStatus{
		Filename:             "2.mkv",
		Filepath:             localFiles[1].Path,
		CompletionPercentage: 1,
		CurrentTimeInSeconds: 1200,
		DurationInSeconds:    1200,
		PlaybackType:         mediaplayer.PlaybackTypeFile,
	}
	h.playbackManager.handleVideoCompleted(completedStatus)

	completedChanged := expectPlaybackEvent[PlaybackStatusChangedEvent](t, subscriber.EventCh)
	require.Equal(t, 2, completedChanged.State.EpisodeNumber)
	completedEvent := expectPlaybackEvent[VideoCompletedEvent](t, subscriber.EventCh)
	require.Equal(t, "2.mkv", completedEvent.Filename)

	progressCalls := h.platform.UpdateEntryProgressCalls()
	require.Len(t, progressCalls, 1)
	require.Equal(t, media.ID, progressCalls[0].MediaID)
	require.Equal(t, 2, progressCalls[0].Progress)
	require.NotNil(t, progressCalls[0].TotalEpisodes)
	require.Equal(t, 12, *progressCalls[0].TotalEpisodes)
	require.True(t, h.playbackManager.historyMap["2.mkv"].ProgressUpdated)
	require.Equal(t, events.PlaybackManagerProgressVideoCompleted, h.wsEventManager.lastType())
	require.Equal(t, 1, h.wsEventManager.count(events.PlaybackManagerProgressUpdated))

	h.playbackManager.handleTrackingStopped("closed")

	stoppedEvent := expectPlaybackEvent[VideoStoppedEvent](t, subscriber.EventCh)
	require.Equal(t, "closed", stoppedEvent.Reason)
	require.True(t, h.playbackManager.nextEpisodeLocalFile.IsPresent())
	require.Same(t, localFiles[2], h.playbackManager.nextEpisodeLocalFile.MustGet())
	require.Equal(t, events.PlaybackManagerProgressTrackingStopped, h.wsEventManager.lastType())
}

func TestPlaybackManagerTrackingStartedUsesNewLocalFileState(t *testing.T) {
	// the first status event for a new file should use the new file's metadata, not whatever was playing before.
	h := newPlaybackManagerTestWrapper(t)

	oldMedia := testmocks.NewBaseAnimeBuilder(130003, "Bocchi the Rock!").
		WithUserPreferredTitle("Bocchi the Rock!").
		WithEpisodes(12).
		Build()
	newMedia := testmocks.NewBaseAnimeBuilder(166617, "Fate/strange Fake").
		WithUserPreferredTitle("Fate/strange Fake").
		WithEpisodes(13).
		Build()

	oldFiles := anime.NewTestLocalFiles(anime.TestLocalFileGroup{
		LibraryPath:      "/Anime",
		FilePathTemplate: "/Anime/Bocchi/%ep.mkv",
		MediaID:          oldMedia.ID,
		Episodes: []anime.TestLocalFileEpisode{
			{Episode: 10, AniDBEpisode: "10", Type: anime.LocalFileTypeMain},
		},
	})
	newFiles := anime.NewTestLocalFiles(anime.TestLocalFileGroup{
		LibraryPath:      "/Anime",
		FilePathTemplate: "/Anime/Fate/%ep.mkv",
		MediaID:          newMedia.ID,
		Episodes: []anime.TestLocalFileEpisode{
			{Episode: 1, AniDBEpisode: "1", Type: anime.LocalFileTypeMain},
			{Episode: 2, AniDBEpisode: "2", Type: anime.LocalFileTypeMain},
		},
	})
	allFiles := append(append([]*anime.LocalFile{}, oldFiles...), newFiles...)

	prevLocalFiles := db_bridge.CurrLocalFiles
	prevLocalFilesDbID := db_bridge.CurrLocalFilesDbId
	_, err := db_bridge.InsertLocalFiles(h.database, allFiles)
	require.NoError(t, err)
	t.Cleanup(func() {
		db_bridge.CurrLocalFiles = prevLocalFiles
		db_bridge.CurrLocalFilesDbId = prevLocalFilesDbID
	})

	wrapper := anime.NewLocalFileWrapper(allFiles)
	oldWrapperEntry, ok := wrapper.GetLocalEntryById(oldMedia.ID)
	require.True(t, ok)

	statusCurrent := anilist.MediaListStatusCurrent
	oldEntry := &anilist.AnimeListEntry{Media: oldMedia, Progress: new(9)}
	newEntry := &anilist.AnimeListEntry{Media: newMedia, Progress: new(0)}
	h.playbackManager.SetAnimeCollection(&anilist.AnimeCollection{
		MediaListCollection: &anilist.AnimeCollection_MediaListCollection{
			Lists: []*anilist.AnimeCollection_MediaListCollection_Lists{{
				Status: new(statusCurrent),
				Entries: []*anilist.AnimeCollection_MediaListCollection_Lists_Entries{
					oldEntry,
					newEntry,
				},
			}},
		},
	})

	h.playbackManager.currentMediaListEntry = mo.Some(oldEntry)
	h.playbackManager.currentLocalFile = mo.Some(oldFiles[0])
	h.playbackManager.currentLocalFileWrapperEntry = mo.Some(oldWrapperEntry)

	subscriber := h.playbackManager.SubscribeToPlaybackStatus("unit-local-start")
	status := &mediaplayer.PlaybackStatus{
		Filename:             newFiles[0].Name,
		Filepath:             newFiles[0].Path,
		CompletionPercentage: 0.001,
		CurrentTimeInSeconds: 1,
		DurationInSeconds:    1200,
		PlaybackType:         mediaplayer.PlaybackTypeFile,
	}

	h.playbackManager.handleTrackingStarted(status)

	changedEvent := expectPlaybackEvent[PlaybackStatusChangedEvent](t, subscriber.EventCh)
	require.Equal(t, 1, changedEvent.State.EpisodeNumber)
	require.Equal(t, "1", changedEvent.State.AniDbEpisode)
	require.Equal(t, newMedia.ID, changedEvent.State.MediaId)
	require.Equal(t, newMedia.GetPreferredTitle(), changedEvent.State.MediaTitle)
	require.Equal(t, newFiles[0].Name, changedEvent.State.Filename)
	require.True(t, changedEvent.State.CanPlayNext)

	startedEvent := expectPlaybackEvent[VideoStartedEvent](t, subscriber.EventCh)
	require.Equal(t, newFiles[0].Name, startedEvent.Filename)
	require.Equal(t, newFiles[0].Path, startedEvent.Filepath)
	require.Same(t, newEntry, h.playbackManager.currentMediaListEntry.MustGet())
	require.Same(t, newFiles[0], h.playbackManager.currentLocalFile.MustGet())
	require.Equal(t, events.PlaybackManagerProgressTrackingStarted, h.wsEventManager.lastType())
}

func TestPlaybackManagerUnitStreamPlaybackStatusAndProgressTracking(t *testing.T) {
	// this covers the stream tracking handlers, including progress sync when a streamed episode completes.
	h := newPlaybackManagerTestWrapper(t)
	h.seedAutoUpdateProgress(t, true)

	media := testmocks.NewBaseAnimeBuilder(201, "Dungeon Meshi").
		WithUserPreferredTitle("Dungeon Meshi").
		WithEpisodes(24).
		Build()
	entry := &anilist.AnimeListEntry{Media: media, Progress: new(1)}
	collection := newAnimeCollection(media, entry, anilist.MediaListStatusCurrent)
	h.playbackManager.SetAnimeCollection(collection)
	h.playbackManager.currentStreamMedia = mo.Some(media)
	h.playbackManager.currentStreamEpisode = mo.Some(&anime.Episode{EpisodeNumber: 2, ProgressNumber: 2, AniDBEpisode: "2"})
	h.playbackManager.currentStreamAniDbEpisode = mo.Some("2")
	subscriber := h.playbackManager.SubscribeToPlaybackStatus("unit-stream")

	startedStatus := &mediaplayer.PlaybackStatus{
		Filename:             "Stream",
		Filepath:             "https://example.com/stream/2",
		CompletionPercentage: 0.1,
		CurrentTimeInSeconds: 60,
		DurationInSeconds:    1500,
		PlaybackType:         mediaplayer.PlaybackTypeStream,
	}
	h.playbackManager.handleStreamingTrackingStarted(startedStatus)

	startedChanged := expectPlaybackEvent[PlaybackStatusChangedEvent](t, subscriber.EventCh)
	require.Equal(t, 2, startedChanged.State.EpisodeNumber)
	require.Equal(t, media.ID, startedChanged.State.MediaId)
	startedEvent := expectPlaybackEvent[StreamStartedEvent](t, subscriber.EventCh)
	require.Equal(t, "Stream", startedEvent.Filename)
	require.True(t, h.playbackManager.currentMediaListEntry.IsPresent())
	require.Equal(t, events.PlaybackManagerProgressTrackingStarted, h.wsEventManager.lastType())

	status := &mediaplayer.PlaybackStatus{
		Filename:             "Stream",
		Filepath:             "https://example.com/stream/2",
		CompletionPercentage: 0.5,
		CurrentTimeInSeconds: 750,
		DurationInSeconds:    1500,
		Playing:              true,
		PlaybackType:         mediaplayer.PlaybackTypeStream,
	}
	h.playbackManager.handleStreamingPlaybackStatus(status)

	streamChanged := expectPlaybackEvent[PlaybackStatusChangedEvent](t, subscriber.EventCh)
	require.Equal(t, 2, streamChanged.State.EpisodeNumber)
	require.Equal(t, events.PlaybackManagerProgressPlaybackState, h.wsEventManager.lastType())

	completedStatus := &mediaplayer.PlaybackStatus{
		Filename:             "Stream",
		Filepath:             "https://example.com/stream/2",
		CompletionPercentage: 1,
		CurrentTimeInSeconds: 1500,
		DurationInSeconds:    1500,
		PlaybackType:         mediaplayer.PlaybackTypeStream,
	}
	h.playbackManager.handleStreamingVideoCompleted(completedStatus)

	completedChanged := expectPlaybackEvent[PlaybackStatusChangedEvent](t, subscriber.EventCh)
	require.Equal(t, 2, completedChanged.State.EpisodeNumber)
	completedEvent := expectPlaybackEvent[StreamCompletedEvent](t, subscriber.EventCh)
	require.Equal(t, "Stream", completedEvent.Filename)

	progressCalls := h.platform.UpdateEntryProgressCalls()
	require.Len(t, progressCalls, 1)
	require.Equal(t, media.ID, progressCalls[0].MediaID)
	require.Equal(t, 2, progressCalls[0].Progress)
	require.NotNil(t, progressCalls[0].TotalEpisodes)
	require.Equal(t, 24, *progressCalls[0].TotalEpisodes)
	require.True(t, h.playbackManager.historyMap["Stream"].ProgressUpdated)
	require.Equal(t, 1, h.wsEventManager.count(events.PlaybackManagerProgressUpdated))

	h.playbackManager.handleStreamingTrackingStopped("finished")

	stoppedEvent := expectPlaybackEvent[StreamStoppedEvent](t, subscriber.EventCh)
	require.Equal(t, "finished", stoppedEvent.Reason)
	require.Equal(t, events.PlaybackManagerProgressTrackingStopped, h.wsEventManager.lastType())
}

func TestPlaybackManagerUnitManualProgressTrackingSyncsProgress(t *testing.T) {
	// manual tracking should hold the current episode in memory and sync it when the user asks for it.
	h := newPlaybackManagerTestWrapper(t)

	media := testmocks.NewBaseAnimeBuilder(909, "Orb").
		WithUserPreferredTitle("Orb").
		WithEpisodes(25).
		Build()
	entry := &anilist.AnimeListEntry{Media: media, Progress: new(4)}
	h.platform = testmocks.NewFakePlatformBuilder().WithAnimeCollection(newAnimeCollection(media, entry, anilist.MediaListStatusCurrent)).Build()
	h.playbackManager.platformRef = util.NewRef[platform.Platform](h.platform)

	err := h.playbackManager.StartManualProgressTracking(&StartManualProgressTrackingOptions{
		ClientId:      "unit",
		MediaId:       media.ID,
		EpisodeNumber: 5,
	})
	require.NoError(t, err)
	require.Equal(t, ManualTrackingPlayback, h.playbackManager.currentPlaybackType)
	require.True(t, h.playbackManager.currentManualTrackingState.IsPresent())
	require.Equal(t, 4, h.playbackManager.currentManualTrackingState.MustGet().CurrentProgress)
	require.Equal(t, 25, h.playbackManager.currentManualTrackingState.MustGet().TotalEpisodes)
	require.Eventually(t, func() bool {
		return h.wsEventManager.count(events.PlaybackManagerManualTrackingPlaybackState) > 0
	}, time.Second, 10*time.Millisecond)

	err = h.playbackManager.SyncCurrentProgress()
	require.NoError(t, err)

	progressCalls := h.platform.UpdateEntryProgressCalls()
	require.Len(t, progressCalls, 1)
	require.Equal(t, media.ID, progressCalls[0].MediaID)
	require.Equal(t, 5, progressCalls[0].Progress)
	require.NotNil(t, progressCalls[0].TotalEpisodes)
	require.Equal(t, 25, *progressCalls[0].TotalEpisodes)
	require.Equal(t, 2, h.refreshCalls)

	h.playbackManager.CancelManualProgressTracking()
	require.Eventually(t, func() bool {
		return h.wsEventManager.count(events.PlaybackManagerManualTrackingStopped) == 1
	}, 4*time.Second, 25*time.Millisecond)
	require.True(t, h.playbackManager.currentManualTrackingState.IsAbsent())
}

func TestPlaybackManagerLiveRepositoryEventsReachCallbacks(t *testing.T) {
	// this uses the real repository subscription wiring, but it stays in-memory and never launches a player.
	h := newPlaybackManagerTestWrapper(t)
	repo := mediaplayer.NewRepository(&mediaplayer.NewRepositoryOptions{
		Logger:         util.NewLogger(),
		Default:        "",
		WSEventManager: events.NewMockWSEventManager(util.NewLogger()),
	})

	h.playbackManager.SetMediaPlayerRepository(repo)
	t.Cleanup(func() {
		if h.playbackManager.cancel != nil {
			h.playbackManager.cancel()
		}
	})

	require.Eventually(t, func() bool {
		return h.playbackManager.MediaPlayerRepository == repo && h.playbackManager.mediaPlayerRepoSubscriber != nil
	}, time.Second, 10*time.Millisecond)

	received := make(chan PlaybackErrorEvent, 1)
	h.playbackManager.RegisterMediaPlayerCallback(func(event PlaybackEvent) bool {
		playbackError, ok := event.(PlaybackErrorEvent)
		if ok {
			received <- playbackError
		}
		return false
	})

	h.playbackManager.mediaPlayerRepoSubscriber.EventCh <- mediaplayer.TrackingRetryEvent{Reason: "player unreachable"}

	select {
	case event := <-received:
		require.Equal(t, "player unreachable", event.Reason)
	case <-time.After(time.Second):
		t.Fatal("callback did not receive repository event")
	}
}

func TestPlaybackManagerLiveRepositoryStreamCompletionSyncsProgress(t *testing.T) {
	// this exercises the real repository subscription loop and proves stream completion can drive a progress sync.
	h := newPlaybackManagerTestWrapper(t)
	h.seedAutoUpdateProgress(t, true)
	media := testmocks.NewBaseAnimeBuilder(700, "Lazarus").
		WithUserPreferredTitle("Lazarus").
		WithEpisodes(13).
		Build()
	h.playbackManager.SetAnimeCollection(newAnimeCollection(media, &anilist.AnimeListEntry{
		Media:    media,
		Progress: new(0),
	}, anilist.MediaListStatusCurrent))
	h.playbackManager.currentStreamMedia = mo.Some(media)
	h.playbackManager.currentStreamEpisode = mo.Some(&anime.Episode{EpisodeNumber: 1, ProgressNumber: 1, AniDBEpisode: "1"})
	h.playbackManager.currentStreamAniDbEpisode = mo.Some("1")

	repo := mediaplayer.NewRepository(&mediaplayer.NewRepositoryOptions{
		Logger:         util.NewLogger(),
		Default:        "",
		WSEventManager: events.NewMockWSEventManager(util.NewLogger()),
	})

	h.playbackManager.SetMediaPlayerRepository(repo)
	t.Cleanup(func() {
		if h.playbackManager.cancel != nil {
			h.playbackManager.cancel()
		}
	})

	require.Eventually(t, func() bool {
		return h.playbackManager.MediaPlayerRepository == repo && h.playbackManager.mediaPlayerRepoSubscriber != nil
	}, time.Second, 10*time.Millisecond)

	h.playbackManager.mediaPlayerRepoSubscriber.EventCh <- mediaplayer.StreamingTrackingStartedEvent{Status: &mediaplayer.PlaybackStatus{
		Filename:             "Stream",
		Filepath:             "https://example.com/stream/1",
		CompletionPercentage: 0.1,
		CurrentTimeInSeconds: 60,
		DurationInSeconds:    1500,
		PlaybackType:         mediaplayer.PlaybackTypeStream,
	}}
	h.playbackManager.mediaPlayerRepoSubscriber.EventCh <- mediaplayer.StreamingVideoCompletedEvent{Status: &mediaplayer.PlaybackStatus{
		Filename:             "Stream",
		Filepath:             "https://example.com/stream/1",
		CompletionPercentage: 1,
		CurrentTimeInSeconds: 1500,
		DurationInSeconds:    1500,
		PlaybackType:         mediaplayer.PlaybackTypeStream,
	}}

	require.Eventually(t, func() bool {
		calls := h.platform.UpdateEntryProgressCalls()
		return len(calls) == 1 && calls[0].MediaID == media.ID && calls[0].Progress == 1
	}, time.Second, 10*time.Millisecond)
	require.True(t, h.playbackManager.historyMap["Stream"].ProgressUpdated)
}

type playbackManagerTestWrapper struct {
	database        *db.Database
	wsEventManager  *recordingWSEventManager
	refreshCalls    int
	platform        *testmocks.FakePlatform
	playbackManager *PlaybackManager
}

func newPlaybackManagerTestWrapper(t *testing.T) *playbackManagerTestWrapper {
	t.Helper()

	env := testutil.NewTestEnv(t)
	logger := util.NewLogger()
	database := env.MustNewDatabase(logger)
	wsEventManager := &recordingWSEventManager{MockWSEventManager: events.NewMockWSEventManager(logger)}
	continuityManager := continuity.NewManager(&continuity.NewManagerOptions{
		FileCacher: env.NewCacher("continuity"),
		Logger:     logger,
		Database:   database,
	})
	continuityManager.SetSettings(&continuity.Settings{WatchContinuityEnabled: true})
	platformImpl := testmocks.NewFakePlatformBuilder().Build()
	platformInterface := platform.Platform(platformImpl)
	var provider metadata_provider.Provider

	h := &playbackManagerTestWrapper{
		database:       database,
		wsEventManager: wsEventManager,
		platform:       platformImpl,
	}
	h.playbackManager = New(&NewPlaybackManagerOptions{
		Logger:              logger,
		WSEventManager:      wsEventManager,
		PlatformRef:         util.NewRef(platformInterface),
		MetadataProviderRef: util.NewRef(provider),
		Database:            database,
		RefreshAnimeCollectionFunc: func() {
			h.refreshCalls++
		},
		ContinuityManager: continuityManager,
		IsOfflineRef:      util.NewRef(false),
	})

	h.seedAutoUpdateProgress(t, false)
	return h
}

func (h *playbackManagerTestWrapper) seedAutoUpdateProgress(t *testing.T, enabled bool) {
	t.Helper()

	_, err := h.database.UpsertSettings(&models.Settings{
		BaseModel: models.BaseModel{ID: 1},
		Library: &models.LibrarySettings{
			AutoUpdateProgress: enabled,
		},
	})
	require.NoError(t, err)
}

type recordingWSEventManager struct {
	*events.MockWSEventManager
	mu     sync.Mutex
	events []events.MockWSEvent
}

func (m *recordingWSEventManager) SendEvent(t string, payload interface{}) {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.events = append(m.events, events.MockWSEvent{Type: t, Payload: payload})
}

func (m *recordingWSEventManager) count(eventType string) int {
	m.mu.Lock()
	defer m.mu.Unlock()

	count := 0
	for _, event := range m.events {
		if event.Type == eventType {
			count++
		}
	}
	return count
}

func (m *recordingWSEventManager) lastType() string {
	m.mu.Lock()
	defer m.mu.Unlock()

	if len(m.events) == 0 {
		return ""
	}
	return m.events[len(m.events)-1].Type
}

func newAnimeCollection(media *anilist.BaseAnime, entry *anilist.AnimeListEntry, status anilist.MediaListStatus) *anilist.AnimeCollection {
	entry.Status = new(status)
	entry.Media = media
	return &anilist.AnimeCollection{
		MediaListCollection: &anilist.AnimeCollection_MediaListCollection{
			Lists: []*anilist.AnimeCollection_MediaListCollection_Lists{{
				Status:  new(status),
				Entries: []*anilist.AnimeCollection_MediaListCollection_Lists_Entries{entry},
			}},
		},
	}
}

func expectPlaybackEvent[T PlaybackEvent](t *testing.T, ch <-chan PlaybackEvent) T {
	t.Helper()

	select {
	case event := <-ch:
		typed, ok := event.(T)
		if !ok {
			t.Fatalf("unexpected playback event type %T", event)
		}
		return typed
	case <-time.After(time.Second):
		var zero T
		t.Fatal("timed out waiting for playback event")
		return zero
	}
}
