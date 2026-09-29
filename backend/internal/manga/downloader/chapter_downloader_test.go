package chapter_downloader

import (
	"bytes"
	"image"
	"image/color"
	"image/png"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"testing"

	"seanime/internal/database/db"
	"seanime/internal/events"
	hibikemanga "seanime/internal/extension/hibike/manga"
	"seanime/internal/testutil"

	"github.com/goccy/go-json"
	"github.com/stretchr/testify/require"
)

func newTestDownloader(t *testing.T) (*Downloader, *db.Database, string) {
	t.Helper()

	env := testutil.NewTestEnv(t)
	logger := env.Logger()
	database := env.MustNewDatabase(logger)
	downloadDir := env.MustMkdir("downloads")

	downloader := NewDownloader(&NewDownloaderOptions{
		Logger:         logger,
		WSEventManager: events.NewMockWSEventManager(logger),
		Database:       database,
		DownloadDir:    downloadDir,
	})

	return downloader, database, downloadDir
}

func newTestPNG(t *testing.T) []byte {
	t.Helper()

	var buf bytes.Buffer
	img := image.NewRGBA(image.Rect(0, 0, 1, 1))
	img.Set(0, 0, color.RGBA{R: 255, G: 128, B: 64, A: 255})
	require.NoError(t, png.Encode(&buf, img))

	return buf.Bytes()
}

func TestQueueAddsItemToDatabase(t *testing.T) {
	downloader, database, _ := newTestDownloader(t)

	pages := []*hibikemanga.ChapterPage{{
		Index: 0,
		URL:   "https://example.com/01.png",
	}}
	id := DownloadID{
		Provider:      "test-provider",
		MediaId:       101517,
		ChapterId:     "chapter-1",
		ChapterNumber: "1",
	}

	err := downloader.AddToQueue(DownloadOptions{
		DownloadID: id,
		Pages:      pages,
		StartNow:   false,
	})
	require.NoError(t, err)

	next, err := database.GetNextChapterDownloadQueueItem()
	require.NoError(t, err)
	require.NotNil(t, next)
	require.Equal(t, id.Provider, next.Provider)
	require.Equal(t, id.MediaId, next.MediaID)
	require.Equal(t, id.ChapterId, next.ChapterID)
	require.Equal(t, id.ChapterNumber, next.ChapterNumber)
	require.Equal(t, string(QueueStatusNotStarted), next.Status)
	require.NotEmpty(t, next.PageData)
}

func TestDownloadChapterImagesWritesRegistry(t *testing.T) {
	downloader, database, downloadDir := newTestDownloader(t)

	imageData := newTestPNG(t)
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "image/png")
		_, _ = w.Write(imageData)
	}))
	defer server.Close()

	pages := []*hibikemanga.ChapterPage{{
		Index: 0,
		URL:   server.URL + "/page.png",
	}}
	id := DownloadID{
		Provider:      "test-provider",
		MediaId:       101517,
		ChapterId:     "chapter-1",
		ChapterNumber: "1",
	}

	err := downloader.AddToQueue(DownloadOptions{
		DownloadID: id,
		Pages:      pages,
		StartNow:   false,
	})
	require.NoError(t, err)

	require.NoError(t, database.UpdateChapterDownloadQueueItemStatus(id.Provider, id.MediaId, id.ChapterId, string(QueueStatusDownloading)))
	downloader.queue.current = &QueueInfo{
		DownloadID: id,
		Pages:      pages,
		Status:     QueueStatusDownloading,
	}

	err = downloader.downloadChapterImages(downloader.queue.current)
	require.NoError(t, err)

	chapterDir := filepath.Join(downloadDir, FormatChapterDirName(id.Provider, id.MediaId, id.ChapterId, id.ChapterNumber))
	registryPath := filepath.Join(chapterDir, "registry.json")
	registryBytes, err := os.ReadFile(registryPath)
	require.NoError(t, err)

	var registry Registry
	require.NoError(t, json.Unmarshal(registryBytes, &registry))
	require.Len(t, registry, 1)
	pageInfo, ok := registry[0]
	require.True(t, ok)
	require.Equal(t, "01.png", pageInfo.Filename)
	require.Equal(t, server.URL+"/page.png", pageInfo.OriginalURL)

	_, err = os.Stat(filepath.Join(chapterDir, pageInfo.Filename))
	require.NoError(t, err)

	queueItems, err := database.GetChapterDownloadQueue()
	require.NoError(t, err)
	require.Empty(t, queueItems)
}
