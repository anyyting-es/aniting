package handlers

import (
	"encoding/base64"
	"errors"
	"io"
	"net/http"
	"net/http/httptest"
	"net/url"
	"seanime/internal/security"
	"strconv"
	"strings"
	"testing"

	"github.com/goccy/go-json"
	"github.com/labstack/echo/v4"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestProxyTransportConfig(t *testing.T) {
	proxy := &videoProxy{}
	client := proxy.newClient(false, false)
	transport, ok := client.Transport.(*http.Transport)
	require.True(t, ok)

	// the default path should avoid http/2 stream-level failures
	assert.False(t, transport.ForceAttemptHTTP2)
	assert.NotNil(t, transport.TLSNextProto)
	assert.Equal(t, []string{"http/1.1"}, transport.TLSClientConfig.NextProtos)
	assert.True(t, transport.DisableCompression)

	fallbackClient := proxy.newClient(false, true)
	fallbackTransport, ok := fallbackClient.Transport.(*http.Transport)
	require.True(t, ok)
	assert.True(t, fallbackTransport.ForceAttemptHTTP2)
	assert.Nil(t, fallbackTransport.TLSNextProto)
	assert.Empty(t, fallbackTransport.TLSClientConfig.NextProtos)
}

func TestProxyFallback(t *testing.T) {
	security.SetSecureMode("")
	t.Cleanup(func() { security.SetSecureMode("") })

	primaryClient := &http.Client{Transport: roundTripFunc(func(req *http.Request) (*http.Response, error) {
		// only negotiation failures should get a second chance with http/2
		return nil, errors.New("remote error: tls: no application protocol")
	})}
	fallbackClient := &http.Client{Transport: roundTripFunc(func(req *http.Request) (*http.Response, error) {
		return &http.Response{
			StatusCode: http.StatusOK,
			Header:     make(http.Header),
			Body:       io.NopCloser(strings.NewReader("ok")),
			Request:    req,
		}, nil
	})}
	req, err := http.NewRequest(http.MethodGet, "https://example.com/video.mp4", nil)
	require.NoError(t, err)
	req.Header.Set("Range", "bytes=0-1")

	proxy := &videoProxy{client: primaryClient, fallbackClient: fallbackClient}
	resp, err := proxy.do(req)
	require.NoError(t, err)
	t.Cleanup(func() { _ = resp.Body.Close() })

	body, err := io.ReadAll(resp.Body)
	require.NoError(t, err)
	assert.Equal(t, http.StatusOK, resp.StatusCode)
	assert.Equal(t, "ok", string(body))
	assert.Equal(t, "bytes=0-1", resp.Request.Header.Get("Range"))
}

func TestProxyNoFallbackOnStreamError(t *testing.T) {
	security.SetSecureMode("")
	t.Cleanup(func() { security.SetSecureMode("") })

	fallbackCalled := false
	primaryClient := &http.Client{Transport: roundTripFunc(func(req *http.Request) (*http.Response, error) {
		// stream-level http/2 errors are the failure mode we avoid by preferring http/1.1
		return nil, errors.New("connection error: FLOW_CONTROL_ERROR")
	})}
	fallbackClient := &http.Client{Transport: roundTripFunc(func(req *http.Request) (*http.Response, error) {
		fallbackCalled = true
		return nil, nil
	})}
	req, err := http.NewRequest(http.MethodGet, "https://example.com/video.mp4", nil)
	require.NoError(t, err)

	proxy := &videoProxy{client: primaryClient, fallbackClient: fallbackClient}
	resp, err := proxy.do(req)

	require.Error(t, err)
	assert.Nil(t, resp)
	assert.False(t, fallbackCalled)
}

func TestProxyForwardsHeadersAndRange(t *testing.T) {
	security.SetSecureMode("")
	t.Cleanup(func() { security.SetSecureMode("") })

	var upstreamHeader http.Header
	initTestClients(t, &http.Client{Transport: roundTripFunc(func(r *http.Request) (*http.Response, error) {
		// configured source headers should reach the upstream without hop-by-hop headers
		upstreamHeader = r.Header.Clone()
		assert.Equal(t, http.MethodGet, r.Method)
		return newResp(r, http.StatusPartialContent, http.Header{
			echo.HeaderContentType: []string{"video/mp4"},
			"X-Upstream":           []string{"yes"},
		}, "abc"), nil
	})}, nil)

	headers := map[string]string{
		"Accept":          "video/*",
		"Accept-Encoding": "gzip",
		"Connection":      "close",
		"Host":            "example.invalid",
		"Referer":         "https://source.example/watch",
		"User-Agent":      "SeanimeTest/1.0",
	}
	clientHeader := http.Header{"Range": []string{"bytes=0-2"}}

	rec := runProxy(t, http.MethodGet, "https://video.example/video.mp4", headers, clientHeader)

	require.Equal(t, http.StatusPartialContent, rec.Code)
	assert.Equal(t, "abc", rec.Body.String())
	assert.Equal(t, "video/*", upstreamHeader.Get("Accept"))
	assert.Empty(t, upstreamHeader.Get("Accept-Encoding"))
	assert.Empty(t, upstreamHeader.Get("Connection"))
	assert.Equal(t, "bytes=0-2", upstreamHeader.Get("Range"))
	assert.Equal(t, "https://source.example/watch", upstreamHeader.Get("Referer"))
	assert.Equal(t, "SeanimeTest/1.0", upstreamHeader.Get("User-Agent"))
	assert.Equal(t, "yes", rec.Header().Get("X-Upstream"))
	assert.Equal(t, "*", rec.Header().Get("Access-Control-Allow-Origin"))
}

func TestProxyHeadUsesGet(t *testing.T) {
	security.SetSecureMode("")
	t.Cleanup(func() { security.SetSecureMode("") })

	var upstreamMethod string
	initTestClients(t, &http.Client{Transport: roundTripFunc(func(r *http.Request) (*http.Response, error) {
		// some video hosts do not support head, so the proxy still uses get upstream
		upstreamMethod = r.Method
		return newResp(r, http.StatusAccepted, http.Header{
			echo.HeaderContentType: []string{"video/mp4"},
		}, "body should not be sent"), nil
	})}, nil)

	rec := runProxy(t, http.MethodHead, "https://video.example/video.mp4", nil, nil)

	require.Equal(t, http.StatusAccepted, rec.Code)
	assert.Equal(t, http.MethodGet, upstreamMethod)
	assert.Empty(t, rec.Body.String())
}

func TestProxyRewritesHLS(t *testing.T) {
	security.SetSecureMode("")
	t.Cleanup(func() { security.SetSecureMode("") })

	playlist := strings.Join([]string{
		"#EXTM3U",
		"#EXT-X-VERSION:7",
		"#EXT-X-TARGETDURATION:10",
		"#EXT-X-KEY:METHOD=AES-128,URI=\"key.key\"",
		"#EXT-X-MAP:URI=\"init.mp4\"",
		"#EXTINF:10,",
		"segment.ts",
		"#EXTINF:10,",
		"https://cdn.example.com/absolute.ts",
		"#EXT-X-ENDLIST",
		"",
	}, "\n")

	initTestClients(t, &http.Client{Transport: roundTripFunc(func(r *http.Request) (*http.Response, error) {
		return newResp(r, http.StatusOK, http.Header{
			echo.HeaderContentType: []string{"application/vnd.apple.mpegurl"},
		}, playlist), nil
	})}, nil)

	headers := map[string]string{"Referer": "https://source.example/watch"}
	rec := runProxy(t, http.MethodGet, "https://video.example/hls/index.m3u8?token=source", headers, nil, "token", "proxy-token")

	require.Equal(t, http.StatusOK, rec.Code)
	body := rec.Body.String()
	assert.Contains(t, body, "/api/v1/proxy?")
	assert.Contains(t, body, "headers=")
	assert.Contains(t, body, "hlsKey=1")
	assert.Contains(t, body, "token=proxy-token")
	assert.Contains(t, body, url.QueryEscape("https://video.example/hls/key.key"))
	assert.Contains(t, body, url.QueryEscape("https://video.example/hls/init.mp4"))
	assert.Contains(t, body, url.QueryEscape("https://video.example/hls/segment.ts"))
	assert.Contains(t, body, url.QueryEscape("https://cdn.example.com/absolute.ts"))
	assert.Equal(t, "application/vnd.apple.mpegurl", rec.Header().Get(echo.HeaderContentType))
}

func TestProxyKeyDecodesBase64(t *testing.T) {
	security.SetSecureMode("")
	t.Cleanup(func() { security.SetSecureMode("") })

	keyBytes := []byte("0123456789abcdef")
	encodedKey := base64.StdEncoding.EncodeToString(keyBytes) + "\n"
	initTestClients(t, &http.Client{Transport: roundTripFunc(func(r *http.Request) (*http.Response, error) {
		// aes-128 hls keys must be raw 16-byte payloads
		return newResp(r, http.StatusOK, http.Header{
			echo.HeaderContentType: []string{"text/plain"},
		}, encodedKey), nil
	})}, nil)

	rec := runProxy(t, http.MethodGet, "https://video.example/keys/key.bin", nil, nil, videoProxyHLSKeyQueryKey, "1")

	require.Equal(t, http.StatusOK, rec.Code)
	assert.Equal(t, keyBytes, rec.Body.Bytes())
	assert.Equal(t, "application/octet-stream", rec.Header().Get(echo.HeaderContentType))
	assert.Equal(t, strconv.Itoa(len(keyBytes)), rec.Header().Get(echo.HeaderContentLength))

	proxy := &videoProxy{}
	rawKey := []byte("0123456789abcdef")
	normalizedKey, decoded := proxy.normalizeKey(rawKey)
	assert.False(t, decoded)
	assert.Equal(t, rawKey, normalizedKey)

	encodedAES256Key := []byte(base64.StdEncoding.EncodeToString([]byte("0123456789abcdef0123456789abcdef")))
	normalizedKey, decoded = proxy.normalizeKey(encodedAES256Key)
	assert.False(t, decoded)
	assert.Equal(t, encodedAES256Key, normalizedKey)
}

func initTestClients(t *testing.T, client *http.Client, fallbackClient *http.Client) {
	t.Helper()

	previous := *defaultVideoProxy

	defaultVideoProxy.client = client
	defaultVideoProxy.fallbackClient = fallbackClient
	defaultVideoProxy.secureClient = client
	defaultVideoProxy.secureFallback = fallbackClient

	t.Cleanup(func() {
		*defaultVideoProxy = previous
	})
}

func newResp(req *http.Request, status int, header http.Header, body string) *http.Response {
	return &http.Response{
		StatusCode: status,
		Header:     header,
		Body:       io.NopCloser(strings.NewReader(body)),
		Request:    req,
	}
}

func runProxy(t *testing.T, method string, targetURL string, upstreamHeaders map[string]string, clientHeaders http.Header, extraQuery ...string) *httptest.ResponseRecorder {
	t.Helper()

	query := url.Values{}
	query.Set("url", targetURL)
	if len(upstreamHeaders) > 0 {
		headerBytes, err := json.Marshal(upstreamHeaders)
		require.NoError(t, err)
		query.Set("headers", string(headerBytes))
	}
	for i := 0; i+1 < len(extraQuery); i += 2 {
		query.Set(extraQuery[i], extraQuery[i+1])
	}

	e := echo.New()
	req := httptest.NewRequest(method, "/api/v1/proxy?"+query.Encode(), nil)
	for key, values := range clientHeaders {
		for _, value := range values {
			req.Header.Add(key, value)
		}
	}
	rec := httptest.NewRecorder()
	c := e.NewContext(req, rec)
	h := &Handler{}

	require.NoError(t, h.VideoProxy(c))
	return rec
}

type roundTripFunc func(*http.Request) (*http.Response, error)

func (fn roundTripFunc) RoundTrip(req *http.Request) (*http.Response, error) {
	return fn(req)
}
