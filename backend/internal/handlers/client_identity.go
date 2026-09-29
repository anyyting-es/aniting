package handlers

import (
	"net/http"
	"seanime/internal/core"
	"strings"
)

const (
	clientIdHeaderName      = "X-Seanime-Client-Id"
	clientIdProofHeaderName = "X-Seanime-Client-Id-Proof"
	clientIdCookieName      = "Seanime-Client-Id"
	clientIdQueryParam      = "id"
	clientIdProofQueryParam = "proof"
	clientPlatformHeader    = "X-Seanime-Client-Platform"
	clientPlatformQuery     = "platform"
	clientIdTokenPrefix     = "client-id:"

	ClientPlatformWeb    = "web"
	ClientPlatformDenshi = "denshi"
	ClientPlatformMobile = "mobile"
)

func normalizeClientPlatform(value string) string {
	switch strings.ToLower(strings.TrimSpace(value)) {
	case ClientPlatformWeb:
		return ClientPlatformWeb
	case ClientPlatformDenshi:
		return ClientPlatformDenshi
	case ClientPlatformMobile:
		return ClientPlatformMobile
	default:
		return ""
	}
}

func formatClientIdTokenSubject(clientID string) string {
	return clientIdTokenPrefix + strings.TrimSpace(clientID)
}

func generateClientIdentityProof(app *core.App, clientID string) string {
	clientID = strings.TrimSpace(clientID)
	if app == nil || clientID == "" {
		return ""
	}

	proof, err := app.GetClientIdentityHMACAuth().GenerateToken(formatClientIdTokenSubject(clientID))
	if err != nil {
		return ""
	}

	return proof
}

func getSignedClientId(app *core.App, claimedId string, proof string) string {
	claimedId = strings.TrimSpace(claimedId)
	proof = strings.TrimSpace(proof)
	if app == nil || claimedId == "" || proof == "" {
		return ""
	}

	if _, err := app.GetClientIdentityHMACAuth().ValidateToken(proof, formatClientIdTokenSubject(claimedId)); err != nil {
		return ""
	}

	return claimedId
}

func getClientIdFromRequest(app *core.App, req *http.Request) string {
	if req == nil {
		return ""
	}

	if clientID := getSignedClientId(app, req.Header.Get(clientIdHeaderName), req.Header.Get(clientIdProofHeaderName)); clientID != "" {
		return clientID
	}

	if req.URL != nil && req.URL.Path == "/events" {
		if clientID := getSignedClientId(app, req.URL.Query().Get(clientIdQueryParam), req.URL.Query().Get(clientIdProofQueryParam)); clientID != "" {
			return clientID
		}
	}

	return ""
}

func getClaimedClientIdFromRequest(req *http.Request) string {
	if req == nil {
		return ""
	}

	if clientID := strings.TrimSpace(req.Header.Get(clientIdHeaderName)); clientID != "" {
		return clientID
	}

	if req.URL != nil && req.URL.Path == "/events" {
		return strings.TrimSpace(req.URL.Query().Get(clientIdQueryParam))
	}

	return ""
}

func canAcceptClaimedClientId(app *core.App, req *http.Request) bool {
	if app == nil || app.Config == nil || req == nil {
		return false
	}

	return isRequestPermitted(req, "", app.Config.Server.AccessAllowlist)
}

func resolveClientIdFromRequest(app *core.App, req *http.Request, cookieValue string) string {
	if clientID := getClientIdFromRequest(app, req); clientID != "" {
		return clientID
	}

	if clientID := getClaimedClientIdFromRequest(req); clientID != "" && canAcceptClaimedClientId(app, req) {
		return clientID
	}

	return strings.TrimSpace(cookieValue)
}

func getClientPlatformFromRequest(req *http.Request) string {
	if req == nil {
		return ""
	}

	if platform := normalizeClientPlatform(req.Header.Get(clientPlatformHeader)); platform != "" {
		return platform
	}

	if req.URL != nil && req.URL.Path == "/events" {
		return normalizeClientPlatform(req.URL.Query().Get(clientPlatformQuery))
	}

	return ""
}

func setClientIdentityHeaders(headers http.Header, app *core.App, clientID string) {
	clientID = strings.TrimSpace(clientID)
	if headers == nil || clientID == "" {
		return
	}

	headers.Set(clientIdHeaderName, clientID)
	if proof := generateClientIdentityProof(app, clientID); proof != "" {
		headers.Set(clientIdProofHeaderName, proof)
	}
}
