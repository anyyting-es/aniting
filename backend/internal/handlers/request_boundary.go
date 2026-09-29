package handlers

import (
	"net"
	"net/http"
	"net/netip"
	"net/url"
	"seanime/internal/security"
	"strings"
)

type requestBoundaryView struct {
	host         string
	hostname     string
	port         string
	scheme       string
	clientIP     netip.Addr
	remoteIP     netip.Addr
	trustedProxy bool
}

// createRequestBoundaryView processes an HTTP request and returns a structure describing the request's host, IP, scheme, and related attributes.
func createRequestBoundaryView(req *http.Request) requestBoundaryView {
	view := requestBoundaryView{}
	if req == nil {
		return view
	}

	remoteIP, ok := parseIPToken(req.RemoteAddr)
	if ok {
		view.remoteIP = remoteIP
		view.clientIP = remoteIP
		view.trustedProxy = isTrustedProxyAddr(remoteIP)
	}

	host := strings.TrimSpace(req.Host)
	if view.trustedProxy {
		if forwardedHost := firstForwardedValue(req.Header.Get("X-Forwarded-Host")); forwardedHost != "" {
			host = forwardedHost
		}
		if forwardedFor := firstForwardedValue(req.Header.Get("X-Forwarded-For")); forwardedFor != "" {
			if clientIP, ok := parseIPToken(forwardedFor); ok {
				view.clientIP = clientIP
			}
		}
	}

	parsedHost, err := url.Parse("//" + host)
	if err == nil {
		view.host = host
		view.hostname = strings.ToLower(strings.TrimSpace(parsedHost.Hostname()))
		view.port = parsedHost.Port()
	} else {
		view.host = host
	}

	view.scheme = "http"
	if req.TLS != nil {
		view.scheme = "https"
	}
	if view.trustedProxy {
		if forwardedProto := strings.ToLower(firstForwardedValue(req.Header.Get("X-Forwarded-Proto"))); forwardedProto == "http" || forwardedProto == "https" {
			view.scheme = forwardedProto
		}
	}

	return view
}

func firstForwardedValue(raw string) string {
	if raw == "" {
		return ""
	}

	parts := strings.Split(raw, ",")
	if len(parts) == 0 {
		return ""
	}

	return strings.TrimSpace(parts[0])
}

func parseIPToken(raw string) (netip.Addr, bool) {
	raw = strings.TrimSpace(raw)
	if raw == "" {
		return netip.Addr{}, false
	}

	if strings.HasPrefix(raw, "[") {
		if host, _, err := net.SplitHostPort(raw); err == nil {
			raw = host
		}
	} else if strings.Count(raw, ":") == 1 {
		if host, _, err := net.SplitHostPort(raw); err == nil {
			raw = host
		}
	}

	addr, err := netip.ParseAddr(strings.Trim(raw, "[]"))
	if err != nil {
		return netip.Addr{}, false
	}

	return addr.Unmap(), true
}

func isTrustedProxyAddr(addr netip.Addr) bool {
	if !addr.IsValid() {
		return false
	}

	for _, rawEntry := range security.GetTrustedProxies() {
		entry := strings.TrimSpace(rawEntry)
		if entry == "" {
			continue
		}

		if strings.Contains(entry, "/") {
			prefix, err := netip.ParsePrefix(entry)
			if err == nil && prefix.Contains(addr) {
				return true
			}
			continue
		}

		trustedAddr, err := netip.ParseAddr(entry)
		if err == nil && trustedAddr.Unmap() == addr {
			return true
		}
	}

	return false
}

func requestClientIP(req *http.Request) string {
	view := createRequestBoundaryView(req)
	if view.clientIP.IsValid() {
		return view.clientIP.String()
	}

	return strings.TrimSpace(req.RemoteAddr)
}

func requestUsesTrustedHTTPS(req *http.Request) bool {
	view := createRequestBoundaryView(req)
	if view.scheme == "https" {
		return true
	}

	externalURL := strings.TrimSpace(security.GetExternalURL())
	if externalURL == "" {
		return false
	}

	parsed, err := url.Parse(externalURL)
	if err != nil || !strings.EqualFold(parsed.Scheme, "https") {
		return false
	}

	if view.hostname == "" {
		return false
	}

	return strings.EqualFold(parsed.Hostname(), view.hostname)
}
