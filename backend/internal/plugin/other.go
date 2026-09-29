package plugin

import (
	"context"
	"seanime/internal/events"
	"seanime/internal/extension"
	"seanime/internal/goja/goja_bindings"
	"seanime/internal/library/anime"
	"seanime/internal/onlinestream"
	"seanime/internal/torrent_clients/torrent_client"
	gojautil "seanime/internal/util/goja"
	"strconv"

	"github.com/dop251/goja"
	"github.com/rs/zerolog"
)

type autoDownloaderRunCheckOptions struct {
	IsSimulation bool   `json:"isSimulation"`
	RuleIDs      []uint `json:"ruleIds"`
}

// BindOnlinestreamToContextObj binds 'onlinestream' to the UI context object
func (a *AppContextImpl) BindOnlinestreamToContextObj(vm *goja.Runtime, obj *goja.Object, logger *zerolog.Logger, ext *extension.Extension, scheduler *gojautil.Scheduler) {

}

// BindMediastreamToContextObj binds 'mediastream' to the UI context object
func (a *AppContextImpl) BindMediastreamToContextObj(vm *goja.Runtime, obj *goja.Object, logger *zerolog.Logger, ext *extension.Extension, scheduler *gojautil.Scheduler) {

}

// BindTorrentClientToContextObj binds 'torrentClient' to the UI context object
func (a *AppContextImpl) BindTorrentClientToContextObj(vm *goja.Runtime, obj *goja.Object, logger *zerolog.Logger, ext *extension.Extension, scheduler *gojautil.Scheduler) {

	torrentClientObj := vm.NewObject()
	_ = torrentClientObj.Set("getTorrents", func() goja.Value {
		promise, resolve, reject := vm.NewPromise()

		torrentClient, ok := a.torrentClientRepository.Get()
		if !ok {
			goja_bindings.PanicThrowErrorString(vm, "torrentClient not set")
		}

		go func() {
			torrents, err := torrentClient.GetList(&torrent_client.GetListOptions{})
			scheduler.ScheduleAsync(func() error {
				if err != nil {
					reject(goja_bindings.NewErrorString(vm, "error getting torrents: "+err.Error()))
					return nil
				}
				resolve(vm.ToValue(torrents))
				return nil
			})
		}()

		return vm.ToValue(promise)
	})

	_ = torrentClientObj.Set("getActiveTorrents", func() goja.Value {
		promise, resolve, reject := vm.NewPromise()

		torrentClient, ok := a.torrentClientRepository.Get()
		if !ok {
			goja_bindings.PanicThrowErrorString(vm, "torrentClient not set")
		}

		go func() {
			activeTorrents, err := torrentClient.GetActiveTorrents(&torrent_client.GetListOptions{})
			scheduler.ScheduleAsync(func() error {
				if err != nil {
					reject(goja_bindings.NewErrorString(vm, "error getting active torrents: "+err.Error()))
					return nil
				}
				resolve(vm.ToValue(activeTorrents))
				return nil
			})
		}()

		return vm.ToValue(promise)
	})

	_ = torrentClientObj.Set("addMagnets", func(magnets []string, dest string) goja.Value {
		promise, resolve, reject := vm.NewPromise()

		torrentClient, ok := a.torrentClientRepository.Get()
		if !ok {
			goja_bindings.PanicThrowErrorString(vm, "torrentClient not set")
		}

		go func() {
			err := torrentClient.AddMagnets(magnets, dest)
			scheduler.ScheduleAsync(func() error {
				if err != nil {
					reject(goja_bindings.NewErrorString(vm, "error adding magnets: "+err.Error()))
					return nil
				}
				resolve(goja.Undefined())
				return nil
			})
		}()

		return vm.ToValue(promise)
	})

	_ = torrentClientObj.Set("removeTorrents", func(hashes []string) goja.Value {
		promise, resolve, reject := vm.NewPromise()

		torrentClient, ok := a.torrentClientRepository.Get()
		if !ok {
			goja_bindings.PanicThrowErrorString(vm, "torrentClient not set")
		}

		go func() {
			err := torrentClient.RemoveTorrents(hashes)
			scheduler.ScheduleAsync(func() error {
				if err != nil {
					reject(goja_bindings.NewErrorString(vm, "error removing torrents: "+err.Error()))
					return nil
				}
				resolve(goja.Undefined())
				return nil
			})
		}()

		return vm.ToValue(promise)
	})

	_ = torrentClientObj.Set("pauseTorrents", func(hashes []string) goja.Value {
		promise, resolve, reject := vm.NewPromise()

		torrentClient, ok := a.torrentClientRepository.Get()
		if !ok {
			goja_bindings.PanicThrowErrorString(vm, "torrentClient not set")
		}

		go func() {
			err := torrentClient.PauseTorrents(hashes)
			scheduler.ScheduleAsync(func() error {
				if err != nil {
					reject(goja_bindings.NewErrorString(vm, "error pausing torrents: "+err.Error()))
					return nil
				}
				resolve(goja.Undefined())
				return nil
			})
		}()

		return vm.ToValue(promise)
	})

	_ = torrentClientObj.Set("resumeTorrents", func(hashes []string) goja.Value {
		promise, resolve, reject := vm.NewPromise()

		torrentClient, ok := a.torrentClientRepository.Get()
		if !ok {
			goja_bindings.PanicThrowErrorString(vm, "torrentClient not set")
		}

		go func() {
			err := torrentClient.ResumeTorrents(hashes)
			scheduler.ScheduleAsync(func() error {
				if err != nil {
					reject(goja_bindings.NewErrorString(vm, "error resuming torrents: "+err.Error()))
					return nil
				}
				resolve(goja.Undefined())
				return nil
			})
		}()

		return vm.ToValue(promise)
	})

	_ = torrentClientObj.Set("deselectFiles", func(hash string, indices []int) goja.Value {
		promise, resolve, reject := vm.NewPromise()

		torrentClient, ok := a.torrentClientRepository.Get()
		if !ok {
			goja_bindings.PanicThrowErrorString(vm, "torrentClient not set")
		}

		go func() {
			err := torrentClient.DeselectFiles(hash, indices)
			scheduler.ScheduleAsync(func() error {
				if err != nil {
					reject(goja_bindings.NewErrorString(vm, "error deselecting files: "+err.Error()))
					return nil
				}
				resolve(goja.Undefined())
				return nil
			})
		}()

		return vm.ToValue(promise)
	})

	_ = torrentClientObj.Set("getFiles", func(hash string) goja.Value {
		promise, resolve, reject := vm.NewPromise()

		torrentClient, ok := a.torrentClientRepository.Get()
		if !ok {
			goja_bindings.PanicThrowErrorString(vm, "torrentClient not set")
		}

		go func() {
			files, err := torrentClient.GetFiles(hash)
			scheduler.ScheduleAsync(func() error {
				if err != nil {
					reject(goja_bindings.NewErrorString(vm, "error getting files: "+err.Error()))
					return nil
				}
				resolve(vm.ToValue(files))
				return nil
			})
		}()

		return vm.ToValue(promise)
	})

	_ = obj.Set("torrentClient", torrentClientObj)

}

// BindFillerManagerToContextObj binds 'fillerManager' to the UI context object
func (a *AppContextImpl) BindFillerManagerToContextObj(vm *goja.Runtime, obj *goja.Object, logger *zerolog.Logger, ext *extension.Extension, scheduler *gojautil.Scheduler) {

	fillerManagerObj := vm.NewObject()
	_ = fillerManagerObj.Set("getFillerEpisodes", func(mediaId int) goja.Value {
		fillerManager, ok := a.fillerManager.Get()
		if !ok {
			goja_bindings.PanicThrowErrorString(vm, "fillerManager not set")
		}
		fillerEpisodes, ok := fillerManager.GetFillerEpisodes(mediaId)
		if !ok {
			return goja.Undefined()
		}
		return vm.ToValue(fillerEpisodes)
	})

	_ = fillerManagerObj.Set("removeFillerData", func(mediaId int) goja.Value {
		fillerManager, ok := a.fillerManager.Get()
		if !ok {
			goja_bindings.PanicThrowErrorString(vm, "fillerManager not set")
		}
		fillerManager.RemoveFillerData(mediaId)
		return goja.Undefined()
	})

	_ = fillerManagerObj.Set("setFillerEpisodes", func(mediaId int, fillerEpisodes []string) goja.Value {
		fillerManager, ok := a.fillerManager.Get()
		if !ok {
			goja_bindings.PanicThrowErrorString(vm, "fillerManager not set")
		}
		fillerManager.StoreFillerData("plugin", strconv.Itoa(mediaId), mediaId, fillerEpisodes)
		return goja.Undefined()
	})

	_ = fillerManagerObj.Set("isEpisodeFiller", func(mediaId int, episodeNumber int) goja.Value {
		fillerManager, ok := a.fillerManager.Get()
		if !ok {
			goja_bindings.PanicThrowErrorString(vm, "fillerManager not set")
		}
		return vm.ToValue(fillerManager.IsEpisodeFiller(mediaId, episodeNumber))
	})

	_ = fillerManagerObj.Set("hydrateFillerData", func(e *anime.Entry) goja.Value {
		fillerManager, ok := a.fillerManager.Get()
		if !ok {
			goja_bindings.PanicThrowErrorString(vm, "fillerManager not set")
		}
		fillerManager.HydrateFillerData(e)
		return goja.Undefined()
	})

	_ = fillerManagerObj.Set("hydrateOnlinestreamFillerData", func(mId int, episodes []*onlinestream.Episode) goja.Value {
		fillerManager, ok := a.fillerManager.Get()
		if !ok {
			goja_bindings.PanicThrowErrorString(vm, "fillerManager not set")
		}
		fillerManager.HydrateOnlinestreamFillerData(mId, episodes)
		return goja.Undefined()
	})

	_ = obj.Set("fillerManager", fillerManagerObj)

}

// BindAutoDownloaderToContextObj binds 'autoDownloader' to the UI context object
func (a *AppContextImpl) BindAutoDownloaderToContextObj(vm *goja.Runtime, obj *goja.Object, logger *zerolog.Logger, ext *extension.Extension, scheduler *gojautil.Scheduler) {

	autoDownloaderObj := vm.NewObject()
	_ = autoDownloaderObj.Set("run", func(call goja.FunctionCall) goja.Value {
		autoDownloader, ok := a.autoDownloader.Get()
		if !ok {
			goja_bindings.PanicThrowErrorString(vm, "autoDownloader not set")
		}
		isSimulation := false
		if len(call.Arguments) > 0 && !goja.IsUndefined(call.Argument(0)) {
			isSimulation = call.Argument(0).ToBoolean()
		}
		autoDownloader.Run(isSimulation)
		return goja.Undefined()
	})
	_ = autoDownloaderObj.Set("runCheck", func(opts autoDownloaderRunCheckOptions) goja.Value {
		promise, resolve, _ := vm.NewPromise()

		autoDownloader, ok := a.autoDownloader.Get()
		if !ok {
			goja_bindings.PanicThrowErrorString(vm, "autoDownloader not set")
		}

		go func() {
			autoDownloader.ClearSimulationResults()
			autoDownloader.RunCheck(context.Background(), opts.IsSimulation, opts.RuleIDs...)
			results := autoDownloader.GetSimulationResults()

			scheduler.ScheduleAsync(func() error {
				resolve(vm.ToValue(results))
				return nil
			})
		}()

		return vm.ToValue(promise)
	})
	_ = autoDownloaderObj.Set("getSimulationResults", func() goja.Value {
		autoDownloader, ok := a.autoDownloader.Get()
		if !ok {
			goja_bindings.PanicThrowErrorString(vm, "autoDownloader not set")
		}
		return vm.ToValue(autoDownloader.GetSimulationResults())
	})
	_ = autoDownloaderObj.Set("clearSimulationResults", func() goja.Value {
		autoDownloader, ok := a.autoDownloader.Get()
		if !ok {
			goja_bindings.PanicThrowErrorString(vm, "autoDownloader not set")
		}
		autoDownloader.ClearSimulationResults()
		return goja.Undefined()
	})
	_ = autoDownloaderObj.Set("getSettings", func() goja.Value {
		autoDownloader, ok := a.autoDownloader.Get()
		if !ok {
			goja_bindings.PanicThrowErrorString(vm, "autoDownloader not set")
		}
		settings := autoDownloader.GetSettings()
		if settings == nil {
			return goja.Undefined()
		}
		return vm.ToValue(settings)
	})
	_ = autoDownloaderObj.Set("isEnabled", func() goja.Value {
		autoDownloader, ok := a.autoDownloader.Get()
		if !ok {
			goja_bindings.PanicThrowErrorString(vm, "autoDownloader not set")
		}
		return vm.ToValue(autoDownloader.IsEnabled())
	})
	_ = autoDownloaderObj.Set("runNow", func() goja.Value {
		autoDownloader, ok := a.autoDownloader.Get()
		if !ok {
			goja_bindings.PanicThrowErrorString(vm, "autoDownloader not set")
		}
		autoDownloader.Run(false)
		return goja.Undefined()
	})
	_ = obj.Set("autoDownloader", autoDownloaderObj)
}

// BindAutoScannerToContextObj binds 'autoScanner' to the UI context object
func (a *AppContextImpl) BindAutoScannerToContextObj(vm *goja.Runtime, obj *goja.Object, logger *zerolog.Logger, ext *extension.Extension, scheduler *gojautil.Scheduler) {

	autoScannerObj := vm.NewObject()
	_ = autoScannerObj.Set("notify", func() goja.Value {
		autoScanner, ok := a.autoScanner.Get()
		if !ok {
			goja_bindings.PanicThrowErrorString(vm, "autoScanner not set")
		}
		autoScanner.Notify()
		return goja.Undefined()
	})
	_ = autoScannerObj.Set("runNow", func() goja.Value {
		autoScanner, ok := a.autoScanner.Get()
		if !ok {
			goja_bindings.PanicThrowErrorString(vm, "autoScanner not set")
		}
		autoScanner.RunNow()
		return goja.Undefined()
	})
	_ = autoScannerObj.Set("isEnabled", func() goja.Value {
		autoScanner, ok := a.autoScanner.Get()
		if !ok {
			goja_bindings.PanicThrowErrorString(vm, "autoScanner not set")
		}
		return vm.ToValue(autoScanner.IsEnabled())
	})
	_ = autoScannerObj.Set("isWaiting", func() goja.Value {
		autoScanner, ok := a.autoScanner.Get()
		if !ok {
			goja_bindings.PanicThrowErrorString(vm, "autoScanner not set")
		}
		return vm.ToValue(autoScanner.IsWaiting())
	})
	_ = autoScannerObj.Set("isScanning", func() goja.Value {
		autoScanner, ok := a.autoScanner.Get()
		if !ok {
			goja_bindings.PanicThrowErrorString(vm, "autoScanner not set")
		}
		return vm.ToValue(autoScanner.IsScanning())
	})
	_ = autoScannerObj.Set("getWaitTimeMs", func() goja.Value {
		autoScanner, ok := a.autoScanner.Get()
		if !ok {
			goja_bindings.PanicThrowErrorString(vm, "autoScanner not set")
		}
		return vm.ToValue(autoScanner.GetWaitTime().Milliseconds())
	})
	_ = obj.Set("autoScanner", autoScannerObj)

}

// BindFileCacherToContextObj binds 'fileCacher' to the UI context object
func (a *AppContextImpl) BindFileCacherToContextObj(vm *goja.Runtime, obj *goja.Object, logger *zerolog.Logger, ext *extension.Extension, scheduler *gojautil.Scheduler) {

}

// BindExternalPlayerLinkToContextObj binds 'externalPlayerLink' to the UI context object
func (a *AppContextImpl) BindExternalPlayerLinkToContextObj(vm *goja.Runtime, obj *goja.Object, logger *zerolog.Logger, ext *extension.Extension, scheduler *gojautil.Scheduler) {

	externalPlayerLinkObj := vm.NewObject()
	_ = externalPlayerLinkObj.Set("open", func(url string, mediaId int, episodeNumber int, mediaTitle string) goja.Value {
		wsEventManager, ok := a.wsEventManager.Get()
		if !ok {
			goja_bindings.PanicThrowErrorString(vm, "wsEventManager not set")
		}
		// Send the external player link
		wsEventManager.SendEvent(events.ExternalPlayerOpenURL, struct {
			Url           string `json:"url"`
			MediaId       int    `json:"mediaId"`
			EpisodeNumber int    `json:"episodeNumber"`
			MediaTitle    string `json:"mediaTitle"`
		}{
			Url:           url,
			MediaId:       mediaId,
			EpisodeNumber: episodeNumber,
			MediaTitle:    mediaTitle,
		})
		return goja.Undefined()
	})
	_ = obj.Set("externalPlayerLink", externalPlayerLinkObj)
}
