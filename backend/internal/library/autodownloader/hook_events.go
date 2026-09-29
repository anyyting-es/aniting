package autodownloader

import (
	"seanime/internal/api/anilist"
	"seanime/internal/database/models"
	"seanime/internal/hook_resolver"
	"seanime/internal/library/anime"
)

// AutoDownloaderRunStartedEvent is triggered when the autodownloader starts checking for new episodes.
// Prevent default to abort the run.
type AutoDownloaderRunStartedEvent struct {
	hook_resolver.Event
	Rules        []*anime.AutoDownloaderRule    `json:"rules"`
	Profiles     []*anime.AutoDownloaderProfile `json:"profiles"`
	IsSimulation bool                           `json:"isSimulation"`
}

// AutoDownloaderRunCompletedEvent is triggered when the autodownloader finishes a run.
type AutoDownloaderRunCompletedEvent struct {
	hook_resolver.Event
	Rules           []*anime.AutoDownloaderRule    `json:"rules"`
	Profiles        []*anime.AutoDownloaderProfile `json:"profiles"`
	IsSimulation    bool                           `json:"isSimulation"`
	DownloadedCount int                            `json:"downloadedCount"`
	QueuedCount     int                            `json:"queuedCount"`
	DelayedCount    int                            `json:"delayedCount"`
}

// AutoDownloaderBeforeFetchTorrentsEvent is triggered before the autodownloader fetches torrents from providers.
// Prevent default to skip native provider retrieval.
type AutoDownloaderBeforeFetchTorrentsEvent struct {
	hook_resolver.Event
	Rules           []*anime.AutoDownloaderRule    `json:"rules"`
	Profiles        []*anime.AutoDownloaderProfile `json:"profiles"`
	ProviderIDs     []string                       `json:"providerIds"`
	DefaultProvider string                         `json:"defaultProvider"`
	Torrents        []*NormalizedTorrent           `json:"torrents"`
}

// AutoDownloaderTorrentsFetchedEvent is triggered at the beginning of a run, when the autodownloader fetches torrents from the provider.
type AutoDownloaderTorrentsFetchedEvent struct {
	hook_resolver.Event
	Torrents []*NormalizedTorrent `json:"torrents"`
}

// AutoDownloaderMatchVerifiedEvent is triggered when a torrent is verified to follow a rule.
// Changing MatchFound or Episode lets the hook override the verified result.
// Prevent default to reject the match.
type AutoDownloaderMatchVerifiedEvent struct {
	hook_resolver.Event
	// Fetched torrent
	Torrent    *NormalizedTorrent           `json:"torrent"`
	Rule       *anime.AutoDownloaderRule    `json:"rule"`
	ListEntry  *anilist.AnimeListEntry      `json:"listEntry"`
	LocalEntry *anime.LocalFileWrapperEntry `json:"localEntry"`
	// The episode number found for the match
	// If the match failed, this will be 0
	Episode int `json:"episode"`
	// Whether the torrent matches the rule
	// Changing this value to true will trigger a download even if the match failed;
	MatchFound bool `json:"matchFound"`
}

// AutoDownloaderBestCandidateSelectedEvent is triggered when the best candidate for an episode is selected.
// Prevent default to skip handling the episode.
type AutoDownloaderBestCandidateSelectedEvent struct {
	hook_resolver.Event
	Rule         *anime.AutoDownloaderRule  `json:"rule"`
	Episode      int                        `json:"episode"`
	Candidates   []*Candidate               `json:"candidates"`
	Candidate    *Candidate                 `json:"candidate"`
	ExistingItem *models.AutoDownloaderItem `json:"existingItem"`
	IsSimulation bool                       `json:"isSimulation"`
}

// AutoDownloaderSettingsUpdatedEvent is triggered when the autodownloader settings are updated
type AutoDownloaderSettingsUpdatedEvent struct {
	hook_resolver.Event
	Settings *models.AutoDownloaderSettings `json:"settings"`
}

// AutoDownloaderBeforeQueueDelayedTorrentEvent is triggered when the autodownloader is about to queue a torrent with delay.
// Prevent default to skip the delayed queue behavior.
type AutoDownloaderBeforeQueueDelayedTorrentEvent struct {
	hook_resolver.Event
	Candidate    *Candidate                `json:"candidate"`
	Rule         *anime.AutoDownloaderRule `json:"rule"`
	Episode      int                       `json:"episode"`
	DelayMinutes int                       `json:"delayMinutes"`
	IsSimulation bool                      `json:"isSimulation"`
}

// AutoDownloaderBeforeDownloadTorrentEvent is triggered when the autodownloader is about to download a torrent.
// Prevent default to abort the download.
type AutoDownloaderBeforeDownloadTorrentEvent struct {
	hook_resolver.Event
	Torrent      *NormalizedTorrent           `json:"torrent"`
	Rule         *anime.AutoDownloaderRule    `json:"rule"`
	Episode      int                          `json:"episode"`
	Score        int                          `json:"score"`
	Items        []*models.AutoDownloaderItem `json:"items"`
	ExistingItem *models.AutoDownloaderItem   `json:"existingItem"`
	IsSimulation bool                         `json:"isSimulation"`
}

// AutoDownloaderAfterDownloadTorrentEvent is triggered after the autodownloader queues or downloads a torrent.
type AutoDownloaderAfterDownloadTorrentEvent struct {
	hook_resolver.Event
	Torrent      *NormalizedTorrent         `json:"torrent"`
	Rule         *anime.AutoDownloaderRule  `json:"rule"`
	Episode      int                        `json:"episode"`
	Score        int                        `json:"score"`
	Downloaded   bool                       `json:"downloaded"`
	Item         *models.AutoDownloaderItem `json:"item"`
	IsSimulation bool                       `json:"isSimulation"`
}
