package util

import (
	"archive/zip"
	"bytes"
	"os"
	"path/filepath"
	"testing"

	"github.com/stretchr/testify/require"
)

func writeZipArchive(t testing.TB, entries map[string]string) string {
	t.Helper()

	var buf bytes.Buffer
	zw := zip.NewWriter(&buf)
	for name, body := range entries {
		writer, err := zw.Create(name)
		require.NoError(t, err)
		_, err = writer.Write([]byte(body))
		require.NoError(t, err)
	}
	require.NoError(t, zw.Close())

	archivePath := filepath.Join(t.TempDir(), "archive.zip")
	require.NoError(t, os.WriteFile(archivePath, buf.Bytes(), 0o644))
	return archivePath
}

func TestValidVideoExtension(t *testing.T) {
	tests := []struct {
		ext      string
		expected bool
	}{
		{ext: ".mp4", expected: true},
		{ext: ".avi", expected: true},
		{ext: ".mkv", expected: true},
		{ext: ".mov", expected: true},
		{ext: ".unknown", expected: false},
		{ext: ".MP4", expected: true},
		{ext: ".AVI", expected: true},
		{ext: "", expected: false},
	}

	for _, test := range tests {
		t.Run(test.ext, func(t *testing.T) {
			result := IsValidVideoExtension(test.ext)
			require.Equal(t, test.expected, result)
		})
	}
}

func TestSubdirectory(t *testing.T) {
	tests := []struct {
		parent   string
		child    string
		expected bool
	}{
		{parent: "C:\\parent", child: "C:\\parent\\child", expected: true},
		{parent: "C:\\parent", child: "C:\\parent\\child.txt", expected: true},
		{parent: "C:\\parent", child: "C:/PARENT/child.txt", expected: true},
		{parent: "C:\\parent", child: "C:\\parent\\..\\child", expected: false},
		{parent: "C:\\parent", child: "C:\\parent", expected: false},
	}

	for _, test := range tests {
		t.Run(test.child, func(t *testing.T) {
			result := IsSubdirectory(test.parent, test.child)
			require.Equal(t, test.expected, result)
		})
	}
}

func TestIsFileUnderDir(t *testing.T) {
	tests := []struct {
		parent   string
		child    string
		expected bool
	}{
		{parent: "C:\\parent", child: "C:\\parent\\child", expected: true},
		{parent: "C:\\parent", child: "C:\\parent\\child.txt", expected: true},
		{parent: "C:\\parent", child: "C:/PARENT/child.txt", expected: true},
		{parent: "C:\\parent", child: "C:\\parent\\..\\child", expected: false},
		{parent: "C:\\parent", child: "C:\\parent", expected: false},
	}

	for _, test := range tests {
		t.Run(test.child, func(t *testing.T) {
			result := IsFileUnderDir(test.child, test.parent)
			require.Equal(t, test.expected, result)
		})
	}
}

func TestSameDir(t *testing.T) {
	tests := []struct {
		dir1     string
		dir2     string
		expected bool
	}{
		{dir1: "C:\\dir", dir2: "C:\\dir", expected: true},
		{dir1: "C:\\dir", dir2: "C:\\DIR", expected: true},
		{dir1: "C:\\dir1", dir2: "C:\\dir2", expected: false},
	}

	for _, test := range tests {
		t.Run(test.dir2, func(t *testing.T) {
			result := IsSameDir(test.dir1, test.dir2)
			require.Equal(t, test.expected, result)
		})
	}
}

func TestResolveArchiveEntryPath(t *testing.T) {
	t.Run("allows nested paths inside destination", func(t *testing.T) {
		resolved, err := ResolveArchiveEntryPath("/tmp/extracted", "folder/file.txt")
		require.NoError(t, err)
		require.Equal(t, filepath.Join("/tmp/extracted", "folder", "file.txt"), resolved)
	})

	t.Run("rejects parent traversal", func(t *testing.T) {
		_, err := ResolveArchiveEntryPath("/tmp/extracted", "../escape.txt")
		require.ErrorIs(t, err, ErrArchivePathTraversal)
	})

	t.Run("rejects windows style traversal", func(t *testing.T) {
		_, err := ResolveArchiveEntryPath("/tmp/extracted", `..\\escape.txt`)
		require.ErrorIs(t, err, ErrArchivePathTraversal)
	})
}

func TestUnzipFileRejectsArchiveTraversal(t *testing.T) {
	archivePath := writeZipArchive(t, map[string]string{
		"../escape.txt": "pwned",
	})

	root := t.TempDir()
	dest := filepath.Join(root, "dest")
	err := UnzipFile(archivePath, dest)
	require.ErrorIs(t, err, ErrArchivePathTraversal)
	_, statErr := os.Stat(filepath.Join(root, "escape.txt"))
	require.Error(t, statErr)
	require.True(t, os.IsNotExist(statErr))
}
