package nakama

import (
	"seanime/internal/database/models"
	"seanime/internal/events"
	"seanime/internal/util"
	"sync"
	"testing"
	"time"

	"github.com/samber/mo"
	"github.com/stretchr/testify/require"
)

func TestWatchPartyPlaybackStatusIgnoresStaleSequence(t *testing.T) {
	// old messages should not trigger any sync work once we've seen a newer sequence.
	h := newWatchPartySyncWrapper(false)
	h.setPeerSession(1.2)
	h.player.setStatus(&WatchPartyPlaybackStatus{Paused: false, CurrentTime: 12, Duration: 100})
	h.wpm.lastRxSequence = 5

	h.wpm.handleWatchPartyPlaybackStatusEvent(&WatchPartyPlaybackStatusPayload{
		PlaybackStatus: &WatchPartyPlaybackStatus{Paused: false, CurrentTime: 18, Duration: 100},
		Timestamp:      time.Now().UnixNano(),
		SequenceNumber: 4,
	})

	require.Equal(t, 5, int(h.wpm.lastRxSequence))
	require.Zero(t, h.player.pauseCount())
	require.Zero(t, h.player.resumeCount())
	require.Empty(t, h.player.seekHistory())
}

func TestWatchPartyPlaybackStatusResumesAndSeeksOnce(t *testing.T) {
	// host resume should only do one resume path and one corrective seek.
	h := newWatchPartySyncWrapper(false)
	h.setPeerSession(1.2)
	h.player.setStatus(&WatchPartyPlaybackStatus{Paused: true, CurrentTime: 10, Duration: 100})

	h.wpm.handleWatchPartyPlaybackStatusEvent(&WatchPartyPlaybackStatusPayload{
		PlaybackStatus: &WatchPartyPlaybackStatus{Paused: false, CurrentTime: 14, Duration: 100},
		Timestamp:      time.Now().Add(-300 * time.Millisecond).UnixNano(),
		SequenceNumber: 1,
	})

	seeks := h.player.seekHistory()
	require.Equal(t, 1, h.player.resumeCount())
	require.Zero(t, h.player.pauseCount())
	require.Len(t, seeks, 1)
	require.InDelta(t, 14.6, seeks[0], 0.25)
	require.Equal(t, uint64(1), h.wpm.lastRxSequence)
}

func TestWatchPartySyncPlaybackPositionSkipsWhilePendingSeekIsFresh(t *testing.T) {
	// a recent local seek should suppress another correction until the first one settles.
	h := newWatchPartySyncWrapper(false)
	session := h.setPeerSession(1.0)
	h.player.setStatus(&WatchPartyPlaybackStatus{Paused: false, CurrentTime: 16, Duration: 100})
	h.wpm.pendingSeekTime = time.Now().Add(-100 * time.Millisecond)
	h.wpm.pendingSeekPosition = 18

	h.wpm.syncPlaybackPosition(
		&WatchPartyPlaybackStatus{Paused: false, CurrentTime: 20, Duration: 100},
		&WatchPartyPlaybackStatus{Paused: false, CurrentTime: 16, Duration: 100},
		0.1,
		session,
	)

	require.Empty(t, h.player.seekHistory())
	require.False(t, h.wpm.pendingSeekTime.IsZero())
}

func TestWatchPartyPlaybackStatusPauseStartsCatchUp(t *testing.T) {
	// when the host pauses far ahead of the peer, we should catch up before pausing.
	h := newWatchPartySyncWrapper(false)
	h.setPeerSession(1.0)
	h.player.setPullSequence(
		&WatchPartyPlaybackStatus{Paused: false, CurrentTime: 7.5, Duration: 100},
		&WatchPartyPlaybackStatus{Paused: false, CurrentTime: 9.7, Duration: 100},
	)

	h.wpm.handleWatchPartyPlaybackStatusEvent(&WatchPartyPlaybackStatusPayload{
		PlaybackStatus: &WatchPartyPlaybackStatus{Paused: true, CurrentTime: 10, Duration: 100},
		Timestamp:      time.Now().UnixNano(),
		SequenceNumber: 1,
	})

	require.Eventually(t, func() bool {
		return h.player.pauseCount() == 1 && len(h.player.seekHistory()) == 1
	}, time.Second, 25*time.Millisecond)
	require.Zero(t, h.player.resumeCount())
	require.InDelta(t, 10.0, h.player.seekHistory()[0], 0.01)
}

func TestWatchPartyCheckAndManageBufferingPausesAndResumes(t *testing.T) {
	// host playback should pause for buffering peers and resume once everyone is ready.
	h := newWatchPartySyncWrapper(true)
	peer := &WatchPartySessionParticipant{ID: "peer-1", Username: "peer", IsReady: false, IsBuffering: true}
	h.setHostSession(peer)
	h.player.setStatus(&WatchPartyPlaybackStatus{Paused: false, CurrentTime: 20, Duration: 100})

	h.wpm.checkAndManageBuffering()

	require.Equal(t, 1, h.player.pauseCount())
	require.True(t, h.wpm.isWaitingForBuffers)

	peer.IsBuffering = false
	peer.IsReady = true
	h.player.setStatus(&WatchPartyPlaybackStatus{Paused: true, CurrentTime: 20, Duration: 100})
	h.wpm.bufferWaitStart = time.Now().Add(-150 * time.Millisecond)

	h.wpm.checkAndManageBuffering()

	require.Equal(t, 1, h.player.resumeCount())
	require.False(t, h.wpm.isWaitingForBuffers)
}

func TestWatchPartyCalculateBufferStateDetectsStallsAndSeeks(t *testing.T) {
	// stall detection should take two bad samples, then reset once playback jumps like a seek.
	h := newWatchPartySyncWrapper(false)

	isBuffering, health := h.wpm.calculateBufferState(&WatchPartyPlaybackStatus{Paused: false, CurrentTime: 10, Duration: 100})
	require.False(t, isBuffering)
	require.InDelta(t, 1.0, health, 0.01)

	h.wpm.lastPosition = 10
	h.wpm.lastPositionTime = time.Now().Add(-2 * time.Second)
	h.wpm.stallCount = 0
	isBuffering, health = h.wpm.calculateBufferState(&WatchPartyPlaybackStatus{Paused: false, CurrentTime: 10.1, Duration: 100})
	require.False(t, isBuffering)
	require.InDelta(t, 0.85, health, 0.01)
	require.Equal(t, 1, h.wpm.stallCount)

	h.wpm.lastPosition = 10.1
	h.wpm.lastPositionTime = time.Now().Add(-2 * time.Second)
	h.wpm.stallCount = 1
	isBuffering, health = h.wpm.calculateBufferState(&WatchPartyPlaybackStatus{Paused: false, CurrentTime: 10.2, Duration: 100})
	require.True(t, isBuffering)
	require.InDelta(t, 0.7, health, 0.01)
	require.Equal(t, 2, h.wpm.stallCount)

	h.wpm.lastPosition = 10.2
	h.wpm.lastPositionTime = time.Now().Add(-2 * time.Second)
	h.wpm.stallCount = 2
	isBuffering, health = h.wpm.calculateBufferState(&WatchPartyPlaybackStatus{Paused: false, CurrentTime: 14.6, Duration: 100})
	require.False(t, isBuffering)
	require.InDelta(t, 1.0, health, 0.01)
	require.Zero(t, h.wpm.stallCount)
}

type watchPartySyncWrapper struct {
	wpm    *WatchPartyManager
	player *fakeWatchPartyPlayer
}

func newWatchPartySyncWrapper(isHost bool) *watchPartySyncWrapper {
	logger := util.NewLogger()
	manager := &Manager{
		logger:         logger,
		settings:       &models.NakamaSettings{IsHost: isHost},
		wsEventManager: events.NewMockWSEventManager(logger),
		hostConnection: &HostConnection{PeerId: "peer-1", Authenticated: true},
		isOfflineRef:   util.NewRef(false),
	}

	wpm := NewWatchPartyManager(manager)
	player := &fakeWatchPartyPlayer{}
	wpm.playbackController = player

	return &watchPartySyncWrapper{
		wpm:    wpm,
		player: player,
	}
}

func (h *watchPartySyncWrapper) setPeerSession(syncThreshold float64) *WatchPartySession {
	session := &WatchPartySession{
		ID: "session-1",
		Participants: map[string]*WatchPartySessionParticipant{
			"peer-1": {
				ID:       "peer-1",
				Username: "host",
				IsHost:   true,
			},
		},
		Settings: &WatchPartySessionSettings{
			SyncThreshold:     syncThreshold,
			MaxBufferWaitTime: 2,
		},
		CurrentMediaInfo: &WatchPartySessionMediaInfo{MediaId: 1, EpisodeNumber: 1, StreamType: WatchPartyStreamTypeFile},
	}

	h.wpm.currentSession = mo.Some(session)
	return session
}

func (h *watchPartySyncWrapper) setHostSession(peer *WatchPartySessionParticipant) *WatchPartySession {
	session := &WatchPartySession{
		ID: "session-1",
		Participants: map[string]*WatchPartySessionParticipant{
			"host": {
				ID:       "host",
				Username: "host",
				IsHost:   true,
				IsReady:  true,
			},
			peer.ID: peer,
		},
		Settings: &WatchPartySessionSettings{
			SyncThreshold:     1.0,
			MaxBufferWaitTime: 2,
		},
		CurrentMediaInfo: &WatchPartySessionMediaInfo{MediaId: 1, EpisodeNumber: 1, StreamType: WatchPartyStreamTypeFile},
	}

	h.wpm.currentSession = mo.Some(session)
	return session
}

type fakeWatchPartyPlayer struct {
	mu        sync.Mutex
	status    *WatchPartyPlaybackStatus
	sequence  []*WatchPartyPlaybackStatus
	pullIndex int
	pauses    int
	resumes   int
	seeks     []float64
}

func (p *fakeWatchPartyPlayer) setStatus(status *WatchPartyPlaybackStatus) {
	p.mu.Lock()
	defer p.mu.Unlock()

	p.status = clonePlaybackStatus(status)
	p.sequence = nil
	p.pullIndex = 0
}

func (p *fakeWatchPartyPlayer) setPullSequence(statuses ...*WatchPartyPlaybackStatus) {
	p.mu.Lock()
	defer p.mu.Unlock()

	p.sequence = make([]*WatchPartyPlaybackStatus, 0, len(statuses))
	for _, status := range statuses {
		p.sequence = append(p.sequence, clonePlaybackStatus(status))
	}
	p.pullIndex = 0
	if len(p.sequence) > 0 {
		p.status = clonePlaybackStatus(p.sequence[0])
	}
}

func (p *fakeWatchPartyPlayer) PullStatus() (*WatchPartyPlaybackStatus, bool) {
	p.mu.Lock()
	defer p.mu.Unlock()

	if len(p.sequence) > 0 {
		idx := p.pullIndex
		if idx >= len(p.sequence) {
			idx = len(p.sequence) - 1
		}
		status := clonePlaybackStatus(p.sequence[idx])
		p.status = clonePlaybackStatus(status)
		if p.pullIndex < len(p.sequence)-1 {
			p.pullIndex++
		}
		return status, true
	}

	if p.status == nil {
		return nil, false
	}

	return clonePlaybackStatus(p.status), true
}

func (p *fakeWatchPartyPlayer) Pause() {
	p.mu.Lock()
	defer p.mu.Unlock()

	p.pauses++
	if p.status != nil {
		p.status.Paused = true
	}
}

func (p *fakeWatchPartyPlayer) Resume() {
	p.mu.Lock()
	defer p.mu.Unlock()

	p.resumes++
	if p.status != nil {
		p.status.Paused = false
	}
}

func (p *fakeWatchPartyPlayer) SeekTo(seconds float64) {
	p.mu.Lock()
	defer p.mu.Unlock()

	p.seeks = append(p.seeks, seconds)
	if p.status != nil {
		p.status.CurrentTime = seconds
	}
}

func (p *fakeWatchPartyPlayer) pauseCount() int {
	p.mu.Lock()
	defer p.mu.Unlock()
	return p.pauses
}

func (p *fakeWatchPartyPlayer) resumeCount() int {
	p.mu.Lock()
	defer p.mu.Unlock()
	return p.resumes
}

func (p *fakeWatchPartyPlayer) seekHistory() []float64 {
	p.mu.Lock()
	defer p.mu.Unlock()

	ret := make([]float64, len(p.seeks))
	copy(ret, p.seeks)
	return ret
}

func clonePlaybackStatus(status *WatchPartyPlaybackStatus) *WatchPartyPlaybackStatus {
	if status == nil {
		return nil
	}

	cloned := *status
	return &cloned
}
