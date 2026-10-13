package shows

import (
	"path/filepath"
	"seanime/internal/library/filesystem"
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

		hint := "tv"
		if opts.FolderTypes != nil {
			if t, ok := opts.FolderTypes[dirPath]; ok && t != "" {
				hint = t
			}
		}

		// Skip folders explicitly designated strictly as anime-only
		if hint == "anime" {
			continue
		}

		filePaths, err := filesystem.GetMediaFilePathsFromDir(dirPath)
		if err != nil {
			continue
		}

		for _, fp := range filePaths {
			normPath := filepath.ToSlash(fp)

			// If file was already scanned and locked or matched, keep it
			if existing, exists := existingMap[normPath]; exists {
				resultMap[normPath] = existing
				continue
			}

			// New file discovered
			mediaType := hint
			if mediaType == "mixed" {
				mediaType = ""
			}
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
