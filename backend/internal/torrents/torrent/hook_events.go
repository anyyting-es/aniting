package torrent

import "seanime/internal/hook_resolver"

// TorrentSearchRequestedEvent is triggered before Seanime searches anime torrents.
// Prevent default to skip the native search and return SearchData.
type TorrentSearchRequestedEvent struct {
	hook_resolver.Event
	Options    AnimeSearchOptions `json:"options"`
	SearchData *SearchData        `json:"searchData"`
}

// TorrentSearchEvent is triggered after Seanime assembles the torrent search response.
// Handlers can mutate SearchData before it is cached and returned.
type TorrentSearchEvent struct {
	hook_resolver.Event
	Options    AnimeSearchOptions `json:"options"`
	SearchData *SearchData        `json:"searchData"`
}
