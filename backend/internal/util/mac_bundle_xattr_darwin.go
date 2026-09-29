//go:build darwin

package util

import (
	"errors"
	"io/fs"
	"os"
	"path/filepath"

	"golang.org/x/sys/unix"
)

func ClearMacAppQuarantine(root string) error {
	return filepath.WalkDir(root, func(path string, d fs.DirEntry, walkErr error) error {
		if walkErr != nil {
			return walkErr
		}

		var err error
		if d.Type()&os.ModeSymlink != 0 {
			err = unix.Lremovexattr(path, "com.apple.quarantine")
		} else {
			err = unix.Removexattr(path, "com.apple.quarantine")
		}

		if err != nil && !errors.Is(err, unix.ENOATTR) {
			return err
		}

		return nil
	})
}
