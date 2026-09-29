package gojautil

import (
	"context"
	"testing"
	"time"

	"github.com/dop251/goja"
	"github.com/stretchr/testify/require"
)

func TestWaitForPromiseReturnsWhenResolved(t *testing.T) {
	vm := goja.New()

	value, err := vm.RunString(`Promise.resolve("ok")`)
	require.NoError(t, err)

	promise, ok := value.Export().(*goja.Promise)
	require.True(t, ok)

	err = WaitForPromise(context.Background(), promise)
	require.NoError(t, err)
	require.Equal(t, goja.PromiseStateFulfilled, promise.State())
	require.Equal(t, "ok", promise.Result().String())
}

func TestWaitForPromiseHonorsContextTimeout(t *testing.T) {
	vm := goja.New()
	promise, _, _ := vm.NewPromise()

	ctx, cancel := context.WithTimeout(context.Background(), 20*time.Millisecond)
	defer cancel()

	err := WaitForPromise(ctx, promise)
	require.ErrorIs(t, err, context.DeadlineExceeded)
	require.Equal(t, goja.PromiseStatePending, promise.State())
}
