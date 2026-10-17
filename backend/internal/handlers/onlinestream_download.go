package handlers

import (
	"errors"
	"seanime/internal/onlinestream"

	"github.com/labstack/echo/v4"
)

// HandleStartOnlinestreamDownload
//
//	@summary starts downloading an online stream episode directly on the server host.
//	@desc Queues and downloads an online stream episode into the local anime library using ffmpeg.
//	@route /api/v1/onlinestream/download [POST]
//	@returns onlinestream.DownloadTask
func (h *Handler) HandleStartOnlinestreamDownload(c echo.Context) error {
	type body struct {
		MediaID       int                      `json:"mediaId"`
		EpisodeNumber int                      `json:"episodeNumber"`
		AnimeTitle    string                   `json:"animeTitle"`
		EpisodeTitle  string                   `json:"episodeTitle"`
		Thumbnail     string                   `json:"thumbnail,omitempty"`
		ProviderID    string                   `json:"providerId"`
		ProviderName  string                   `json:"providerName"`
		Server        string                   `json:"server"`
		Quality       string                   `json:"quality"`
		VideoURL      string                   `json:"videoUrl"`
		Headers       map[string]string         `json:"headers,omitempty"`
		IsHLS         bool                     `json:"isHls"`
		Destination   string                   `json:"destination,omitempty"`
		Subtitles     []*onlinestream.Subtitle `json:"subtitles,omitempty"`
	}

	var b body
	if err := c.Bind(&b); err != nil {
		return h.RespondWithError(c, err)
	}

	if b.VideoURL == "" {
		return h.RespondWithError(c, errors.New("videoUrl is required"))
	}
	if b.MediaID <= 0 {
		return h.RespondWithError(c, errors.New("invalid mediaId"))
	}

	if b.Destination != "" {
		if err := h.guardStrictFilesystemPath(c, b.Destination); err != nil {
			return err
		}
	}

	if h.App.OnlinestreamDownloader == nil {
		return h.RespondWithError(c, errors.New("onlinestream downloader not initialized"))
	}

	task, err := h.App.OnlinestreamDownloader.StartDownload(onlinestream.StartDownloadOptions{
		MediaID:       b.MediaID,
		EpisodeNumber: b.EpisodeNumber,
		AnimeTitle:    b.AnimeTitle,
		EpisodeTitle:  b.EpisodeTitle,
		Thumbnail:     b.Thumbnail,
		ProviderID:    b.ProviderID,
		ProviderName:  b.ProviderName,
		Server:        b.Server,
		Quality:       b.Quality,
		VideoURL:      b.VideoURL,
		Headers:       b.Headers,
		IsHLS:         b.IsHLS,
		Destination:   b.Destination,
		Subtitles:     b.Subtitles,
	})
	if err != nil {
		return h.RespondWithError(c, err)
	}

	return h.RespondWithData(c, task)
}

// HandleGetOnlinestreamDownloadQueue
//
//	@summary returns the current onlinestream download tasks and their progress.
//	@route /api/v1/onlinestream/download-queue [GET]
//	@returns []*onlinestream.DownloadTask
func (h *Handler) HandleGetOnlinestreamDownloadQueue(c echo.Context) error {
	if h.App.OnlinestreamDownloader == nil {
		return h.RespondWithData(c, []*onlinestream.DownloadTask{})
	}

	queue := h.App.OnlinestreamDownloader.GetQueue()
	return h.RespondWithData(c, queue)
}

// HandleCancelOnlinestreamDownload
//
//	@summary cancels an ongoing or queued onlinestream download.
//	@route /api/v1/onlinestream/download-queue/:id [DELETE]
//	@returns bool
func (h *Handler) HandleCancelOnlinestreamDownload(c echo.Context) error {
	id := c.Param("id")
	if id == "" {
		type body struct {
			ID string `json:"id"`
		}
		var b body
		if err := c.Bind(&b); err == nil && b.ID != "" {
			id = b.ID
		}
	}

	if id == "" {
		return h.RespondWithError(c, errors.New("task id is required"))
	}

	if h.App.OnlinestreamDownloader == nil {
		return h.RespondWithError(c, errors.New("onlinestream downloader not initialized"))
	}

	if err := h.App.OnlinestreamDownloader.CancelDownload(id); err != nil {
		return h.RespondWithError(c, err)
	}

	return h.RespondWithData(c, true)
}

// HandleClearCompletedOnlinestreamDownloads
//
//	@summary clears completed, cancelled, or failed onlinestream tasks from memory.
//	@route /api/v1/onlinestream/download-queue/clear [POST]
//	@returns bool
func (h *Handler) HandleClearCompletedOnlinestreamDownloads(c echo.Context) error {
	if h.App.OnlinestreamDownloader != nil {
		h.App.OnlinestreamDownloader.ClearCompleted()
	}
	return h.RespondWithData(c, true)
}
