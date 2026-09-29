package plugin

import (
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	database "seanime/internal/database/db"
	"seanime/internal/database/models"
	"seanime/internal/events"
	"seanime/internal/extension"
	"seanime/internal/extension_repo/prompt"
	"seanime/internal/testutil"
	"seanime/internal/util"
	gojautil "seanime/internal/util/goja"
	"testing"
	"time"

	"github.com/dop251/goja"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func newSecureTestCtx(t *testing.T) (*AppContextImpl, *events.MockWSEventManager) {
	t.Helper()

	database.CurrSettings = nil
	t.Cleanup(func() {
		database.CurrSettings = nil
	})

	logger := util.NewLogger()
	env := testutil.NewTestEnv(t)
	db := env.MustNewDatabase(logger)
	_, err := db.UpsertSettings(&models.Settings{
		BaseModel: models.BaseModel{ID: 1},
		Library: &models.LibrarySettings{
			EnableExtensionSecureMode: true,
		},
	})
	require.NoError(t, err)

	ws := events.NewMockWSEventManager(logger)
	manager := prompt.NewManager(&prompt.NewManagerOptions{Logger: logger, WSEventManager: ws})
	appCtx := NewAppContext().(*AppContextImpl)
	appCtx.SetModulesPartial(AppContextModules{
		Database:      db,
		PromptManager: manager,
	})

	return appCtx, ws
}

func newSecureTestExt(dir string) *extension.Extension {
	return &extension.Extension{
		ID:   "secure-test",
		Name: "Secure Test",
		Plugin: &extension.PluginManifest{
			Permissions: extension.PluginPermissions{
				Scopes: []extension.PluginPermissionScope{extension.PluginPermissionSystem},
				Allow: extension.PluginAllowlist{
					ReadPaths:  []string{filepath.ToSlash(dir) + "/**/*"},
					WritePaths: []string{filepath.ToSlash(dir) + "/**/*"},
				},
			},
		},
	}
}

func waitSecurePrompt(t *testing.T, ws *events.MockWSEventManager, index int) prompt.Request {
	t.Helper()

	var request prompt.Request
	require.Eventually(t, func() bool {
		events := ws.Events()
		if len(events) <= index || events[index].Type != prompt.EventRequest {
			return false
		}
		payload, ok := events[index].Payload.(prompt.Request)
		if !ok {
			return false
		}
		request = payload
		return true
	}, time.Second, 10*time.Millisecond)

	return request
}

func allowSecurePrompt(ws *events.MockWSEventManager, id string) {
	ws.MockSendClientEvent(&events.WebsocketClientEvent{
		ClientID: "client-1",
		Type:     events.WebsocketClientEventType(prompt.EventResponse),
		Payload:  prompt.Response{ID: id, Allowed: true},
	})
}

func TestSecureModePromptsSystemRead(t *testing.T) {
	appCtx, ws := newSecureTestCtx(t)
	dir := t.TempDir()
	filePath := filepath.Join(dir, "secret.txt")
	require.NoError(t, os.WriteFile(filePath, []byte("secret"), 0644))

	vm := goja.New()
	scheduler := gojautil.NewScheduler()
	t.Cleanup(scheduler.Stop)
	appCtx.BindSystem(vm, util.NewLogger(), newSecureTestExt(dir), scheduler)

	osObj := vm.Get("$os").ToObject(vm)
	readFile, ok := goja.AssertFunction(osObj.Get("readFile"))
	require.True(t, ok)

	done := make(chan error, 1)
	go func() {
		_, err := readFile(osObj, vm.ToValue(filePath))
		done <- err
	}()

	request := waitSecurePrompt(t, ws, 0)
	assert.Equal(t, "system", request.Kind)
	assert.Contains(t, request.Action, "read")
	assert.Equal(t, filePath, request.Resource)

	allowSecurePrompt(ws, request.ID)
	require.NoError(t, <-done)

	_, err := readFile(osObj, vm.ToValue(filePath))
	require.NoError(t, err)
	assert.Len(t, ws.Events(), 1)
}

func TestSecureModePromptsDownloaderWrite(t *testing.T) {
	appCtx, ws := newSecureTestCtx(t)
	dir := t.TempDir()
	destination := filepath.Join(dir, "download.txt")
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		_, _ = w.Write([]byte("downloaded"))
	}))
	t.Cleanup(server.Close)

	vm := goja.New()
	scheduler := gojautil.NewScheduler()
	t.Cleanup(scheduler.Stop)
	ctxObj := vm.NewObject()
	appCtx.BindDownloaderToContextObj(vm, ctxObj, util.NewLogger(), newSecureTestExt(dir), scheduler)

	downloaderObj := ctxObj.Get("downloader").ToObject(vm)
	download, ok := goja.AssertFunction(downloaderObj.Get("download"))
	require.True(t, ok)

	done := make(chan error, 1)
	go func() {
		_, err := download(downloaderObj, vm.ToValue(server.URL), vm.ToValue(destination), vm.ToValue(map[string]interface{}{}))
		done <- err
	}()

	request := waitSecurePrompt(t, ws, 0)
	assert.Equal(t, "download", request.Kind)
	assert.Equal(t, destination, request.Resource)

	allowSecurePrompt(ws, request.ID)
	require.NoError(t, <-done)
}
