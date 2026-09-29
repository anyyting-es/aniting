package plugin_ui

import (
	"context"
	"encoding/json"
	gojautil "seanime/internal/util/goja"
	"strings"
	"sync"
	"sync/atomic"
	"time"

	"github.com/dop251/goja"
)

// helpers that use existing primitives
func (c *Context) bindDXHelpers(obj *goja.Object) {
	cache := newDXCache(c)
	jobs := newDXJobs(c)

	_ = obj.Set("cache", cache.object())
	_ = obj.Set("settings", (&dxSettingsRoot{ctx: c}).object())
	_ = obj.Set("jobs", jobs.object())

	c.registerOnCleanup(cache.clear)
	c.registerOnCleanup(jobs.cancelAll)
}

type dxCache struct {
	ctx      *Context
	mu       sync.Mutex
	entries  map[string]*dxCacheEntry
	inflight map[string]goja.Value
}

type dxCacheEntry struct {
	value     goja.Value
	expiresAt time.Time
	timer     *time.Timer
}

func newDXCache(ctx *Context) *dxCache {
	return &dxCache{
		ctx:      ctx,
		entries:  make(map[string]*dxCacheEntry),
		inflight: make(map[string]goja.Value),
	}
}

func (c *dxCache) object() *goja.Object {
	obj := c.ctx.vm.NewObject()
	_ = obj.Set("get", c.get)
	_ = obj.Set("set", c.set)
	_ = obj.Set("has", c.has)
	_ = obj.Set("remove", c.remove)
	_ = obj.Set("delete", c.remove)
	_ = obj.Set("clear", func(goja.FunctionCall) goja.Value {
		c.clear()
		return goja.Undefined()
	})
	_ = obj.Set("getOrSet", c.getOrSet)
	_ = obj.Set("getOrLoad", c.getOrSet)
	_ = obj.Set("remember", c.getOrSet)
	_ = obj.Set("size", func(goja.FunctionCall) goja.Value {
		c.mu.Lock()
		defer c.mu.Unlock()
		return c.ctx.vm.ToValue(len(c.entries))
	})
	return obj
}

func (c *dxCache) get(call goja.FunctionCall) goja.Value {
	key := gojautil.ExpectStringArg(c.ctx.vm, call, 0)
	if entry := c.getEntry(key); entry != nil {
		return entry.value
	}
	if len(call.Arguments) > 1 {
		return call.Argument(1)
	}
	return goja.Undefined()
}

func (c *dxCache) set(call goja.FunctionCall) goja.Value {
	key := gojautil.ExpectStringArg(c.ctx.vm, call, 0)
	value := call.Argument(1)
	c.setValue(key, value, dxTTL(c.ctx.vm, call.Argument(2)))
	return value
}

func (c *dxCache) has(call goja.FunctionCall) goja.Value {
	key := gojautil.ExpectStringArg(c.ctx.vm, call, 0)
	return c.ctx.vm.ToValue(c.getEntry(key) != nil)
}

func (c *dxCache) remove(call goja.FunctionCall) goja.Value {
	key := gojautil.ExpectStringArg(c.ctx.vm, call, 0)
	return c.ctx.vm.ToValue(c.removeKey(key))
}

func (c *dxCache) getOrSet(call goja.FunctionCall) goja.Value {
	key := gojautil.ExpectStringArg(c.ctx.vm, call, 0)
	loader := gojautil.ExpectFunctionArg(c.ctx.vm, call, 1)
	ttl := dxTTL(c.ctx.vm, call.Argument(2))

	if entry := c.getEntry(key); entry != nil {
		return entry.value
	}
	if promise := c.getInflight(key); promise != nil {
		return promise
	}

	value, err := loader(c.ctx.vm.GlobalObject())
	if err != nil {
		panic(err)
	}
	if dxIsThenable(c.ctx.vm, value) {
		return c.trackPromise(key, value, ttl)
	}

	c.setValue(key, value, ttl)
	return value
}

func (c *dxCache) getEntry(key string) *dxCacheEntry {
	c.mu.Lock()
	defer c.mu.Unlock()

	entry := c.entries[key]
	if entry == nil {
		return nil
	}
	if !entry.expiresAt.IsZero() && time.Now().After(entry.expiresAt) {
		if entry.timer != nil {
			entry.timer.Stop()
		}
		delete(c.entries, key)
		return nil
	}
	return entry
}

func (c *dxCache) setValue(key string, value goja.Value, ttl time.Duration) {
	entry := &dxCacheEntry{value: value}
	if ttl > 0 {
		entry.expiresAt = time.Now().Add(ttl)
		entry.timer = time.AfterFunc(ttl, func() {
			c.mu.Lock()
			if c.entries[key] == entry {
				delete(c.entries, key)
			}
			c.mu.Unlock()
		})
	}

	c.mu.Lock()
	if old := c.entries[key]; old != nil && old.timer != nil {
		old.timer.Stop()
	}
	c.entries[key] = entry
	c.mu.Unlock()
}

func (c *dxCache) getInflight(key string) goja.Value {
	c.mu.Lock()
	defer c.mu.Unlock()
	return c.inflight[key]
}

func (c *dxCache) setInflight(key string, promise goja.Value) {
	c.mu.Lock()
	c.inflight[key] = promise
	c.mu.Unlock()
}

func (c *dxCache) deleteInflight(key string, promise goja.Value) {
	c.mu.Lock()
	if c.inflight[key] == promise {
		delete(c.inflight, key)
	}
	c.mu.Unlock()
}

func (c *dxCache) removeKey(key string) bool {
	c.mu.Lock()
	defer c.mu.Unlock()

	entry, ok := c.entries[key]
	if entry != nil && entry.timer != nil {
		entry.timer.Stop()
	}
	delete(c.entries, key)
	delete(c.inflight, key)
	return ok
}

func (c *dxCache) clear() {
	c.mu.Lock()
	defer c.mu.Unlock()

	for _, entry := range c.entries {
		if entry.timer != nil {
			entry.timer.Stop()
		}
	}
	c.entries = make(map[string]*dxCacheEntry)
	c.inflight = make(map[string]goja.Value)
}

func (c *dxCache) trackPromise(key string, value goja.Value, ttl time.Duration) goja.Value {
	promise, resolve, reject := c.ctx.vm.NewPromise()
	promiseValue := c.ctx.vm.ToValue(promise)
	c.setInflight(key, promiseValue)

	dxThen(c.ctx.vm, value, func(result goja.Value) {
		c.deleteInflight(key, promiseValue)
		c.setValue(key, result, ttl)
		_ = resolve(result)
	}, func(reason goja.Value) {
		c.deleteInflight(key, promiseValue)
		c.removeKey(key)
		_ = reject(reason)
	})

	return promiseValue
}

type dxSettingsRoot struct {
	ctx *Context
}

func (s *dxSettingsRoot) object() *goja.Object {
	obj := s.ctx.vm.NewObject()
	_ = obj.Set("define", s.define)
	return obj
}

func (s *dxSettingsRoot) define(call goja.FunctionCall) goja.Value {
	name := gojautil.ExpectStringArg(s.ctx.vm, call, 0)
	settings := &dxSettings{
		ctx:      s.ctx,
		key:      "settings:" + name,
		defaults: dxMap(call.Argument(1).Export()),
		watchers: make(map[int64]goja.Callable),
	}
	settings.save(settings.load())
	return settings.object()
}

type dxSettings struct {
	ctx      *Context
	key      string
	defaults map[string]interface{}
	watchID  atomic.Int64
	mu       sync.Mutex
	watchers map[int64]goja.Callable
}

func (s *dxSettings) object() *goja.Object {
	obj := s.ctx.vm.NewObject()
	_ = obj.Set("key", s.key)
	_ = obj.Set("defaults", dxClone(s.defaults))
	_ = obj.Set("get", s.get)
	_ = obj.Set("set", s.set)
	_ = obj.Set("save", s.jsSave)
	_ = obj.Set("reset", func(goja.FunctionCall) goja.Value { return s.ctx.vm.ToValue(s.save(s.defaults)) })
	_ = obj.Set("fieldRef", s.fieldRef)
	_ = obj.Set("watch", s.watch)
	return obj
}

func (s *dxSettings) get(call goja.FunctionCall) goja.Value {
	current := s.load()
	if len(call.Arguments) == 0 || dxEmpty(call.Argument(0)) {
		return s.ctx.vm.ToValue(current)
	}

	value, ok := dxReadPath(current, call.Argument(0).String())
	if !ok {
		if len(call.Arguments) > 1 {
			return call.Argument(1)
		}
		return goja.Undefined()
	}
	return s.ctx.vm.ToValue(value)
}

func (s *dxSettings) set(call goja.FunctionCall) goja.Value {
	if len(call.Arguments) == 1 {
		return s.ctx.vm.ToValue(s.save(dxMerge(s.load(), call.Argument(0).Export())))
	}

	path := gojautil.ExpectStringArg(s.ctx.vm, call, 0)
	next := dxWritePath(s.load(), path, call.Argument(1).Export())
	return s.ctx.vm.ToValue(s.save(next))
}

func (s *dxSettings) jsSave(call goja.FunctionCall) goja.Value {
	if len(call.Arguments) == 0 || dxEmpty(call.Argument(0)) {
		return s.ctx.vm.ToValue(s.save(s.load()))
	}
	return s.ctx.vm.ToValue(s.save(call.Argument(0).Export()))
}

func (s *dxSettings) fieldRef(call goja.FunctionCall) goja.Value {
	current := s.load()
	if len(call.Arguments) == 0 || dxEmpty(call.Argument(0)) {
		return s.ctx.jsfieldRef(goja.FunctionCall{Arguments: []goja.Value{s.ctx.vm.ToValue(current)}})
	}
	value, _ := dxReadPath(current, call.Argument(0).String())
	return s.ctx.jsfieldRef(goja.FunctionCall{Arguments: []goja.Value{s.ctx.vm.ToValue(value)}})
}

func (s *dxSettings) watch(call goja.FunctionCall) goja.Value {
	callback := gojautil.ExpectFunctionArg(s.ctx.vm, call, 0)
	id := s.watchID.Add(1)

	s.mu.Lock()
	s.watchers[id] = callback
	s.mu.Unlock()

	cancel := func() {
		s.mu.Lock()
		delete(s.watchers, id)
		s.mu.Unlock()
	}
	s.ctx.registerOnCleanup(cancel)

	return s.ctx.vm.ToValue(func(goja.FunctionCall) goja.Value {
		cancel()
		return goja.Undefined()
	})
}

func (s *dxSettings) load() map[string]interface{} {
	var stored interface{}
	if s.ctx.store != nil {
		if value, ok := s.ctx.store.GetOk(s.key); ok {
			stored = value
		}
	}
	if stored == nil && s.ctx.storage != nil {
		value, err := s.ctx.storage.Get(s.key)
		if err == nil {
			stored = value
		}
	}
	return dxMerge(s.defaults, stored)
}

func (s *dxSettings) save(next interface{}) map[string]interface{} {
	value := dxMerge(s.defaults, next)
	if s.ctx.store != nil {
		s.ctx.store.Set(s.key, dxClone(value))
	}
	if s.ctx.storage != nil {
		if err := s.ctx.storage.Set(s.key, dxClone(value)); err != nil {
			panic(s.ctx.vm.NewGoError(err))
		}
	}
	s.notify(value)
	return value
}

func (s *dxSettings) notify(value map[string]interface{}) {
	s.mu.Lock()
	watchers := make([]goja.Callable, 0, len(s.watchers))
	for _, watcher := range s.watchers {
		watchers = append(watchers, watcher)
	}
	s.mu.Unlock()

	if len(watchers) == 0 {
		return
	}
	for _, watcher := range watchers {
		next := dxClone(value)
		if _, err := watcher(s.ctx.vm.GlobalObject(), s.ctx.vm.ToValue(next)); err != nil {
			panic(err)
		}
	}
}

type dxJobs struct {
	ctx      *Context
	mu       sync.Mutex
	cancelID atomic.Int64
	cancels  map[string]dxCancel
	running  map[string]goja.Value
}

type dxCancel struct {
	id     int64
	cancel context.CancelFunc
}

func newDXJobs(ctx *Context) *dxJobs {
	return &dxJobs{
		ctx:     ctx,
		cancels: make(map[string]dxCancel),
		running: make(map[string]goja.Value),
	}
}

func (j *dxJobs) object() *goja.Object {
	obj := j.ctx.vm.NewObject()
	_ = obj.Set("singleflight", j.singleflight)
	_ = obj.Set("debounce", j.debounce)
	_ = obj.Set("poll", j.poll)
	_ = obj.Set("cancel", func(call goja.FunctionCall) goja.Value {
		key := gojautil.ExpectStringArg(j.ctx.vm, call, 0)
		return j.ctx.vm.ToValue(j.cancel(key))
	})
	_ = obj.Set("cancelAll", func(goja.FunctionCall) goja.Value {
		j.cancelAll()
		return goja.Undefined()
	})
	_ = obj.Set("isRunning", func(call goja.FunctionCall) goja.Value {
		key := gojautil.ExpectStringArg(j.ctx.vm, call, 0)
		return j.ctx.vm.ToValue(j.isRunning(key))
	})
	return obj
}

func (j *dxJobs) singleflight(call goja.FunctionCall) goja.Value {
	key := gojautil.ExpectStringArg(j.ctx.vm, call, 0)
	fn := dxExpectFunction(j.ctx.vm, call, 1)

	j.mu.Lock()
	if promise := j.running[key]; promise != nil {
		j.mu.Unlock()
		return promise
	}
	promise, resolve, reject := j.ctx.vm.NewPromise()
	promiseValue := j.ctx.vm.ToValue(promise)
	j.running[key] = promiseValue
	j.mu.Unlock()

	value, err := fn(j.ctx.vm.GlobalObject())
	if err != nil {
		j.deleteRunning(key, promiseValue)
		_ = reject(err)
		return promiseValue
	}
	if dxIsThenable(j.ctx.vm, value) {
		dxThen(j.ctx.vm, value, func(result goja.Value) {
			j.deleteRunning(key, promiseValue)
			_ = resolve(result)
		}, func(reason goja.Value) {
			j.deleteRunning(key, promiseValue)
			_ = reject(reason)
		})
		return promiseValue
	}

	j.deleteRunning(key, promiseValue)
	_ = resolve(value)

	return promiseValue
}

func (j *dxJobs) debounce(call goja.FunctionCall) goja.Value {
	key := gojautil.ExpectStringArg(j.ctx.vm, call, 0)
	fn := gojautil.ExpectFunctionArg(j.ctx.vm, call, 1)
	delay := dxDelay(j.ctx.vm, call.Argument(2))

	j.cancel(key)
	ctx, cancel := context.WithCancel(context.Background())
	timer := time.NewTimer(delay)
	cancelFn := func() {
		cancel()
		timer.Stop()
	}
	cancelID := j.setCancel(key, cancelFn)

	go func() {
		select {
		case <-ctx.Done():
			return
		case <-timer.C:
			j.deleteCancel(key, cancelID)
			j.ctx.scheduler.ScheduleAsync(func() error {
				_, err := fn(j.ctx.vm.GlobalObject())
				return err
			})
		}
	}()

	return j.ctx.vm.ToValue(func(goja.FunctionCall) goja.Value {
		j.cancel(key)
		return goja.Undefined()
	})
}

func (j *dxJobs) poll(call goja.FunctionCall) goja.Value {
	key := gojautil.ExpectStringArg(j.ctx.vm, call, 0)
	fn := gojautil.ExpectFunctionArg(j.ctx.vm, call, 1)
	interval := dxDelay(j.ctx.vm, call.Argument(2))
	immediate := false
	if len(call.Arguments) > 3 && !dxEmpty(call.Argument(3)) {
		immediate = call.Argument(3).ToObject(j.ctx.vm).Get("immediate").ToBoolean()
	}

	j.cancel(key)
	ctx, cancel := context.WithCancel(context.Background())
	j.setCancel(key, cancel)

	invoke := func() (goja.Value, error) {
		return fn(j.ctx.vm.GlobalObject())
	}

	run := func() {
		j.ctx.scheduler.ScheduleAsync(func() error {
			value, err := invoke()
			if err != nil {
				return err
			}
			dxCatch(j.ctx.vm, value)
			return nil
		})
	}
	if immediate {
		value, err := invoke()
		if err != nil {
			panic(err)
		}
		dxCatch(j.ctx.vm, value)
	}

	go func() {
		ticker := time.NewTicker(interval)
		defer ticker.Stop()
		for {
			select {
			case <-ctx.Done():
				return
			case <-ticker.C:
				run()
			}
		}
	}()

	return j.ctx.vm.ToValue(func(goja.FunctionCall) goja.Value {
		j.cancel(key)
		return goja.Undefined()
	})
}

func (j *dxJobs) setCancel(key string, cancel context.CancelFunc) int64 {
	id := j.cancelID.Add(1)
	j.mu.Lock()
	j.cancels[key] = dxCancel{id: id, cancel: cancel}
	j.mu.Unlock()
	return id
}

func (j *dxJobs) deleteCancel(key string, cancelID int64) {
	j.mu.Lock()
	if current := j.cancels[key]; current.id == cancelID {
		delete(j.cancels, key)
	}
	j.mu.Unlock()
}

func (j *dxJobs) cancel(key string) bool {
	j.mu.Lock()
	entry, ok := j.cancels[key]
	if ok {
		delete(j.cancels, key)
	}
	j.mu.Unlock()

	if !ok {
		return false
	}
	entry.cancel()
	return true
}

func (j *dxJobs) cancelAll() {
	j.mu.Lock()
	cancels := make([]context.CancelFunc, 0, len(j.cancels))
	for _, entry := range j.cancels {
		cancels = append(cancels, entry.cancel)
	}
	j.cancels = make(map[string]dxCancel)
	j.running = make(map[string]goja.Value)
	j.mu.Unlock()

	for _, cancel := range cancels {
		cancel()
	}
}

func (j *dxJobs) isRunning(key string) bool {
	j.mu.Lock()
	defer j.mu.Unlock()
	return j.running[key] != nil
}

func (j *dxJobs) deleteRunning(key string, promise goja.Value) {
	j.mu.Lock()
	if j.running[key] == promise {
		delete(j.running, key)
	}
	j.mu.Unlock()
}

func dxThen(vm *goja.Runtime, value goja.Value, onResolve func(goja.Value), onReject func(goja.Value)) {
	then, this, ok := dxThenable(vm, value)
	if !ok {
		onResolve(value)
		return
	}

	resolve := func(call goja.FunctionCall) goja.Value {
		onResolve(call.Argument(0))
		return goja.Undefined()
	}
	reject := func(call goja.FunctionCall) goja.Value {
		onReject(call.Argument(0))
		return goja.Undefined()
	}
	if _, err := then(this, vm.ToValue(resolve), vm.ToValue(reject)); err != nil {
		onReject(vm.NewGoError(err))
	}
}

func dxCatch(vm *goja.Runtime, value goja.Value) {
	then, this, ok := dxThenable(vm, value)
	if !ok {
		return
	}
	noop := func(goja.FunctionCall) goja.Value { return goja.Undefined() }
	logError := func(call goja.FunctionCall) goja.Value {
		if console := vm.GlobalObject().Get("console"); !dxEmpty(console) {
			if log, ok := goja.AssertFunction(console.ToObject(vm).Get("error")); ok {
				_, _ = log(console, call.Argument(0))
			}
		}
		return goja.Undefined()
	}
	_, _ = then(this, vm.ToValue(noop), vm.ToValue(logError))
}

func dxIsThenable(vm *goja.Runtime, value goja.Value) bool {
	_, _, ok := dxThenable(vm, value)
	return ok
}

func dxThenable(vm *goja.Runtime, value goja.Value) (goja.Callable, goja.Value, bool) {
	if dxEmpty(value) {
		return nil, nil, false
	}
	obj := value.ToObject(vm)
	then, ok := goja.AssertFunction(obj.Get("then"))
	return then, value, ok
}

func dxTTL(vm *goja.Runtime, value goja.Value) time.Duration {
	if dxEmpty(value) {
		return 0
	}
	if _, ok := value.Export().(map[string]interface{}); ok {
		value = value.ToObject(vm).Get("ttl")
	}
	if dxEmpty(value) || value.ToInteger() <= 0 {
		return 0
	}
	return time.Duration(value.ToInteger()) * time.Millisecond
}

func dxDelay(vm *goja.Runtime, value goja.Value) time.Duration {
	if dxEmpty(value) {
		panic(vm.NewTypeError("delay is required"))
	}
	delay := value.ToInteger()
	if delay <= 0 {
		delay = 1
	}
	return time.Duration(delay) * time.Millisecond
}

func dxExpectFunction(vm *goja.Runtime, call goja.FunctionCall, index int) goja.Callable {
	if fn, ok := goja.AssertFunction(call.Argument(index)); ok {
		return fn
	}
	for i, arg := range call.Arguments {
		if i == 0 || i == index {
			continue
		}
		if fn, ok := goja.AssertFunction(arg); ok {
			return fn
		}
	}
	panic(vm.NewTypeError("callback must be a function"))
}

func dxEmpty(value goja.Value) bool {
	return value == nil || goja.IsUndefined(value) || goja.IsNull(value)
}

func dxMap(value interface{}) map[string]interface{} {
	if value == nil {
		return map[string]interface{}{}
	}
	if v, ok := dxClone(value).(map[string]interface{}); ok {
		return v
	}
	return map[string]interface{}{}
}

func dxMerge(defaults interface{}, stored interface{}) map[string]interface{} {
	ret := dxMap(defaults)
	for key, value := range dxMap(stored) {
		ret[key] = value
	}
	return ret
}

func dxReadPath(value interface{}, path string) (interface{}, bool) {
	current := value
	for _, part := range strings.Split(path, ".") {
		if part == "" {
			continue
		}
		m, ok := current.(map[string]interface{})
		if !ok {
			return nil, false
		}
		current, ok = m[part]
		if !ok {
			return nil, false
		}
	}
	return current, true
}

func dxWritePath(value map[string]interface{}, path string, next interface{}) map[string]interface{} {
	ret := dxMap(value)
	parts := strings.Split(path, ".")
	if len(parts) == 0 {
		return dxMap(next)
	}

	current := ret
	for _, part := range parts[:len(parts)-1] {
		if part == "" {
			continue
		}
		nested, ok := current[part].(map[string]interface{})
		if !ok {
			nested = map[string]interface{}{}
			current[part] = nested
		}
		current = nested
	}
	last := parts[len(parts)-1]
	if last != "" {
		current[last] = dxClone(next)
	}
	return ret
}

func dxClone(value interface{}) interface{} {
	if value == nil {
		return nil
	}
	bs, err := json.Marshal(value)
	if err != nil {
		return value
	}
	var ret interface{}
	if err = json.Unmarshal(bs, &ret); err != nil {
		return value
	}
	return ret
}
