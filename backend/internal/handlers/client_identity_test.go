package handlers

import (
	"net/http"
	"net/http/httptest"
	"seanime/internal/core"
	"testing"

	"github.com/stretchr/testify/assert"
)

func TestResolveSignedClientId(t *testing.T) {
	app := &core.App{ClientIdentitySecret: "test-client-identity-secret"}
	proof := generateClientIdentityProof(app, "client-1")

	assert.Equal(t, "client-1", getSignedClientId(app, "client-1", proof))
	assert.Empty(t, getSignedClientId(app, "client-2", proof))
	assert.Empty(t, getSignedClientId(app, "client-1", "bad-proof"))
}

func TestResolveValidatedClientId(t *testing.T) {
	app := &core.App{ClientIdentitySecret: "test-client-identity-secret"}
	headerProof := generateClientIdentityProof(app, "header-client")
	queryProof := generateClientIdentityProof(app, "query-client")

	t.Run("accepts signed header client id", func(t *testing.T) {
		req := httptest.NewRequest(http.MethodGet, "/api/v1/status", nil)
		req.Header.Set(clientIdHeaderName, "header-client")
		req.Header.Set(clientIdProofHeaderName, headerProof)

		assert.Equal(t, "header-client", getClientIdFromRequest(app, req))
	})

	t.Run("rejects unsigned header client id", func(t *testing.T) {
		req := httptest.NewRequest(http.MethodGet, "/api/v1/status", nil)
		req.Header.Set(clientIdHeaderName, "header-client")

		assert.Empty(t, getClientIdFromRequest(app, req))
	})

	t.Run("accepts signed websocket query client id", func(t *testing.T) {
		req := httptest.NewRequest(http.MethodGet, "/events?id=query-client&proof="+queryProof, nil)

		assert.Equal(t, "query-client", getClientIdFromRequest(app, req))
	})
}

func TestResolveClientIdFromRequest(t *testing.T) {
	app := &core.App{ClientIdentitySecret: "test-client-identity-secret", Config: &core.Config{}}
	headerProof := generateClientIdentityProof(app, "header-client")

	t.Run("signed header overrides stale cookie", func(t *testing.T) {
		// signed claims are the active browser identity
		req := newTrustedClientIDRequest(http.MethodGet, "/api/v1/status")
		req.Header.Set(clientIdHeaderName, "header-client")
		req.Header.Set(clientIdProofHeaderName, headerProof)

		assert.Equal(t, "header-client", resolveClientIdFromRequest(app, req, "cookie-client"))
	})

	t.Run("trusted unsigned header overrides stale cookie", func(t *testing.T) {
		// trusted app clients can refresh a missing proof
		req := newTrustedClientIDRequest(http.MethodGet, "/api/v1/status")
		req.Header.Set(clientIdHeaderName, "header-client")

		assert.Equal(t, "header-client", resolveClientIdFromRequest(app, req, "cookie-client"))
	})

	t.Run("trusted invalid proof keeps claimed id", func(t *testing.T) {
		// server restarts invalidate proofs before the client can resync
		req := newTrustedClientIDRequest(http.MethodGet, "/api/v1/status")
		req.Header.Set(clientIdHeaderName, "header-client")
		req.Header.Set(clientIdProofHeaderName, "stale-proof")

		assert.Equal(t, "header-client", resolveClientIdFromRequest(app, req, "cookie-client"))
	})

	t.Run("trusted websocket query can bootstrap proof", func(t *testing.T) {
		// websocket opens before the client has a signed proof
		req := newTrustedClientIDRequest(http.MethodGet, "/events?id=query-client")

		assert.Equal(t, "query-client", resolveClientIdFromRequest(app, req, ""))
	})

	t.Run("untrusted unsigned header falls back to cookie", func(t *testing.T) {
		// untrusted origins cannot claim arbitrary client ids
		req := newUntrustedClientIDRequest(http.MethodGet, "/api/v1/status")
		req.Header.Set(clientIdHeaderName, "header-client")

		assert.Equal(t, "cookie-client", resolveClientIdFromRequest(app, req, "cookie-client"))
	})

	t.Run("untrusted unsigned header without cookie is ignored", func(t *testing.T) {
		// callers without proof get a fresh middleware id later
		req := newUntrustedClientIDRequest(http.MethodGet, "/api/v1/status")
		req.Header.Set(clientIdHeaderName, "header-client")

		assert.Empty(t, resolveClientIdFromRequest(app, req, ""))
	})
}

func newTrustedClientIDRequest(method string, path string) *http.Request {
	req := httptest.NewRequest(method, "http://127.0.0.1:43211"+path, nil)
	req.RemoteAddr = "127.0.0.1:51111"
	req.Header.Set("Origin", "app://-")
	return req
}

func newUntrustedClientIDRequest(method string, path string) *http.Request {
	req := httptest.NewRequest(method, "http://127.0.0.1:43211"+path, nil)
	req.RemoteAddr = "127.0.0.1:51111"
	req.Header.Set("Origin", "https://example.invalid")
	return req
}

func TestClientAppPlatform(t *testing.T) {
	t.Run("accepts normalized header platform", func(t *testing.T) {
		req := httptest.NewRequest(http.MethodGet, "/api/v1/status", nil)
		req.Header.Set(clientPlatformHeader, " DensHi ")

		assert.Equal(t, ClientPlatformDenshi, getClientPlatformFromRequest(req))
	})

	t.Run("accepts websocket query platform", func(t *testing.T) {
		req := httptest.NewRequest(http.MethodGet, "/events?platform=mobile", nil)

		assert.Equal(t, ClientPlatformMobile, getClientPlatformFromRequest(req))
	})

	t.Run("ignores invalid platform values", func(t *testing.T) {
		req := httptest.NewRequest(http.MethodGet, "/api/v1/status", nil)
		req.Header.Set(clientPlatformHeader, "windows")

		assert.Empty(t, getClientPlatformFromRequest(req))
	})
}
