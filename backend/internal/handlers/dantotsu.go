package handlers

import (
	"errors"
	"fmt"
	"net/http"
	"net/url"
	"strconv"
	"strings"
	"time"

	"github.com/goccy/go-json"
	"github.com/labstack/echo/v4"
)

const (
	dantotsuBaseURL = "https://api.dantotsu.app"
	dantotsuAppAuth = "6*45Qp%W2RS@t38jkXoSKY588Ynj%n"
)

var dantotsuHTTPClient = &http.Client{Timeout: 25 * time.Second}

// dantotsuStatusError carries the upstream HTTP status when Dantotsu returns a
// non-2xx response, so callers can special-case "no comments" style errors.
type dantotsuStatusError struct {
	status int
	err    error
}

func (e *dantotsuStatusError) Error() string { return e.err.Error() }
func (e *dantotsuStatusError) Unwrap() error { return e.err }

func (h *Handler) dantotsuAuthToken() (string, error) {
	h.dantotsuMu.Lock()
	defer h.dantotsuMu.Unlock()

	if h.dantotsuToken != "" {
		return h.dantotsuToken, nil
	}
	anilistToken := h.App.GetUserAnilistToken()
	if anilistToken == "" {
		return "", errors.New("anilist account is required for community chat")
	}

	form := url.Values{"token": {anilistToken}}
	req, err := http.NewRequest(http.MethodPost, dantotsuBaseURL+"/authenticate", strings.NewReader(form.Encode()))
	if err != nil {
		return "", err
	}
	req.Header.Set("Content-Type", "application/x-www-form-urlencoded")
	req.Header.Set("Accept", "application/json")
	req.Header.Set("appauth", dantotsuAppAuth)

	res, err := dantotsuHTTPClient.Do(req)
	if err != nil {
		return "", fmt.Errorf("dantotsu authentication failed: %w", err)
	}
	defer res.Body.Close()
	if res.StatusCode != http.StatusOK {
		return "", fmt.Errorf("dantotsu authentication failed with status %d", res.StatusCode)
	}

	var payload struct {
		AuthToken string `json:"authToken"`
		User      struct {
			UserID string `json:"user_id"`
		} `json:"user"`
	}
	if err := json.NewDecoder(res.Body).Decode(&payload); err != nil {
		return "", fmt.Errorf("invalid dantotsu authentication response: %w", err)
	}
	if payload.AuthToken == "" {
		return "", errors.New("dantotsu authentication returned no token")
	}
	h.dantotsuToken = payload.AuthToken
	h.dantotsuUserID = payload.User.UserID
	return h.dantotsuToken, nil
}

func (h *Handler) dantotsuRequest(method, path string, query url.Values, form url.Values) (*http.Response, error) {
	token, err := h.dantotsuAuthToken()
	if err != nil {
		return nil, err
	}
	var body *strings.Reader
	if form != nil {
		body = strings.NewReader(form.Encode())
	} else {
		body = strings.NewReader("")
	}
	req, err := http.NewRequest(method, dantotsuBaseURL+path, body)
	if err != nil {
		return nil, err
	}
	if query != nil {
		req.URL.RawQuery = query.Encode()
	}
	req.Header.Set("Accept", "application/json")
	req.Header.Set("appauth", dantotsuAppAuth)
	req.Header.Set("Authorization", token)
	if form != nil {
		req.Header.Set("Content-Type", "application/x-www-form-urlencoded")
	}
	res, err := dantotsuHTTPClient.Do(req)
	if err != nil {
		return nil, fmt.Errorf("dantotsu request failed: %w", err)
	}
	if res.StatusCode == http.StatusUnauthorized {
		res.Body.Close()
		h.dantotsuMu.Lock()
		h.dantotsuToken = ""
		h.dantotsuMu.Unlock()
		return nil, errors.New("dantotsu session expired; please retry")
	}
	if res.StatusCode < 200 || res.StatusCode >= 300 {
		status := res.StatusCode
		res.Body.Close()
		return nil, &dantotsuStatusError{
			status: status,
			err:    fmt.Errorf("dantotsu request failed with status %d", status),
		}
	}
	return res, nil
}

func (h *Handler) HandleDantotsuComments(c echo.Context) error {
	mediaID, err := strconv.Atoi(c.Param("mediaId"))
	if err != nil || mediaID <= 0 {
		return h.RespondWithStatusError(c, http.StatusBadRequest, errors.New("invalid media id"))
	}
	page, err := strconv.Atoi(c.Param("page"))
	if err != nil || page <= 0 {
		return h.RespondWithStatusError(c, http.StatusBadRequest, errors.New("invalid page"))
	}
	query := url.Values{"sort": []string{"newest"}}
	if tag := c.QueryParam("tag"); tag != "" {
		query.Set("tag", tag)
	}
	res, err := h.dantotsuRequest(
		http.MethodGet,
		fmt.Sprintf("/comments/%d/%d", mediaID, page),
		query,
		nil,
	)
	if err != nil {
		// Dantotsu returns an error status when a media/episode has no comment
		// thread yet; surface that as an empty list so the UI shows
		// "be the first to comment" instead of an error.
		var statusErr *dantotsuStatusError
		if errors.As(err, &statusErr) {
			return h.RespondWithData(c, map[string]any{
				"comments":   []any{},
				"totalPages": 0,
			})
		}
		return h.RespondWithError(c, err)
	}
	defer res.Body.Close()
	var payload interface{}
	if err := json.NewDecoder(res.Body).Decode(&payload); err != nil {
		return h.RespondWithError(c, fmt.Errorf("invalid dantotsu comments response: %w", err))
	}
	return h.RespondWithData(c, payload)
}

func (h *Handler) HandleDantotsuCreateComment(c echo.Context) error {
	var body struct {
		MediaID         int    `json:"mediaId"`
		Content         string `json:"content"`
		Tag             *int   `json:"tag"`
		ParentCommentID *int   `json:"parentCommentId"`
	}
	if err := c.Bind(&body); err != nil {
		return h.RespondWithStatusError(c, http.StatusBadRequest, err)
	}
	if body.MediaID <= 0 || strings.TrimSpace(body.Content) == "" {
		return h.RespondWithStatusError(c, http.StatusBadRequest, errors.New("media id and content are required"))
	}
	h.dantotsuMu.Lock()
	userID := h.dantotsuUserID
	h.dantotsuMu.Unlock()
	if userID == "" {
		return h.RespondWithError(c, errors.New("anilist account is required for community chat"))
	}
	form := url.Values{
		"user_id":  {userID},
		"media_id": {strconv.Itoa(body.MediaID)},
		"content":  {strings.TrimSpace(body.Content)},
	}
	if body.Tag != nil {
		form.Set("tag", strconv.Itoa(*body.Tag))
	}
	if body.ParentCommentID != nil {
		form.Set("parent_comment_id", strconv.Itoa(*body.ParentCommentID))
	}
	res, err := h.dantotsuRequest(http.MethodPost, "/comments", nil, form)
	if err != nil {
		return h.RespondWithError(c, err)
	}
	defer res.Body.Close()
	var payload interface{}
	if err := json.NewDecoder(res.Body).Decode(&payload); err != nil {
		return h.RespondWithError(c, fmt.Errorf("invalid dantotsu comment response: %w", err))
	}
	return h.RespondWithData(c, payload)
}

func (h *Handler) HandleDantotsuVote(c echo.Context) error {
	commentID, err := strconv.Atoi(c.Param("commentId"))
	if err != nil || commentID <= 0 {
		return h.RespondWithStatusError(c, http.StatusBadRequest, errors.New("invalid comment id"))
	}
	voteType, err := strconv.Atoi(c.Param("voteType"))
	if err != nil || (voteType != -1 && voteType != 0 && voteType != 1) {
		return h.RespondWithStatusError(c, http.StatusBadRequest, errors.New("invalid vote type"))
	}
	res, err := h.dantotsuRequest(
		http.MethodPost,
		fmt.Sprintf("/comments/vote/%d/%d", commentID, voteType),
		nil,
		nil,
	)
	if err != nil {
		return h.RespondWithError(c, err)
	}
	defer res.Body.Close()
	return h.RespondWithData(c, true)
}
