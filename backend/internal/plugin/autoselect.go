package plugin

import (
	"context"
	"seanime/internal/api/anilist"
	"seanime/internal/database/db_bridge"
	"seanime/internal/extension"
	"seanime/internal/goja/goja_bindings"
	"seanime/internal/library/anime"
	gojautil "seanime/internal/util/goja"

	"github.com/dop251/goja"
	"github.com/rs/zerolog"
)

type autoSelectBindings struct {
	vm        *goja.Runtime
	ctx       *AppContextImpl
	scheduler *gojautil.Scheduler
}

func (a *AppContextImpl) BindAutoSelectToContextObj(vm *goja.Runtime, obj *goja.Object, _ *zerolog.Logger, _ *extension.Extension, scheduler *gojautil.Scheduler) {
	autoSelectObj := vm.NewObject()

	b := autoSelectBindings{
		vm:        vm,
		ctx:       a,
		scheduler: scheduler,
	}

	_ = autoSelectObj.Set("search", b.search)

	_ = autoSelectObj.Set("getProfile", func() goja.Value {
		database, ok := a.database.Get()
		if !ok {
			goja_bindings.PanicThrowErrorString(vm, "database not set")
		}

		profile, err := db_bridge.GetAutoSelectProfile(database)
		if err != nil {
			goja_bindings.PanicThrowError(vm, err)
		}
		if profile == nil || profile.DbID == 0 {
			return goja.Undefined()
		}

		return vm.ToValue(profile)
	})

	_ = autoSelectObj.Set("saveProfile", func(profile anime.AutoSelectProfile) goja.Value {
		database, ok := a.database.Get()
		if !ok {
			goja_bindings.PanicThrowErrorString(vm, "database not set")
		}

		if err := db_bridge.SaveAutoSelectProfile(database, &profile); err != nil {
			goja_bindings.PanicThrowError(vm, err)
		}

		saved, err := db_bridge.GetAutoSelectProfile(database)
		if err != nil || saved == nil {
			return goja.Undefined()
		}

		return vm.ToValue(saved)
	})

	_ = autoSelectObj.Set("deleteProfile", func() goja.Value {
		database, ok := a.database.Get()
		if !ok {
			goja_bindings.PanicThrowErrorString(vm, "database not set")
		}

		if err := db_bridge.DeleteAutoSelectProfile(database); err != nil {
			goja_bindings.PanicThrowError(vm, err)
		}

		return goja.Undefined()
	})

	_ = obj.Set("autoSelect", autoSelectObj)
}

func (p *autoSelectBindings) search(media *anilist.BaseAnime, episodeNumber int) goja.Value {
	promise, resolve, reject := p.vm.NewPromise()

	autoSelect, ok := p.ctx.autoSelect.Get()
	if !ok {
		goja_bindings.PanicThrowErrorString(p.vm, "autoSelect not set")
	}

	database, ok := p.ctx.database.Get()
	if !ok {
		goja_bindings.PanicThrowErrorString(p.vm, "database not set")
	}

	profile, err := db_bridge.GetAutoSelectProfile(database)
	if err != nil {
		goja_bindings.PanicThrowError(p.vm, err)
	}
	if profile == nil {
		profile = &anime.AutoSelectProfile{}
	}

	go func() {
		res, err := autoSelect.Search(context.Background(), media, episodeNumber, profile)
		p.scheduler.ScheduleAsync(func() error {
			if err != nil {
				jsErr := p.vm.NewGoError(err)
				reject(jsErr)
			} else {
				resolve(p.vm.ToValue(res))
			}
			return nil
		})
	}()

	return p.vm.ToValue(promise)
}
