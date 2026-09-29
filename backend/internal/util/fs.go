package util

import (
	"archive/zip"
	"errors"
	"fmt"
	"io"
	"os"
	"path"
	"path/filepath"
	"runtime"
	"strings"

	"github.com/nwaples/rardecode/v2"
)

var (
	ErrArchivePathTraversal    = errors.New("archive entry path escapes destination")
	ErrUnsupportedArchiveEntry = errors.New("unsupported archive entry")
)

func DirSize(path string) (uint64, error) {
	var size int64
	err := filepath.Walk(path, func(_ string, info os.FileInfo, err error) error {
		if err != nil {
			return err
		}
		if !info.IsDir() {
			size += info.Size()
		}
		return err
	})
	return uint64(size), err
}

func IsValidMediaFile(path string) bool {
	return !strings.HasPrefix(path, "._")
}
func IsValidVideoExtension(ext string) bool {
	validExtensions := map[string]struct{}{
		".mp4": {}, ".avi": {}, ".mkv": {}, ".mov": {}, ".flv": {}, ".wmv": {}, ".webm": {},
		".mpeg": {}, ".mpg": {}, ".m4v": {}, ".3gp": {}, ".3g2": {}, ".ogg": {}, ".ogv": {},
		".vob": {}, ".mts": {}, ".m2ts": {}, ".ts": {}, ".f4v": {}, ".ogm": {}, ".rm": {},
		".rmvb": {}, ".drc": {}, ".yuv": {}, ".asf": {}, ".amv": {}, ".m2v": {}, ".mpe": {},
		".mpv": {}, ".mp2": {}, ".svi": {}, ".mxf": {}, ".roq": {}, ".nsv": {}, ".f4p": {},
		".f4a": {}, ".f4b": {},
	}
	ext = strings.ToLower(ext)
	_, exists := validExtensions[ext]
	return exists
}

func IsSubdirectory(parent, child string) bool {
	parentPath, err := normalizeComparablePath(parent)
	if err != nil {
		return false
	}
	childPath, err := normalizeComparablePath(child)
	if err != nil {
		return false
	}

	return isStrictDescendantPath(parentPath, childPath)
}

func IsSubdirectoryOfAny(dirs []string, child string) bool {
	for _, dir := range dirs {
		if IsSubdirectory(dir, child) {
			return true
		}
	}
	return false
}

func IsSameDir(dir1, dir2 string) bool {
	normalizedDir1, err := normalizeComparablePath(dir1)
	if err != nil {
		return false
	}
	normalizedDir2, err := normalizeComparablePath(dir2)
	if err != nil {
		return false
	}

	return normalizedDir1 == normalizedDir2
}

func IsFileUnderDir(filePath, dir string) bool {
	normalizedDir, err := normalizeComparablePath(dir)
	if err != nil {
		return false
	}
	normalizedFile, err := normalizeComparablePath(filePath)
	if err != nil {
		return false
	}

	return isStrictDescendantPath(normalizedDir, normalizedFile)
}

func isStrictDescendantPath(parent, child string) bool {
	if parent == child {
		return false
	}

	prefix := parent
	if !strings.HasSuffix(prefix, "/") {
		prefix += "/"
	}

	return strings.HasPrefix(child, prefix)
}

func normalizeComparablePath(input string) (string, error) {
	if looksLikeWindowsPath(input) {
		normalized := strings.ReplaceAll(input, `\`, "/")
		if len(normalized) >= 2 && normalized[1] == ':' {
			volume := strings.ToLower(normalized[:2])
			tail := path.Clean("/" + strings.TrimPrefix(normalized[2:], "/"))
			return volume + strings.ToLower(tail), nil
		}

		return strings.ToLower(path.Clean(normalized)), nil
	}

	absPath, err := filepath.Abs(input)
	if err != nil {
		return "", err
	}

	normalized := filepath.ToSlash(filepath.Clean(absPath))
	if runtime.GOOS == "windows" {
		normalized = strings.ToLower(normalized)
	}

	return normalized, nil
}

func looksLikeWindowsPath(input string) bool {
	if len(input) >= 2 && input[1] == ':' {
		return true
	}

	return strings.Contains(input, `\`)
}

func ResolveArchiveEntryPath(destRoot, entryName string) (string, error) {
	normalizedEntry := strings.ReplaceAll(entryName, `\`, "/")
	cleanedEntry := path.Clean(normalizedEntry)
	if normalizedEntry == "" || cleanedEntry == "." || cleanedEntry == "/" {
		return "", fmt.Errorf("invalid archive entry path: %q", entryName)
	}

	resolvedPath := filepath.Join(destRoot, filepath.FromSlash(normalizedEntry))
	normalizedDestRoot, err := normalizeComparablePath(destRoot)
	if err != nil {
		return "", err
	}

	normalizedResolvedPath, err := normalizeComparablePath(resolvedPath)
	if err != nil {
		return "", err
	}

	if normalizedResolvedPath != normalizedDestRoot && !isStrictDescendantPath(normalizedDestRoot, normalizedResolvedPath) {
		return "", fmt.Errorf("%w: %s", ErrArchivePathTraversal, entryName)
	}

	return resolvedPath, nil
}

// UnzipFile unzips a file to the destination.
//
//	Example:
//	// If "file.zip" contains `folder > file.text`
//	UnzipFile("file.zip", "/path/to/dest") // -> "/path/to/dest/folder/file.txt"
//	// If "file.zip" contains `file.txt`
//	UnzipFile("file.zip", "/path/to/dest") // -> "/path/to/dest/file.txt"
func UnzipFile(src, dest string) error {
	r, err := zip.OpenReader(src)
	if err != nil {
		return fmt.Errorf("failed to open zip file: %w", err)
	}
	defer r.Close()

	// Create a temporary folder to extract the files
	extractedDir, err := os.MkdirTemp(filepath.Dir(dest), ".extracted-")
	if err != nil {
		return fmt.Errorf("failed to create temp folder: %w", err)
	}
	defer os.RemoveAll(extractedDir)

	// Iterate through the files in the archive
	for _, f := range r.File {
		mode := f.Mode()
		if mode&os.ModeSymlink != 0 || (!mode.IsRegular() && !f.FileInfo().IsDir()) {
			return fmt.Errorf("%w: %s", ErrUnsupportedArchiveEntry, f.Name)
		}

		fpath, err := ResolveArchiveEntryPath(extractedDir, f.Name)
		if err != nil {
			return fmt.Errorf("failed to resolve archive path: %w", err)
		}
		// If the file is a directory, create it in the destination
		if f.FileInfo().IsDir() {
			_ = os.MkdirAll(fpath, os.ModePerm)
			continue
		}
		// Make sure the parent directory exists (will not return an error if it already exists)
		if err := os.MkdirAll(filepath.Dir(fpath), os.ModePerm); err != nil {
			return fmt.Errorf("failed to create parent directory: %w", err)
		}

		// Open the file in the destination
		outFile, err := os.OpenFile(fpath, os.O_WRONLY|os.O_CREATE|os.O_TRUNC, f.Mode())
		if err != nil {
			return fmt.Errorf("failed to open file: %w", err)
		}
		// Open the file in the archive
		rc, err := f.Open()
		if err != nil {
			_ = outFile.Close()
			return fmt.Errorf("failed to open file in archive: %w", err)
		}

		// Copy the file from the archive to the destination
		_, err = io.Copy(outFile, rc)
		_ = outFile.Close()
		_ = rc.Close()

		if err != nil {
			return fmt.Errorf("failed to copy file: %w", err)
		}
	}

	// Ensure the destination directory exists
	if err := os.MkdirAll(dest, os.ModePerm); err != nil {
		return fmt.Errorf("failed to create destination directory: %w", err)
	}

	// Move the contents of the extracted directory to the destination
	entries, err := os.ReadDir(extractedDir)
	if err != nil {
		return fmt.Errorf("failed to read extracted directory: %w", err)
	}

	for _, entry := range entries {
		srcPath := filepath.Join(extractedDir, entry.Name())
		destPath := filepath.Join(dest, entry.Name())

		// Remove existing file/directory at destination if it exists
		_ = os.RemoveAll(destPath)

		// Move the file/directory to the destination
		if err := os.Rename(srcPath, destPath); err != nil {
			return fmt.Errorf("failed to move extracted item %s: %w", entry.Name(), err)
		}
	}

	return nil
}

// UnrarFile unzips a rar file to the destination.
func UnrarFile(src, dest string) error {
	r, err := rardecode.OpenReader(src)
	if err != nil {
		return fmt.Errorf("failed to open rar file: %w", err)
	}
	defer r.Close()

	// Create a temporary folder to extract the files
	extractedDir, err := os.MkdirTemp(filepath.Dir(dest), ".extracted-")
	if err != nil {
		return fmt.Errorf("failed to create temp folder: %w", err)
	}
	defer os.RemoveAll(extractedDir)

	// Iterate through the files in the archive
	for {
		header, err := r.Next()
		if err == io.EOF {
			break
		}
		if err != nil {
			return fmt.Errorf("failed to get next file in archive: %w", err)
		}

		fpath, err := ResolveArchiveEntryPath(extractedDir, header.Name)
		if err != nil {
			return fmt.Errorf("failed to resolve archive path: %w", err)
		}
		// If the file is a directory, create it in the destination
		if header.IsDir {
			_ = os.MkdirAll(fpath, os.ModePerm)
			continue
		}

		// Make sure the parent directory exists (will not return an error if it already exists)
		if err := os.MkdirAll(filepath.Dir(fpath), os.ModePerm); err != nil {
			return fmt.Errorf("failed to create parent directory: %w", err)
		}

		// Open the file in the destination
		outFile, err := os.Create(fpath)
		if err != nil {
			return fmt.Errorf("failed to create file: %w", err)
		}

		// Copy the file from the archive to the destination
		_, err = io.Copy(outFile, r)
		outFile.Close()

		if err != nil {
			return fmt.Errorf("failed to copy file: %w", err)
		}
	}

	// Ensure the destination directory exists
	if err := os.MkdirAll(dest, os.ModePerm); err != nil {
		return fmt.Errorf("failed to create destination directory: %w", err)
	}

	// Move the contents of the extracted directory to the destination
	entries, err := os.ReadDir(extractedDir)
	if err != nil {
		return fmt.Errorf("failed to read extracted directory: %w", err)
	}

	for _, entry := range entries {
		srcPath := filepath.Join(extractedDir, entry.Name())
		destPath := filepath.Join(dest, entry.Name())

		// Remove existing file/directory at destination if it exists
		_ = os.RemoveAll(destPath)

		// Move the file/directory to the destination
		if err := os.Rename(srcPath, destPath); err != nil {
			return fmt.Errorf("failed to move extracted item %s: %w", entry.Name(), err)
		}
	}

	return nil
}

// MoveToDestination moves a folder or file to the destination
//
//	Example:
//	MoveToDestination("/path/to/src/folder", "/path/to/dest") // -> "/path/to/dest/folder"
func MoveToDestination(src, dest string) error {
	// Ensure the destination folder exists
	if _, err := os.Stat(dest); os.IsNotExist(err) {
		err := os.MkdirAll(dest, os.ModePerm)
		if err != nil {
			return fmt.Errorf("failed to create destination folder: %v", err)
		}
	}

	destFolder := filepath.Join(dest, filepath.Base(src))

	// Move the folder by renaming it
	err := os.Rename(src, destFolder)
	if err != nil {
		return fmt.Errorf("failed to move folder: %v", err)
	}

	return nil
}

// UnwrapAndMove moves the last subfolder containing the files to the destination.
// If there is a single file, it will move that file only.
//
//	Example:
//
//	Case 1:
//	src/
//		- Anime/
//			- Ep1.mkv
//			- Ep2.mkv
//	UnwrapAndMove("/path/to/src", "/path/to/dest") // -> "/path/to/dest/Anime"
//
//	Case 2:
//	src/
//		- {HASH}/
//			- Anime/
//				- Ep1.mkv
//				- Ep2.mkv
//	UnwrapAndMove("/path/to/src", "/path/to/dest") // -> "/path/to/dest/Anime"
//
//	Case 3:
//	src/
//		- {HASH}/
//			- Anime/
//				- Ep1.mkv
//	UnwrapAndMove("/path/to/src", "/path/to/dest") // -> "/path/to/dest/Ep1.mkv"
//
//	Case 4:
//	src/
//		- {HASH}/
//			- Anime/
//				- Anime 1/
//					- Ep1.mkv
//					- Ep2.mkv
//				- Anime 2/
//					- Ep1.mkv
//					- Ep2.mkv
//	UnwrapAndMove("/path/to/src", "/path/to/dest") // -> "/path/to/dest/Anime"
func UnwrapAndMove(src, dest string) error {
	// Ensure the source and destination directories exist
	if _, err := os.Stat(src); os.IsNotExist(err) {
		return fmt.Errorf("source directory does not exist: %s", src)
	}
	_ = os.MkdirAll(dest, os.ModePerm)

	srcEntries, err := os.ReadDir(src)
	if err != nil {
		return err
	}

	// If the source folder contains multiple files or folders, move its contents to the destination
	if len(srcEntries) > 1 {
		for _, srcEntry := range srcEntries {
			err := MoveToDestination(filepath.Join(src, srcEntry.Name()), dest)
			if err != nil {
				return err
			}
		}
		return nil
	}

	folderMap := make(map[string]int)
	err = FindFolderChildCount(src, folderMap)
	if err != nil {
		return err
	}

	var folderToMove string
	for folder, count := range folderMap {
		if count > 1 {
			if folderToMove == "" || len(folder) < len(folderToMove) {
				folderToMove = folder
			}
			continue
		}
	}

	// It's a single file, move that file only
	if folderToMove == "" {
		fp := GetDeepestFile(src)
		if fp == "" {
			return fmt.Errorf("no files found in the source directory")
		}
		return MoveToDestination(fp, dest)
	}

	// Move the folder containing multiple files or folders
	err = MoveToDestination(folderToMove, dest)
	if err != nil {
		return err
	}

	return nil
}

// Finds the folder to move to the destination
func FindFolderChildCount(src string, folderMap map[string]int) error {
	srcEntries, err := os.ReadDir(src)
	if err != nil {
		return err
	}

	for _, srcEntry := range srcEntries {
		folderMap[src]++
		if srcEntry.IsDir() {
			err = FindFolderChildCount(filepath.Join(src, srcEntry.Name()), folderMap)
			if err != nil {
				return err
			}
		}
	}

	return nil
}

func GetDeepestFile(src string) (fp string) {
	srcEntries, err := os.ReadDir(src)
	if err != nil {
		return ""
	}

	for _, srcEntry := range srcEntries {
		if srcEntry.IsDir() {
			return GetDeepestFile(filepath.Join(src, srcEntry.Name()))
		}
		return filepath.Join(src, srcEntry.Name())
	}

	return ""
}
