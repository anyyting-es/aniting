package plugin

import (
	"context"
	"errors"
	"seanime/internal/extension"
	"seanime/internal/goja/goja_bindings"
	torrentsearch "seanime/internal/torrents/torrent"
	gojautil "seanime/internal/util/goja"

	"github.com/dop251/goja"
	"github.com/rs/zerolog"
)

func (a *AppContextImpl) BindTorrentSearchToContextObj(vm *goja.Runtime, obj *goja.Object, _ *zerolog.Logger, _ *extension.Extension, scheduler *gojautil.Scheduler) {
	torrentSearchObj := vm.NewObject()

	_ = torrentSearchObj.Set("getProviderIds", func() goja.Value {
		repo, ok := a.torrentRepository.Get()
		if !ok {
			goja_bindings.PanicThrowErrorString(vm, "torrent repository not set")
		}
		return vm.ToValue(repo.GetAllAnimeProviderExtensionIds())
	})

	_ = torrentSearchObj.Set("getDefaultProviderId", func() goja.Value {
		repo, ok := a.torrentRepository.Get()
		if !ok {
			goja_bindings.PanicThrowErrorString(vm, "torrent repository not set")
		}

		ext, found := repo.GetDefaultAnimeProviderExtension()
		if !found || ext == nil {
			return goja.Undefined()
		}

		return vm.ToValue(ext.GetID())
	})

	_ = torrentSearchObj.Set("searchAnime", func(opts torrentsearch.AnimeSearchOptions) goja.Value {
		promise, resolve, reject := vm.NewPromise()

		repo, ok := a.torrentRepository.Get()
		if !ok {
			goja_bindings.PanicThrowErrorString(vm, "torrent repository not set")
		}

		if opts.Media == nil {
			reject(vm.NewGoError(errors.New("media is required")))
			return vm.ToValue(promise)
		}

		if opts.Type == "" {
			reject(vm.NewGoError(errors.New("type is required")))
			return vm.ToValue(promise)
		}

		go func() {
			searchData, err := repo.SearchAnime(context.Background(), opts)
			scheduler.ScheduleAsync(func() error {
				if err != nil {
					reject(vm.NewGoError(err))
				} else {
					resolve(vm.ToValue(searchData))
				}
				return nil
			})
		}()

		return vm.ToValue(promise)
	})

	_ = obj.Set("torrentSearch", torrentSearchObj)
}
