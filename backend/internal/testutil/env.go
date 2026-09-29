package testutil

import (
	"os"
	pathpkg "path"
	"path/filepath"
	"seanime/internal/database/db"
	"seanime/internal/util"
	"seanime/internal/util/filecache"
	"strings"
	"testing"
	"unicode"

	"github.com/rs/zerolog"
)

const defaultTestDatabaseName = "seanime-test"

type TestEnv struct {
	t        testing.TB
	RootDir  string
	DataDir  string
	CacheDir string
	logger   *zerolog.Logger
	cfg      *Config
}

func NewTestEnv(t testing.TB, flags ...SkipFunc) *TestEnv {
	t.Helper()

	cfg, err := readConfig()
	if err != nil {
		if len(flags) > 0 {
			t.Skipf("testutil: skipping flagged test env because test config is unavailable: %v", err)
		}
		cfg = defaultConfig()
	}
	for _, fn := range flags {
		fn(t, cfg)
	}

	rootDir := t.TempDir()
	dataDir := filepath.Join(rootDir, "data")
	env := &TestEnv{
		t:        t,
		RootDir:  rootDir,
		DataDir:  dataDir,
		CacheDir: filepath.Join(dataDir, "cache"),
		logger:   util.NewLogger(),
		cfg:      cloneConfig(cfg),
	}

	env.cfg.Path.DataDir = env.DataDir
	env.cfg.Database.Name = sanitizeTestName(t.Name())

	env.mustMkdirAll(env.DataDir)
	env.mustMkdirAll(env.CacheDir)

	return env
}

func (env *TestEnv) Logger() *zerolog.Logger {
	return env.logger
}

func (env *TestEnv) Config() *Config {
	return cloneConfig(env.cfg)
}

func (env *TestEnv) RootPath(parts ...string) string {
	return filepath.Join(append([]string{env.RootDir}, parts...)...)
}

func (env *TestEnv) DataPath(parts ...string) string {
	return filepath.Join(append([]string{env.DataDir}, parts...)...)
}

func (env *TestEnv) CachePath(parts ...string) string {
	return filepath.Join(append([]string{env.CacheDir}, parts...)...)
}

func (env *TestEnv) EnsureDir(parts ...string) string {
	return env.mustMkdirAll(env.RootPath(parts...))
}

func (env *TestEnv) EnsureDataDir(parts ...string) string {
	return env.mustMkdirAll(env.DataPath(parts...))
}

func (env *TestEnv) EnsureCacheDir(parts ...string) string {
	return env.mustMkdirAll(env.CachePath(parts...))
}

func (env *TestEnv) MustMkdir(parts ...string) string {
	return env.EnsureDir(parts...)
}

func (env *TestEnv) MustMkdirData(parts ...string) string {
	return env.EnsureDataDir(parts...)
}

func (env *TestEnv) FixturePath(path string) string {
	return filepath.Join(env.RootDir, FixtureRelPath(path))
}

func (env *TestEnv) MustWriteFixtureFile(path string, data []byte) string {
	env.t.Helper()

	target := env.FixturePath(path)
	env.mustMkdirAll(filepath.Dir(target))
	if err := os.WriteFile(target, data, 0644); err != nil {
		env.t.Fatalf("testutil: could not write fixture file %q: %v", target, err)
	}

	return target
}

func (env *TestEnv) NewCacher(parts ...string) *filecache.Cacher {
	env.t.Helper()

	dir := env.CachePath(parts...)
	env.mustMkdirAll(dir)

	cacher, err := filecache.NewCacher(dir)
	if err != nil {
		env.t.Fatalf("testutil: could not create cacher: %v", err)
	}

	return cacher
}

func (env *TestEnv) NewDatabase(name string) *db.Database {
	env.t.Helper()

	if name == "" {
		name = env.cfg.Database.Name
		if name == "" {
			name = defaultTestDatabaseName
		}
	}

	database, err := db.NewDatabase(env.DataDir, name, env.logger)
	if err != nil {
		env.t.Fatalf("testutil: could not create database: %v", err)
	}

	return database
}

func (env *TestEnv) MustNewDatabase(logger *zerolog.Logger) *db.Database {
	env.t.Helper()

	if logger != nil {
		env.logger = logger
	}

	return env.NewDatabase("")
}

func (env *TestEnv) mustMkdirAll(path string) string {
	env.t.Helper()

	if err := os.MkdirAll(path, os.ModePerm); err != nil {
		env.t.Fatalf("testutil: could not create directory %q: %v", path, err)
	}

	return path
}

func FixtureRelPath(path string) string {
	normalized := strings.ReplaceAll(path, `\`, "/")
	if len(normalized) >= 2 && normalized[1] == ':' {
		normalized = normalized[2:]
	}

	cleaned := pathpkg.Clean("/" + normalized)
	cleaned = strings.TrimPrefix(cleaned, "/")
	if cleaned == "." {
		return ""
	}

	return filepath.FromSlash(cleaned)
}

func NormalizeTestPath(path string) string {
	if resolved, err := filepath.EvalSymlinks(path); err == nil {
		return filepath.Clean(resolved)
	}

	return filepath.Clean(path)
}

func sanitizeTestName(name string) string {
	if name == "" {
		return defaultTestDatabaseName
	}

	var b strings.Builder
	lastDash := false
	for _, r := range strings.ToLower(name) {
		switch {
		case unicode.IsLetter(r), unicode.IsDigit(r):
			b.WriteRune(r)
			lastDash = false
		case !lastDash:
			b.WriteByte('-')
			lastDash = true
		}
	}

	sanitized := strings.Trim(b.String(), "-")
	if sanitized == "" {
		return defaultTestDatabaseName
	}

	return defaultTestDatabaseName + "-" + sanitized
}
