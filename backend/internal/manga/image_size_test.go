package manga

import (
	"bytes"
	"image"
	"image/color"
	"image/png"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/stretchr/testify/require"
)

func newTestPNG(t *testing.T, width, height int) []byte {
	t.Helper()

	var buf bytes.Buffer
	img := image.NewRGBA(image.Rect(0, 0, width, height))
	img.Set(0, 0, color.RGBA{R: 255, G: 128, B: 64, A: 255})
	require.NoError(t, png.Encode(&buf, img))

	return buf.Bytes()
}

func TestGetImageNaturalSize(t *testing.T) {
	imageData := newTestPNG(t, 23, 17)
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "image/png")
		_, _ = w.Write(imageData)
	}))
	defer server.Close()

	width, height, err := getImageNaturalSize(server.URL)
	require.NoError(t, err)
	require.Equal(t, 23, width)
	require.Equal(t, 17, height)
}

func TestGetImageNaturalSizeB(t *testing.T) {
	width, height, err := getImageNaturalSizeB(newTestPNG(t, 31, 19))
	require.NoError(t, err)
	require.Equal(t, 31, width)
	require.Equal(t, 19, height)
}

func TestGetImageNaturalSizeBInvalidData(t *testing.T) {
	width, height, err := getImageNaturalSizeB([]byte("not an image"))
	require.Error(t, err)
	require.Zero(t, width)
	require.Zero(t, height)
}
