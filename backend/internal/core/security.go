package core

import (
	"seanime/internal/security"
	"strings"

	"github.com/spf13/viper"
)

func (a *App) SyncSecurityConfig() {
	if a == nil || a.Config == nil {
		return
	}

	security.SetRequestBoundaryConfig(a.Config.Server.TrustedProxies, a.Config.Server.ExternalURL)
}

func (a *App) SetSecureMode(mode string, updateConfig bool) {
	requestedMode := strings.TrimSpace(strings.ToLower(mode))
	normalizedMode := security.NormalizeMode(requestedMode)
	if requestedMode != "" && normalizedMode == security.SecureModeDefault {
		a.Logger.Warn().Str("mode", mode).Msg("app: Invalid secure mode, defaulting to baseline mode")
	}

	security.SetSecureMode(normalizedMode)
	if updateConfig { // unused for now
		a.Config.Server.SecureMode = normalizedMode
		viper.Set("server.secureMode", normalizedMode)
		err := viper.WriteConfig()
		if err != nil {
			a.Logger.Err(err).Msg("app: Failed to write config after setting secure mode")
		}
	}
	logMode := normalizedMode
	if logMode == "" {
		logMode = "default"
	}
	a.Logger.Info().Str("mode", logMode).Msg("app: Secure mode changed")
}
