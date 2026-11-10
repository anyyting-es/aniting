package mobile

import (
	"embed"
	"os"
	"aniting/internal/core"
	"aniting/internal/handlers"
)

//go:embed all:web
var WebFS embed.FS

func StartServer(dataDir string, cacheDir string, port int) {
	go func() {
		defer func() {
			if r := recover(); r != nil {
			}
		}()

		_ = os.Setenv("ANITING_DATA_DIR", dataDir)
		_ = os.Setenv("ANITING_WORKING_DIR", dataDir)

		flags := core.AnitingFlags{
			DataDir:          dataDir,
			Host:             "127.0.0.1",
			Port:             port,
			DisablePassword:  true,
			IsDesktopSidecar: false,
		}

		app := core.NewApp(&core.ConfigOptions{
			Flags: flags,
		})

		app.InitLogging(false)

		echoApp := core.NewEchoApp(app, &WebFS)

		handlers.InitRoutes(app, echoApp)

		core.RunEchoServer(app, echoApp)
	}()
}
