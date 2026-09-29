package plugin_ui

import (
	"encoding/json"
	"fmt"
	wsevents "seanime/internal/events"
	"seanime/internal/extension"
	"strings"
	"sync"
	"time"

	"github.com/dop251/goja"
)

func BindDebug(vm *goja.Runtime, ext *extension.Extension, wsEventManager wsevents.WSEventManagerInterface) *goja.Object {
	if value := vm.Get("$debug"); value != nil && !goja.IsUndefined(value) && !goja.IsNull(value) {
		return value.ToObject(vm)
	}

	debugObj := newDebug(vm, ext, wsEventManager)
	_ = vm.Set("$debug", debugObj)
	return debugObj
}

func newDebug(vm *goja.Runtime, ext *extension.Extension, wsEventManager wsevents.WSEventManagerInterface) *goja.Object {
	debugObj := vm.NewObject()
	_ = debugObj.Set("enabled", ext != nil && ext.IsDevelopment)

	noop := func(goja.FunctionCall) goja.Value { return goja.Undefined() }
	if ext == nil || !ext.IsDevelopment {
		for _, name := range []string{"log", "info", "warn", "error", "debug", "inspect", "mark", "time", "timeEnd", "clear"} {
			_ = debugObj.Set(name, noop)
		}
		return debugObj
	}

	timers := map[string]time.Time{}
	var timersMu sync.Mutex

	log := func(level string) func(goja.FunctionCall) goja.Value {
		return func(call goja.FunctionCall) goja.Value {
			sendDebugLog(vm, ext, wsEventManager, level, call.Arguments)
			return goja.Undefined()
		}
	}

	_ = debugObj.Set("log", log("log"))
	_ = debugObj.Set("info", log("info"))
	_ = debugObj.Set("warn", log("warn"))
	_ = debugObj.Set("error", log("error"))
	_ = debugObj.Set("debug", log("debug"))
	_ = debugObj.Set("inspect", log("debug"))
	_ = debugObj.Set("mark", log("info"))
	_ = debugObj.Set("clear", func(goja.FunctionCall) goja.Value {
		sendDebugEvent(ext, wsEventManager, ServerDebugClearEvent, ServerDebugClearEventPayload{})
		return goja.Undefined()
	})
	_ = debugObj.Set("time", func(call goja.FunctionCall) goja.Value {
		label := "default"
		if len(call.Arguments) > 0 && !goja.IsUndefined(call.Argument(0)) {
			label = call.Argument(0).String()
		}
		timersMu.Lock()
		timers[label] = time.Now()
		timersMu.Unlock()
		return goja.Undefined()
	})
	_ = debugObj.Set("timeEnd", func(call goja.FunctionCall) goja.Value {
		label := "default"
		if len(call.Arguments) > 0 && !goja.IsUndefined(call.Argument(0)) {
			label = call.Argument(0).String()
		}
		timersMu.Lock()
		startedAt, ok := timers[label]
		delete(timers, label)
		timersMu.Unlock()
		if ok {
			sendDebugLog(vm, ext, wsEventManager, "debug", []goja.Value{vm.ToValue(label), vm.ToValue(map[string]interface{}{
				"durationMs": time.Since(startedAt).Milliseconds(),
			})})
		}
		return goja.Undefined()
	})

	return debugObj
}

func sendDebugLog(vm *goja.Runtime, ext *extension.Extension, wsEventManager wsevents.WSEventManagerInterface, level string, args []goja.Value) {
	values := make([]interface{}, 0, len(args))
	parts := make([]string, 0, len(args))
	for _, arg := range args {
		value := debugValue(arg)
		values = append(values, value)
		parts = append(parts, debugString(value))
	}

	sendDebugEvent(ext, wsEventManager, ServerDebugLogEvent, ServerDebugLogEventPayload{
		At:      time.Now().UnixMilli(),
		Level:   level,
		Message: strings.Join(parts, " "),
		Values:  values,
	})
}

func sendDebugEvent(ext *extension.Extension, wsEventManager wsevents.WSEventManagerInterface, eventType ServerEventType, payload interface{}) {
	if ext == nil || wsEventManager == nil {
		return
	}

	wsEventManager.SendEvent(string(wsevents.PluginEvent), &ServerPluginEvent{
		ExtensionID: ext.ID,
		Type:        eventType,
		Payload:     payload,
	})
}

func debugValue(value goja.Value) interface{} {
	if value == nil || goja.IsUndefined(value) {
		return nil
	}

	if obj, ok := value.(*goja.Object); ok {
		constructor := obj.Get("constructor")
		if constructorObj, ok := constructor.(*goja.Object); ok {
			name := constructorObj.Get("name")
			if name != nil && !goja.IsUndefined(name) && strings.HasSuffix(name.String(), "Error") {
				ret := map[string]interface{}{"name": name.String()}
				if message := obj.Get("message"); message != nil && !goja.IsUndefined(message) {
					ret["message"] = message.String()
				}
				if stack := obj.Get("stack"); stack != nil && !goja.IsUndefined(stack) {
					ret["stack"] = stack.String()
				}
				return ret
			}
		}
	}

	exported := value.Export()
	if _, err := json.Marshal(exported); err != nil {
		return value.String()
	}
	return exported
}

func debugString(value interface{}) string {
	switch v := value.(type) {
	case nil:
		return "undefined"
	case string:
		return v
	case bool, int, int64, float64:
		return fmt.Sprintf("%v", v)
	default:
		bs, err := json.Marshal(v)
		if err != nil {
			return fmt.Sprintf("%v", v)
		}
		return string(bs)
	}
}
