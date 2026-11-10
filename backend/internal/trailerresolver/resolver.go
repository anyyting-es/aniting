// Package trailerresolver resolves YouTube trailer URLs into directly playable
// media URLs.
//
// YouTube does not serve a watch page as media: both ExoPlayer and libmpv need a
// real stream URL. Resolution is delegated to the `yt-dlp` binary (the only
// implementation that keeps up with YouTube's SABR / PO-token changes), and the
// result is cached per video id because the resolved URLs stay valid for hours.
//
// One single `yt-dlp -J` extraction yields every format, so the cost (~6-8s
// cold) is paid once and the caller gets:
//
//   - Muxed: video+audio in a single URL (360p). Simplest path, works on any
//     engine that cannot merge tracks (ExoPlayer without MergingMediaSource).
//   - Video / Audio: separate tracks for engines that can combine them
//     (libmpv via `audio-add`, Media3 via MergingMediaSource).
package trailerresolver

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"os/exec"
	"regexp"
	"strings"
	"sync"
	"time"
)

// ErrUnavailable reports that no usable yt-dlp binary was found on this host.
// Clients should fall back to the embedded player.
var ErrUnavailable = errors.New("trailer resolver unavailable: yt-dlp not found")

// ErrInvalidVideoID reports a malformed or unsupported YouTube reference.
var ErrInvalidVideoID = errors.New("invalid youtube video id")

const (
	// extractionTimeout bounds a single yt-dlp run.
	extractionTimeout = 60 * time.Second

	// cacheTTL is deliberately shorter than YouTube's own URL lifetime
	// (~6h) so a cached URL is never handed out close to expiring.
	cacheTTL = 60 * time.Minute

	// maxVideoHeight keeps trailers at a sane resolution for a 30s preview
	// while still being watchable full screen.
	maxVideoHeight = 1080
)

// Streams is the resolved, directly playable representation of a trailer.
type Streams struct {
	VideoID string `json:"videoId"`
	Title   string `json:"title"`
	Author  string `json:"author,omitempty"`

	// Duration in seconds.
	Duration int `json:"duration"`

	// MuxedURL carries both video and audio.
	MuxedURL    string `json:"muxedUrl,omitempty"`
	MuxedHeight int    `json:"muxedHeight,omitempty"`

	// VideoURL / AudioURL are separate tracks.
	VideoURL    string `json:"videoUrl,omitempty"`
	VideoHeight int    `json:"videoHeight,omitempty"`
	AudioURL    string `json:"audioUrl,omitempty"`
	AudioCodec  string `json:"audioCodec,omitempty"`

	// ExpiresAt is when the URLs stop being valid.
	ExpiresAt time.Time `json:"expiresAt"`

	// ResolutionMS is how long the extraction took (0 when cached).
	ResolutionMS int64 `json:"resolutionMs"`

	// Cached reports whether this response came from the in-memory cache.
	Cached bool `json:"cached"`
}

type cacheEntry struct {
	streams Streams
	stored  time.Time
}

type ytFormat struct {
	FormatID string  `json:"format_id"`
	URL      string  `json:"url"`
	VCodec   string  `json:"vcodec"`
	ACodec   string  `json:"acodec"`
	Ext      string  `json:"ext"`
	Height   int     `json:"height"`
	ABR      float64 `json:"abr"`
}

type ytDump struct {
	Title    string     `json:"title"`
	Uploader string     `json:"uploader"`
	Duration float64    `json:"duration"`
	Formats  []ytFormat `json:"formats"`
}

// Resolver resolves and caches trailer streams.
type Resolver struct {
	// BinaryPath overrides the yt-dlp executable lookup (tests / bundling).
	BinaryPath string

	mu       sync.Mutex
	cache    map[string]cacheEntry
	extractMu sync.Mutex
}

var defaultResolver = &Resolver{}

// Default returns the process-wide resolver used by the HTTP handler.
func Default() *Resolver { return defaultResolver }

var videoIDPattern = regexp.MustCompile(`^[A-Za-z0-9_-]{11}$`)

// ExtractVideoID pulls the 11-char id out of a plain id or any common YouTube
// URL shape (watch, youtu.be, embed, shorts).
func ExtractVideoID(raw string) (string, error) {
	s := strings.TrimSpace(raw)
	if s == "" {
		return "", ErrInvalidVideoID
	}
	if videoIDPattern.MatchString(s) {
		return s, nil
	}

	for _, marker := range []string{"v=", "youtu.be/", "/embed/", "/shorts/", "/live/"} {
		if idx := strings.Index(s, marker); idx >= 0 {
			rest := s[idx+len(marker):]
			if cut := strings.IndexAny(rest, "&#?"); cut >= 0 {
				rest = rest[:cut]
			}
			if videoIDPattern.MatchString(rest) {
				return rest, nil
			}
		}
	}
	return "", ErrInvalidVideoID
}

func (r *Resolver) binary() (string, error) {
	if r.BinaryPath != "" {
		return r.BinaryPath, nil
	}
	if custom := os.Getenv("ANITING_YTDLP"); custom != "" {
		return custom, nil
	}
	path, err := exec.LookPath("yt-dlp")
	if err != nil {
		return "", ErrUnavailable
	}
	return path, nil
}

// Resolve returns the playable streams for a video id or URL.
func (r *Resolver) Resolve(ctx context.Context, raw string) (Streams, error) {
	id, err := ExtractVideoID(raw)
	if err != nil {
		return Streams{}, err
	}

	r.mu.Lock()
	if entry, ok := r.cache[id]; ok && time.Since(entry.stored) < cacheTTL {
		r.mu.Unlock()
		cached := entry.streams
		cached.Cached = true
		cached.ResolutionMS = 0
		return cached, nil
	}
	r.mu.Unlock()

	binary, err := r.binary()
	if err != nil {
		return Streams{}, err
	}

	// Serialise extractions: a burst of hovers must not spawn five yt-dlp
	// processes competing for the same video.
	r.extractMu.Lock()
	defer r.extractMu.Unlock()

	// Another goroutine may have filled the cache while we waited.
	r.mu.Lock()
	if entry, ok := r.cache[id]; ok && time.Since(entry.stored) < cacheTTL {
		r.mu.Unlock()
		cached := entry.streams
		cached.Cached = true
		cached.ResolutionMS = 0
		return cached, nil
	}
	r.mu.Unlock()

	started := time.Now()
	streams, err := r.extract(ctx, binary, id)
	if err != nil {
		return Streams{}, err
	}
	if streams.MuxedURL == "" && (streams.VideoURL == "" || streams.AudioURL == "") {
		return Streams{}, fmt.Errorf("yt-dlp: no playable stream for %s", id)
	}
	streams.ResolutionMS = time.Since(started).Milliseconds()

	r.mu.Lock()
	if r.cache == nil {
		r.cache = make(map[string]cacheEntry)
	}
	r.cache[id] = cacheEntry{streams: streams, stored: time.Now()}
	r.mu.Unlock()

	return streams, nil
}

func (r *Resolver) extract(ctx context.Context, binary, id string) (Streams, error) {
	ctx, cancel := context.WithTimeout(ctx, extractionTimeout)
	defer cancel()

	cmd := exec.CommandContext(
		ctx,
		binary,
		"-J",
		"--no-warnings",
		"--no-playlist",
		"--no-progress",
		"https://www.youtube.com/watch?v="+id,
	)
	out, err := cmd.Output()
	if err != nil {
		return Streams{}, fmt.Errorf("yt-dlp: %w", err)
	}

	var dump ytDump
	if err := json.Unmarshal(out, &dump); err != nil {
		return Streams{}, fmt.Errorf("yt-dlp json: %w", err)
	}

	return pickStreams(id, &dump), nil
}

// pickStreams chooses the best muxed, video-only and audio-only formats from a
// parsed yt-dlp dump. Pure function so the selection rules are testable without
// touching the network or the yt-dlp binary.
func pickStreams(id string, dump *ytDump) Streams {
	streams := Streams{
		VideoID:   id,
		Title:     dump.Title,
		Author:    dump.Uploader,
		Duration:  int(dump.Duration),
		ExpiresAt: time.Now().Add(cacheTTL),
	}

	var bestMuxed, bestVideo, bestAudio *ytFormat

	for i := range dump.Formats {
		f := &dump.Formats[i]
		if f.URL == "" {
			continue
		}
		hasVideo := f.VCodec != "" && f.VCodec != "none"
		hasAudio := f.ACodec != "" && f.ACodec != "none"

		switch {
		case hasVideo && hasAudio:
			if f.Ext == "mp4" && (bestMuxed == nil || f.Height > bestMuxed.Height) {
				bestMuxed = f
			}
		case hasVideo:
			if f.Ext != "mp4" || f.Height > maxVideoHeight {
				continue
			}
			if bestVideo == nil || f.Height > bestVideo.Height {
				bestVideo = f
			}
		case hasAudio:
			if bestAudio == nil || f.ABR > bestAudio.ABR {
				bestAudio = f
			}
		}
	}

	if bestMuxed != nil {
		streams.MuxedURL = bestMuxed.URL
		streams.MuxedHeight = bestMuxed.Height
	}
	if bestVideo != nil {
		streams.VideoURL = bestVideo.URL
		streams.VideoHeight = bestVideo.Height
	}
	if bestAudio != nil {
		streams.AudioURL = bestAudio.URL
		streams.AudioCodec = bestAudio.ACodec
	}

	return streams
}
