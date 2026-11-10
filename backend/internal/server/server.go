package server

import (
	"embed"

	"aniting/internal/core"
	"aniting/internal/cron"
	"aniting/internal/handlers"
)

func startApp(embeddedLogo []byte) (*core.App, core.AnitingFlags) {
	// Print the header
	core.PrintHeader()

	// Get the flags
	flags := core.GetAnitingFlags()

	// Create the app instance
	app := core.NewApp(&core.ConfigOptions{
		Flags:        flags,
		EmbeddedLogo: embeddedLogo,
	})

	app.InitLogging(false)

	return app, flags
}

func startAppLoop(webFS *embed.FS, app *core.App) {
	// Create the echo app instance
	echoApp := core.NewEchoApp(app, webFS)

	// Initialize the routes
	handlers.InitRoutes(app, echoApp)

	// Run the server
	core.RunEchoServer(app, echoApp)

	// Run the jobs in the background
	cron.RunJobs(app)

	// Keep the process alive until it is terminated
	select {}
}
