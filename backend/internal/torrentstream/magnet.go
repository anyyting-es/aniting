package torrentstream

import (
	"context"
	"fmt"
	"path"
	"strings"
	"time"

	"seanime/internal/events"
	"seanime/internal/util"

	"github.com/anacrolix/torrent"
	"github.com/samber/mo"
)

// StartMagnetStreamOptions starts a torrent stream from a raw magnet / info hash
// instead of an AniList media. It is used by TMDB sources that return torrent
// metadata (e.g. Torrentio) and therefore have no AniList id or episode mapping.
type StartMagnetStreamOptions struct {
	Magnet       string `json:"magnet,omitempty"`
	InfoHash     string `json:"infoHash,omitempty"`
	FileIndex    *int   `json:"fileIndex,omitempty"`
	FileNameHint string `json:"fileNameHint,omitempty"`
	ClientId     string `json:"clientId,omitempty"`
	UserAgent    string `json:"userAgent,omitempty"`
}

var magnetStreamVideoExts = map[string]struct{}{
	".mkv":  {},
	".mp4":  {},
	".m4v":  {},
	".avi":  {},
	".webm": {},
	".mov":  {},
	".ts":   {},
	".m2ts": {},
	".wmv":  {},
	".flv":  {},
	".ogv":  {},
}

// StartMagnetStream adds a torrent from a magnet link, selects the file to play
// and exposes it through the regular torrentstream HTTP endpoint.
func (r *Repository) StartMagnetStream(ctx context.Context, opts *StartMagnetStreamOptions) (err error) {
	defer util.HandlePanicInModuleWithError("torrentstream/stream/StartMagnetStream", &err)

	var startLaunchTime = time.Now()

	if opts == nil {
		return fmt.Errorf("torrentstream: missing options")
	}

	magnet := strings.TrimSpace(opts.Magnet)
	if magnet == "" {
		infoHash := strings.TrimSpace(opts.InfoHash)
		if infoHash == "" {
			return fmt.Errorf("torrentstream: missing magnet link")
		}
		magnet = "magnet:?xt=urn:btih:" + infoHash
	}
	if !strings.HasPrefix(magnet, "magnet:") {
		return fmt.Errorf("torrentstream: invalid magnet link")
	}

	r.logger.Info().
		Str("clientId", opts.ClientId).
		Str("fileHint", opts.FileNameHint).
		Msg("torrentstream: Starting stream from magnet")

	r.sendStateEvent(eventLoading)
	r.wsEventManager.SendEvent(events.ShowIndefiniteLoader, "torrentstream")
	defer func() {
		r.wsEventManager.SendEvent(events.HideIndefiniteLoader, "torrentstream")
	}()

	r.streamActionMu.Lock()
	defer r.streamActionMu.Unlock()

	r.playback.currentVideoDuration = 0

	selectedTorrent, err := r.client.AddTorrent(ctx, magnet)
	if err != nil {
		r.sendStateEvent(eventLoadingFailed)
		return fmt.Errorf("torrentstream: failed to add torrent: %w", err)
	}

	file := selectMagnetStreamFile(selectedTorrent.Files(), opts.FileIndex, opts.FileNameHint)
	if file == nil {
		selectedTorrent.Drop()
		r.sendStateEvent(eventLoadingFailed)
		return fmt.Errorf("torrentstream: no playable file found in torrent")
	}

	for _, f := range selectedTorrent.Files() {
		if f != file {
			f.SetPriority(torrent.PiecePriorityNone)
		}
	}
	file.Download()
	r.setPriorityDownloadStrategy(selectedTorrent, file)

	r.client.currentFile = mo.Some(file)
	r.client.currentTorrent = mo.Some(selectedTorrent)
	r.client.ResetBaselines()
	r.resetPreloadFlag()
	r.client.cleanupActiveTorrentFiles()
	// Drop the previously active torrent now that the new one is current.
	r.client.dropExcessTorrents(selectedTorrent.InfoHash())

	if settings, ok := r.settings.Get(); ok && settings.AutoDeletePreviousTorrents {
		infoHash := selectedTorrent.InfoHash()
		r.client.purgeInactiveTorrentFolders(infoHash)
	}

	// Wait for the first pieces before returning. Media players open the stream
	// immediately after this call; if the endpoint has no data yet, the player's
	// network probe can time out and give up on the torrent.
	waitCtx, cancelWait := context.WithTimeout(ctx, 30*time.Second)
	readyTime, waitErr := r.waitForReadyToStream(waitCtx, "", false, startLaunchTime)
	cancelWait()
	if waitErr != nil {
		r.logger.Warn().Err(waitErr).Msg("torrentstream: magnet stream is not ready yet, starting anyway")
	} else {
		r.logDiagnostics(startLaunchTime, 0, 0, readyTime)
	}

	r.sendStateEvent(eventTorrentLoaded)
	r.sendStateEvent(eventTorrentStartedPlaying)

	r.logger.Info().
		Str("torrent", selectedTorrent.Name()).
		Str("file", file.DisplayPath()).
		Msg("torrentstream: Magnet stream ready")

	return nil
}

// selectMagnetStreamFile picks the file to stream inside a torrent.
// The explicit file index wins, then the filename hint, then the largest video.
func selectMagnetStreamFile(files []*torrent.File, fileIndex *int, nameHint string) *torrent.File {
	if len(files) == 0 {
		return nil
	}

	if fileIndex != nil && *fileIndex >= 0 && *fileIndex < len(files) {
		return files[*fileIndex]
	}

	hint := strings.ToLower(strings.TrimSpace(nameHint))
	if hint != "" {
		for _, f := range files {
			displayPath := strings.ToLower(f.DisplayPath())
			if displayPath == hint ||
				strings.HasSuffix(displayPath, "/"+hint) ||
				strings.ToLower(path.Base(displayPath)) == hint {
				return f
			}
		}
	}

	var bestVideo *torrent.File
	for _, f := range files {
		if !isMagnetStreamVideoFile(f.DisplayPath()) {
			continue
		}
		if bestVideo == nil || f.Length() > bestVideo.Length() {
			bestVideo = f
		}
	}
	if bestVideo != nil {
		return bestVideo
	}

	var largest *torrent.File
	for _, f := range files {
		if largest == nil || f.Length() > largest.Length() {
			largest = f
		}
	}
	return largest
}

func isMagnetStreamVideoFile(displayPath string) bool {
	ext := strings.ToLower(path.Ext(displayPath))
	_, ok := magnetStreamVideoExts[ext]
	return ok
}
