package gojautil

import (
	"context"
	"fmt"
	"time"

	"github.com/dop251/goja"
)

// WaitForPromise blocks until the promise settles or the context is canceled.
func WaitForPromise(ctx context.Context, promise *goja.Promise) error {
	if promise == nil {
		return fmt.Errorf("cannot wait for nil promise")
	}

	if ctx == nil {
		ctx = context.Background()
	}

	for promise.State() == goja.PromiseStatePending {
		select {
		case <-ctx.Done():
			return ctx.Err()
		default:
		}

		time.Sleep(10 * time.Millisecond)
	}

	return nil
}

// BindAwait binds the $await function to the Goja runtime.
// Hooks don't wait for promises to resolve, so $await is used to wrap a promise and wait for it to resolve.
func BindAwait(vm *goja.Runtime) {
	vm.Set("$await", func(promise goja.Value) (goja.Value, error) {
		if promise, ok := promise.Export().(*goja.Promise); ok {
			if err := WaitForPromise(context.Background(), promise); err != nil {
				return nil, err
			}

			// If the promise is rejected, return the error
			if promise.State() == goja.PromiseStateRejected {
				err := promise.Result()
				return nil, fmt.Errorf("promise rejected: %v", err)
			}

			// If the promise is fulfilled, return the result
			res := promise.Result()
			return res, nil
		}

		// If the promise is not a Goja promise, return the value as is
		return promise, nil
	})
}
