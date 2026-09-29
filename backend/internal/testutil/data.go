package testutil

import (
	"os"
	"path/filepath"
	"runtime"
	"strconv"
	"sync"
	"testing"

	"github.com/spf13/viper"
)

type Config struct {
	Provider ProviderConfig `mapstructure:"provider"`
	Path     PathConfig     `mapstructure:"path"`
	Database DatabaseConfig `mapstructure:"database"`
	Flags    FlagsConfig    `mapstructure:"flags"`
}

type FlagsConfig struct {
	EnableAnilistTests         bool `mapstructure:"enable_anilist_tests"`
	EnableAnilistMutationTests bool `mapstructure:"enable_anilist_mutation_tests"`
	EnableMalTests             bool `mapstructure:"enable_mal_tests"`
	EnableMalMutationTests     bool `mapstructure:"enable_mal_mutation_tests"`
	EnableMediaPlayerTests     bool `mapstructure:"enable_media_player_tests"`
	EnableTorrentClientTests   bool `mapstructure:"enable_torrent_client_tests"`
	EnableTorrentstreamTests   bool `mapstructure:"enable_torrentstream_tests"`
	EnableLiveTests            bool `mapstructure:"enable_live_tests"`
}

type ProviderConfig struct {
	AnilistJwt           string `mapstructure:"anilist_jwt"`
	AnilistUsername      string `mapstructure:"anilist_username"`
	MalJwt               string `mapstructure:"mal_jwt"`
	QbittorrentHost      string `mapstructure:"qbittorrent_host"`
	QbittorrentPort      int    `mapstructure:"qbittorrent_port"`
	QbittorrentUsername  string `mapstructure:"qbittorrent_username"`
	QbittorrentPassword  string `mapstructure:"qbittorrent_password"`
	QbittorrentPath      string `mapstructure:"qbittorrent_path"`
	TransmissionHost     string `mapstructure:"transmission_host"`
	TransmissionPort     int    `mapstructure:"transmission_port"`
	TransmissionPath     string `mapstructure:"transmission_path"`
	TransmissionUsername string `mapstructure:"transmission_username"`
	TransmissionPassword string `mapstructure:"transmission_password"`
	MpcHost              string `mapstructure:"mpc_host"`
	MpcPort              int    `mapstructure:"mpc_port"`
	MpcPath              string `mapstructure:"mpc_path"`
	VlcHost              string `mapstructure:"vlc_host"`
	VlcPort              int    `mapstructure:"vlc_port"`
	VlcPassword          string `mapstructure:"vlc_password"`
	VlcPath              string `mapstructure:"vlc_path"`
	MpvPath              string `mapstructure:"mpv_path"`
	MpvSocket            string `mapstructure:"mpv_socket"`
	IinaPath             string `mapstructure:"iina_path"`
	IinaSocket           string `mapstructure:"iina_socket"`
	TorBoxApiKey         string `mapstructure:"torbox_api_key"`
	RealDebridApiKey     string `mapstructure:"realdebrid_api_key"`
}

type PathConfig struct {
	DataDir         string `mapstructure:"dataDir"`
	SampleVideoPath string `mapstructure:"sampleVideoPath"`
}

type DatabaseConfig struct {
	Name string `mapstructure:"name"`
}

func defaultConfig() *Config {
	return &Config{
		Path:     PathConfig{},
		Database: DatabaseConfig{Name: defaultTestDatabaseName},
		Flags:    FlagsConfig{},
	}
}

// SkipFunc conditionally skips a test based on configuration.
type SkipFunc func(t testing.TB, cfg *Config)

var (
	projectRootVal  string
	projectRootOnce sync.Once
)

// ProjectRoot returns the absolute path to the repository root
// by walking up from this source file until it finds go.mod.
func ProjectRoot() string {
	projectRootOnce.Do(func() {
		_, filename, _, ok := runtime.Caller(0)
		if !ok {
			panic("testutil: runtime.Caller failed")
		}
		dir := filepath.Dir(filename)
		for {
			if _, err := os.Stat(filepath.Join(dir, "go.mod")); err == nil {
				projectRootVal = dir
				return
			}
			parent := filepath.Dir(dir)
			if parent == dir {
				panic("testutil: could not find project root (no go.mod)")
			}
			dir = parent
		}
	})
	return projectRootVal
}

// configDir returns the directory containing the test config file.
// Respects the TEST_CONFIG_PATH env var if set.
func configDir() string {
	if p := os.Getenv("TEST_CONFIG_PATH"); p != "" {
		return p
	}
	return filepath.Join(ProjectRoot(), "test")
}

// DataPath returns the absolute path to a JSON file in test/data.
func DataPath(name string) string {
	return filepath.Join(ProjectRoot(), "test", "data", name+".json")
}

// TestDataPath returns the absolute path to a JSON file in test/testdata.
func TestDataPath(name string) string {
	return filepath.Join(ProjectRoot(), "test", "testdata", name+".json")
}

const (
	SampleVideoPathEnv           = "TEST_SAMPLE_VIDEO_PATH"
	RecordAnilistFixturesEnvName = "SEANIME_TEST_RECORD_ANILIST_FIXTURES"
)

// InitTestProvider loads the test configuration and skips the test
// if any of the provided skip functions decide it should not run.
func InitTestProvider(t testing.TB, flags ...SkipFunc) *Config {
	t.Helper()

	cfg, err := readConfig()
	if err != nil {
		cfg = defaultConfig()
	}

	for _, fn := range flags {
		fn(t, cfg)
	}

	return cfg
}

// LoadConfig loads and returns a fresh test configuration instance.
func LoadConfig(t testing.TB) *Config {
	t.Helper()

	cfg, err := readConfig()
	if err != nil {
		t.Fatalf("testutil: could not load config: %v", err)
	}

	return cfg
}

// MustLoadConfig loads and returns a fresh test configuration instance.
// It panics if the configuration cannot be loaded.
func MustLoadConfig() *Config {
	cfg, err := readConfig()
	if err != nil {
		panic("testutil: could not load config: " + err.Error())
	}

	return cfg
}

func readConfig() (*Config, error) {
	v := viper.New()
	v.SetConfigName("config")
	v.AddConfigPath(configDir())
	if err := v.ReadInConfig(); err != nil {
		return nil, err
	}
	var c Config
	if err := v.Unmarshal(&c); err != nil {
		return nil, err
	}
	return &c, nil
}

func cloneConfig(cfg *Config) *Config {
	if cfg == nil {
		return nil
	}

	return new(*cfg)
}

// RequireSampleVideoPath returns the configured sample media path for external
// playback tests. It respects TEST_SAMPLE_VIDEO_PATH and skips if unset.
func RequireSampleVideoPath(t testing.TB) string {
	t.Helper()

	if path := os.Getenv(SampleVideoPathEnv); path != "" {
		return path
	}

	cfg := LoadConfig(t)
	if cfg.Path.SampleVideoPath == "" {
		t.Skip("media playback tests require path.sampleVideoPath or TEST_SAMPLE_VIDEO_PATH")
	}

	return cfg.Path.SampleVideoPath
}

// ShouldRecordAnilistFixtures reports whether AniList mock helpers may write
// back into repository fixtures during a test run.
func ShouldRecordAnilistFixtures() bool {
	value := os.Getenv(RecordAnilistFixturesEnvName)
	if value == "" {
		return false
	}

	enabled, err := strconv.ParseBool(value)
	if err != nil {
		return false
	}

	return enabled
}

func Live() SkipFunc {
	return func(t testing.TB, cfg *Config) {
		t.Helper()
		if !cfg.Flags.EnableLiveTests {
			t.Skip("live tests disabled; set flags.enable_live_tests to true to enable")
		}
	}
}

func Anilist() SkipFunc {
	return func(t testing.TB, cfg *Config) {
		t.Helper()
		if !cfg.Flags.EnableAnilistTests {
			t.Skip("anilist tests disabled")
		}
	}
}

func AnilistMutation() SkipFunc {
	return func(t testing.TB, cfg *Config) {
		t.Helper()
		if !cfg.Flags.EnableAnilistMutationTests {
			t.Skip("anilist mutation tests disabled")
		}
		if cfg.Provider.AnilistJwt == "" {
			t.Skip("anilist mutation tests require anilist_jwt")
		}
	}
}

func MyAnimeList() SkipFunc {
	return func(t testing.TB, cfg *Config) {
		t.Helper()
		if !cfg.Flags.EnableMalTests {
			t.Skip("mal tests disabled")
		}
	}
}

func MyAnimeListMutation() SkipFunc {
	return func(t testing.TB, cfg *Config) {
		t.Helper()
		if !cfg.Flags.EnableMalMutationTests {
			t.Skip("mal mutation tests disabled")
		}
		if cfg.Provider.MalJwt == "" {
			t.Skip("mal mutation tests require mal_jwt")
		}
	}
}

func MediaPlayer() SkipFunc {
	return func(t testing.TB, cfg *Config) {
		t.Helper()
		if !cfg.Flags.EnableMediaPlayerTests {
			t.Skip("media player tests disabled")
		}
		if cfg.Provider.MpvPath == "" {
			t.Skip("media player tests require mpv_path")
		}
	}
}

func TorrentClient() SkipFunc {
	return func(t testing.TB, cfg *Config) {
		t.Helper()
		if !cfg.Flags.EnableTorrentClientTests {
			t.Skip("torrent client tests disabled")
		}
	}
}

func Torrentstream() SkipFunc {
	return func(t testing.TB, cfg *Config) {
		t.Helper()
		if !cfg.Flags.EnableTorrentstreamTests {
			t.Skip("torrentstream tests disabled")
		}
	}
}
