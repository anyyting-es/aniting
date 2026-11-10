package handlers

import (
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"testing"

	"github.com/stretchr/testify/require"
)

func TestDownloadTorrentFileUsesContentDispositionFilename(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Disposition", `attachment; filename="[SubsPlease] Example - 01.torrent"`)
		_, _ = w.Write([]byte("torrent-data"))
	}))
	defer server.Close()

	dest := t.TempDir()
	require.NoError(t, downloadTorrentFile(server.URL+"/download/12345", dest))

	content, err := os.ReadFile(filepath.Join(dest, "[SubsPlease] Example - 01.torrent"))
	require.NoError(t, err)
	require.Equal(t, "torrent-data", string(content))

	_, err = os.Stat(filepath.Join(dest, "12345"))
	require.ErrorIs(t, err, os.ErrNotExist)
}

func TestDownloadTorrentFileFallsBackToURLFilename(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		_, _ = w.Write([]byte("torrent-data"))
	}))
	defer server.Close()

	dest := t.TempDir()
	require.NoError(t, downloadTorrentFile(server.URL+"/download/%5BGroup%5D%20Example.torrent?token=123", dest))

	content, err := os.ReadFile(filepath.Join(dest, "[Group] Example.torrent"))
	require.NoError(t, err)
	require.Equal(t, "torrent-data", string(content))
}

func TestDownloadTorrentFileAddsTorrentExtensionForTorrentContent(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/x-bittorrent")
		_, _ = w.Write([]byte("torrent-data"))
	}))
	defer server.Close()

	dest := t.TempDir()
	require.NoError(t, downloadTorrentFile(server.URL+"/download/12345", dest))

	content, err := os.ReadFile(filepath.Join(dest, "12345.torrent"))
	require.NoError(t, err)
	require.Equal(t, "torrent-data", string(content))
}

