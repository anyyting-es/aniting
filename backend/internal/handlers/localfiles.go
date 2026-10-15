package handlers

import (
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"seanime/internal/database/db_bridge"
	"seanime/internal/database/models"
	"seanime/internal/library/anime"
	"seanime/internal/library/filesystem"
	"seanime/internal/library/shows"
	"seanime/internal/library_explorer"
	"seanime/internal/platforms/simulated_platform"
	"strings"
	"time"

	"github.com/goccy/go-json"
	"github.com/labstack/echo/v4"
	"github.com/samber/lo"
	"github.com/sourcegraph/conc/pool"
)

// HandleGetLocalFiles
//
//	@summary returns all local files.
//	@desc Reminder that local files are scanned from the library path.
//	@route /api/v1/library/local-files [GET]
//	@returns []anime.LocalFile
func (h *Handler) HandleGetLocalFiles(c echo.Context) error {
	if err := h.guardStrictLocalOnlyAction(c); err != nil {
		return err
	}

	lfs, _, err := db_bridge.GetLocalFiles(h.App.Database)
	if err != nil {
		return h.RespondWithError(c, err)
	}

	return h.RespondWithData(c, lfs)
}

func (h *Handler) HandleDumpLocalFilesToFile(c echo.Context) error {
	if err := h.guardStrictLocalOnlyAction(c); err != nil {
		return err
	}

	lfs, _, err := db_bridge.GetLocalFiles(h.App.Database)
	if err != nil {
		return h.RespondWithError(c, err)
	}

	filename := fmt.Sprintf("seanime-localfiles-%s.json", time.Now().Format("2006-01-02_15-04-05"))

	c.Response().Header().Set("Content-Disposition", fmt.Sprintf("attachment; filename=%s", filename))
	c.Response().Header().Set("Content-Type", "application/json")

	jsonData, err := json.MarshalIndent(lfs, "", "  ")
	if err != nil {
		return h.RespondWithError(c, err)
	}

	return c.Blob(200, "application/json", jsonData)
}

// HandleImportLocalFiles
//
//	@summary imports local files from the given path.
//	@desc This will import local files from the given path.
//	@desc The response is ignored, the client should refetch the entire library collection and media entry.
//	@route /api/v1/library/local-files/import [POST]
func (h *Handler) HandleImportLocalFiles(c echo.Context) error {
	type body struct {
		DataFilePath string `json:"dataFilePath"`
	}

	b := new(body)
	if err := c.Bind(b); err != nil {
		return h.RespondWithError(c, err)
	}

	if err := h.guardStrictLocalOnlyAction(c); err != nil {
		return err
	}

	if err := h.guardStrictFilesystemPath(c, b.DataFilePath); err != nil {
		return err
	}

	contentB, err := os.ReadFile(b.DataFilePath)
	if err != nil {
		return h.RespondWithError(c, err)
	}

	var lfs []*anime.LocalFile
	if err := json.Unmarshal(contentB, &lfs); err != nil {
		return h.RespondWithError(c, err)
	}

	if len(lfs) == 0 {
		return h.RespondWithError(c, errors.New("no local files found"))
	}

	_, err = db_bridge.InsertLocalFiles(h.App.Database, lfs)
	if err != nil {
		return h.RespondWithError(c, err)
	}

	h.App.Database.TrimLocalFileEntries()

	anime.ClearMissingEpisodesCache()

	return h.RespondWithData(c, true)
}

// HandleLocalFileBulkAction
//
//	@summary performs an action on all local files.
//	@desc This will perform the given action on all local files.
//	@desc The response is ignored, the client should refetch the entire library collection and media entry.
//	@route /api/v1/library/local-files [POST]
//	@returns []anime.LocalFile
func (h *Handler) HandleLocalFileBulkAction(c echo.Context) error {
	if err := h.guardStrictLocalOnlyAction(c); err != nil {
		return err
	}

	type body struct {
		Action string `json:"action"`
	}

	b := new(body)
	if err := c.Bind(b); err != nil {
		return h.RespondWithError(c, err)
	}

	// Get all the local files
	lfs, lfsId, err := db_bridge.GetLocalFiles(h.App.Database)
	if err != nil {
		return h.RespondWithError(c, err)
	}

	switch b.Action {
	case "lock":
		for _, lf := range lfs {
			// Note: Don't lock local files that are not associated with a media.
			// Else refreshing the library will ignore them.
			if lf.MediaId != 0 {
				lf.Locked = true
			}
		}
	case "unlock":
		for _, lf := range lfs {
			lf.Locked = false
		}
	}

	// Save the local files
	retLfs, err := db_bridge.SaveLocalFiles(h.App.Database, lfsId, lfs)
	if err != nil {
		return h.RespondWithError(c, err)
	}

	return h.RespondWithData(c, retLfs)
}

// HandleUpdateLocalFileData
//
//	@summary updates the local file with the given path.
//	@desc This will update the local file with the given path.
//	@desc The response is ignored, the client should refetch the entire library collection and media entry.
//	@route /api/v1/library/local-file [PATCH]
//	@returns []anime.LocalFile
func (h *Handler) HandleUpdateLocalFileData(c echo.Context) error {
	if err := h.guardStrictLocalOnlyAction(c); err != nil {
		return err
	}

	type body struct {
		Path     string                   `json:"path"`
		Metadata *anime.LocalFileMetadata `json:"metadata"`
		Locked   bool                     `json:"locked"`
		Ignored  bool                     `json:"ignored"`
		MediaId  int                      `json:"mediaId"`
	}

	b := new(body)
	if err := c.Bind(b); err != nil {
		return h.RespondWithError(c, err)
	}

	// Get all the local files
	lfs, lfsId, err := db_bridge.GetLocalFiles(h.App.Database)
	if err != nil {
		return h.RespondWithError(c, err)
	}

	lf, found := lo.Find(lfs, func(i *anime.LocalFile) bool {
		return i.HasSamePath(b.Path)
	})
	if !found {
		return h.RespondWithError(c, errors.New("local file not found"))
	}
	lf.Metadata = b.Metadata
	lf.Locked = b.Locked
	lf.Ignored = b.Ignored
	lf.MediaId = b.MediaId

	// Save the local files
	retLfs, err := db_bridge.SaveLocalFiles(h.App.Database, lfsId, lfs)
	if err != nil {
		return h.RespondWithError(c, err)
	}

	anime.ClearMissingEpisodesCache()

	return h.RespondWithData(c, retLfs)
}

// HandleSuperUpdateLocalFiles
//
//	@summary updates local files with the given paths.
//	@desc The client should refetch the entire library collection and media entry.
//	@route /api/v1/library/local-files/super-update [PATCH]
//	@returns bool
func (h *Handler) HandleSuperUpdateLocalFiles(c echo.Context) error {
	if err := h.guardStrictLocalOnlyAction(c); err != nil {
		return err
	}

	type body struct {
		Files []*library_explorer.SuperUpdateFileOptions `json:"files"`
	}

	b := new(body)
	if err := c.Bind(b); err != nil {
		return h.RespondWithError(c, err)
	}
	// Super update the files
	err := h.App.LibraryExplorer.SuperUpdateFiles(b.Files)
	if err != nil {
		return h.RespondWithError(c, err)
	}

	anime.ClearMissingEpisodesCache()

	return h.RespondWithData(c, true)
}

// HandleUpdateLocalFiles
//
//	@summary updates local files with the given paths.
//	@desc The client should refetch the entire library collection and media entry.
//	@route /api/v1/library/local-files [PATCH]
//	@returns bool
func (h *Handler) HandleUpdateLocalFiles(c echo.Context) error {
	if err := h.guardStrictLocalOnlyAction(c); err != nil {
		return err
	}

	type body struct {
		Paths   []string `json:"paths"`
		Action  string   `json:"action"`
		MediaId int      `json:"mediaId,omitempty"`
	}

	b := new(body)
	if err := c.Bind(b); err != nil {
		return h.RespondWithError(c, err)
	}

	// Get all the local files
	lfs, lfsId, err := db_bridge.GetLocalFiles(h.App.Database)
	if err != nil {
		return h.RespondWithError(c, err)
	}

	// Update the files
	for _, path := range b.Paths {
		lf, found := lo.Find(lfs, func(i *anime.LocalFile) bool {
			return i.HasSamePath(path)
		})
		if !found {
			continue
		}
		switch b.Action {
		case "lock":
			lf.Locked = true
		case "unlock":
			lf.Locked = false
		case "ignore":
			lf.MediaId = 0
			lf.Ignored = true
			lf.Locked = false
		case "unignore":
			lf.Ignored = false
			lf.Locked = false
		case "unmatch":
			lf.MediaId = 0
			lf.Locked = false
			lf.Ignored = false
		case "match":
			lf.MediaId = b.MediaId
			lf.Locked = true
			lf.Ignored = false
		}
	}

	// Save the local files
	_, err = db_bridge.SaveLocalFiles(h.App.Database, lfsId, lfs)
	if err != nil {
		return h.RespondWithError(c, err)
	}

	anime.ClearMissingEpisodesCache()

	return h.RespondWithData(c, true)
}

// HandleDeleteLocalFiles
//
//	@summary deletes local files with the given paths.
//	@desc This will delete the local files with the given paths.
//	@desc The client should refetch the entire library collection and media entry.
//	@route /api/v1/library/local-files [DELETE]
//	@returns bool
func (h *Handler) HandleDeleteLocalFiles(c echo.Context) error {
	if err := h.guardStrictLocalOnlyAction(c); err != nil {
		return err
	}

	type body struct {
		Paths []string `json:"paths"`
	}

	b := new(body)
	if err := c.Bind(b); err != nil {
		return h.RespondWithError(c, err)
	}

	// Get all the local files
	lfs, lfsId, err := db_bridge.GetLocalFiles(h.App.Database)
	if err != nil {
		return h.RespondWithError(c, err)
	}
	selectedFiles, err := localFilesForPaths(lfs, b.Paths)
	if err != nil {
		return h.RespondWithError(c, err)
	}

	// Delete the files
	p := pool.New().WithErrors()
	for _, lf := range selectedFiles {
		path := lf.Path
		p.Go(func() error {
			err := os.Remove(path)
			if err != nil {
				return err
			}
			return nil
		})
	}
	if err := p.Wait(); err != nil {
		return h.RespondWithError(c, err)
	}

	// Remove the files from the list
	lfs = lo.Filter(lfs, func(i *anime.LocalFile, _ int) bool {
		return !lo.ContainsBy(selectedFiles, func(lf *anime.LocalFile) bool {
			return lf.HasSamePath(i.Path)
		})
	})

	// Save the local files
	_, err = db_bridge.SaveLocalFiles(h.App.Database, lfsId, lfs)
	if err != nil {
		return h.RespondWithError(c, err)
	}

	anime.ClearMissingEpisodesCache()

	go h.App.UpdateLibrarySize(true)

	return h.RespondWithData(c, true)
}

func localFilesForPaths(lfs []*anime.LocalFile, paths []string) ([]*anime.LocalFile, error) {
	ret := make([]*anime.LocalFile, 0, len(paths))
	for _, path := range paths {
		lf, found := lo.Find(lfs, func(i *anime.LocalFile) bool {
			return i.HasSamePath(path)
		})
		if !found {
			return nil, fmt.Errorf("local file not found: %s", path)
		}
		ret = append(ret, lf)
	}

	return lo.UniqBy(ret, func(lf *anime.LocalFile) string {
		return lf.Path
	}), nil
}

// HandleRemoveEmptyDirectories
//
//	@summary removes empty directories.
//	@desc This will remove empty directories in the library path.
//	@route /api/v1/library/empty-directories [DELETE]
//	@returns bool
func (h *Handler) HandleRemoveEmptyDirectories(c echo.Context) error {
	if err := h.guardStrictLocalOnlyAction(c); err != nil {
		return err
	}

	libraryPaths, err := h.App.Database.GetAllLibraryPathsFromSettings()
	if err != nil {
		return h.RespondWithError(c, err)
	}

	for _, path := range libraryPaths {
		filesystem.RemoveEmptyDirectories(path, h.App.Logger)
	}

	return h.RespondWithData(c, true)
}

// HandleRemoveLibraryFolder unlinks or removes a library folder from settings and immediately purges its files from local library & shows database.
//
//	@summary removes a library folder and purges its indexed files
//	@route /api/v1/library/remove-folder [POST]
//	@returns bool
func (h *Handler) HandleRemoveLibraryFolder(c echo.Context) error {
	if err := h.guardStrictLocalOnlyAction(c); err != nil {
		return err
	}

	type body struct {
		Path   string `json:"path"`
		IsMain bool   `json:"isMain"`
	}

	var b body
	if err := c.Bind(&b); err != nil {
		return h.RespondWithError(c, err)
	}

	rawTarget := strings.TrimSpace(b.Path)
	targetPath := filepath.ToSlash(filepath.Clean(rawTarget))
	targetPath = strings.TrimSuffix(targetPath, "/")
	if targetPath == "" && !b.IsMain {
		return h.RespondWithError(c, errors.New("empty path"))
	}

	// 1. Update settings
	settings, err := h.App.Database.GetSettings()
	if err != nil {
		return h.RespondWithError(c, err)
	}

	if settings.Library != nil {
		mainSlash := filepath.ToSlash(filepath.Clean(strings.TrimSpace(settings.Library.LibraryPath)))
		mainSlash = strings.TrimSuffix(mainSlash, "/")
		if targetPath == "" && b.IsMain {
			targetPath = mainSlash
		}
		if b.IsMain || (targetPath != "" && mainSlash == targetPath) {
			settings.Library.LibraryPath = ""
		}
		var newAdditionals []string
		for _, p := range settings.Library.LibraryPaths {
			pSlash := filepath.ToSlash(filepath.Clean(strings.TrimSpace(p)))
			pSlash = strings.TrimSuffix(pSlash, "/")
			if pSlash != "" && pSlash != targetPath {
				newAdditionals = append(newAdditionals, p)
			}
		}
		settings.Library.LibraryPaths = newAdditionals

		settings.BaseModel = models.BaseModel{
			ID:        1,
			UpdatedAt: time.Now(),
		}
		if _, err := h.App.Database.UpsertSettings(settings); err == nil {
			h.App.WSEventManager.SendEvent("settings", settings)
		}
	}

	hasAnyPaths := false
	if settings.Library != nil {
		if strings.TrimSpace(settings.Library.LibraryPath) != "" || len(settings.Library.LibraryPaths) > 0 {
			hasAnyPaths = true
		}
	}

	pathBelongsToTarget := func(filePath string) bool {
		if targetPath == "" {
			return false
		}
		fClean := filepath.ToSlash(filepath.Clean(strings.TrimSpace(filePath)))
		return fClean == targetPath || strings.HasPrefix(fClean, targetPath+"/")
	}

	// 2. Purge show local files
	showFiles, showId, err := db_bridge.GetShowLocalFiles(h.App.Database)
	if err == nil {
		filteredShows := make([]*shows.ShowLocalFile, 0)
		if hasAnyPaths {
			for _, sf := range showFiles {
				if !pathBelongsToTarget(sf.Path) {
					filteredShows = append(filteredShows, sf)
				}
			}
		}
		_, _ = db_bridge.SaveShowLocalFiles(h.App.Database, showId, filteredShows)
	}

	// 3. Purge anime local files
	animeFiles, animeId, err := db_bridge.GetLocalFiles(h.App.Database)
	filteredAnime := make([]*anime.LocalFile, 0)
	if err == nil {
		if hasAnyPaths {
			for _, af := range animeFiles {
				if !pathBelongsToTarget(af.Path) {
					filteredAnime = append(filteredAnime, af)
				}
			}
		}
		_, _ = db_bridge.SaveLocalFiles(h.App.Database, animeId, filteredAnime)
		if len(filteredAnime) == 0 {
			_, _ = db_bridge.InsertLocalFiles(h.App.Database, make([]*anime.LocalFile, 0))
		}
	}

	// 4. Purge shelved files
	shelved, err := db_bridge.GetShelvedLocalFiles(h.App.Database)
	if err == nil {
		filteredShelved := make([]*anime.LocalFile, 0)
		if hasAnyPaths {
			for _, sh := range shelved {
				if !pathBelongsToTarget(sh.Path) {
					filteredShelved = append(filteredShelved, sh)
				}
			}
		}
		_ = db_bridge.SaveShelvedLocalFiles(h.App.Database, filteredShelved)
	}

	// 5. Purge orphaned entries from simulated anime collection if unauthenticated
	if sp, ok := h.App.AnilistPlatformRef.Get().(*simulated_platform.SimulatedPlatform); ok {
		remainingMediaIds := make(map[int]bool)
		for _, f := range filteredAnime {
			if f.MediaId > 0 {
				remainingMediaIds[f.MediaId] = true
			}
		}
		if col, err := sp.GetAnimeCollection(c.Request().Context(), false); err == nil && col != nil && col.GetMediaListCollection() != nil {
			wrapper := sp.GetAnimeCollectionWrapper()
			var toDelete []int
			for _, list := range col.GetMediaListCollection().GetLists() {
				for _, entry := range list.GetEntries() {
					if entry.GetMedia() != nil {
						mId := entry.GetMedia().GetID()
						if !remainingMediaIds[mId] {
							toDelete = append(toDelete, mId)
						}
					}
				}
			}
			for _, mId := range toDelete {
				_ = wrapper.DeleteEntry(mId)
			}
		}
	}

	// 6. Clear caches and refresh collection
	go h.App.RefreshAnimeCollection()
	anime.ClearMissingEpisodesCache()

	return h.RespondWithData(c, true)
}

