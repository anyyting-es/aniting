package plugin

import (
	"context"
	"seanime/internal/extension"
	"seanime/internal/goja/goja_bindings"
	"seanime/internal/torrentstream"
	gojautil "seanime/internal/util/goja"

	"github.com/dop251/goja"
	"github.com/rs/zerolog"
)

func (a *AppContextImpl) BindTorrentstreamToContextObj(vm *goja.Runtime, obj *goja.Object, _ *zerolog.Logger, _ *extension.Extension, scheduler *gojautil.Scheduler) {
	torrentstreamObj := vm.NewObject()

	_ = torrentstreamObj.Set("isEnabled", func() goja.Value {
		repo, ok := a.torrentstreamRepository.Get()
		if !ok {
			goja_bindings.PanicThrowErrorString(vm, "torrentstream repository not set")
		}
		return vm.ToValue(repo.IsEnabled())
	})

	_ = torrentstreamObj.Set("getPreviousStreamOptions", func() goja.Value {
		repo, ok := a.torrentstreamRepository.Get()
		if !ok {
			goja_bindings.PanicThrowErrorString(vm, "torrentstream repository not set")
		}
		opts, found := repo.GetPreviousStreamOptions()
		if !found || opts == nil {
			return goja.Undefined()
		}
		return vm.ToValue(opts)
	})

	_ = torrentstreamObj.Set("getBatchHistory", func(mediaId int) goja.Value {
		repo, ok := a.torrentstreamRepository.Get()
		if !ok {
			goja_bindings.PanicThrowErrorString(vm, "torrentstream repository not set")
		}
		resp := repo.GetBatchHistory(mediaId)
		if resp == nil || resp.Torrent == nil {
			return goja.Undefined()
		}
		return vm.ToValue(resp)
	})

	_ = torrentstreamObj.Set("startStream", func(opts torrentstream.StartStreamOptions) goja.Value {
		promise, resolve, reject := vm.NewPromise()

		repo, ok := a.torrentstreamRepository.Get()
		if !ok {
			goja_bindings.PanicThrowErrorString(vm, "torrentstream repository not set")
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

	// _ = torrentstreamObj.Set("preloadStream", func(opts torrentstream.StartStreamOptions) goja.Value {
	// 	promise, resolve, reject := vm.NewPromise()

	// 	repo, ok := a.torrentstreamRepository.Get()
	// 	if !ok {
	// 		goja_bindings.PanicThrowErrorString(vm, "torrentstream repository not set")
	// 	}

	// 	if err := validatePlaybackTarget(string(opts.PlaybackType), opts.ClientId); err != nil {
	// 		reject(vm.NewGoError(err))
	// 		return vm.ToValue(promise)
	// 	}

	// 	go func() {
	// 		err := repo.PreloadStream(context.Background(), &opts)
	// 		scheduler.ScheduleAsync(func() error {
	// 			if err != nil {
	// 				reject(vm.NewGoError(err))
	// 			} else {
	// 				resolve(goja.Undefined())
	// 			}
	// 			return nil
	// 		})
	// 	}()

	// 	return vm.ToValue(promise)
	// })

	_ = torrentstreamObj.Set("stopStream", func() goja.Value {
		promise, resolve, reject := vm.NewPromise()

		repo, ok := a.torrentstreamRepository.Get()
		if !ok {
			goja_bindings.PanicThrowErrorString(vm, "torrentstream repository not set")
		}

		go func() {
			err := repo.StopStream()
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

	_ = torrentstreamObj.Set("cancelPreparedStream", func() goja.Value {
		repo, ok := a.torrentstreamRepository.Get()
		if !ok {
			goja_bindings.PanicThrowErrorString(vm, "torrentstream repository not set")
		}
		repo.CancelPreparedStream()
		return goja.Undefined()
	})

	_ = obj.Set("torrentstream", torrentstreamObj)
}
