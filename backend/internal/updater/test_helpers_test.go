package updater

import (
	"archive/tar"
	"archive/zip"
	"bytes"
	"compress/gzip"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"seanime/internal/events"
	"seanime/internal/util"
	"strings"
	"testing"
)

type updaterTestFixture struct {
	server     *httptest.Server
	release    *Release
	deadAPIURL string
}

func newUpdaterTestFixture(t *testing.T) *updaterTestFixture {
	t.Helper()

	zipArchive := mustCreateZipArchive(t)
	tarGzArchive := mustCreateTarGzArchive(t)

	mux := http.NewServeMux()
	server := httptest.NewTLSServer(mux)

	release := &Release{
		Url:         server.URL + "/release/v3.5.2",
		HtmlUrl:     server.URL + "/release/v3.5.2/html",
		NodeId:      "release-node",
		TagName:     "v3.5.2",
		Name:        "v3.5.2",
		Body:        "Test release",
		PublishedAt: "2026-03-03T14:36:02Z",
		Released:    true,
		Version:     "3.5.2",
		Assets: []ReleaseAsset{
			{
				Url:                server.URL + "/assets/seanime-3.5.2_Windows_x86_64.zip",
				Id:                 1,
				NodeId:             "asset-zip",
				Name:               "seanime-3.5.2_Windows_x86_64.zip",
				ContentType:        "application/zip",
				Uploaded:           true,
				Size:               int64(len(zipArchive)),
				BrowserDownloadUrl: server.URL + "/assets/seanime-3.5.2_Windows_x86_64.zip",
			},
			{
				Url:                server.URL + "/assets/seanime-3.5.2_MacOS_arm64.tar.gz",
				Id:                 2,
				NodeId:             "asset-tar",
				Name:               "seanime-3.5.2_MacOS_arm64.tar.gz",
				ContentType:        "application/gzip",
				Uploaded:           true,
				Size:               int64(len(tarGzArchive)),
				BrowserDownloadUrl: server.URL + "/assets/seanime-3.5.2_MacOS_arm64.tar.gz",
			},
		},
	}

	mux.HandleFunc("/api/release", func(w http.ResponseWriter, r *http.Request) {
		writeTestJSON(t, w, DocsResponse{Release: *release})
	})
	mux.HandleFunc("/api/updates/stable/stable_server.json", func(w http.ResponseWriter, r *http.Request) {
		writeTestJSON(t, w, DocsResponse{Release: *release})
	})
	mux.HandleFunc("/api/updates/nightly/nightly_server.json", func(w http.ResponseWriter, r *http.Request) {
		writeTestJSON(t, w, DocsResponse{Release: *release})
	})
	mux.HandleFunc("/api/github-status", func(w http.ResponseWriter, r *http.Request) {
		writeTestJSON(t, w, map[string]string{"status": "up"})
	})
	mux.HandleFunc("/api/404", func(w http.ResponseWriter, r *http.Request) {
		http.NotFound(w, r)
	})
	mux.HandleFunc("/github/releases/latest", func(w http.ResponseWriter, r *http.Request) {
		writeTestJSON(t, w, map[string]any{
			"url":          release.Url,
			"html_url":     release.HtmlUrl,
			"node_id":      release.NodeId,
			"tag_name":     release.TagName,
			"name":         release.Name,
			"draft":        false,
			"prerelease":   false,
			"published_at": release.PublishedAt,
			"body":         release.Body,
			"assets": []map[string]any{
				{
					"url":                  release.Assets[0].Url,
					"id":                   release.Assets[0].Id,
					"node_id":              release.Assets[0].NodeId,
					"name":                 release.Assets[0].Name,
					"content_type":         release.Assets[0].ContentType,
					"state":                "uploaded",
					"size":                 release.Assets[0].Size,
					"browser_download_url": release.Assets[0].BrowserDownloadUrl,
				},
				{
					"url":                  release.Assets[1].Url,
					"id":                   release.Assets[1].Id,
					"node_id":              release.Assets[1].NodeId,
					"name":                 release.Assets[1].Name,
					"content_type":         release.Assets[1].ContentType,
					"state":                "uploaded",
					"size":                 release.Assets[1].Size,
					"browser_download_url": release.Assets[1].BrowserDownloadUrl,
				},
			},
		})
	})
	mux.HandleFunc("/assets/seanime-3.5.2_Windows_x86_64.zip", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/zip")
		_, _ = w.Write(zipArchive)
	})
	mux.HandleFunc("/assets/seanime-3.5.2_MacOS_arm64.tar.gz", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/gzip")
		_, _ = w.Write(tarGzArchive)
	})

	fixture := &updaterTestFixture{
		server:     server,
		release:    release,
		deadAPIURL: server.URL + "/api/404",
	}
	fixture.apply(t)
	t.Cleanup(server.Close)

	return fixture
}

func (f *updaterTestFixture) newUpdater(currVersion string, wsEventManager events.WSEventManagerInterface) *Updater {
	updater := New(currVersion, util.NewLogger(), wsEventManager)
	updater.client = f.server.Client()
	return updater
}

func (f *updaterTestFixture) apply(t *testing.T) {
	t.Helper()

	oldWebsiteURL := websiteUrl
	oldFallbackGithubURL := fallbackGithubUrl
	oldGithubCheckURL := githubCheckUrl
	oldSeanimeStableURL := seanimeStableUrl
	oldSeanimeNightlyURL := seanimeNightlyUrl

	websiteUrl = f.server.URL + "/api/release"
	fallbackGithubUrl = f.server.URL + "/github/releases/latest"
	githubCheckUrl = f.server.URL + "/api/github-status"
	seanimeStableUrl = f.server.URL + "/api/updates/stable/stable_server.json"
	seanimeNightlyUrl = f.server.URL + "/api/updates/nightly/nightly_server.json"

	t.Cleanup(func() {
		websiteUrl = oldWebsiteURL
		fallbackGithubUrl = oldFallbackGithubURL
		githubCheckUrl = oldGithubCheckURL
		seanimeStableUrl = oldSeanimeStableURL
		seanimeNightlyUrl = oldSeanimeNightlyURL
	})
}

func writeTestJSON(t *testing.T, w http.ResponseWriter, value any) {
	t.Helper()

	w.Header().Set("Content-Type", "application/json")
	if err := json.NewEncoder(w).Encode(value); err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
	}
}

func mustCreateZipArchive(t *testing.T) []byte {
	t.Helper()

	var buf bytes.Buffer
	zw := zip.NewWriter(&buf)

	files := map[string]string{
		"bin/seanime.exe": "windows-binary",
		"README.txt":      "release notes",
	}

	for name, body := range files {
		writer, err := zw.Create(name)
		if err != nil {
			t.Fatalf("create zip entry %s: %v", name, err)
		}
		if _, err := writer.Write([]byte(body)); err != nil {
			t.Fatalf("write zip entry %s: %v", name, err)
		}
	}

	if err := zw.Close(); err != nil {
		t.Fatalf("close zip archive: %v", err)
	}

	return buf.Bytes()
}

func mustCreateTarGzArchive(t *testing.T) []byte {
	t.Helper()

	var buf bytes.Buffer
	gzw := gzip.NewWriter(&buf)
	tw := tar.NewWriter(gzw)

	files := map[string]string{
		"bin/seanime": "macos-binary",
		"README.txt":  "release notes",
	}

	for name, body := range files {
		header := &tar.Header{
			Name: name,
			Mode: 0o644,
			Size: int64(len(body)),
		}
		if strings.HasPrefix(name, "bin/") {
			header.Mode = 0o755
		}
		if err := tw.WriteHeader(header); err != nil {
			t.Fatalf("write tar header %s: %v", name, err)
		}
		if _, err := tw.Write([]byte(body)); err != nil {
			t.Fatalf("write tar body %s: %v", name, err)
		}
	}

	if err := tw.Close(); err != nil {
		t.Fatalf("close tar writer: %v", err)
	}
	if err := gzw.Close(); err != nil {
		t.Fatalf("close gzip writer: %v", err)
	}

	return buf.Bytes()
}
