package torrent

import (
	"fmt"
	hibiketorrent "seanime/internal/extension/hibike/torrent"
	"strings"
)

func (r *Repository) ResolveMagnetLink(t *hibiketorrent.AnimeTorrent) (string, error) {
	if t == nil {
		return "", fmt.Errorf("torrent not provided")
	}

	if strings.HasPrefix(strings.ToLower(t.MagnetLink), "magnet:?") {
		return t.MagnetLink, nil
	}

	if strings.HasPrefix(strings.ToLower(t.Link), "magnet:?") {
		return t.Link, nil
	}

	providerExtension, ok := r.GetAnimeProviderExtension(t.Provider)
	if !ok {
		return "", fmt.Errorf("provider extension not found")
	}

	magnet, err := providerExtension.GetProvider().GetTorrentMagnetLink(t)
	if err != nil {
		return "", err
	}

	if magnet == "" {
		return "", fmt.Errorf("magnet link not found")
	}

	return magnet, nil
}
