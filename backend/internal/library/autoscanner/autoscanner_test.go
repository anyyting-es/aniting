package autoscanner

import (
	"seanime/internal/api/anilist"
	"seanime/internal/database/db"
	"seanime/internal/database/models"
	"seanime/internal/events"
	"seanime/internal/testutil"
	"seanime/internal/util"
	"sync"
	"sync/atomic"
	"testing"
	"time"

	"github.com/stretchr/testify/require"
)

func TestNewAutoScannerAppliesDefaultsAndSetters(t *testing.T) {
	// the constructor should apply defaults, and then the setters should override them.
	h := newAutoScannerTestWrapper(t, false, 0)

	require.Equal(t, 15*time.Second, h.autoScanner.waitTime)
	require.NotNil(t, h.autoScanner.fileActionCh)
	require.NotNil(t, h.autoScanner.scannedCh)
	require.False(t, h.autoScanner.enabled)

	collection := &anilist.AnimeCollection{}
	h.autoScanner.SetAnimeCollection(collection)
	require.Same(t, collection, h.autoScanner.animeCollection)

	settings := models.LibrarySettings{
		AutoScan: true,
	}
	h.autoScanner.SetSettings(settings)
	require.True(t, h.autoScanner.enabled)
	require.Equal(t, settings, h.autoScanner.settings)

	custom := newAutoScannerTestWrapper(t, true, 25*time.Millisecond)
	require.Equal(t, 25*time.Millisecond, custom.autoScanner.waitTime)
	require.True(t, custom.autoScanner.enabled)
}

func TestAutoScannerNotifyQueuesSignalsAndMissedActions(t *testing.T) {
	// Notify should send a signal on the channel when enabled, but if we're currently waiting it should mark that we missed an action instead.
	var nilScanner *AutoScanner
	nilScanner.Notify()

	t.Run("enabled queue gets a signal", func(t *testing.T) {
		h := newAutoScannerTestWrapper(t, true, 10*time.Millisecond)

		h.autoScanner.Notify()

		require.Eventually(t, func() bool {
			return len(h.autoScanner.fileActionCh) == 1
		}, time.Second, 5*time.Millisecond)
	})

	t.Run("disabled scanner stays quiet", func(t *testing.T) {
		h := newAutoScannerTestWrapper(t, false, 10*time.Millisecond)

		h.autoScanner.Notify()

		time.Sleep(20 * time.Millisecond)
		require.Zero(t, len(h.autoScanner.fileActionCh))
	})

	t.Run("waiting scanner marks the action as missed", func(t *testing.T) {
		h := newAutoScannerTestWrapper(t, true, 10*time.Millisecond)
		h.autoScanner.waiting = true

		h.autoScanner.Notify()

		require.True(t, h.autoScanner.missedAction)
		require.Zero(t, len(h.autoScanner.fileActionCh))
	})
}

func TestAutoScannerWaitAndScanDebouncesMissedActions(t *testing.T) {
	// when another file event lands during the wait window, we should restart the timer and still scan once.
	h := newAutoScannerTestWrapper(t, true, 25*time.Millisecond)
	h.seedSettings(t, "")

	startedAt := time.Now()
	done := make(chan struct{})
	go func() {
		defer close(done)
		h.autoScanner.waitAndScan()
	}()

	time.Sleep(10 * time.Millisecond)
	h.autoScanner.Notify()

	require.Eventually(t, func() bool {
		return h.wsEventManager.count(events.AutoScanCompleted) == 1
	}, time.Second, 5*time.Millisecond)

	select {
	case <-done:
	case <-time.After(time.Second):
		t.Fatal("waitAndScan did not finish")
	}

	require.Equal(t, 1, h.wsEventManager.count(events.AutoScanStarted))
	require.Equal(t, 1, h.wsEventManager.count(events.AutoScanCompleted))
	require.False(t, h.autoScanner.waiting)
	require.False(t, h.autoScanner.missedAction)
	require.GreaterOrEqual(t, time.Since(startedAt), 40*time.Millisecond)
}

func TestAutoScannerRunNowBypassesEnabledFlag(t *testing.T) {
	// even if the scanner is disabled, RunNow should trigger a scan
	h := newAutoScannerTestWrapper(t, false, 10*time.Millisecond)
	h.seedSettings(t, "")

	h.autoScanner.RunNow()

	require.Eventually(t, func() bool {
		return h.wsEventManager.count(events.AutoScanCompleted) == 1
	}, time.Second, 5*time.Millisecond)

	require.Equal(t, []string{events.AutoScanStarted, events.AutoScanCompleted}, h.wsEventManager.types())
	require.Zero(t, h.refreshCalls.Load())
	require.False(t, h.autoScanner.scanning.Load())
}

func TestAutoScannerScanSkipsConcurrentRuns(t *testing.T) {
	// the compare-and-swap guard should keep a second scan from even starting.
	h := newAutoScannerTestWrapper(t, true, 10*time.Millisecond)
	h.autoScanner.scanning.Store(true)
	t.Cleanup(func() {
		h.autoScanner.scanning.Store(false)
	})

	h.autoScanner.scan()

	require.Empty(t, h.wsEventManager.types())
	require.True(t, h.autoScanner.scanning.Load())
}

type autoScannerTestWrapper struct {
	database       *db.Database
	wsEventManager *recordingWSEventManager
	autoScanner    *AutoScanner
	refreshCalls   atomic.Int32
}

func newAutoScannerTestWrapper(t *testing.T, enabled bool, waitTime time.Duration) *autoScannerTestWrapper {
	t.Helper()

	resetAutoscannerTestState(t)

	env := testutil.NewTestEnv(t)
	logger := util.NewLogger()
	database := env.MustNewDatabase(logger)
	wsEventManager := &recordingWSEventManager{MockWSEventManager: events.NewMockWSEventManager(logger)}
	h := &autoScannerTestWrapper{
		database:       database,
		wsEventManager: wsEventManager,
	}
	h.autoScanner = New(&NewAutoScannerOptions{
		Database:       database,
		Logger:         logger,
		Enabled:        enabled,
		WaitTime:       waitTime,
		WSEventManager: wsEventManager,
		OnRefreshCollection: func() {
			h.refreshCalls.Add(1)
		},
	})

	return h
}

func (h *autoScannerTestWrapper) seedSettings(t *testing.T, libraryPath string) {
	t.Helper()

	_, err := h.database.UpsertSettings(&models.Settings{
		BaseModel: models.BaseModel{ID: 1},
		Library: &models.LibrarySettings{
			LibraryPath: libraryPath,
		},
	})
	require.NoError(t, err)
}

type recordingWSEventManager struct {
	*events.MockWSEventManager
	mu        sync.Mutex
	typesSent []string
}

func (m *recordingWSEventManager) SendEvent(t string, _ interface{}) {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.typesSent = append(m.typesSent, t)
}

func (m *recordingWSEventManager) count(eventType string) int {
	m.mu.Lock()
	defer m.mu.Unlock()

	count := 0
	for _, t := range m.typesSent {
		if t == eventType {
			count++
		}
	}
	return count
}

func (m *recordingWSEventManager) types() []string {
	m.mu.Lock()
	defer m.mu.Unlock()

	ret := make([]string, len(m.typesSent))
	copy(ret, m.typesSent)
	return ret
}

func resetAutoscannerTestState(t *testing.T) {
	t.Helper()

	previousSettings := db.CurrSettings
	db.CurrSettings = nil
	t.Cleanup(func() {
		db.CurrSettings = previousSettings
	})
}
