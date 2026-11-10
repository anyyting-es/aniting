package handlers

import (
	"errors"

	"github.com/labstack/echo/v4"

	"aniting/internal/trailerresolver"
)

// HandleResolveTrailer
//
//	@summary resolves a YouTube trailer into directly playable media URLs.
//	@desc accepts ?id=<11-char id> or ?url=<any youtube url>. Results are cached
//	@desc for an hour, so only the first call pays the yt-dlp extraction cost.
//	@route /api/v1/trailer/resolve [GET]
//	@returns trailerresolver.Streams
func (h *Handler) HandleResolveTrailer(c echo.Context) error {
	ref := c.QueryParam("id")
	if ref == "" {
		ref = c.QueryParam("url")
	}
	if ref == "" {
		return h.RespondWithError(c, errors.New("missing id or url parameter"))
	}

	streams, err := trailerresolver.Default().Resolve(c.Request().Context(), ref)
	if err != nil {
		if errors.Is(err, trailerresolver.ErrInvalidVideoID) {
			return h.RespondWithError(c, err)
		}
		// ExoPlayer/mpv clients fall back to the embedded player when the
		// resolver is missing or YouTube rejects the extraction.
		return h.RespondWithError(c, err)
	}

	return h.RespondWithData(c, streams)
}
