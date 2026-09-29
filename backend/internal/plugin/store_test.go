package plugin

import (
	gojautil "seanime/internal/util/goja"
	"testing"
	"time"

	"github.com/dop251/goja"
	"github.com/stretchr/testify/require"
)

func bindTestStore(t *testing.T, data map[string]any) (*Store[string, any], *goja.Runtime, *gojautil.Scheduler) {
	t.Helper()

	store := NewStore[string, any](data)
	runtime := goja.New()
	scheduler := gojautil.NewScheduler()
	store.Bind(runtime, scheduler)

	t.Cleanup(scheduler.Stop)
	t.Cleanup(store.Stop)

	return store, runtime, scheduler
}

func TestStoreBindingGetReturnsDetachedObjects(t *testing.T) {
	store, runtime, _ := bindTestStore(t, map[string]any{
		"state": map[string]any{
			"nested": map[string]any{"count": 1},
		},
	})

	_, err := runtime.RunString(`
		const state = $store.get("state")
		state.nested.count = 2
		state.extra = { ok: true }
	`)
	require.NoError(t, err)

	value, ok := store.Get("state").(map[string]any)
	require.True(t, ok)

	nested, ok := value["nested"].(map[string]any)
	require.True(t, ok)
	require.EqualValues(t, 1, nested["count"])
	_, exists := value["extra"]
	require.False(t, exists)
}

func TestStoreBindingSetDetachesOriginalObject(t *testing.T) {
	store, runtime, _ := bindTestStore(t, nil)

	_, err := runtime.RunString(`
		const state = { nested: { count: 1 } }
		$store.set("state", state)
		state.nested.count = 2
		state.extra = true
	`)
	require.NoError(t, err)

	value, ok := store.Get("state").(map[string]any)
	require.True(t, ok)

	nested, ok := value["nested"].(map[string]any)
	require.True(t, ok)
	require.EqualValues(t, 1, nested["count"])
	_, exists := value["extra"]
	require.False(t, exists)
}

func TestStoreBindingWatchReturnsDetachedObjects(t *testing.T) {
	store, runtime, _ := bindTestStore(t, nil)

	updates := make(chan interface{}, 1)
	require.NoError(t, runtime.Set("recordStoreValue", func(value interface{}) {
		updates <- value
	}))

	_, err := runtime.RunString(`
		$store.watch("state", function(value) {
			value.nested.count = 2
			value.extra = true
			recordStoreValue(value)
		})
	`)
	require.NoError(t, err)

	store.Set("state", map[string]any{
		"nested": map[string]any{"count": 1},
	})

	select {
	case <-updates:
	case <-time.After(2 * time.Second):
		t.Fatal("timed out waiting for store watch update")
	}

	value, ok := store.Get("state").(map[string]any)
	require.True(t, ok)

	nested, ok := value["nested"].(map[string]any)
	require.True(t, ok)
	require.EqualValues(t, 1, nested["count"])
	_, exists := value["extra"]
	require.False(t, exists)
}
