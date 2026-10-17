package onlinestream

import (
	"testing"

	"github.com/rs/zerolog"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestDownloaderTaskValidationAndQueue(t *testing.T) {
	logger := zerolog.Nop()
	downloader := NewDownloader(&NewDownloaderOptions{
		Logger: &logger,
		GetLibraryPath: func() string {
			return "/fake/library"
		},
	})

	// 1. Missing video URL should fail
	_, err := downloader.StartDownload(StartDownloadOptions{
		MediaID:       10,
		EpisodeNumber: 1,
		AnimeTitle:    "Test Anime",
		VideoURL:      "",
	})
	require.ErrorIs(t, err, ErrNoVideoURL)

	// 2. Queue empty initially
	queue := downloader.GetQueue()
	assert.Empty(t, queue)

	// 3. Clean filename sanitize
	assert.Equal(t, "My_Hero_Academia", sanitizeName("My:Hero/Academia?"))
}

func TestDownloaderClearCompleted(t *testing.T) {
	logger := zerolog.Nop()
	downloader := NewDownloader(&NewDownloaderOptions{
		Logger: &logger,
	})

	downloader.tasks["10_1"] = &DownloadTask{
		ID:     "10_1",
		Status: DownloadStatusCompleted,
	}
	downloader.tasks["10_2"] = &DownloadTask{
		ID:     "10_2",
		Status: DownloadStatusCancelled,
	}
	downloader.tasks["10_3"] = &DownloadTask{
		ID:     "10_3",
		Status: DownloadStatusDownloading,
	}

	downloader.ClearCompleted()

	queue := downloader.GetQueue()
	assert.Len(t, queue, 1)
	assert.Equal(t, "10_3", queue[0].ID)
}
