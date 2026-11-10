package trailerresolver

import (
	"context"
	"errors"
	"testing"
	"time"
)

func TestExtractVideoID(t *testing.T) {
	valid := map[string]string{
		"aqz-KE-bpKQ":                                        "aqz-KE-bpKQ",
		"https://www.youtube.com/watch?v=aqz-KE-bpKQ":        "aqz-KE-bpKQ",
		"https://youtu.be/aqz-KE-bpKQ":                       "aqz-KE-bpKQ",
		"https://www.youtube.com/embed/aqz-KE-bpKQ":          "aqz-KE-bpKQ",
		"https://www.youtube.com/shorts/aqz-KE-bpKQ?feature=x": "aqz-KE-bpKQ",
		"https://www.youtube.com/watch?list=PL1&v=aqz-KE-bpKQ&t=30": "aqz-KE-bpKQ",
	}
	for input, want := range valid {
		got, err := ExtractVideoID(input)
		if err != nil {
			t.Fatalf("%q: unexpected error %v", input, err)
		}
		if got != want {
			t.Fatalf("%q: got %q, want %q", input, got, want)
		}
	}

	invalid := []string{
		"",
		"   ",
		"https://vimeo.com/12345",
		"https://www.youtube.com/watch?v=short",
		"aqz-KE-bpKQextra",
	}
	for _, input := range invalid {
		if _, err := ExtractVideoID(input); !errors.Is(err, ErrInvalidVideoID) {
			t.Fatalf("%q: expected ErrInvalidVideoID, got %v", input, err)
		}
	}
}

func TestPickStreams(t *testing.T) {
	dump := &ytDump{
		Title:    "Trailer",
		Uploader: "Studio",
		Duration: 95,
		Formats: []ytFormat{
			// muxed 360p + a better muxed 720p webm (must be ignored: ext).
			{FormatID: "18", URL: "muxed360", VCodec: "avc1", ACodec: "mp4a", Ext: "mp4", Height: 360},
			{FormatID: "43", URL: "muxed720webm", VCodec: "vp9", ACodec: "opus", Ext: "webm", Height: 720},
			// video-only candidates.
			{FormatID: "137", URL: "video1080", VCodec: "avc1", ACodec: "none", Ext: "mp4", Height: 1080},
			{FormatID: "248", URL: "video1080vp9", VCodec: "vp9", ACodec: "none", Ext: "webm", Height: 1080},
			{FormatID: "313", URL: "video2160", VCodec: "vp9", ACodec: "none", Ext: "mp4", Height: 2160},
			// audio-only candidates.
			{FormatID: "140", URL: "audio128", VCodec: "none", ACodec: "mp4a", Ext: "m4a", ABR: 128},
			{FormatID: "258", URL: "audio387", VCodec: "none", ACodec: "mp4a", Ext: "m4a", ABR: 387},
			// no url: must be skipped.
			{FormatID: "999", URL: "", VCodec: "avc1", ACodec: "none", Ext: "mp4", Height: 4320},
		},
	}

	got := pickStreams("aqz-KE-bpKQ", dump)

	if got.VideoID != "aqz-KE-bpKQ" || got.Title != "Trailer" || got.Duration != 95 {
		t.Fatalf("metadata not carried over: %+v", got)
	}
	if got.MuxedURL != "muxed360" {
		t.Fatalf("muxed: got %q", got.MuxedURL)
	}
	if got.VideoURL != "video1080" || got.VideoHeight != 1080 {
		t.Fatalf("video: got %q @%d", got.VideoURL, got.VideoHeight)
	}
	if got.AudioURL != "audio387" {
		t.Fatalf("audio: got %q", got.AudioURL)
	}
	if got.ExpiresAt.Before(time.Now()) {
		t.Fatalf("expiry must be in the future, got %v", got.ExpiresAt)
	}
}

func TestPickStreamsPrefersMuxedWhenNoSplitTracks(t *testing.T) {
	dump := &ytDump{
		Formats: []ytFormat{
			{FormatID: "18", URL: "muxed360", VCodec: "avc1", ACodec: "mp4a", Ext: "mp4", Height: 360},
		},
	}
	got := pickStreams("id", dump)
	if got.MuxedURL == "" {
		t.Fatal("expected a muxed URL")
	}
	if got.VideoURL != "" || got.AudioURL != "" {
		t.Fatal("expected no split tracks")
	}
}

func TestResolveRejectsInvalidID(t *testing.T) {
	r := &Resolver{}
	if _, err := r.Resolve(context.Background(), "nope"); !errors.Is(err, ErrInvalidVideoID) {
		t.Fatalf("expected ErrInvalidVideoID, got %v", err)
	}
}

func TestResolveReportsUnavailableWithoutBinary(t *testing.T) {
	t.Setenv("ANITING_YTDLP", "")
	r := &Resolver{BinaryPath: ""}
	// Only meaningful when yt-dlp is absent from PATH; skip otherwise.
	if _, err := r.binary(); err == nil {
		t.Skip("yt-dlp is installed on this host")
	}
	if _, err := r.Resolve(context.Background(), "aqz-KE-bpKQ"); !errors.Is(err, ErrUnavailable) {
		t.Fatalf("expected ErrUnavailable, got %v", err)
	}
}
