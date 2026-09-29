package security

import (
	"seanime/internal/util"
	"slices"
	"strings"
)

const (
	SecureModeDefault  = ""
	SecureModeHardened = "hardened"
	SecureModeLax      = "lax"
	SecureModeStrict   = "strict"
)

type SecurityContext struct {
	SecureMode     string
	TrustedProxies []string
	ExternalURL    string
}

var GlobalSecurityContext = util.NewRef(&SecurityContext{})

func NormalizeMode(mode string) string {
	switch strings.ToLower(strings.TrimSpace(mode)) {
	case SecureModeHardened:
		return SecureModeHardened
	case SecureModeLax:
		return SecureModeLax
	case SecureModeStrict:
		return SecureModeStrict
	default:
		return SecureModeDefault
	}
}

func SetSecureMode(mode string) {
	current := GlobalSecurityContext.Get()
	GlobalSecurityContext.Set(&SecurityContext{
		SecureMode:     NormalizeMode(mode),
		TrustedProxies: slices.Clone(current.TrustedProxies),
		ExternalURL:    current.ExternalURL,
	})
}

func IsStrict() bool {
	return GlobalSecurityContext.Get().SecureMode == SecureModeStrict
}

func IsLax() bool {
	return GlobalSecurityContext.Get().SecureMode == SecureModeLax
}

func IsHardened() bool {
	mode := GlobalSecurityContext.Get().SecureMode
	return mode == SecureModeHardened || mode == SecureModeStrict
}

func SetRequestBoundaryConfig(trustedProxies []string, externalURL string) {
	current := GlobalSecurityContext.Get()
	GlobalSecurityContext.Set(&SecurityContext{
		SecureMode:     current.SecureMode,
		TrustedProxies: slices.Clone(trustedProxies),
		ExternalURL:    strings.TrimSpace(externalURL),
	})
}

func GetTrustedProxies() []string {
	return slices.Clone(GlobalSecurityContext.Get().TrustedProxies)
}

func GetExternalURL() string {
	return strings.TrimSpace(GlobalSecurityContext.Get().ExternalURL)
}
