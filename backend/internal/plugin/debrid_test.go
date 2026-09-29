package plugin

import (
	"path/filepath"
	"strings"
	"testing"
	"time"

	"seanime/internal/database/models"
	"seanime/internal/debrid/debrid"
	"seanime/internal/extension"
	"seanime/internal/testutil"
	"seanime/internal/util"
	gojautil "seanime/internal/util/goja"

	"github.com/dop251/goja"
	"github.com/stretchr/testify/require"
)

func bindTestDebridWithAppContext(t *testing.T, appCtx *AppContextImpl, ext *extension.Extension) (*goja.Runtime, *goja.Object, *gojautil.Scheduler) {
	t.Helper()

	vm := goja.New()
	obj := vm.NewObject()
	scheduler := gojautil.NewScheduler()
	logger := util.NewLogger()

	appCtx.BindDebridToContextObj(vm, obj, logger, ext, scheduler)

	t.Cleanup(scheduler.Stop)

	return vm, obj, scheduler

}

func bindTestDebrid(t *testing.T, ext *extension.Extension) (*AppContextImpl, *goja.Runtime, *goja.Object, *gojautil.Scheduler) {
	t.Helper()

	appCtx := NewAppContext().(*AppContextImpl)
	vm, obj, scheduler := bindTestDebridWithAppContext(t, appCtx, ext)

	return appCtx, vm, obj, scheduler
}

func requirePromiseRejected(t *testing.T, value goja.Value) *goja.Promise {
	t.Helper()

	promise, ok := value.Export().(*goja.Promise)
	require.True(t, ok, "value should export to a promise")
	require.Eventually(t, func() bool {
		return promise.State() == goja.PromiseStateRejected
	}, time.Second, 10*time.Millisecond)

	return promise
}

func requirePromiseRejectionContains(t *testing.T, value goja.Value, message string) {
	t.Helper()

	promise := requirePromiseRejected(t, value)
	require.Contains(t, promise.Result().String(), message)
}

func testDebridExtension(writePaths []string) *extension.Extension {
	return &extension.Extension{
		ID: "test-debrid",
		Plugin: &extension.PluginManifest{
			Permissions: extension.PluginPermissions{
				Scopes: []extension.PluginPermissionScope{extension.PluginPermissionDebrid},
				Allow: extension.PluginAllowlist{
					WritePaths: writePaths,
				},
			},
		},
	}
}

func TestDebridAddTorrentRejectsMissingTorrentSource(t *testing.T) {
	_, vm, obj, _ := bindTestDebrid(t, testDebridExtension(nil))

	debridObj := obj.Get("debrid").ToObject(vm)
	addTorrent, ok := goja.AssertFunction(debridObj.Get("addTorrent"))
	require.True(t, ok)

	ret, err := addTorrent(debridObj, vm.ToValue(debridAddTorrentOptions{}))
	require.NoError(t, err)
	requirePromiseRejectionContains(t, ret, "torrent or magnetLink or infoHash is required")
}

func TestDebridGetQueuedDownloadsReturnsDatabaseItems(t *testing.T) {
	env := testutil.NewTestEnv(t)
	logger := util.NewLogger()
	database := env.MustNewDatabase(logger)

	require.NoError(t, database.InsertDebridTorrentItem(&models.DebridTorrentItem{
		TorrentItemID: "queued-1",
		Destination:   "/library/anime",
		Provider:      "fake-provider",
		MediaId:       101,
	}))

	appCtx := NewAppContext().(*AppContextImpl)
	appCtx.SetModulesPartial(AppContextModules{Database: database})

	vm, obj, _ := bindTestDebridWithAppContext(t, appCtx, testDebridExtension(nil))

	debridObj := obj.Get("debrid").ToObject(vm)
	getQueuedDownloads, ok := goja.AssertFunction(debridObj.Get("getQueuedDownloads"))
	require.True(t, ok)

	ret, err := getQueuedDownloads(debridObj)
	require.NoError(t, err)

	var items []debridQueuedDownload
	require.NoError(t, vm.ExportTo(ret, &items))
	require.Len(t, items, 1)
	require.Equal(t, debridQueuedDownload{
		TorrentItemID: "queued-1",
		Destination:   "/library/anime",
		Provider:      "fake-provider",
		MediaID:       101,
	}, items[0])
}

func TestDebridAddAndQueueTorrentRejectsUnauthorizedDestination(t *testing.T) {
	allowedDir := t.TempDir()
	blockedDir := t.TempDir()
	ext := testDebridExtension([]string{filepath.ToSlash(filepath.Join(allowedDir, "**"))})

	_, vm, obj, _ := bindTestDebrid(t, ext)

	debridObj := obj.Get("debrid").ToObject(vm)
	addAndQueueTorrent, ok := goja.AssertFunction(debridObj.Get("addAndQueueTorrent"))
	require.True(t, ok)

	ret, err := addAndQueueTorrent(debridObj, vm.ToValue(debridAddAndQueueTorrentOptions{
		MagnetLink:  "magnet:?xt=urn:btih:abcdef",
		Destination: filepath.Join(blockedDir, "episode.mkv"),
	}))
	require.NoError(t, err)
	requirePromiseRejectionContains(t, ret, "destination path not authorized for write")
}

func TestDebridDownloadTorrentRejectsUnauthorizedDestination(t *testing.T) {
	allowedDir := t.TempDir()
	blockedDir := t.TempDir()
	ext := testDebridExtension([]string{filepath.ToSlash(filepath.Join(allowedDir, "**"))})

	_, vm, obj, _ := bindTestDebrid(t, ext)

	debridObj := obj.Get("debrid").ToObject(vm)
	downloadTorrent, ok := goja.AssertFunction(debridObj.Get("downloadTorrent"))
	require.True(t, ok)

	ret, err := downloadTorrent(debridObj, vm.ToValue(debridDownloadTorrentOptions{
		TorrentItem: &debrid.TorrentItem{ID: "torrent-1", Name: "test"},
		Destination: filepath.Join(blockedDir, "episode.mkv"),
	}))
	require.NoError(t, err)
	requirePromiseRejectionContains(t, ret, "destination path not authorized for write")
}

func TestValidateDebridDestinationRequiresAbsolutePath(t *testing.T) {
	appCtx := NewAppContext().(*AppContextImpl)
	err := validateDebridDestination(appCtx, testDebridExtension([]string{"**"}), "relative/path.mkv")
	require.Error(t, err)
	require.True(t, strings.Contains(err.Error(), "absolute path"))
}
