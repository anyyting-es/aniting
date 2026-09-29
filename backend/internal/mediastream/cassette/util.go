package cassette

import (
	"errors"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"time"

	"github.com/goccy/go-json"
	"github.com/rs/zerolog"
)

// ParseSegment extracts the segment number from a filename like "segment-42.ts"
func ParseSegment(segment string) (int32, error) {
	var ret int32
	_, err := fmt.Sscanf(segment, "segment-%d.ts", &ret)
	if err != nil {
		return 0, errors.New("cassette: could not parse segment name")
	}
	return ret, nil
}

// getSavedInfo deserializes a json file
func getSavedInfo[T any](savePath string, target *T) error {
	f, err := os.Open(savePath)
	if err != nil {
		return err
	}
	defer f.Close()
	data, err := io.ReadAll(f)
	if err != nil {
		return err
	}
	return json.Unmarshal(data, target)
}

// saveInfo serializes the value to json and stores it on disk
func saveInfo[T any](savePath string, value *T) error {
	data, err := json.Marshal(*value)
	if err != nil {
		return err
	}
	_ = os.MkdirAll(filepath.Dir(savePath), 0755)
	return os.WriteFile(savePath, data, 0666)
}

// printExecTime logs elapsed time for an operation
func printExecTime(logger *zerolog.Logger, message string, args ...any) func() {
	msg := fmt.Sprintf(message, args...)
	start := time.Now()
	logger.Trace().Msgf("cassette: Running %s", msg)
	return func() {
		logger.Trace().Msgf("cassette: %s finished in %s", msg, time.Since(start))
	}
}

// GetEnvOr returns the environment variable value or default
func GetEnvOr(env, def string) string {
	if v := os.Getenv(env); v != "" {
		return v
	}
	return def
}

// closestEven rounds n up to the nearest even number
func closestEven(n int32) int32 {
	if n%2 != 0 {
		return n + 1
	}
	return n
}

// abs32 returns the absolute value of an int32
func abs32(x int32) int32 {
	if x < 0 {
		return -x
	}
	return x
}
