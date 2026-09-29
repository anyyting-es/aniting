package mediaplayer

import (
	"seanime/internal/events"
	"seanime/internal/mediaplayers/mpchc"
	"seanime/internal/mediaplayers/mpv"
	"seanime/internal/mediaplayers/vlc"
	"seanime/internal/testutil"
	"seanime/internal/util"
	"testing"
)

func NewTestRepository(t *testing.T, defaultPlayer string) *Repository {
	if defaultPlayer == "" {
		defaultPlayer = "mpv"
	}
	cfg := testutil.InitTestProvider(t, testutil.MediaPlayer())

	logger := util.NewLogger()
	WSEventManager := events.NewMockWSEventManager(logger)

	_vlc := &vlc.VLC{
		Host:     cfg.Provider.VlcHost,
		Port:     cfg.Provider.VlcPort,
		Password: cfg.Provider.VlcPassword,
		Logger:   logger,
	}

	_mpc := &mpchc.MpcHc{
		Host:   cfg.Provider.MpcHost,
		Port:   cfg.Provider.MpcPort,
		Logger: logger,
	}

	_mpv := mpv.New(logger, "", "")

	repo := NewRepository(&NewRepositoryOptions{
		Logger:         logger,
		Default:        defaultPlayer,
		WSEventManager: WSEventManager,
		Mpv:            _mpv,
		VLC:            _vlc,
		MpcHc:          _mpc,
	})

	return repo
}
