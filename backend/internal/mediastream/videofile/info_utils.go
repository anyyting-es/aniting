package videofile

import (
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"os"
)

// GetHashFromPath returns a deterministic hash derived from the file path and
// its last-modified timestamp. The hash changes when the file is re-written,
// ensuring stale cache entries are invalidated.
//
// Uses SHA-256 with a stable time format (UnixNano) to avoid locale-dependent
// string representations of ModTime.
func GetHashFromPath(path string) (string, error) {
	info, err := os.Stat(path)
	if err != nil {
		return "", err
	}
	h := sha256.New()
	// Use UnixNano instead of ModTime().String() which can vary across
	// locales and Go versions.
	_, _ = fmt.Fprintf(h, "%s:%d", path, info.ModTime().UnixNano())
	return hex.EncodeToString(h.Sum(nil))[:40], nil // 40-char hex prefix
}
