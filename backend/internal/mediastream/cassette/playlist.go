package cassette

import (
	"fmt"
	"seanime/internal/mediastream/videofile"
	"strings"
)

// playlist generation

// GenerateMasterPlaylist builds the hls master playlist using the quality ladder
func GenerateMasterPlaylist(info *videofile.MediaInfo, ladder []QualityLadderEntry, token string) string {
	var b strings.Builder
	b.WriteString("#EXTM3U\n")

	if info.Video == nil {
		// just list audio tracks if audio only
		writeAudioTracks(&b, info, token)
		return b.String()
	}

	// The codec advertized for transcoded variants. Original uses the source's actual codec when known.
	transcodedCodec := "avc1.640028" // h264 High L4.0 safe default

	tokenSuffix := ""
	if token != "" {
		tokenSuffix = "?token=" + token
	}

	for _, entry := range ladder {
		b.WriteString("#EXT-X-STREAM-INF:")

		if entry.Quality == Original {
			// use actual source properties
			avg, peak := EffectiveBitrate(Original, info.Video.Bitrate)
			fmt.Fprintf(&b, "AVERAGE-BANDWIDTH=%d,", avg)
			fmt.Fprintf(&b, "BANDWIDTH=%d,", peak)
			fmt.Fprintf(&b, "RESOLUTION=%dx%d,", info.Video.Width, info.Video.Height)
			codec := transcodedCodec
			if entry.OriginalCanTransmux && info.Video.MimeCodec != nil {
				codec = *info.Video.MimeCodec
			}
			fmt.Fprintf(&b, "CODECS=\"%s,mp4a.40.2\",", codec)
		} else {
			// use quality-specific bitrates capped at source
			avg, peak := EffectiveBitrate(entry.Quality, info.Video.Bitrate)
			fmt.Fprintf(&b, "AVERAGE-BANDWIDTH=%d,", avg)
			fmt.Fprintf(&b, "BANDWIDTH=%d,", peak)
			fmt.Fprintf(&b, "RESOLUTION=%dx%d,", entry.Width, entry.Height)
			fmt.Fprintf(&b, "CODECS=\"%s,mp4a.40.2\",", transcodedCodec)
		}

		b.WriteString("AUDIO=\"audio\",")
		b.WriteString("CLOSED-CAPTIONS=NONE\n")
		fmt.Fprintf(&b, "./%s/index.m3u8%s\n", entry.Quality, tokenSuffix)
	}

	writeAudioTracks(&b, info, token)
	return b.String()
}

// writeAudioTracks appends audio track entries to the playlist
func writeAudioTracks(b *strings.Builder, info *videofile.MediaInfo, token string) {
	tokenSuffix := ""
	if token != "" {
		tokenSuffix = "?token=" + token
	}
	for _, audio := range info.Audios {
		b.WriteString("#EXT-X-MEDIA:TYPE=AUDIO,")
		b.WriteString("GROUP-ID=\"audio\",")
		if audio.Language != nil {
			fmt.Fprintf(b, "LANGUAGE=\"%s\",", *audio.Language)
		}
		switch {
		case audio.Title != nil:
			fmt.Fprintf(b, "NAME=\"%s\",", *audio.Title)
		case audio.Language != nil:
			fmt.Fprintf(b, "NAME=\"%s\",", *audio.Language)
		default:
			fmt.Fprintf(b, "NAME=\"Audio %d\",", audio.Index)
		}
		if audio.IsDefault {
			b.WriteString("DEFAULT=YES,")
		}

		ch := audio.Channels
		if ch == 0 {
			ch = 2
		}
		fmt.Fprintf(b, "CHANNELS=\"%d\",", ch)
		fmt.Fprintf(b, "URI=\"./audio/%d/index.m3u8%s\"\n", audio.Index, tokenSuffix)
	}
}

// GenerateVariantPlaylist builds a variant playlist listing every segment
func GenerateVariantPlaylist(ki *KeyframeIndex, duration float64, token string) string {
	tokenSuffix := ""
	if token != "" {
		tokenSuffix = "?token=" + token
	}
	var b strings.Builder

	b.WriteString("#EXTM3U\n")
	b.WriteString("#EXT-X-VERSION:6\n")
	b.WriteString("#EXT-X-PLAYLIST-TYPE:EVENT\n")
	b.WriteString("#EXT-X-START:TIME-OFFSET=0\n")
	b.WriteString("#EXT-X-TARGETDURATION:4\n")
	b.WriteString("#EXT-X-MEDIA-SEQUENCE:0\n")
	b.WriteString("#EXT-X-INDEPENDENT-SEGMENTS\n")

	length, isDone := ki.Length()
	for seg := int32(0); seg < length-1; seg++ {
		fmt.Fprintf(&b, "#EXTINF:%.6f\n", ki.Get(seg+1)-ki.Get(seg))
		fmt.Fprintf(&b, "segment-%d.ts%s\n", seg, tokenSuffix)
	}

	// Final segment, include only when extraction is complete
	if isDone && length > 0 {
		fmt.Fprintf(&b, "#EXTINF:%.6f\n", duration-ki.Get(length-1))
		fmt.Fprintf(&b, "segment-%d.ts%s\n", length-1, tokenSuffix)
		b.WriteString("#EXT-X-ENDLIST")
	}

	return b.String()
}
