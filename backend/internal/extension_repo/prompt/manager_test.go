package prompt

import (
	"context"
	"errors"
	"seanime/internal/events"
	"seanime/internal/extension"
	"seanime/internal/util"
	"seanime/internal/util/result"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func newTestWS() *events.MockWSEventManager {
	return events.NewMockWSEventManager(util.NewLogger())
}

func waitForRequest(t *testing.T, ws *events.MockWSEventManager, index int) Request {
	t.Helper()

	var request Request
	require.Eventually(t, func() bool {
		events := ws.Events()
		if len(events) <= index {
			return false
		}
		if events[index].Type != EventRequest {
			return false
		}
		payload, ok := events[index].Payload.(Request)
		if !ok {
			return false
		}
		request = payload
		return true
	}, time.Second, 10*time.Millisecond)

	return request
}

func sendResponse(ws *events.MockWSEventManager, id string, allowed bool) {
	ws.MockSendClientEvent(&events.WebsocketClientEvent{
		ClientID: "client-1",
		Type:     events.WebsocketClientEventType(EventResponse),
		Payload:  Response{ID: id, Allowed: allowed},
	})
}

func sendSync(ws *events.MockWSEventManager) {
	ws.MockSendClientEvent(&events.WebsocketClientEvent{
		ClientID: "client-1",
		Type:     events.WebsocketClientEventType(EventSync),
	})
}

func TestAskAllowsAfterClientResponse(t *testing.T) {
	// the prompt blocks until the frontend sends an allow response
	ws := newTestWS()
	manager := NewManager(&NewManagerOptions{WSEventManager: ws})
	done := make(chan error, 1)

	go func() {
		done <- manager.Ask(context.Background(), &extension.Extension{ID: "plugin-a", Name: "Plugin A"}, Options{
			Kind:   "settings",
			Action: "view settings",
			TTL:    time.Second,
		})
	}()

	request := waitForRequest(t, ws, 0)
	assert.Equal(t, "plugin-a", request.Extension.ID)

	sendResponse(ws, request.ID, true)

	assert.NoError(t, <-done)
}

func TestAskRejectsDeniedResponse(t *testing.T) {
	// deny should unblock callers with a specific permission error
	ws := newTestWS()
	manager := NewManager(&NewManagerOptions{WSEventManager: ws})
	done := make(chan error, 1)

	go func() {
		done <- manager.Ask(context.Background(), &extension.Extension{ID: "plugin-a", Name: "Plugin A"}, Options{TTL: time.Second})
	}()

	request := waitForRequest(t, ws, 0)
	sendResponse(ws, request.ID, false)

	assert.True(t, errors.Is(<-done, ErrDenied))
}

func TestAskUsesCachedAllow(t *testing.T) {
	ws := newTestWS()
	manager := NewManager(&NewManagerOptions{WSEventManager: ws})
	cache := result.NewCache[string, bool]()
	opts := Options{
		Kind:     "settings",
		Action:   "view settings",
		TTL:      time.Second,
		Cache:    cache,
		CacheKey: "settings:view:library.autoScan",
	}
	done := make(chan error, 1)

	go func() {
		done <- manager.Ask(context.Background(), &extension.Extension{ID: "plugin-a", Name: "Plugin A"}, opts)
	}()

	request := waitForRequest(t, ws, 0)
	sendResponse(ws, request.ID, true)

	assert.NoError(t, <-done)
	assert.NoError(t, manager.Ask(context.Background(), &extension.Extension{ID: "plugin-a", Name: "Plugin A"}, opts))

	assert.Len(t, ws.Events(), 1)
}

func TestAskPromptsAgainAfterCacheExpires(t *testing.T) {
	ws := newTestWS()
	manager := NewManager(&NewManagerOptions{WSEventManager: ws})
	cache := result.NewCache[string, bool]()
	opts := Options{
		Kind:     "settings",
		Action:   "view settings",
		TTL:      time.Second,
		Cache:    cache,
		CacheKey: "settings:view:library.autoScan",
		CacheTTL: 20 * time.Millisecond,
	}
	done := make(chan error, 1)

	go func() {
		done <- manager.Ask(context.Background(), &extension.Extension{ID: "plugin-a", Name: "Plugin A"}, opts)
	}()

	request := waitForRequest(t, ws, 0)
	sendResponse(ws, request.ID, true)

	assert.NoError(t, <-done)
	time.Sleep(30 * time.Millisecond)

	go func() {
		done <- manager.Ask(context.Background(), &extension.Extension{ID: "plugin-a", Name: "Plugin A"}, opts)
	}()

	secondRequest := waitForRequest(t, ws, 1)
	assert.NotEqual(t, request.ID, secondRequest.ID)
	sendResponse(ws, secondRequest.ID, true)

	assert.NoError(t, <-done)
	assert.Len(t, ws.Events(), 2)
}

func TestAskResendsPendingPromptOnSync(t *testing.T) {
	ws := newTestWS()
	manager := NewManager(&NewManagerOptions{WSEventManager: ws})
	done := make(chan error, 1)

	go func() {
		done <- manager.Ask(context.Background(), &extension.Extension{ID: "plugin-a", Name: "Plugin A"}, Options{
			Kind:   "settings",
			Action: "view settings",
			TTL:    time.Second,
		})
	}()

	request := waitForRequest(t, ws, 0)
	sendSync(ws)
	resynced := waitForRequest(t, ws, 1)

	assert.Equal(t, request.ID, resynced.ID)
	assert.Equal(t, request.Extension.ID, resynced.Extension.ID)

	sendResponse(ws, request.ID, true)
	assert.NoError(t, <-done)
}

func TestAskDismissesExpiredPrompt(t *testing.T) {
	ws := newTestWS()
	manager := NewManager(&NewManagerOptions{WSEventManager: ws})
	done := make(chan error, 1)

	go func() {
		done <- manager.Ask(context.Background(), &extension.Extension{ID: "plugin-a", Name: "Plugin A"}, Options{
			Kind:   "settings",
			Action: "view settings",
			TTL:    20 * time.Millisecond,
		})
	}()

	request := waitForRequest(t, ws, 0)
	dismissed := waitForRequest(t, ws, 1)

	assert.Equal(t, request.ID, dismissed.ID)
	assert.True(t, dismissed.Expired)
	assert.Error(t, <-done)
}
