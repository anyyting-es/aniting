package handlers

import (
	"bytes"
	"context"
	"crypto/tls"
	"encoding/base64"
	"errors"
	"fmt"
	"io"
	"net"
	"net/http"
	url2 "net/url"
	"seanime/internal/security"
	"seanime/internal/util"
	"strconv"
	"strings"
	"time"

	"github.com/5rahim/hls-m3u8/m3u8"
	"github.com/goccy/go-json"
	"github.com/labstack/echo/v4"
	"github.com/rs/zerolog/log"
)

const (
	videoProxyUserAgent      = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/132.0.0.0 Safari/537.36"
	videoProxyHLSKeyQueryKey = "hlsKey"
	videoProxyMaxHLSKeyBytes = 64 * 1024
)

type videoProxy struct {
	client         *http.Client
	fallbackClient *http.Client
	secureClient   *http.Client
	secureFallback *http.Client
}

type videoProxyRewriter struct {
	baseURL   *url2.URL
	headerMap map[string]string
	authToken string
}

var (
	defaultVideoProxy            = newVideoProxy()
	errVideoProxyRedirectBlocked = errors.New("proxy redirect blocked")
)

var videoProxyHopHeaders = map[string]struct{}{
	"connection":          {},
	"keep-alive":          {},
	"proxy-authenticate":  {},
	"proxy-authorization": {},
	"proxy-connection":    {},
	"te":                  {},
	"trailer":             {},
	"transfer-encoding":   {},
	"upgrade":             {},
}

var videoProxyBlockedRequestHeaders = map[string]struct{}{
	"accept-encoding": {},
	"content-length":  {},
	"host":            {},
}

func newVideoProxy() *videoProxy {
	p := &videoProxy{}
	p.client = p.newClient(false, false)
	p.fallbackClient = p.newClient(false, true)
	p.secureClient = p.newClient(true, false)
	p.secureFallback = p.newClient(true, true)
	return p
}

func (p *videoProxy) newClient(verifyTLS bool, allowHTTP2 bool) *http.Client {
	tlsConfig := &tls.Config{
		InsecureSkipVerify: !verifyTLS,
	}
	if !allowHTTP2 {
		tlsConfig.NextProtos = []string{"http/1.1"}
	}

	transport := &http.Transport{
		Proxy: http.ProxyFromEnvironment,
		DialContext: (&net.Dialer{
			Timeout:   30 * time.Second,
			KeepAlive: 30 * time.Second,
		}).DialContext,
		MaxIdleConns:          100,
		MaxIdleConnsPerHost:   10,
		IdleConnTimeout:       90 * time.Second,
		TLSHandshakeTimeout:   10 * time.Second,
		ResponseHeaderTimeout: 30 * time.Second,
		ExpectContinueTimeout: 1 * time.Second,
		TLSClientConfig:       tlsConfig,
		ForceAttemptHTTP2:     allowHTTP2,
		DisableCompression:    true,
	}
	if !allowHTTP2 {
		transport.TLSNextProto = map[string]func(string, *tls.Conn) http.RoundTripper{}
	}

	return &http.Client{
		Transport: transport,
		CheckRedirect: func(req *http.Request, via []*http.Request) error {
			if len(via) >= 10 {
				return errors.New("stopped after 10 redirects")
			}

			if verifyTLS {
				if err := security.ValidateOutboundUrl(req.URL.String()); err != nil {
					return fmt.Errorf("%w: %w", errVideoProxyRedirectBlocked, err)
				}
			}

			return nil
		},
	}
}

func (p *videoProxy) clients() (*http.Client, *http.Client) {
	if security.IsStrict() && p.secureClient != nil {
		return p.secureClient, p.secureFallback
	}

	return p.client, p.fallbackClient
}

func (p *videoProxy) do(req *http.Request) (*http.Response, error) {
	client, fallbackClient := p.clients()
	resp, err := client.Do(req)
	if err == nil || fallbackClient == nil || !shouldRetryHTTP2(err) {
		return resp, err
	}
	if resp != nil && resp.Body != nil {
		_ = resp.Body.Close()
	}

	fallbackReq := req.Clone(req.Context())
	fallbackReq.Header = req.Header.Clone()
	log.Debug().Err(err).Str("url", req.URL.String()).Msg("proxy: Retrying upstream request with HTTP/2")
	return fallbackClient.Do(fallbackReq)
}

func shouldRetryHTTP2(err error) bool {
	if err == nil {
		return false
	}

	msg := strings.ToLower(err.Error())
	return strings.Contains(msg, "no application protocol") ||
		strings.Contains(msg, "server selected unsupported protocol") ||
		strings.Contains(msg, "malformed http response") ||
		strings.Contains(msg, "http2_handshake_failed")
}

func (p *videoProxy) streamKey(c echo.Context, resp *http.Response) error {
	bodyBytes, err := io.ReadAll(io.LimitReader(resp.Body, videoProxyMaxHLSKeyBytes+1))
	if err != nil {
		log.Error().Err(err).Msg("proxy: Error reading HLS key")
		return echo.NewHTTPError(http.StatusInternalServerError, "Failed to read HLS key")
	}
	if len(bodyBytes) > videoProxyMaxHLSKeyBytes {
		return echo.NewHTTPError(http.StatusBadGateway, "HLS key response is too large")
	}

	keyBytes, decoded := p.normalizeKey(bodyBytes)
	if decoded {
		c.Response().Header().Del(echo.HeaderContentEncoding)
		c.Response().Header().Set(echo.HeaderContentType, "application/octet-stream")
	}
	c.Response().Header().Set(echo.HeaderContentLength, strconv.Itoa(len(keyBytes)))

	return c.Blob(resp.StatusCode, c.Response().Header().Get(echo.HeaderContentType), keyBytes)
}

func (p *videoProxy) normalizeKey(bodyBytes []byte) ([]byte, bool) {
	trimmed := bytes.TrimSpace(bodyBytes)
	if len(trimmed) == 0 {
		return bodyBytes, false
	}

	encodings := []*base64.Encoding{
		base64.StdEncoding,
		base64.RawStdEncoding,
		base64.URLEncoding,
		base64.RawURLEncoding,
	}
	for _, encoding := range encodings {
		decoded := make([]byte, encoding.DecodedLen(len(trimmed)))
		n, err := encoding.Decode(decoded, trimmed)
		if err != nil {
			continue
		}
		decoded = decoded[:n]
		if len(decoded) == 16 {
			return decoded, true
		}
	}

	return bodyBytes, false
}

func (h *Handler) VideoProxy(c echo.Context) (err error) {
	defer util.HandlePanicInModuleWithError("util/VideoProxy", &err)
	proxy := defaultVideoProxy

	rawURL := c.QueryParam("url")
	headers := c.QueryParam("headers")
	authToken := c.QueryParam("token")
	isHLSKey := c.QueryParam(videoProxyHLSKeyQueryKey) == "1"

	parsedURL, err := proxy.parseURL(rawURL)
	if err != nil {
		return h.RespondWithStatusError(c, http.StatusBadRequest, err)
	}

	if err := security.ValidateOutboundUrl(parsedURL.String()); err != nil {
		return h.RespondWithStatusError(c, http.StatusForbidden, err)
	}

	var headerMap map[string]string
	if headers != "" {
		if err := json.Unmarshal([]byte(headers), &headerMap); err != nil {
			log.Error().Err(err).Msg("proxy: Error unmarshalling headers")
			return h.RespondWithStatusError(c, http.StatusBadRequest, err)
		}
	}

	proxyReq, err := proxy.newRequest(c, parsedURL.String(), headerMap)
	if err != nil {
		log.Error().Err(err).Str("url", rawURL).Msg("proxy: Error creating request")
		return echo.NewHTTPError(http.StatusInternalServerError)
	}

	resp, err := proxy.do(proxyReq)

	if err != nil {
		if !errors.Is(err, context.Canceled) {
			log.Error().Err(err).Msg("proxy: Error sending request")
		}
		if errors.Is(err, errVideoProxyRedirectBlocked) {
			return h.RespondWithStatusError(c, http.StatusForbidden, err)
		}
		return echo.NewHTTPError(http.StatusBadGateway)
	}
	defer resp.Body.Close()

	proxy.copyHeaders(c.Response().Header(), resp.Header)
	proxy.setCORS(c.Response().Header())

	// always use get upstream, even for head requests since some servers don't handle head requests properly
	if c.Request().Method == http.MethodHead {
		return c.NoContent(resp.StatusCode)
	}
	if isHLSKey {
		return proxy.streamKey(c, resp)
	}

	isHlsPlaylist := proxy.isHLSPlaylist(parsedURL, resp.Header)

	if !isHlsPlaylist {
		return c.Stream(resp.StatusCode, c.Response().Header().Get("Content-Type"), resp.Body)
	}

	// HLS Playlist
	//log.Debug().Str("url", url).Msg("proxy: Processing HLS playlist")

	bodyBytes, readErr := io.ReadAll(resp.Body)
	if readErr != nil {
		log.Error().Err(readErr).Str("url", rawURL).Msg("proxy: Error reading HLS response body")
		return echo.NewHTTPError(http.StatusInternalServerError, "Failed to read HLS playlist")
	}

	buffer := bytes.NewBuffer(bodyBytes)
	playlist, listType, decodeErr := m3u8.Decode(*buffer, true)
	if decodeErr != nil {
		log.Warn().Err(decodeErr).Str("url", rawURL).Msg("proxy: Failed to decode M3U8 playlist, proxying raw content")
		c.Response().Header().Set(echo.HeaderContentType, resp.Header.Get("Content-Type"))
		c.Response().Header().Set(echo.HeaderContentLength, strconv.Itoa(len(bodyBytes)))
		return c.Blob(resp.StatusCode, c.Response().Header().Get(echo.HeaderContentType), bodyBytes)
	}

	var modifiedPlaylistBytes []byte
	needsRewrite := false
	rewriter := proxy.newRewriter(parsedURL, headerMap, authToken)

	if listType == m3u8.MEDIA {
		mediaPl := playlist.(*m3u8.MediaPlaylist)

		for _, segment := range mediaPl.Segments {
			if segment != nil {
				if rewriter.rewrite(&segment.URI) {
					needsRewrite = true
				}

				for i := range segment.Keys {
					if rewriter.rewriteKey(&segment.Keys[i].URI) {
						needsRewrite = true
					}
				}

				if segment.Map != nil {
					if rewriter.rewrite(&segment.Map.URI) {
						needsRewrite = true
					}
				}
			}
		}

		for _, segment := range mediaPl.PartialSegments {
			if segment != nil {
				if rewriter.rewrite(&segment.URI) {
					needsRewrite = true
				}
			}
		}

		if mediaPl.PreloadHints != nil {
			if rewriter.rewrite(&mediaPl.PreloadHints.URI) {
				needsRewrite = true
			}
		}

		if mediaPl.Map != nil {
			if rewriter.rewrite(&mediaPl.Map.URI) {
				needsRewrite = true
			}
		}

		for i := range mediaPl.Keys {
			if rewriter.rewriteKey(&mediaPl.Keys[i].URI) {
				needsRewrite = true
			}
		}

		if needsRewrite {
			buffer := mediaPl.Encode()
			modifiedPlaylistBytes = buffer.Bytes()
		}

	} else if listType == m3u8.MASTER {
		masterPl := playlist.(*m3u8.MasterPlaylist)

		for _, variant := range masterPl.Variants {
			if variant != nil {
				if rewriter.rewrite(&variant.URI) {
					needsRewrite = true
				}

				for _, alternative := range variant.Alternatives {
					if alternative != nil && rewriter.rewrite(&alternative.URI) {
						needsRewrite = true
					}
				}
			}
		}

		for i := range masterPl.SessionKeys {
			if rewriter.rewriteKey(&masterPl.SessionKeys[i].URI) {
				needsRewrite = true
			}
		}

		if needsRewrite {
			buffer := masterPl.Encode()
			modifiedPlaylistBytes = buffer.Bytes()
		}

	} else {
		modifiedPlaylistBytes = bodyBytes
	}

	if modifiedPlaylistBytes == nil {
		modifiedPlaylistBytes = bodyBytes
	}

	contentType := "application/vnd.apple.mpegurl"
	c.Response().Header().Set(echo.HeaderContentType, contentType)
	c.Response().Header().Set(echo.HeaderContentLength, strconv.Itoa(len(modifiedPlaylistBytes)))
	if resp.Header.Get("Cache-Control") == "" {
		c.Response().Header().Set("Cache-Control", "no-cache")
	}
	log.Debug().Bool("rewritten", needsRewrite).Str("url", rawURL).Msg("proxy: Sending modified HLS playlist")

	return c.Blob(resp.StatusCode, c.Response().Header().Get("Content-Type"), modifiedPlaylistBytes)
}

//////////////////// Rewrite

func (p *videoProxy) newRewriter(baseURL *url2.URL, headerMap map[string]string, authToken string) videoProxyRewriter {
	return videoProxyRewriter{
		baseURL:   baseURL,
		headerMap: headerMap,
		authToken: authToken,
	}
}

func (r videoProxyRewriter) rewrite(uri *string) bool {
	return r.rewriteURL(uri, false)
}

func (r videoProxyRewriter) rewriteKey(uri *string) bool {
	return r.rewriteURL(uri, true)
}

func (r videoProxyRewriter) rewriteURL(uri *string, isHLSKey bool) bool {
	if uri == nil || strings.TrimSpace(*uri) == "" || r.isProxyURL(*uri) {
		return false
	}

	targetURL, ok := r.resolve(*uri)
	if !ok {
		return false
	}

	*uri = r.proxyURL(targetURL, isHLSKey)
	return true
}

func (r videoProxyRewriter) resolve(rawURI string) (string, bool) {
	uri := strings.TrimSpace(rawURI)
	if r.baseURL == nil {
		return uri, false
	}

	parsedURI, err := url2.Parse(uri)
	if err != nil {
		return uri, false
	}

	resolvedURL := r.baseURL.ResolveReference(parsedURI)
	resolvedURL.Scheme = strings.ToLower(resolvedURL.Scheme)
	if resolvedURL.Scheme != "http" && resolvedURL.Scheme != "https" {
		return uri, false
	}
	if resolvedURL.Host == "" {
		return uri, false
	}

	return resolvedURL.String(), true
}

func (p *videoProxy) newRequest(c echo.Context, targetURL string, headerMap map[string]string) (*http.Request, error) {
	req, err := http.NewRequestWithContext(c.Request().Context(), http.MethodGet, targetURL, nil)
	if err != nil {
		return nil, err
	}

	for key, value := range headerMap {
		if p.isBlockedHeader(key) {
			continue
		}
		req.Header.Set(key, value)
	}

	if req.Header.Get("Accept") == "" {
		req.Header.Set("Accept", "*/*")
	}
	if req.Header.Get("User-Agent") == "" {
		req.Header.Set("User-Agent", videoProxyUserAgent)
	}
	if rangeHeader := c.Request().Header.Get("Range"); rangeHeader != "" {
		req.Header.Set("Range", rangeHeader)
	}

	return req, nil
}

////////////////////////////// Helpers

func (p *videoProxy) copyHeaders(dst http.Header, src http.Header) {
	for key, values := range src {
		if p.isHopHeader(key) {
			continue
		}

		dst.Del(key)
		for _, value := range values {
			dst.Add(key, value)
		}
	}
}

func (p *videoProxy) setCORS(header http.Header) {
	header.Set("Access-Control-Allow-Origin", "*")
	header.Set("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
	header.Set("Access-Control-Allow-Headers", "Authorization, Content-Type, Range")
	header.Set("Access-Control-Expose-Headers", "Accept-Ranges, Content-Length, Content-Range, Content-Type")
}

func (p *videoProxy) isHLSPlaylist(parsedURL *url2.URL, header http.Header) bool {
	contentType := strings.ToLower(header.Get(echo.HeaderContentType))
	if strings.Contains(contentType, "mpegurl") || strings.Contains(contentType, "vnd.apple.mpegurl") {
		return true
	}

	return strings.HasSuffix(strings.ToLower(parsedURL.Path), ".m3u8")
}

func (p *videoProxy) isBlockedHeader(key string) bool {
	key = strings.ToLower(strings.TrimSpace(key))
	if key == "" {
		return true
	}
	if _, ok := videoProxyHopHeaders[key]; ok {
		return true
	}
	_, ok := videoProxyBlockedRequestHeaders[key]
	return ok
}

func (p *videoProxy) isHopHeader(key string) bool {
	_, ok := videoProxyHopHeaders[strings.ToLower(strings.TrimSpace(key))]
	return ok
}

func (r videoProxyRewriter) proxyURL(targetURL string, isHLSKey bool) string {
	query := url2.Values{}
	query.Set("url", targetURL)
	if len(r.headerMap) > 0 {
		headers, err := json.Marshal(r.headerMap)
		if err == nil && len(headers) > 2 {
			query.Set("headers", string(headers))
		}
	}
	if r.authToken != "" {
		query.Set("token", r.authToken)
	}
	if isHLSKey {
		query.Set(videoProxyHLSKeyQueryKey, "1")
	}

	return "/api/v1/proxy?" + query.Encode()
}

func (r videoProxyRewriter) isProxyURL(rawURL string) bool {
	if strings.Contains(rawURL, "/api/v1/proxy?url=") || strings.Contains(rawURL, url2.QueryEscape("/api/v1/proxy?url=")) {
		return true
	}

	parsedURL, err := url2.Parse(rawURL)
	if err != nil {
		return false
	}

	return strings.HasSuffix(parsedURL.Path, "/api/v1/proxy") && parsedURL.Query().Has("url")
}

func (p *videoProxy) parseURL(rawURL string) (*url2.URL, error) {
	rawURL = strings.TrimSpace(rawURL)
	if rawURL == "" {
		return nil, errors.New("missing url")
	}

	parsedURL, err := url2.Parse(rawURL)
	if err != nil {
		return nil, err
	}
	parsedURL.Scheme = strings.ToLower(parsedURL.Scheme)
	if parsedURL.Scheme != "http" && parsedURL.Scheme != "https" {
		return nil, fmt.Errorf("unsupported url scheme: %s", parsedURL.Scheme)
	}
	if parsedURL.Host == "" {
		return nil, errors.New("missing host")
	}

	return parsedURL, nil
}
