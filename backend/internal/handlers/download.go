package handlers

import (
	"errors"
	"fmt"
	"io"
	"mime"
	"net/http"
	urlpkg "net/url"
	"os"
	"path"
	"path/filepath"
	"aniting/internal/api/anilist"
	"aniting/internal/util"
	"strings"
	"sync"
	"time"

	"github.com/labstack/echo/v4"
)

type downloadGrantChallenge struct {
	code      string
	clientId  string
	createdAt time.Time
}

var (
	downloadGrantChallenges   = make(map[string]*downloadGrantChallenge) // keyed by challenge ID
	downloadGrantChallengesMu sync.Mutex
	downloadGrantChallengeTTL = 2 * time.Minute
)

// HandleDownloadTorrentFile
//
//	@summary downloads torrent files to the destination folder
//	@route /api/v1/download-torrent-file [POST]
//	@returns bool
func (h *Handler) HandleDownloadTorrentFile(c echo.Context) error {

	type body struct {
		DownloadUrls []string           `json:"download_urls"`
		Destination  string             `json:"destination"`
		Media        *anilist.BaseAnime `json:"media"`
		ClientId     string             `json:"clientId"`
	}

	var b body
	if err := c.Bind(&b); err != nil {
		return h.RespondWithError(c, err)
	}

	if err := h.guardStrictLocalOnlyAction(c); err != nil {
		return err
	}

	if b.Destination == "" {
		return h.RespondWithError(c, errors.New("destination not found"))
	}

	if !filepath.IsAbs(b.Destination) {
		return h.RespondWithError(c, errors.New("destination path must be absolute"))
	}

	if err := h.guardStrictFilesystemPath(c, b.Destination); err != nil {
		return err
	}

	contextClientId := getContextClientId(c)
	if contextClientId == "" {
		return h.RespondWithError(c, fmt.Errorf("client session not found"))
	}

	if !strings.HasPrefix(b.ClientId, "CODE:") {
		challengeID := util.RandomStringWithAlphabet(16, "abcdefghijklmnopqrstuvwxyz0123456789")
		randomCode := util.RandomStringWithAlphabet(32, "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789")

		downloadGrantChallengesMu.Lock()
		for k, ch := range downloadGrantChallenges {
			if time.Since(ch.createdAt) > downloadGrantChallengeTTL {
				delete(downloadGrantChallenges, k)
			}
		}
		downloadGrantChallenges[challengeID] = &downloadGrantChallenge{
			code:      randomCode,
			clientId:  contextClientId,
			createdAt: time.Now(),
		}
		downloadGrantChallengesMu.Unlock()

		h.App.WSEventManager.SendEventTo(contextClientId, "download-torrent-file-permission-check", challengeID+":"+randomCode)
		return h.RespondWithData(c, false)
	}

	payload := strings.TrimPrefix(b.ClientId, "CODE:")
	parts := strings.SplitN(payload, ":", 2)
	if len(parts) != 2 {
		return h.RespondWithError(c, fmt.Errorf("invalid verification format"))
	}
	challengeID := parts[0]
	submittedCode := parts[1]

	downloadGrantChallengesMu.Lock()
	challenge, exists := downloadGrantChallenges[challengeID]
	if exists {
		delete(downloadGrantChallenges, challengeID)
	}
	downloadGrantChallengesMu.Unlock()

	if !exists {
		return h.RespondWithError(c, fmt.Errorf("no pending verification found"))
	}

	if time.Since(challenge.createdAt) > downloadGrantChallengeTTL {
		return h.RespondWithError(c, fmt.Errorf("verification code expired"))
	}

	if challenge.code != submittedCode {
		return h.RespondWithError(c, fmt.Errorf("invalid verification code"))
	}

	if challenge.clientId != contextClientId {
		return h.RespondWithError(c, fmt.Errorf("verification code does not belong to this client session"))
	}

	errs := make([]error, 0)
	for _, url := range b.DownloadUrls {
		err := downloadTorrentFile(url, b.Destination)
		if err != nil {
			errs = append(errs, err)
		}
	}

	if len(errs) == 1 {
		return h.RespondWithError(c, errs[0])
	} else if len(errs) > 1 {
		return h.RespondWithError(c, errors.New("failed to download multiple files"))
	}

	return h.RespondWithData(c, true)
}

func downloadTorrentFile(url string, dest string) (err error) {

	defer util.HandlePanicInModuleWithError("handlers/download/downloadTorrentFile", &err)

	// Get the data
	resp, err := http.Get(url)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	// Check if the request was successful (status code 200)
	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("failed to download file, %s", resp.Status)
	}

	fileName := getTorrentFileName(resp, url)
	if fileName == "" {
		return fmt.Errorf("failed to determine file name")
	}
	filePath := filepath.Join(dest, fileName)

	// Create the destination folder if it doesn't exist
	err = os.MkdirAll(dest, 0755)
	if err != nil {
		return err
	}

	// Create the file
	out, err := os.Create(filePath)
	if err != nil {
		return err
	}
	defer out.Close()

	// Write the body to file
	_, err = io.Copy(out, resp.Body)
	if err != nil {
		return err
	}

	return nil
}

func getTorrentFileName(resp *http.Response, downloadURL string) string {
	if resp != nil {
		contentDisposition := resp.Header.Get("Content-Disposition")
		if _, params, err := mime.ParseMediaType(contentDisposition); err == nil {
			if fileName := cleanTorrentFileName(params["filename"]); fileName != "" {
				return fileName
			}
		}
	}

	if parsedURL, err := urlpkg.Parse(downloadURL); err == nil {
		fileName := path.Base(parsedURL.Path)
		if unescaped, err := urlpkg.PathUnescape(fileName); err == nil {
			fileName = unescaped
		}
		if fileName := cleanTorrentFileName(fileName); fileName != "" && resp != nil {
			contentType := resp.Header.Get("Content-Type")
			mediaType, _, err := mime.ParseMediaType(contentType)
			isTorrentType := err == nil && mediaType == "application/x-bittorrent"
			if filepath.Ext(fileName) == "" && isTorrentType {
				return fileName + ".torrent"
			}
			return fileName
		}
	}

	return cleanTorrentFileName(downloadURL)
}

func cleanTorrentFileName(f string) string {
	f = strings.TrimSpace(f)
	f = strings.ReplaceAll(f, "\\", "/")
	f = path.Base(f)
	if f == "." || f == ".." || f == "/" {
		return ""
	}
	return f
}
