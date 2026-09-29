package plugin

import (
	"errors"
	"seanime/internal/extension"
	"seanime/internal/extension_repo/prompt"
	"seanime/internal/goja/goja_bindings"
	gojautil "seanime/internal/util/goja"
	"seanime/internal/util/result"

	"github.com/dop251/goja"
	"github.com/rs/zerolog"
)

func (a *AppContextImpl) bindExtensionsObj(vm *goja.Runtime, ext *extension.Extension, scheduler *gojautil.Scheduler) *goja.Object {
	extensionsObj := vm.NewObject()
	cache := newPromptCache()

	_ = extensionsObj.Set("enable", func(id string) goja.Value {
		return a.setExtensionDisabled(vm, scheduler, ext, cache, id, false)
	})

	_ = extensionsObj.Set("disable", func(id string) goja.Value {
		return a.setExtensionDisabled(vm, scheduler, ext, cache, id, true)
	})

	_ = extensionsObj.Set("setDisabled", func(id string, disabled bool) goja.Value {
		return a.setExtensionDisabled(vm, scheduler, ext, cache, id, disabled)
	})

	return extensionsObj
}

func (a *AppContextImpl) BindExtensionsToContextObj(vm *goja.Runtime, obj *goja.Object, logger *zerolog.Logger, ext *extension.Extension, scheduler *gojautil.Scheduler) {
	_ = logger
	_ = obj.Set("extensions", a.bindExtensionsObj(vm, ext, scheduler))
}

func (a *AppContextImpl) setExtensionDisabled(vm *goja.Runtime, scheduler *gojautil.Scheduler, ext *extension.Extension, cache *result.Cache[string, bool], id string, disabled bool) goja.Value {
	promise, resolve, reject := vm.NewPromise()

	go func() {
		action := "enable"
		if disabled {
			action = "disable"
		}

		target := a.extensionName(id)
		err := a.ask(ext, prompt.Options{
			Kind:     "extensions",
			Action:   action + " \"" + target + "\"",
			Resource: target,
			Message:  "Allow \"" + ext.Name + "\" to " + action + " \"" + target + "\"?",
			Details:  []string{id},
			Cache:    cache,
			CacheKey: promptKey("extensions", action, id),
		})
		if err == nil {
			if id == "" {
				err = errors.New("extension id is empty")
			} else if a.extensions.SetDisabled == nil {
				err = errors.New("extension manager not set")
			} else {
				err = a.extensions.SetDisabled(id, disabled)
			}
		}

		scheduler.ScheduleAsync(func() error {
			if err != nil {
				reject(goja_bindings.NewErrorString(vm, err.Error()))
				return nil
			}
			resolve(vm.ToValue(true))
			return nil
		})
	}()

	return vm.ToValue(promise)
}

func (a *AppContextImpl) extensionName(id string) string {
	if a.extensions.GetName == nil {
		return id
	}
	name := a.extensions.GetName(id)
	if name == "" {
		return id
	}
	return name
}
