package handlers

import (
	"path/filepath"
	"seanime/internal/database/db_bridge"
	"seanime/internal/library/shows"
	"strings"

	"github.com/labstack/echo/v4"
)

// HandleScanShows scans library directories for TV shows and movies using Plex/Jellyfin naming conventions.
//
//	@summary scans library for shows and movies
//	@route /api/v1/shows/scan [POST]
//	@returns shows.ShowCollection
func (h *Handler) HandleScanShows(c echo.Context) error {
	if err := h.guardStrictLocalOnlyAction(c); err != nil {
		return err
	}

	type body struct {
		FolderTypes map[string]string `json:"folderTypes"`
	}

	var b body
	_ = c.Bind(&b)

	// Retrieve configured library paths
	mainPath, _ := h.App.Database.GetLibraryPathFromSettings()
	additionalPaths, _ := h.App.Database.GetAdditionalLibraryPathsFromSettings()

	var allPaths []string
	if strings.TrimSpace(mainPath) != "" {
		allPaths = append(allPaths, mainPath)
	}
	for _, p := range additionalPaths {
		if strings.TrimSpace(p) != "" {
			allPaths = append(allPaths, p)
		}
	}

	if len(allPaths) == 0 {
		emptyCol := shows.NewShowCollection([]*shows.ShowLocalFile{})
		return h.RespondWithData(c, emptyCol)
	}

	existingFiles, existingId, _ := db_bridge.GetShowLocalFiles(h.App.Database)

	scannedFiles, err := shows.ScanShowDirectories(shows.ScannerOptions{
		DirectoryPaths: allPaths,
		FolderTypes:    b.FolderTypes,
		ExistingFiles:  existingFiles,
	})
	if err != nil {
		return h.RespondWithError(c, err)
	}

	savedFiles, err := db_bridge.SaveShowLocalFiles(h.App.Database, existingId, scannedFiles)
	if err != nil {
		return h.RespondWithError(c, err)
	}

	collection := shows.NewShowCollection(savedFiles)
	return h.RespondWithData(c, collection)
}

// HandleGetShowsCollection returns all scanned TV shows and movies grouped into ShowEntry collections.
//
//	@summary returns the grouped shows collection
//	@route /api/v1/shows/collection [GET]
//	@returns shows.ShowCollection
func (h *Handler) HandleGetShowsCollection(c echo.Context) error {
	if err := h.guardStrictLocalOnlyAction(c); err != nil {
		return err
	}

	files, _, err := db_bridge.GetShowLocalFiles(h.App.Database)
	if err != nil {
		return h.RespondWithError(c, err)
	}

	collection := shows.NewShowCollection(files)
	return h.RespondWithData(c, collection)
}

// HandleGetShowsLocalFiles returns raw scanned files for TV shows and movies.
//
//	@summary returns all show local files
//	@route /api/v1/shows/local-files [GET]
//	@returns []*shows.ShowLocalFile
func (h *Handler) HandleGetShowsLocalFiles(c echo.Context) error {
	if err := h.guardStrictLocalOnlyAction(c); err != nil {
		return err
	}

	files, _, err := db_bridge.GetShowLocalFiles(h.App.Database)
	if err != nil {
		return h.RespondWithError(c, err)
	}

	return h.RespondWithData(c, files)
}

// HandleMatchShow assigns a set of files or a folder to a specific TMDB ID.
//
//	@summary match files or folder with TMDB show/movie
//	@route /api/v1/shows/match [POST]
//	@returns shows.ShowCollection
func (h *Handler) HandleMatchShow(c echo.Context) error {
	if err := h.guardStrictLocalOnlyAction(c); err != nil {
		return err
	}

	type body struct {
		Paths      []string `json:"paths"`
		FolderPath string   `json:"folderPath"`
		TmdbId     int      `json:"tmdbId"`
		MediaType  string   `json:"mediaType"` // "tv" or "movie"
		Title      string   `json:"title"`
	}

	var b body
	if err := c.Bind(&b); err != nil {
		return h.RespondWithError(c, err)
	}

	if b.TmdbId <= 0 {
		return h.RespondWithError(c, echo.NewHTTPError(400, "invalid tmdbId"))
	}

	files, existingId, err := db_bridge.GetShowLocalFiles(h.App.Database)
	if err != nil {
		return h.RespondWithError(c, err)
	}

	pathSet := make(map[string]bool)
	for _, p := range b.Paths {
		pathSet[filepath.ToSlash(p)] = true
	}
	targetFolder := filepath.ToSlash(b.FolderPath)

	matchedAny := false
	for _, f := range files {
		fPath := filepath.ToSlash(f.Path)
		fDir := filepath.ToSlash(f.FolderPath)

		shouldMatch := pathSet[fPath] || (targetFolder != "" && (fDir == targetFolder || strings.HasPrefix(fDir, targetFolder+"/")))
		if shouldMatch {
			f.TmdbId = b.TmdbId
			if b.MediaType != "" {
				f.MediaType = b.MediaType
			}
			if b.Title != "" {
				f.ParsedTitle = b.Title
			}
			f.Locked = true
			matchedAny = true
		}
	}

	if !matchedAny && len(b.Paths) > 0 {
		// If files weren't in show list yet (e.g. freshly matched from general scan), add them
		for _, p := range b.Paths {
			newF := shows.NewShowLocalFile(filepath.ToSlash(p), b.MediaType)
			newF.TmdbId = b.TmdbId
			if b.Title != "" {
				newF.ParsedTitle = b.Title
			}
			newF.Locked = true
			files = append(files, newF)
		}
	}

	saved, err := db_bridge.SaveShowLocalFiles(h.App.Database, existingId, files)
	if err != nil {
		return h.RespondWithError(c, err)
	}

	collection := shows.NewShowCollection(saved)
	return h.RespondWithData(c, collection)
}

// HandleUnmatchShow clears the TMDB ID from specified files or folder.
//
//	@summary unmatch files or folder from TMDB
//	@route /api/v1/shows/unmatch [POST]
//	@returns shows.ShowCollection
func (h *Handler) HandleUnmatchShow(c echo.Context) error {
	if err := h.guardStrictLocalOnlyAction(c); err != nil {
		return err
	}

	type body struct {
		Paths      []string `json:"paths"`
		FolderPath string   `json:"folderPath"`
	}

	var b body
	if err := c.Bind(&b); err != nil {
		return h.RespondWithError(c, err)
	}

	files, existingId, err := db_bridge.GetShowLocalFiles(h.App.Database)
	if err != nil {
		return h.RespondWithError(c, err)
	}

	pathSet := make(map[string]bool)
	for _, p := range b.Paths {
		pathSet[filepath.ToSlash(p)] = true
	}
	targetFolder := filepath.ToSlash(b.FolderPath)

	for _, f := range files {
		fPath := filepath.ToSlash(f.Path)
		fDir := filepath.ToSlash(f.FolderPath)

		shouldUnmatch := pathSet[fPath] || (targetFolder != "" && (fDir == targetFolder || strings.HasPrefix(fDir, targetFolder+"/")))
		if shouldUnmatch {
			f.TmdbId = 0
			f.Locked = false
		}
	}

	saved, err := db_bridge.SaveShowLocalFiles(h.App.Database, existingId, files)
	if err != nil {
		return h.RespondWithError(c, err)
	}

	collection := shows.NewShowCollection(saved)
	return h.RespondWithData(c, collection)
}
