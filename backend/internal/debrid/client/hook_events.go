package debrid_client

import (
	"aniting/internal/api/anilist"
	"aniting/internal/debrid/debrid"
	hibiketorrent "aniting/internal/extension/hibike/torrent"
	"aniting/internal/hook_resolver"
)

// DebridAutoSelectTorrentsFetchedEvent is triggered when the torrents are fetched for auto select.
// The torrents are sorted by seeders from highest to lowest.
// This event is triggered before the top 3 torrents are analyzed.
type DebridAutoSelectTorrentsFetchedEvent struct {
	hook_resolver.Event
	Torrents []*hibiketorrent.AnimeTorrent
}

// DebridSkipStreamCheckEvent is triggered when the debrid client is about to skip the stream check.
// Prevent default to enable the stream check.
type DebridSkipStreamCheckEvent struct {
	hook_resolver.Event
	StreamURL  string `json:"streamURL"`
	Retries    int    `json:"retries"`
	RetryDelay int    `json:"retryDelay"` // in seconds
}

// DebridSendStreamToMediaPlayerEvent is triggered when the debrid client is about to send a stream to the media player.
// Prevent default to skip the playback.
type DebridSendStreamToMediaPlayerEvent struct {
	hook_resolver.Event
	WindowTitle  string             `json:"windowTitle"`
	StreamURL    string             `json:"streamURL"`
	Media        *anilist.BaseAnime `json:"media"`
	AniDbEpisode string             `json:"aniDbEpisode"`
	PlaybackType string             `json:"playbackType"`
}

// DebridAddTorrentRequestedEvent is triggered when Aniting is about to add a torrent to the debrid provider.
// Prevent default to bypass the native add call and provide TorrentItemID yourself.
type DebridAddTorrentRequestedEvent struct {
	hook_resolver.Event
	Options       debrid.AddTorrentOptions `json:"options"`
	Destination   string                   `json:"destination"`
	MediaID       int                      `json:"mediaId"`
	TorrentItemID string                   `json:"torrentItemId"`
}

// DebridAddTorrentEvent is triggered after Aniting adds a torrent to the debrid provider and queues it locally.
type DebridAddTorrentEvent struct {
	hook_resolver.Event
	Options       debrid.AddTorrentOptions `json:"options"`
	Destination   string                   `json:"destination"`
	MediaID       int                      `json:"mediaId"`
	TorrentItemID string                   `json:"torrentItemId"`
}

// DebridLocalDownloadRequestedEvent is triggered when Aniting is about to download a debrid torrent locally.
// Prevent default to skip the default download and override the download.
type DebridLocalDownloadRequestedEvent struct {
	hook_resolver.Event
	TorrentName string `json:"torrentName"`
	Destination string `json:"destination"`
	DownloadUrl string `json:"downloadUrl"`
}

// DebridLocalDownloadStartedEvent is triggered right after Aniting accepts a local debrid download.
type DebridLocalDownloadStartedEvent struct {
	hook_resolver.Event
	TorrentItemID string `json:"torrentItemId"`
	TorrentName   string `json:"torrentName"`
	Destination   string `json:"destination"`
	DownloadUrl   string `json:"downloadUrl"`
}

// DebridLocalDownloadCompletedEvent is triggered when Aniting finishes a local debrid download.
type DebridLocalDownloadCompletedEvent struct {
	hook_resolver.Event
	TorrentItemID string `json:"torrentItemId"`
	TorrentName   string `json:"torrentName"`
	Destination   string `json:"destination"`
}
