package cron

import (
	"aniting/internal/core"
	"time"
)

type JobCtx struct {
	App *core.App
}

func RunJobs(app *core.App) {

	// Run the jobs only if the server is online
	ctx := &JobCtx{
		App: app,
	}

	refreshAnilistTicker := time.NewTicker(10 * time.Minute)
	refreshAnilistSimulatedTicker := time.NewTicker(30 * time.Minute)
	refreshLocalDataTicker := time.NewTicker(30 * time.Minute)

	go func() {
		for {
			select {
			case <-refreshAnilistTicker.C:
				if app.IsOffline() || app.GetUser().IsSimulated {
					continue
				}
				RefreshAnilistDataJob(ctx)
				app.SyncAnilistToSimulatedCollection()
			}
		}
	}()

	go func() {
		for {
			select {
			case <-refreshAnilistSimulatedTicker.C:
				if app.IsOffline() || !app.GetUser().IsSimulated {
					continue
				}
				RefreshAnilistDataJob(ctx)
			}
		}
	}()

	go func() {
		for {
			select {
			case <-refreshLocalDataTicker.C:
				if app.IsOffline() {
					continue
				}
				SyncLocalDataJob(ctx)
			}
		}
	}()

}
