package shows

import (
	"path/filepath"
	"aniting/internal/library/filesystem"
	"strings"
)

// ScannerOptions provides configuration for scanning show and movie directories.
type ScannerOptions struct {
	DirectoryPaths []string          `json:"directoryPaths"`
	FolderTypes    map[string]string `json:"folderTypes"` // path -> "tv" | "movie" | "anime" | "mixed"
	ExistingFiles  []*ShowLocalFile  `json:"existingFiles"`
}

// ScanShowDirectories scans the specified directory paths and returns all discovered ShowLocalFile objects.
func ScanShowDirectories(opts ScannerOptions) ([]*ShowLocalFile, error) {
	existingMap := make(map[string]*ShowLocalFile)
	for _, ef := range opts.ExistingFiles {
		norm := filepath.ToSlash(ef.Path)
		existingMap[norm] = ef
	}

	resultMap := make(map[string]*ShowLocalFile)

	for _, dirPath := range opts.DirectoryPaths {
		if strings.TrimSpace(dirPath) == "" {
			continue
		}

		hint := ""
		if opts.FolderTypes != nil {
			normDir := filepath.ToSlash(filepath.Clean(dirPath))
			for fPath, fType := range opts.FolderTypes {
				if filepath.ToSlash(filepath.Clean(fPath)) == normDir && fType != "" {
					hint = fType
					break
				}
			}
		}

		// Only scan folders explicitly designated as TV, movie, or mixed. Anime is default.
		if hint != "tv" && hint != "movie" && hint != "mixed" {
			continue
		}

		filePaths, err := filesystem.GetMediaFilePathsFromDir(dirPath)
		if err != nil {
			continue
		}

		for _, fp := range filePaths {
			normPath := filepath.ToSlash(fp)

			mediaType := hint
			if mediaType == "mixed" {
				mediaType = ""
			}

			// If file was already scanned, refresh parsed metadata while preserving manual match & lock
			if existing, exists := existingMap[normPath]; exists {
				newFile := NewShowLocalFile(normPath, mediaType)
				if existing.Locked || existing.IsMatched() {
					newFile.TmdbId = existing.TmdbId
					newFile.Locked = existing.Locked
				}
				newFile.Ignored = existing.Ignored
				resultMap[normPath] = newFile
				continue
			}

			// New file discovered
			newFile := NewShowLocalFile(normPath, mediaType)
			resultMap[normPath] = newFile
		}
	}

	result := make([]*ShowLocalFile, 0, len(resultMap))
	for _, f := range resultMap {
		result = append(result, f)
	}

	return result, nil
}
