package plugin

import (
	"seanime/internal/extension"
	"seanime/internal/testutil"
	"seanime/internal/util"
	gojautil "seanime/internal/util/goja"
	"testing"
	"time"

	"github.com/dop251/goja"
	"github.com/rs/zerolog"
	"github.com/stretchr/testify/require"
)

func newStorageTestAppContext(t *testing.T) (*AppContextImpl, *zerolog.Logger) {
	t.Helper()

	env := testutil.NewTestEnv(t)
	logger := util.NewLogger()
	database := env.MustNewDatabase(logger)

	appCtx := NewAppContext().(*AppContextImpl)
	appCtx.SetModulesPartial(AppContextModules{Database: database})

	return appCtx, logger
}

func bindTestStorage(t *testing.T, appCtx *AppContextImpl, logger *zerolog.Logger, extID string) (*Storage, *goja.Runtime, *gojautil.Scheduler) {
	t.Helper()

	runtime := goja.New()
	scheduler := gojautil.NewScheduler()
	storage := appCtx.BindStorage(runtime, logger, &extension.Extension{ID: extID}, scheduler)

	t.Cleanup(scheduler.Stop)
	t.Cleanup(storage.Stop)

	return storage, runtime, scheduler
}

func TestStorageSharesFreshDataAcrossBinders(t *testing.T) {
	appCtx, logger := newStorageTestAppContext(t)
	extID := t.Name()

	storage1, _, _ := bindTestStorage(t, appCtx, logger, extID)
	storage2, _, _ := bindTestStorage(t, appCtx, logger, extID)

	// warm a child-key cache in one binder first
	require.NoError(t, storage1.Set("user.settings.theme", "light"))

	value, err := storage2.Get("user.settings.theme")
	require.NoError(t, err)
	require.Equal(t, "light", value)

	// then overwrite the parent from another binder and expect the cached child to refresh
	require.NoError(t, storage1.Set("user.settings", map[string]interface{}{
		"theme": "dark",
		"lang":  "en",
	}))

	value, err = storage2.Get("user.settings.theme")
	require.NoError(t, err)
	require.Equal(t, "dark", value)

	// delete should also invalidate a previously cached child in the other binder
	require.NoError(t, storage1.Delete("user.settings.theme"))

	hasKey, err := storage2.Has("user.settings.theme")
	require.NoError(t, err)
	require.False(t, hasKey)

	value, err = storage2.Get("user.settings.theme")
	require.NoError(t, err)
	require.Nil(t, value)
}

func TestStorageBindingGetReturnsDetachedObjects(t *testing.T) {
	appCtx, logger := newStorageTestAppContext(t)
	extID := t.Name()

	storage, runtime, _ := bindTestStorage(t, appCtx, logger, extID)

	require.NoError(t, storage.Set("foo", map[string]interface{}{
		"nested": map[string]interface{}{"count": 1},
	}))

	_, err := runtime.RunString(`
		const value = $storage.get("foo")
		value.nested.count = 2
		value.extra = true
	`)
	require.NoError(t, err)

	value, err := storage.Get("foo")
	require.NoError(t, err)

	objectValue, ok := value.(map[string]interface{})
	require.True(t, ok)

	nested, ok := objectValue["nested"].(map[string]interface{})
	require.True(t, ok)
	require.EqualValues(t, 1, nested["count"])
	_, exists := objectValue["extra"]
	require.False(t, exists)
}

func TestStorageBindingSetDetachesOriginalObject(t *testing.T) {
	appCtx, logger := newStorageTestAppContext(t)
	extID := t.Name()

	storage, runtime, _ := bindTestStorage(t, appCtx, logger, extID)

	_, err := runtime.RunString(`
		const value = { nested: { count: 1 } }
		$storage.set("foo", value)
		value.nested.count = 2
		value.extra = true
	`)
	require.NoError(t, err)

	stored, err := storage.Get("foo")
	require.NoError(t, err)

	objectValue, ok := stored.(map[string]interface{})
	require.True(t, ok)

	nested, ok := objectValue["nested"].(map[string]interface{})
	require.True(t, ok)
	require.EqualValues(t, 1, nested["count"])
	_, exists := objectValue["extra"]
	require.False(t, exists)
}

func TestStorageWatchSharesUpdatesAcrossBinders(t *testing.T) {
	appCtx, logger := newStorageTestAppContext(t)
	extID := t.Name()

	watcherStorage, runtime, _ := bindTestStorage(t, appCtx, logger, extID)
	writerStorage, _, _ := bindTestStorage(t, appCtx, logger, extID)

	updates := make(chan interface{}, 1)
	_ = runtime.Set("recordStorageValue", func(value interface{}) {
		updates <- value
	})

	callbackValue, err := runtime.RunString("(function(value) { recordStorageValue(value); })")
	require.NoError(t, err)

	callback, ok := goja.AssertFunction(callbackValue)
	require.True(t, ok)

	cancelValue := watcherStorage.Watch("foo", callback)
	cancelFn, ok := goja.AssertFunction(cancelValue)
	require.True(t, ok)
	t.Cleanup(func() {
		_, _ = cancelFn(goja.Undefined())
	})

	require.NoError(t, writerStorage.Set("foo", "bar"))

	select {
	case value := <-updates:
		require.Equal(t, "bar", value)
	case <-time.After(2 * time.Second):
		t.Fatal("timed out waiting for cross-binder storage watch update")
	}
}

func TestStorageWatchReturnsDetachedObjects(t *testing.T) {
	appCtx, logger := newStorageTestAppContext(t)
	extID := t.Name()

	watcherStorage, runtime, _ := bindTestStorage(t, appCtx, logger, extID)
	writerStorage, _, _ := bindTestStorage(t, appCtx, logger, extID)

	updates := make(chan interface{}, 1)
	require.NoError(t, runtime.Set("recordStorageValue", func(value interface{}) {
		updates <- value
	}))

	_, err := runtime.RunString(`
		$storage.watch("foo", function(value) {
			value.nested.count = 2
			value.extra = true
			recordStorageValue(value)
		})
	`)
	require.NoError(t, err)

	require.NoError(t, writerStorage.Set("foo", map[string]interface{}{
		"nested": map[string]interface{}{"count": 1},
	}))

	select {
	case <-updates:
	case <-time.After(2 * time.Second):
		t.Fatal("timed out waiting for detached storage watch update")
	}

	value, err := watcherStorage.Get("foo")
	require.NoError(t, err)

	objectValue, ok := value.(map[string]interface{})
	require.True(t, ok)

	nested, ok := objectValue["nested"].(map[string]interface{})
	require.True(t, ok)
	require.EqualValues(t, 1, nested["count"])
	_, exists := objectValue["extra"]
	require.False(t, exists)
}
