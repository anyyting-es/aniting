package mpchc

import (
	"seanime/internal/testutil"
	"seanime/internal/util"
	"testing"
	"time"

	"github.com/davecgh/go-spew/spew"
	"github.com/stretchr/testify/assert"
)

func TestMpcHc_Start(t *testing.T) {
	cfg := testutil.InitTestProvider(t, testutil.MediaPlayer(), testutil.Live())

	mpc := &MpcHc{
		Host:   cfg.Provider.MpcHost,
		Path:   cfg.Provider.MpcPath,
		Port:   cfg.Provider.MpcPort,
		Logger: util.NewLogger(),
	}

	err := mpc.Start()
	assert.NoError(t, err)

}

func TestMpcHc_Play(t *testing.T) {
	cfg := testutil.InitTestProvider(t, testutil.MediaPlayer(), testutil.Live())
	sampleVideoPath := testutil.RequireSampleVideoPath(t)

	mpc := &MpcHc{
		Host:   cfg.Provider.MpcHost,
		Path:   cfg.Provider.MpcPath,
		Port:   cfg.Provider.MpcPort,
		Logger: util.NewLogger(),
	}

	err := mpc.Start()
	assert.NoError(t, err)

	res, err := mpc.OpenAndPlay(sampleVideoPath)
	assert.NoError(t, err)

	t.Log(res)

}

func TestMpcHc_GetVariables(t *testing.T) {
	cfg := testutil.InitTestProvider(t, testutil.MediaPlayer(), testutil.Live())

	mpc := &MpcHc{
		Host:   cfg.Provider.MpcHost,
		Path:   cfg.Provider.MpcPath,
		Port:   cfg.Provider.MpcPort,
		Logger: util.NewLogger(),
	}

	err := mpc.Start()
	assert.NoError(t, err)

	res, err := mpc.GetVariables()
	if err != nil {
		t.Fatal(err.Error())
	}

	spew.Dump(res)

}

func TestMpcHc_Seek(t *testing.T) {
	cfg := testutil.InitTestProvider(t, testutil.MediaPlayer(), testutil.Live())
	sampleVideoPath := testutil.RequireSampleVideoPath(t)

	mpc := &MpcHc{
		Host:   cfg.Provider.MpcHost,
		Path:   cfg.Provider.MpcPath,
		Port:   cfg.Provider.MpcPort,
		Logger: util.NewLogger(),
	}

	err := mpc.Start()
	assert.NoError(t, err)

	_, err = mpc.OpenAndPlay(sampleVideoPath)
	assert.NoError(t, err)

	err = mpc.Pause()

	time.Sleep(400 * time.Millisecond)

	err = mpc.SeekTo(100000)
	assert.NoError(t, err)

	time.Sleep(400 * time.Millisecond)

	err = mpc.Pause()

	vars, err := mpc.GetVariables()
	assert.NoError(t, err)

	spew.Dump(vars)

}
