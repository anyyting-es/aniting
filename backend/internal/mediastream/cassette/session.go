package cassette

import (
	"context"
	"fmt"
	"os"
	"path/filepath"
	"seanime/internal/mediastream/videofile"
	"sync"

	"github.com/rs/zerolog"
)

// Session represents a per-file transcode session
type Session struct {
	// ready is decremented once keyframes load
	ready sync.WaitGroup
	// err is set if initialization fails
	err error

	Path      string
	Out       string
	Keyframes *KeyframeIndex
	Info      *videofile.MediaInfo
	Ladder    []QualityLadderEntry

	// videos and audios are created lazily
	videosMu sync.Mutex
	videos   map[Quality]*Pipeline

	audiosMu sync.Mutex
	audios   map[int32]*Pipeline

	settings *Settings
	governor *Governor
	logger   *zerolog.Logger
}

// NewSession creates a transcode session and starts keyframe extraction
func NewSession(
	path, hash string,
	info *videofile.MediaInfo,
	settings *Settings,
	governor *Governor,
	logger *zerolog.Logger,
) *Session {
	s := &Session{
		Path:     path,
		Out:      filepath.Join(settings.StreamDir, hash),
		videos:   make(map[Quality]*Pipeline),
		audios:   make(map[int32]*Pipeline),
		Info:     info,
		Ladder:   BuildQualityLadder(info),
		settings: settings,
		governor: governor,
		logger:   logger,
	}

	s.ready.Add(1)
	go func() {
		defer s.ready.Done()
		s.Keyframes = getOrExtractKeyframes(path, hash, settings, logger)
	}()

	if len(s.Ladder) > 0 {
		logger.Debug().
			Int("tiers", len(s.Ladder)).
			Bool("canTransmux", s.Ladder[0].OriginalCanTransmux).
			Msg("cassette: quality ladder built")
	}

	return s
}

// WaitReady blocks until the keyframe index is ready
func (s *Session) WaitReady() error {
	s.ready.Wait()
	return s.err
}

// master / index / segment accessors

// GetMaster returns the hls master playlist
func (s *Session) GetMaster(token string) string {
	return GenerateMasterPlaylist(s.Info, s.Ladder, token)
}

// GetVideoIndex returns the hls variant playlist for a quality
func (s *Session) GetVideoIndex(q Quality, token string) (string, error) {
	p := s.getVideoPipeline(q)
	return p.GetIndex(token)
}

// GetVideoSegment returns the path to a video segment, blocking until ready
func (s *Session) GetVideoSegment(ctx context.Context, q Quality, seg int32) (string, error) {
	// The timeout is bounded by the pipeline constraints, but the request controls early cancellation.
	type result struct {
		path string
		err  error
	}
	ch := make(chan result, 1)

	go func() {
		p := s.getVideoPipeline(q)
		path, err := p.GetSegment(ctx, seg)
		ch <- result{path, err}
	}()

	select {
	case r := <-ch:
		return r.path, r.err
	case <-ctx.Done():
		return "", fmt.Errorf("cassette: context canceled waiting for video segment %d (%s)", seg, q)
	}
}

// GetAudioIndex returns the hls variant playlist for an audio track
func (s *Session) GetAudioIndex(audio int32, token string) (string, error) {
	p := s.getAudioPipeline(audio)
	return p.GetIndex(token)
}

// GetAudioSegment returns the path to an audio segment
func (s *Session) GetAudioSegment(ctx context.Context, audio, seg int32) (string, error) {
	p := s.getAudioPipeline(audio)
	return p.GetSegment(ctx, seg)
}

// video pipeline factory

func (s *Session) getVideoPipeline(q Quality) *Pipeline {
	s.videosMu.Lock()
	defer s.videosMu.Unlock()

	if p, ok := s.videos[q]; ok {
		return p
	}

	s.logger.Trace().Str("file", filepath.Base(s.Path)).Str("quality", string(q)).
		Msg("cassette: creating video pipeline")

	// Check if this quality can transmux.
	canTransmux := false
	if q == Original {
		for _, entry := range s.Ladder {
			if entry.Quality == Original {
				canTransmux = entry.OriginalCanTransmux
				break
			}
		}
	}

	buildArgs := func(segmentTimes string) []string {
		args := []string{"-map", "0:V:0"}

		if canTransmux {
			// no encode, just copy.
			args = append(args, "-c:v", "copy")
			return args
		}

		if q == Original {
			// Needs transcode even for original quality (e.g. HEVC).
			args = append(args, s.settings.HwAccel.EncodeFlags...)

			avgBitrate, maxBitrate := EffectiveBitrate(Original, s.Info.Video.Bitrate)
			if avgBitrate == 0 {
				avgBitrate = 5_000_000
				maxBitrate = 8_000_000
			}

			width := closestEven(int32(s.Info.Video.Width))
			args = append(args,
				"-vf", BuildVideoFilter(&s.settings.HwAccel, s.Info.Video, width, int32(s.Info.Video.Height)),
				"-bufsize", fmt.Sprint(maxBitrate*5),
				"-b:v", fmt.Sprint(avgBitrate),
				"-maxrate", fmt.Sprint(maxBitrate),
			)

			if s.settings.HwAccel.ForcedIDR {
				args = append(args, "-forced-idr", "1")
			}
			args = append(args,
				"-force_key_frames", segmentTimes,
				"-strict", "-2",
			)
			return args
		}

		// Downscale transcode.
		args = append(args, s.settings.HwAccel.EncodeFlags...)

		width := closestEven(int32(
			float64(q.Height()) / float64(s.Info.Video.Height) * float64(s.Info.Video.Width),
		))
		args = append(args,
			"-vf", BuildVideoFilter(&s.settings.HwAccel, s.Info.Video, width, int32(q.Height())),
			// "-vf", fmt.Sprintf(s.settings.HwAccel.ScaleFilter, width, q.Height()),
			"-bufsize", fmt.Sprint(q.MaxBitrate()*5),
			"-b:v", fmt.Sprint(q.AverageBitrate()),
			"-maxrate", fmt.Sprint(q.MaxBitrate()),
		)
		if s.settings.HwAccel.ForcedIDR {
			args = append(args, "-forced-idr", "1")
		}
		args = append(args,
			"-force_key_frames", segmentTimes,
			"-strict", "-2",
		)
		return args
	}

	outFmt := func(eid int) string {
		return filepath.Join(s.Out, fmt.Sprintf("segment-%s-%d-%%d.ts", q, eid))
	}

	label := fmt.Sprintf("video (%s)", q)
	if canTransmux {
		label = "video (original/transmux)"
	}

	p := NewPipeline(PipelineConfig{
		Kind:       VideoKind,
		Label:      label,
		Session:    s,
		Settings:   s.settings,
		Governor:   s.governor,
		Logger:     s.logger,
		BuildArgs:  buildArgs,
		OutPathFmt: outFmt,
	})
	s.videos[q] = p
	return p
}

// audio pipeline factory

// getAudioPipeline creates or retrieves an audio pipeline.
func (s *Session) getAudioPipeline(idx int32) *Pipeline {
	s.audiosMu.Lock()
	defer s.audiosMu.Unlock()

	if p, ok := s.audios[idx]; ok {
		return p
	}

	s.logger.Trace().Str("file", filepath.Base(s.Path)).Int32("audio", idx).
		Msg("cassette: creating audio pipeline")

	// Get source audio info.
	var srcAudio *videofile.Audio
	for i := range s.Info.Audios {
		if int32(s.Info.Audios[i].Index) == idx {
			srcAudio = &s.Info.Audios[i]
			break
		}
	}

	decision := AudioTranscodeDecision{
		Codec:    "aac",
		Bitrate:  "128k",
		Channels: "2",
	}
	if srcAudio != nil {
		decision = DecideAudioTranscode(srcAudio)
	}

	if decision.Copy {
		s.logger.Debug().Int32("audio", idx).Str("codec", "copy").
			Msg("cassette: audio is HLS-compatible, transmuxing (no re-encode)")
	} else {
		s.logger.Debug().Int32("audio", idx).
			Str("codec", decision.Codec).
			Str("bitrate", decision.Bitrate).
			Str("channels", decision.Channels).
			Msg("cassette: audio needs re-encode")
	}

	buildArgs := func(_ string) []string {
		args := []string{
			"-map", fmt.Sprintf("0:a:%d", idx),
			"-c:a", decision.Codec,
		}
		if !decision.Copy {
			args = append(args, "-ac", decision.Channels)
			if decision.Bitrate != "" {
				args = append(args, "-b:a", decision.Bitrate)
			}
		}
		return args
	}

	outFmt := func(eid int) string {
		return filepath.Join(s.Out, fmt.Sprintf("segment-a%d-%d-%%d.ts", idx, eid))
	}

	p := NewPipeline(PipelineConfig{
		Kind:       AudioKind,
		Label:      fmt.Sprintf("audio %d", idx),
		Session:    s,
		Settings:   s.settings,
		Governor:   s.governor,
		Logger:     s.logger,
		BuildArgs:  buildArgs,
		OutPathFmt: outFmt,
	})
	s.audios[idx] = p
	return p
}

// lifecycle

// Kill stops all running encode pipelines
func (s *Session) Kill() {
	s.videosMu.Lock()
	for _, p := range s.videos {
		p.Kill()
	}
	s.videosMu.Unlock()

	s.audiosMu.Lock()
	for _, p := range s.audios {
		p.Kill()
	}
	s.audiosMu.Unlock()
}

// Destroy stops everything and removes output directory
func (s *Session) Destroy() {
	s.logger.Debug().Str("path", s.Path).Msg("cassette: destroying session")
	s.Kill()
	_ = os.RemoveAll(s.Out)
}
