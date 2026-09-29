package goja_bindings

import (
	"fmt"
	"net/http"
	"net/http/httptest"
	gojautil "seanime/internal/util/goja"
	"sync"
	"sync/atomic"
	"testing"
	"time"

	"github.com/dop251/goja"
	"github.com/stretchr/testify/require"
)

func TestAbortContextStateAndReason(t *testing.T) {
	t.Run("default abort state and reason", func(t *testing.T) {
		vm, _ := newAbortTestRuntime(t)

		val, err := vm.RunString(`
			(() => {
				const controller = new AbortContext();
				const signal = controller.signal;
				const initialAborted = signal.aborted;

				controller.abort();
				const defaultReason = String(signal.reason);

				controller.abort("ignored");

				return {
					initialAborted,
					finalAborted: signal.aborted,
					defaultReason,
					finalReason: String(signal.reason),
				};
			})()
		`)
		require.NoError(t, err)

		obj := val.ToObject(vm)
		require.False(t, obj.Get("initialAborted").ToBoolean())
		require.True(t, obj.Get("finalAborted").ToBoolean())
		require.Contains(t, obj.Get("defaultReason").String(), "context canceled")
		require.Equal(t, obj.Get("defaultReason").String(), obj.Get("finalReason").String())
	})

	t.Run("custom abort reason", func(t *testing.T) {
		vm, _ := newAbortTestRuntime(t)

		val, err := vm.RunString(`
			(() => {
				const controller = new AbortContext();
				controller.abort("Custom reason");
				return {
					aborted: controller.signal.aborted,
					reason: controller.signal.reason,
				};
			})()
		`)
		require.NoError(t, err)

		obj := val.ToObject(vm)
		require.True(t, obj.Get("aborted").ToBoolean())
		require.Equal(t, "Custom reason", obj.Get("reason").String())
	})
}

func TestAbortContextAbortListeners(t *testing.T) {
	t.Run("listener fires once when registered before abort", func(t *testing.T) {
		vm, _ := newAbortTestRuntime(t)

		var count atomic.Int32
		reasons := make(chan string, 1)
		vm.Set("recordAbort", func(reason string) {
			count.Add(1)
			reasons <- reason
		})

		_, err := vm.RunString(`
			(() => {
				const controller = new AbortContext();
				controller.signal.addEventListener("abort", () => {
					recordAbort(String(controller.signal.reason));
				});
				controller.abort("first");
				controller.abort("second");
			})();
		`)
		require.NoError(t, err)

		select {
		case reason := <-reasons:
			require.Equal(t, "first", reason)
		case <-time.After(time.Second):
			t.Fatal("abort listener was not called")
		}

		require.Eventually(t, func() bool {
			return count.Load() == 1
		}, time.Second, 10*time.Millisecond)
		time.Sleep(50 * time.Millisecond)
		require.Equal(t, int32(1), count.Load())
	})

	t.Run("listener added after abort fires asynchronously", func(t *testing.T) {
		vm, _ := newAbortTestRuntime(t)

		reasons := make(chan string, 1)
		vm.Set("recordAbort", func(reason string) {
			reasons <- reason
		})

		_, err := vm.RunString(`
			(() => {
				const controller = new AbortContext();
				controller.abort("late-reason");
				controller.signal.addEventListener("abort", () => {
					recordAbort(String(controller.signal.reason));
				});
			})();
		`)
		require.NoError(t, err)

		select {
		case reason := <-reasons:
			require.Equal(t, "late-reason", reason)
		case <-time.After(time.Second):
			t.Fatal("late abort listener was not called")
		}
	})
}

func TestAbortContextWithFetch(t *testing.T) {
	t.Run("already aborted signal rejects before request starts", func(t *testing.T) {
		vm, _ := newAbortTestRuntime(t)

		var requestCount atomic.Int32
		server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			requestCount.Add(1)
			w.WriteHeader(http.StatusOK)
		}))
		defer server.Close()

		fetch := BindFetch("", vm, []string{"*"})
		defer fetch.Close()

		val, err := vm.RunString(fmt.Sprintf(`
			(() => {
				const controller = new AbortContext();
				controller.abort("request aborted");
				return fetch(%q, {
					signal: controller.signal,
				});
			})()
		`, server.URL))
		require.NoError(t, err)

		promise := requirePromise(t, val)
		waitForPromiseState(t, promise, goja.PromiseStateRejected)
		require.Equal(t, "request aborted", promise.Result().Export())
		require.Equal(t, int32(0), requestCount.Load())
	})

	t.Run("in-flight request is canceled through signal context", func(t *testing.T) {
		vm, _ := newAbortTestRuntime(t)

		started := make(chan struct{})
		canceled := make(chan struct{})
		var startedOnce sync.Once
		var canceledOnce sync.Once

		server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			startedOnce.Do(func() { close(started) })

			select {
			case <-r.Context().Done():
				canceledOnce.Do(func() { close(canceled) })
			case <-time.After(2 * time.Second):
				w.WriteHeader(http.StatusGatewayTimeout)
			}
		}))
		defer server.Close()

		fetch := BindFetch("", vm, []string{"*"})
		defer fetch.Close()

		val, err := vm.RunString(fmt.Sprintf(`
			(() => {
				globalThis.controller = new AbortContext();
				return fetch(%q, {
					signal: controller.signal,
				});
			})()
		`, server.URL))
		require.NoError(t, err)

		promise := requirePromise(t, val)

		select {
		case <-started:
		case <-time.After(time.Second):
			t.Fatal("request never reached test server")
		}

		_, err = vm.RunString(`controller.abort("stop-now")`)
		require.NoError(t, err)

		select {
		case <-canceled:
		case <-time.After(2 * time.Second):
			t.Fatal("request context was not canceled")
		}

		waitForPromiseState(t, promise, goja.PromiseStateRejected)
		require.Contains(t, promise.Result().String(), "canceled")
	})
}

func newAbortTestRuntime(t *testing.T) (*goja.Runtime, *gojautil.Scheduler) {
	t.Helper()

	vm := goja.New()
	scheduler := gojautil.NewScheduler()
	BindAbortContext(vm, scheduler)
	t.Cleanup(scheduler.Stop)

	return vm, scheduler
}

func requirePromise(t *testing.T, value goja.Value) *goja.Promise {
	t.Helper()

	promise, ok := value.Export().(*goja.Promise)
	require.True(t, ok, "value should export to a promise")
	return promise
}

func waitForPromiseState(t *testing.T, promise *goja.Promise, expected goja.PromiseState) {
	t.Helper()

	require.Eventually(t, func() bool {
		return promise.State() == expected
	}, 2*time.Second, 10*time.Millisecond)
}
