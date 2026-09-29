package plugin

import (
	"context"
	"errors"
	"path/filepath"
	"seanime/internal/api/anilist"
	"seanime/internal/api/metadata"
	debrid_client "seanime/internal/debrid/client"
	"seanime/internal/debrid/debrid"
	"seanime/internal/extension"
	hibiketorrent "seanime/internal/extension/hibike/torrent"
	"seanime/internal/goja/goja_bindings"
	"seanime/internal/torrentstream"
	gojautil "seanime/internal/util/goja"

	"github.com/dop251/goja"
	"github.com/rs/zerolog"
)

type debridGetTorrentFilePreviewsOptions struct {
	Torrent       *hibiketorrent.AnimeTorrent `json:"torrent"`
	EpisodeNumber int                         `json:"episodeNumber"`
	Media         *anilist.BaseAnime          `json:"media"`
}

type debridAddTorrentOptions struct {
	Torrent      *hibiketorrent.AnimeTorrent `json:"torrent"`
	MagnetLink   string                      `json:"magnetLink"`
	InfoHash     string                      `json:"infoHash"`
	SelectFileId string                      `json:"selectFileId"`
}

type debridAddAndQueueTorrentOptions struct {
	Torrent      *hibiketorrent.AnimeTorrent `json:"torrent"`
	MagnetLink   string                      `json:"magnetLink"`
	InfoHash     string                      `json:"infoHash"`
	SelectFileId string                      `json:"selectFileId"`
	Destination  string                      `json:"destination"`
	MediaId      int                         `json:"mediaId"`
}

type debridDownloadTorrentOptions struct {
	TorrentItem *debrid.TorrentItem `json:"torrentItem"`
	Destination string              `json:"destination"`
}

type debridQueuedDownload struct {
	TorrentItemID string `json:"torrentItemId"`
	Destination   string `json:"destination"`
	Provider      string `json:"provider"`
	MediaID       int    `json:"mediaId"`
}

func (a *AppContextImpl) BindDebridToContextObj(vm *goja.Runtime, obj *goja.Object, _ *zerolog.Logger, ext *extension.Extension, scheduler *gojautil.Scheduler) {
	debridObj := vm.NewObject()

	_ = debridObj.Set("hasProvider", func() goja.Value {
		repo, ok := a.debridClientRepository.Get()
		if !ok {
			goja_bindings.PanicThrowErrorString(vm, "debrid repository not set")
		}
		return vm.ToValue(repo.HasProvider())
	})

	_ = debridObj.Set("getSettings", func() goja.Value {
		repo, ok := a.debridClientRepository.Get()
		if !ok {
			goja_bindings.PanicThrowErrorString(vm, "debrid repository not set")
		}
		settings := repo.GetSettings()
		if settings == nil {
			return goja.Undefined()
		}
		return vm.ToValue(settings)
	})

	_ = debridObj.Set("getQueuedDownloads", func() goja.Value {
		database, ok := a.database.Get()
		if !ok {
			goja_bindings.PanicThrowErrorString(vm, "database not set")
		}

		items, err := database.GetDebridTorrentItems()
		if err != nil {
			goja_bindings.PanicThrowError(vm, err)
		}

		ret := make([]debridQueuedDownload, 0, len(items))
		for _, item := range items {
			if item == nil {
				continue
			}

			ret = append(ret, debridQueuedDownload{
				TorrentItemID: item.TorrentItemID,
				Destination:   item.Destination,
				Provider:      item.Provider,
				MediaID:       item.MediaId,
			})
		}

		return vm.ToValue(ret)
	})

	_ = debridObj.Set("addTorrent", func(opts debridAddTorrentOptions) goja.Value {
		promise, resolve, reject := vm.NewPromise()

		addOpts, err := a.normalizeDebridAddTorrentOptions(opts)
		if err != nil {
			reject(vm.NewGoError(err))
			return vm.ToValue(promise)
		}

		repo, ok := a.debridClientRepository.Get()
		if !ok {
			goja_bindings.PanicThrowErrorString(vm, "debrid repository not set")
		}

		go func() {
			provider, err := repo.GetProvider()
			if err != nil {
				scheduler.ScheduleAsync(func() error {
					reject(vm.NewGoError(err))
					return nil
				})
				return
			}

			torrentItemID, err := provider.AddTorrent(addOpts)
			scheduler.ScheduleAsync(func() error {
				if err != nil {
					reject(vm.NewGoError(err))
				} else {
					resolve(vm.ToValue(torrentItemID))
				}
				return nil
			})
		}()

		return vm.ToValue(promise)
	})

	_ = debridObj.Set("addAndQueueTorrent", func(opts debridAddAndQueueTorrentOptions) goja.Value {
		promise, resolve, reject := vm.NewPromise()

		if err := validateDebridDestination(a, ext, opts.Destination); err != nil {
			reject(vm.NewGoError(err))
			return vm.ToValue(promise)
		}

		addOpts, err := a.normalizeDebridAddTorrentOptions(debridAddTorrentOptions{
			Torrent:      opts.Torrent,
			MagnetLink:   opts.MagnetLink,
			InfoHash:     opts.InfoHash,
			SelectFileId: opts.SelectFileId,
		})
		if err != nil {
			reject(vm.NewGoError(err))
			return vm.ToValue(promise)
		}

		repo, ok := a.debridClientRepository.Get()
		if !ok {
			goja_bindings.PanicThrowErrorString(vm, "debrid repository not set")
		}

		go func() {
			torrentItemID, err := repo.AddAndQueueTorrent(addOpts, opts.Destination, opts.MediaId)
			scheduler.ScheduleAsync(func() error {
				if err != nil {
					reject(vm.NewGoError(err))
				} else {
					resolve(vm.ToValue(torrentItemID))
				}
				return nil
			})
		}()

		return vm.ToValue(promise)
	})

	_ = debridObj.Set("getTorrentInfo", func(opts debrid.GetTorrentInfoOptions) goja.Value {
		promise, resolve, reject := vm.NewPromise()

		repo, ok := a.debridClientRepository.Get()
		if !ok {
			goja_bindings.PanicThrowErrorString(vm, "debrid repository not set")
		}

		go func() {
			info, err := repo.GetTorrentInfo(opts)
			scheduler.ScheduleAsync(func() error {
				if err != nil {
					reject(vm.NewGoError(err))
				} else {
					resolve(vm.ToValue(info))
				}
				return nil
			})
		}()

		return vm.ToValue(promise)
	})

	_ = debridObj.Set("getTorrents", func() goja.Value {
		promise, resolve, reject := vm.NewPromise()

		repo, ok := a.debridClientRepository.Get()
		if !ok {
			goja_bindings.PanicThrowErrorString(vm, "debrid repository not set")
		}

		go func() {
			provider, err := repo.GetProvider()
			if err != nil {
				scheduler.ScheduleAsync(func() error {
					reject(vm.NewGoError(err))
					return nil
				})
				return
			}

			torrents, err := provider.GetTorrents()
			scheduler.ScheduleAsync(func() error {
				if err != nil {
					reject(vm.NewGoError(err))
				} else {
					resolve(vm.ToValue(torrents))
				}
				return nil
			})
		}()

		return vm.ToValue(promise)
	})

	_ = debridObj.Set("deleteTorrent", func(torrentID string) goja.Value {
		promise, resolve, reject := vm.NewPromise()

		repo, ok := a.debridClientRepository.Get()
		if !ok {
			goja_bindings.PanicThrowErrorString(vm, "debrid repository not set")
		}

		if torrentID == "" {
			reject(vm.NewGoError(errors.New("torrentId is required")))
			return vm.ToValue(promise)
		}

		go func() {
			provider, err := repo.GetProvider()
			if err != nil {
				scheduler.ScheduleAsync(func() error {
					reject(vm.NewGoError(err))
					return nil
				})
				return
			}

			err = provider.DeleteTorrent(torrentID)
			scheduler.ScheduleAsync(func() error {
				if err != nil {
					reject(vm.NewGoError(err))
				} else {
					resolve(goja.Undefined())
				}
				return nil
			})
		}()

		return vm.ToValue(promise)
	})

	_ = debridObj.Set("cancelDownload", func(itemID string) goja.Value {
		promise, resolve, reject := vm.NewPromise()

		repo, ok := a.debridClientRepository.Get()
		if !ok {
			goja_bindings.PanicThrowErrorString(vm, "debrid repository not set")
		}

		if itemID == "" {
			reject(vm.NewGoError(errors.New("itemId is required")))
			return vm.ToValue(promise)
		}

		go func() {
			err := repo.CancelDownload(itemID)
			scheduler.ScheduleAsync(func() error {
				if err != nil {
					reject(vm.NewGoError(err))
				} else {
					resolve(goja.Undefined())
				}
				return nil
			})
		}()

		return vm.ToValue(promise)
	})

	_ = debridObj.Set("downloadTorrent", func(opts debridDownloadTorrentOptions) goja.Value {
		promise, resolve, reject := vm.NewPromise()

		if opts.TorrentItem == nil {
			reject(vm.NewGoError(errors.New("torrentItem is required")))
			return vm.ToValue(promise)
		}

		if err := validateDebridDestination(a, ext, opts.Destination); err != nil {
			reject(vm.NewGoError(err))
			return vm.ToValue(promise)
		}

		repo, ok := a.debridClientRepository.Get()
		if !ok {
			goja_bindings.PanicThrowErrorString(vm, "debrid repository not set")
		}

		if database, ok := a.database.Get(); ok {
			_ = database.DeleteDebridTorrentItemByTorrentItemId(opts.TorrentItem.ID)
		}

		go func() {
			err := repo.DownloadTorrent(*opts.TorrentItem, opts.Destination)
			scheduler.ScheduleAsync(func() error {
				if err != nil {
					reject(vm.NewGoError(err))
				} else {
					resolve(goja.Undefined())
				}
				return nil
			})
		}()

		return vm.ToValue(promise)
	})

	_ = debridObj.Set("getTorrentFilePreviews", func(opts debridGetTorrentFilePreviewsOptions) goja.Value {
		promise, resolve, reject := vm.NewPromise()

		repo, ok := a.debridClientRepository.Get()
		if !ok {
			goja_bindings.PanicThrowErrorString(vm, "debrid repository not set")
		}
		torrentRepo, ok := a.torrentRepository.Get()
		if !ok {
			goja_bindings.PanicThrowErrorString(vm, "torrent repository not set")
		}

		if opts.Torrent == nil {
			reject(vm.NewGoError(errors.New("torrent is required")))
			return vm.ToValue(promise)
		}

		if opts.Media == nil {
			reject(vm.NewGoError(errors.New("media is required")))
			return vm.ToValue(promise)
		}

		go func() {
			magnet, err := torrentRepo.ResolveMagnetLink(opts.Torrent)
			if err != nil {
				scheduler.ScheduleAsync(func() error {
					reject(vm.NewGoError(err))
					return nil
				})
				return
			}

			absoluteOffset := 0
			if metadataProviderRef, ok := a.metadataProviderRef.Get(); ok {
				animeMetadata, _ := metadataProviderRef.Get().GetAnimeMetadata(metadata.AnilistPlatform, opts.Media.ID)
				if animeMetadata != nil {
					absoluteOffset = animeMetadata.GetOffset()
				}
			}

			previews, err := repo.GetTorrentFilePreviewsFromManualSelection(&debrid_client.GetTorrentFilePreviewsOptions{
				Torrent:        opts.Torrent,
				Magnet:         magnet,
				EpisodeNumber:  opts.EpisodeNumber,
				Media:          opts.Media,
				AbsoluteOffset: absoluteOffset,
			})
			scheduler.ScheduleAsync(func() error {
				if err != nil {
					reject(vm.NewGoError(err))
				} else {
					resolve(vm.ToValue(previews))
				}
				return nil
			})
		}()

		return vm.ToValue(promise)
	})

	_ = obj.Set("debrid", debridObj)
}

func (a *AppContextImpl) BindDebridstreamToContextObj(vm *goja.Runtime, obj *goja.Object, _ *zerolog.Logger, _ *extension.Extension, scheduler *gojautil.Scheduler) {
	debridstreamObj := vm.NewObject()

	_ = debridstreamObj.Set("getPreviousStreamOptions", func() goja.Value {
		repo, ok := a.debridClientRepository.Get()
		if !ok {
			goja_bindings.PanicThrowErrorString(vm, "debrid repository not set")
		}
		opts, found := repo.GetPreviousStreamOptions()
		if !found || opts == nil {
			return goja.Undefined()
		}
		return vm.ToValue(opts)
	})

	_ = debridstreamObj.Set("getStreamURL", func() goja.Value {
		repo, ok := a.debridClientRepository.Get()
		if !ok {
			goja_bindings.PanicThrowErrorString(vm, "debrid repository not set")
		}
		streamURL, found := repo.GetStreamURL()
		if !found || streamURL == "" {
			return goja.Undefined()
		}
		return vm.ToValue(streamURL)
	})

	_ = debridstreamObj.Set("startStream", func(opts debrid_client.StartStreamOptions) goja.Value {
		promise, resolve, reject := vm.NewPromise()

		repo, ok := a.debridClientRepository.Get()
		if !ok {
			goja_bindings.PanicThrowErrorString(vm, "debrid repository not set")
		}

		if err := validatePlaybackTarget(string(opts.PlaybackType), opts.ClientId); err != nil {
			reject(vm.NewGoError(err))
			return vm.ToValue(promise)
		}

		go func() {
			err := repo.StartStream(context.Background(), &opts)
			scheduler.ScheduleAsync(func() error {
				if err != nil {
					reject(vm.NewGoError(err))
				} else {
					resolve(goja.Undefined())
				}
				return nil
			})
		}()

		return vm.ToValue(promise)
	})

	_ = debridstreamObj.Set("cancelStream", func(call goja.FunctionCall) goja.Value {
		repo, ok := a.debridClientRepository.Get()
		if !ok {
			goja_bindings.PanicThrowErrorString(vm, "debrid repository not set")
		}

		opts := debrid_client.CancelStreamOptions{}
		if len(call.Arguments) > 0 && !goja.IsUndefined(call.Argument(0)) && !goja.IsNull(call.Argument(0)) {
			if err := vm.ExportTo(call.Argument(0), &opts); err != nil {
				goja_bindings.PanicThrowError(vm, err)
			}
		}

		repo.CancelStream(&opts)
		return goja.Undefined()
	})

	_ = obj.Set("debridstream", debridstreamObj)
}

func (a *AppContextImpl) normalizeDebridAddTorrentOptions(opts debridAddTorrentOptions) (debrid.AddTorrentOptions, error) {
	if opts.Torrent != nil {
		if opts.MagnetLink == "" {
			torrentRepo, ok := a.torrentRepository.Get()
			if !ok {
				return debrid.AddTorrentOptions{}, errors.New("torrent repository not set")
			}

			magnetLink, err := torrentRepo.ResolveMagnetLink(opts.Torrent)
			if err != nil {
				return debrid.AddTorrentOptions{}, err
			}

			opts.MagnetLink = magnetLink
		}

		if opts.InfoHash == "" {
			opts.InfoHash = opts.Torrent.InfoHash
		}
	}

	if opts.MagnetLink == "" && opts.InfoHash == "" {
		return debrid.AddTorrentOptions{}, errors.New("torrent or magnetLink or infoHash is required")
	}

	selectFileID := opts.SelectFileId
	if selectFileID == "" {
		selectFileID = "all"
	}

	return debrid.AddTorrentOptions{
		MagnetLink:   opts.MagnetLink,
		InfoHash:     opts.InfoHash,
		SelectFileId: selectFileID,
	}, nil
}

func validateDebridDestination(a *AppContextImpl, ext *extension.Extension, destination string) error {
	if destination == "" {
		return errors.New("destination is required")
	}

	if !filepath.IsAbs(destination) {
		return errors.New("destination must be an absolute path")
	}

	if !a.isAllowedPath(ext, destination, AllowPathWrite) {
		return errors.New("destination path not authorized for write")
	}

	return nil
}

func validatePlaybackTarget(playbackType string, clientId string) error {
	if playbackType == "" {
		return errors.New("playbackType is required")
	}

	if (playbackType == string(torrentstream.PlaybackTypeNativePlayer) || playbackType == string(torrentstream.PlaybackTypeExternalPlayerLink)) && clientId == "" {
		return errors.New("clientId is required for the selected playbackType")
	}

	if (playbackType == string(debrid_client.PlaybackTypeNativePlayer) || playbackType == string(debrid_client.PlaybackTypeExternalPlayer)) && clientId == "" {
		return errors.New("clientId is required for the selected playbackType")
	}

	return nil
}
