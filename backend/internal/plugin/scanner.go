package plugin

import (
	"context"
	"errors"
	"seanime/internal/database/db_bridge"
	"seanime/internal/extension"
	"seanime/internal/goja/goja_bindings"
	"seanime/internal/library/anime"
	"seanime/internal/library/scanner"
	"seanime/internal/library/summary"
	gojautil "seanime/internal/util/goja"

	"github.com/dop251/goja"
	"github.com/rs/zerolog"
)

type scanOptions struct {
	Enhanced                   bool `json:"enhanced"`
	EnhanceWithOfflineDatabase bool `json:"enhanceWithOfflineDatabase"`
	SkipLockedFiles            bool `json:"skipLockedFiles"`
	SkipIgnoredFiles           bool `json:"skipIgnoredFiles"`
}

func (a *AppContextImpl) BindScannerToContextObj(vm *goja.Runtime, obj *goja.Object, logger *zerolog.Logger, _ *extension.Extension, scheduler *gojautil.Scheduler) {
	scannerObj := vm.NewObject()

	_ = scannerObj.Set("scan", func(opts scanOptions) goja.Value {
		promise, resolve, reject := vm.NewPromise()

		database, ok := a.database.Get()
		if !ok {
			goja_bindings.PanicThrowErrorString(vm, "database not set")
		}
		platformRef, ok := a.anilistPlatformRef.Get()
		if !ok {
			goja_bindings.PanicThrowErrorString(vm, "anilist platform not set")
		}
		metadataProviderRef, ok := a.metadataProviderRef.Get()
		if !ok {
			goja_bindings.PanicThrowErrorString(vm, "metadata provider not set")
		}
		wsEventManager, ok := a.wsEventManager.Get()
		if !ok {
			goja_bindings.PanicThrowErrorString(vm, "ws event manager not set")
		}

		autoDownloader, _ := a.autoDownloader.Get()
		refreshAnimeCollection, _ := a.onRefreshAnilistAnimeCollection.Get()

		go func() {
			settings, err := database.GetSettings()
			if err != nil || settings == nil || settings.Library == nil {
				scheduler.ScheduleAsync(func() error {
					reject(vm.NewGoError(errors.New("library settings not found")))
					return nil
				})
				return
			}

			libraryPath, err := database.GetLibraryPathFromSettings()
			if err != nil {
				scheduler.ScheduleAsync(func() error {
					reject(vm.NewGoError(err))
					return nil
				})
				return
			}
			additionalLibraryPaths, err := database.GetAdditionalLibraryPathsFromSettings()
			if err != nil {
				scheduler.ScheduleAsync(func() error {
					reject(vm.NewGoError(err))
					return nil
				})
				return
			}

			existingLfs, _, err := db_bridge.GetLocalFiles(database)
			if err != nil {
				scheduler.ScheduleAsync(func() error {
					reject(vm.NewGoError(err))
					return nil
				})
				return
			}

			existingShelvedLfs, err := db_bridge.GetShelvedLocalFiles(database)
			if err != nil {
				scheduler.ScheduleAsync(func() error {
					reject(vm.NewGoError(err))
					return nil
				})
				return
			}

			scanSummaryLogger := summary.NewScanSummaryLogger()

			animeCollection, err := platformRef.Get().GetAnimeCollection(context.Background(), false)
			if err != nil {
				animeCollection = nil
			}

			scn := scanner.Scanner{
				DirPath:                    libraryPath,
				OtherDirPaths:              additionalLibraryPaths,
				Enhanced:                   opts.Enhanced,
				EnhanceWithOfflineDatabase: opts.EnhanceWithOfflineDatabase,
				PlatformRef:                platformRef,
				Logger:                     logger,
				WSEventManager:             wsEventManager,
				ExistingLocalFiles:         existingLfs,
				SkipLockedFiles:            opts.SkipLockedFiles,
				SkipIgnoredFiles:           opts.SkipIgnoredFiles,
				ScanSummaryLogger:          scanSummaryLogger,
				MetadataProviderRef:        metadataProviderRef,
				MatchingAlgorithm:          settings.GetLibrary().ScannerMatchingAlgorithm,
				MatchingThreshold:          settings.GetLibrary().ScannerMatchingThreshold,
				UseLegacyMatching:          settings.GetLibrary().ScannerUseLegacyMatching,
				WithShelving:               true,
				ExistingShelvedFiles:       existingShelvedLfs,
				ConfigAsString:             settings.GetLibrary().ScannerConfig,
				AnimeCollection:            animeCollection,
			}

			allLfs, err := scn.Scan(context.Background())
			if err != nil {
				if errors.Is(err, scanner.ErrNoLocalFiles) {
					scheduler.ScheduleAsync(func() error {
						resolve(vm.ToValue([]*anime.LocalFile{}))
						return nil
					})
					return
				}

				scheduler.ScheduleAsync(func() error {
					reject(vm.NewGoError(err))
					return nil
				})
				return
			}

			lfs, err := db_bridge.InsertLocalFiles(database, allLfs)
			if err != nil {
				scheduler.ScheduleAsync(func() error {
					reject(vm.NewGoError(err))
					return nil
				})
				return
			}

			if err := db_bridge.SaveShelvedLocalFiles(database, scn.GetShelvedLocalFiles()); err != nil {
				scheduler.ScheduleAsync(func() error {
					reject(vm.NewGoError(err))
					return nil
				})
				return
			}

			_ = db_bridge.InsertScanSummary(database, scanSummaryLogger.GenerateSummary())

			if autoDownloader != nil {
				go autoDownloader.CleanUpDownloadedItems()
			}
			if refreshAnimeCollection != nil {
				go refreshAnimeCollection()
			}

			scheduler.ScheduleAsync(func() error {
				resolve(vm.ToValue(lfs))
				return nil
			})
		}()

		return vm.ToValue(promise)
	})

	_ = obj.Set("scanner", scannerObj)
}
