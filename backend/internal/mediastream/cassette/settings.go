package cassette

// HwAccelProfile holds ffmpeg flags for a hardware backend
type HwAccelProfile struct {
	// Name is the identifier for logging
	Name string `json:"name"`
	// DecodeFlags are placed before -i
	DecodeFlags []string `json:"decodeFlags"`
	// EncodeFlags are placed after -i
	EncodeFlags []string `json:"encodeFlags"`
	// ScaleFilter is a format string for width/height
	ScaleFilter string `json:"scaleFilter"`
	// NoScaleFilter used when scaling is not needed
	NoScaleFilter string `json:"noScaleFilter"`
	// ForcedIDR ensures segment boundaries align with idr frames
	ForcedIDR bool `json:"forcedIdr"`
}

// Settings holds the runtime configuration for a cassette instance
type Settings struct {
	// StreamDir is the directory where segments are written
	StreamDir string
	// HwAccel is the active hardware acceleration profile
	HwAccel HwAccelProfile
	// FfmpegPath is the path to the ffmpeg binary
	FfmpegPath string
	// FfprobePath is the path to the ffprobe binary
	FfprobePath string
}
