package util

import (
	"cmp"
	"os"
	"path/filepath"
	"slices"
	"strings"
)

type LocalSubtitleFile struct {
	Path     string `json:"path"`
	Filename string `json:"filename"`
	Label    string `json:"label"`
	Language string `json:"language"`
	Type     string `json:"type"`
}

var localSubtitleExtensions = map[string]string{
	".ass":  "ass",
	".ssa":  "ssa",
	".srt":  "srt",
	".vtt":  "vtt",
	".ttml": "ttml",
	".stl":  "stl",
	".txt":  "txt",
}

func FindLocalSubtitleFiles(videoPath string) ([]*LocalSubtitleFile, error) {
	if videoPath == "" {
		return nil, nil
	}

	dir := filepath.Dir(videoPath)
	videoFilename := filepath.Base(videoPath)
	videoBase := strings.TrimSuffix(videoFilename, filepath.Ext(videoFilename))
	if videoBase == "" {
		return nil, nil
	}

	entries, err := os.ReadDir(dir)
	if err != nil {
		return nil, err
	}

	ret := make([]*LocalSubtitleFile, 0)
	for _, entry := range entries {
		if entry.IsDir() {
			continue
		}

		filename := entry.Name()
		ext := strings.ToLower(filepath.Ext(filename))
		subtitleType, ok := localSubtitleExtensions[ext]
		if !ok {
			continue
		}

		subtitleBase := strings.TrimSuffix(filename, filepath.Ext(filename))
		suffix, ok := getLocalSubtitleSuffix(videoBase, subtitleBase)
		if !ok {
			continue
		}

		ret = append(ret, &LocalSubtitleFile{
			Path:     filepath.Join(dir, filename),
			Filename: filename,
			Label:    subtitleBase,
			Language: getLocalSubtitleLanguage(suffix),
			Type:     subtitleType,
		})
	}

	slices.SortFunc(ret, func(a, b *LocalSubtitleFile) int {
		return strings.Compare(strings.ToLower(a.Filename), strings.ToLower(b.Filename))
	})

	return ret, nil
}

func getLocalSubtitleSuffix(videoBase string, subtitleBase string) (string, bool) {
	if strings.EqualFold(videoBase, subtitleBase) {
		return "", true
	}

	prefix := videoBase + "."
	if len(subtitleBase) <= len(prefix) || !strings.EqualFold(subtitleBase[:len(prefix)], prefix) {
		return "", false
	}

	return strings.TrimPrefix(subtitleBase[len(videoBase):], "."), true
}

func getLocalSubtitleLanguage(suffix string) string {
	if suffix == "" {
		return "und"
	}

	parts := strings.FieldsFunc(suffix, func(r rune) bool {
		return r == '.' || r == '_' || r == ','
	})
	for _, part := range parts {
		part = strings.TrimSpace(part)
		if part != "" {
			return part
		}
	}

	return cmp.Or(strings.TrimSpace(suffix), "und")
}
