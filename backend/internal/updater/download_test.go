package updater

import (
	"archive/tar"
	"archive/zip"
	"bytes"
	"compress/gzip"
	"os"
	"path/filepath"
	"seanime/internal/util"
	"strings"
	"testing"

	"github.com/samber/lo"
	"github.com/stretchr/testify/require"
)

func TestUpdater_DownloadLatestRelease(t *testing.T) {
	fixture := newUpdaterTestFixture(t)

	updater := fixture.newUpdater("0.2.0", nil)

	tempDir := t.TempDir()

	// Get the latest release
	release, err := updater.GetLatestRelease("github")
	require.NoError(t, err)

	// Find the asset (zip file)
	asset, ok := lo.Find(release.Assets, func(asset ReleaseAsset) bool {
		return strings.HasSuffix(asset.BrowserDownloadUrl, "Windows_x86_64.zip")
	})
	if !ok {
		t.Fatal("could not find release asset")
	}

	// Download the asset
	folderPath, err := updater.DownloadLatestRelease(asset.BrowserDownloadUrl, tempDir)
	require.NoError(t, err)

	t.Log("Downloaded to:", folderPath)

	// Check if the folder is not empty
	entries, err := os.ReadDir(folderPath)
	if err != nil {
		t.Fatal(err)
	}

	if len(entries) == 0 {
		t.Fatal("folder is empty")
	}

	for _, entry := range entries {
		t.Log(entry.Name())
	}

	// Delete the folder
	if err := os.RemoveAll(folderPath); err != nil {
		t.Fatal(err)
	}

	// Find the asset (.tar.gz file)
	asset2, ok := lo.Find(release.Assets, func(asset ReleaseAsset) bool {
		return strings.HasSuffix(asset.BrowserDownloadUrl, "MacOS_arm64.tar.gz")
	})
	if !ok {
		t.Fatal("could not find release asset")
	}

	// Download the asset
	folderPath2, err := updater.DownloadLatestRelease(asset2.BrowserDownloadUrl, tempDir)
	require.NoError(t, err)

	t.Log("Downloaded to:", folderPath2)

	// Check if the folder is not empty
	entries2, err := os.ReadDir(folderPath2)
	if err != nil {
		t.Fatal(err)
	}

	if len(entries2) == 0 {
		t.Fatal("folder is empty")
	}

	for _, entry := range entries2 {
		t.Log(entry.Name())
	}
}

func TestUpdater_DownloadAssetRejectsInsecureURL(t *testing.T) {
	updater := New("0.2.0", util.NewLogger(), nil)
	updater.LatestRelease = &Release{Version: "3.5.2"}

	_, err := updater.downloadAsset("http://example.com/seanime.zip", t.TempDir())
	require.ErrorIs(t, err, ErrInsecureUpdateURL)
}

func TestUpdater_DecompressZipRejectsArchiveTraversal(t *testing.T) {
	var buf bytes.Buffer
	zw := zip.NewWriter(&buf)
	writer, err := zw.Create("../escape.txt")
	require.NoError(t, err)
	_, err = writer.Write([]byte("pwned"))
	require.NoError(t, err)
	require.NoError(t, zw.Close())

	root := t.TempDir()
	archivePath := filepath.Join(root, "seanime.zip")
	require.NoError(t, os.WriteFile(archivePath, buf.Bytes(), 0o644))

	updater := New("0.2.0", util.NewLogger(), nil)
	updater.LatestRelease = &Release{Version: "3.5.2"}
	_, err = updater.decompressZip(archivePath, "")
	require.ErrorIs(t, err, util.ErrArchivePathTraversal)
	_, statErr := os.Stat(filepath.Join(root, "escape.txt"))
	require.Error(t, statErr)
	require.True(t, os.IsNotExist(statErr))
}

func TestUpdater_DecompressTarGzRejectsArchiveTraversal(t *testing.T) {
	var buf bytes.Buffer
	gzw := gzip.NewWriter(&buf)
	tw := tar.NewWriter(gzw)
	require.NoError(t, tw.WriteHeader(&tar.Header{Name: "../escape.txt", Mode: 0o644, Size: int64(len("pwned"))}))
	_, err := tw.Write([]byte("pwned"))
	require.NoError(t, err)
	require.NoError(t, tw.Close())
	require.NoError(t, gzw.Close())

	root := t.TempDir()
	archivePath := filepath.Join(root, "seanime.tar.gz")
	require.NoError(t, os.WriteFile(archivePath, buf.Bytes(), 0o644))

	updater := New("0.2.0", util.NewLogger(), nil)
	updater.LatestRelease = &Release{Version: "3.5.2"}
	_, err = updater.decompressTarGz(archivePath, "")
	require.ErrorIs(t, err, util.ErrArchivePathTraversal)
	_, statErr := os.Stat(filepath.Join(root, "escape.txt"))
	require.Error(t, statErr)
	require.True(t, os.IsNotExist(statErr))
}
