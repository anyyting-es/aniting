package handlers

import (
	"errors"
	"net/http"
	"strings"

	"github.com/labstack/echo/v4"
)

func (h *Handler) OptionalAuthMiddleware(next echo.HandlerFunc) echo.HandlerFunc {
	return func(c echo.Context) error {
		if h.App.Config.Server.Password == "" {
			return next(c)
		}

		req := c.Request()
		authKey := authFailureRateLimitKey(req)

		path := req.URL.Path
		passwordHash := req.Header.Get("X-Seanime-Token")

		// Allow the following paths to be accessed by anyone
		if path == "/api/v1/status" || // public but restricted
			path == "/events" { // for server events (auth handled by websocket handler)

			if path == "/api/v1/status" {
				// allow status requests by all clients but mark as unauthenticated
				if passwordHash != h.App.ServerPasswordHash {
					c.Set("unauthenticated", true)
				}
			}

			return next(c)
		}

		if passwordHash == h.App.ServerPasswordHash {
			authFailureRateLimits.reset(authKey)
			return next(c)
		}

		// Check HMAC token in query parameter
		token := req.URL.Query().Get("token")
		if token != "" {
			hmacAuth := h.App.GetServerPasswordHMACAuth()
			_, err := hmacAuth.ValidateToken(token, path)
			if err == nil {
				authFailureRateLimits.reset(authKey)
				return next(c)
			} else {
				h.App.Logger.Debug().Err(err).Str("path", path).Msg("server auth: HMAC token validation failed")
			}
		}

		// Handle Nakama client connections
		if h.App.Settings.GetNakama().Enabled && h.App.Settings.GetNakama().IsHost {
			// Verify the Nakama host password in the client request
			nakamaPasswordHeader := req.Header.Get("X-Seanime-Nakama-Token")

			// Allow WebSocket connections for peer-to-host communication
			if path == "/api/v1/nakama/ws" {
				if nakamaPasswordHeader == h.App.Settings.GetNakama().HostPassword {
					authFailureRateLimits.reset(authKey)
					c.Response().Header().Set("X-Seanime-Nakama-Is-Client", "true")
					return next(c)
				}
			}

			// Only allow the following paths to be accessed by Nakama clients
			if strings.HasPrefix(path, "/api/v1/nakama/host/") {
				if nakamaPasswordHeader == h.App.Settings.GetNakama().HostPassword {
					authFailureRateLimits.reset(authKey)
					c.Response().Header().Set("X-Seanime-Nakama-Is-Client", "true")
					return next(c)
				}
			}
		}

		if !authFailureRateLimits.allow(authKey, maxAuthFailuresPerWindow, authFailureWindow) {
			return h.RespondWithStatusError(c, http.StatusTooManyRequests, errTooManyAuthenticationAttempts)
		}

		return h.RespondWithStatusError(c, http.StatusUnauthorized, errors.New("UNAUTHENTICATED"))
	}
}
