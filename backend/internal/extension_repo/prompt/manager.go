package prompt

import (
	"context"
	"errors"
	"fmt"
	"seanime/internal/events"
	"seanime/internal/extension"
	"seanime/internal/util"
	"seanime/internal/util/result"
	"sort"
	"sync"
	"time"

	"github.com/goccy/go-json"
	"github.com/rs/zerolog"
)

const (
	EventRequest    = events.ExtensionPrompt
	EventSync       = events.ExtensionPromptSync
	EventResponse   = events.ExtensionPromptResponse
	DefaultTTL      = 2 * time.Minute
	DefaultCacheTTL = 3 * time.Minute
)

var (
	ErrDenied      = errors.New("prompt denied")
	ErrUnavailable = errors.New("prompt unavailable")
)

type Manager struct {
	logger *zerolog.Logger
	ws     events.WSEventManagerInterface

	mu      sync.Mutex
	pending map[string]*pendingRequest
}

type pendingRequest struct {
	request Request
	ch      chan *Response
}

type NewManagerOptions struct {
	Logger         *zerolog.Logger
	WSEventManager events.WSEventManagerInterface
}

type Extension struct {
	ID   string `json:"id"`
	Name string `json:"name"`
	Icon string `json:"icon"`
}

type Request struct {
	ID         string    `json:"id"`
	Kind       string    `json:"kind"`
	Extension  Extension `json:"extension"`
	Action     string    `json:"action"`
	Resource   string    `json:"resource"`
	Message    string    `json:"message"`
	Details    []string  `json:"details,omitempty"`
	AllowLabel string    `json:"allowLabel,omitempty"`
	DenyLabel  string    `json:"denyLabel,omitempty"`
	Expired    bool      `json:"expired,omitempty"`
	CreatedAt  time.Time `json:"createdAt"`
}

type Options struct {
	Kind       string
	Action     string
	Resource   string
	Message    string
	Details    []string
	AllowLabel string
	DenyLabel  string
	TTL        time.Duration
	Cache      *result.Cache[string, bool]
	CacheKey   string
	CacheTTL   time.Duration
}

type Response struct {
	ID       string `json:"id"`
	Allowed  bool   `json:"allowed"`
	ClientID string `json:"clientId,omitempty"`
}

func NewManager(opts *NewManagerOptions) *Manager {
	logger := opts.Logger
	if logger == nil {
		logger = new(zerolog.Nop())
	}

	ret := &Manager{
		logger:  logger,
		ws:      opts.WSEventManager,
		pending: make(map[string]*pendingRequest),
	}

	if opts.WSEventManager != nil {
		subscriber := opts.WSEventManager.SubscribeToClientEvents("extension-repo-prompt-manager")
		go ret.listen(subscriber)
	}

	return ret
}

func (m *Manager) Ask(ctx context.Context, ext *extension.Extension, opts Options) error {
	if opts.Cache != nil {
		if _, ok := opts.Cache.Get(opts.CacheKey); ok {
			return nil
		}
	}
	if m == nil || m.ws == nil {
		return ErrUnavailable
	}
	if len(m.ws.GetClientIds()) == 0 {
		return ErrUnavailable
	}

	id := util.RandomStringWithAlphabet(24, "abcdefghijklmnopqrstuvwxyz0123456789")
	ch := make(chan *Response, 1)

	request := Request{
		ID:         id,
		Kind:       opts.Kind,
		Action:     opts.Action,
		Resource:   opts.Resource,
		Message:    opts.Message,
		Details:    opts.Details,
		AllowLabel: opts.AllowLabel,
		DenyLabel:  opts.DenyLabel,
		CreatedAt:  time.Now(),
	}
	if ext != nil {
		request.Extension = Extension{
			ID:   ext.ID,
			Name: ext.Name,
			Icon: ext.Icon,
		}
	}

	m.mu.Lock()
	m.pending[id] = &pendingRequest{request: request, ch: ch}
	m.mu.Unlock()
	defer m.delete(id)

	m.sendRequest("", request)

	ttl := opts.TTL
	if ttl == 0 {
		ttl = DefaultTTL
	}

	waitCtx, cancel := context.WithTimeout(ctx, ttl)
	defer cancel()

	select {
	case response := <-ch:
		if response == nil || !response.Allowed {
			return ErrDenied
		}
		if opts.Cache != nil {
			cacheTTL := opts.CacheTTL
			if cacheTTL <= 0 {
				cacheTTL = DefaultCacheTTL
			}
			opts.Cache.SetT(opts.CacheKey, true, cacheTTL)
		}
		return nil
	case <-waitCtx.Done():
		m.dismiss(id)
		return fmt.Errorf("prompt: %w", waitCtx.Err())
	}
}

func (m *Manager) listen(subscriber *events.ClientEventSubscriber) {
	if subscriber == nil {
		return
	}

	for event := range subscriber.Channel {
		if event == nil {
			continue
		}

		switch string(event.Type) {
		case EventSync:
			m.resendTo(event.ClientID)
		case EventResponse:
			var response Response
			if err := decode(event.Payload, &response); err != nil {
				m.logger.Warn().Err(err).Msg("extension prompt: failed to decode response")
				continue
			}
			if response.ClientID == "" {
				response.ClientID = event.ClientID
			}

			m.resolve(&response)
		}
	}
}

func (m *Manager) resendTo(clientID string) {
	if clientID == "" {
		return
	}

	requests := m.pendingRequests()
	for _, request := range requests {
		m.sendRequest(clientID, request)
	}
}

func (m *Manager) pendingRequests() []Request {
	m.mu.Lock()
	defer m.mu.Unlock()

	ret := make([]Request, 0, len(m.pending))
	for _, pending := range m.pending {
		if pending == nil {
			continue
		}
		ret = append(ret, pending.request)
	}

	sort.Slice(ret, func(i, j int) bool {
		return ret[i].CreatedAt.Before(ret[j].CreatedAt)
	})

	return ret
}

func (m *Manager) sendRequest(clientID string, request Request) {
	if clientID == "" {
		m.ws.SendEvent(EventRequest, request)
		return
	}

	m.ws.SendEventTo(clientID, EventRequest, request, true)
}

func (m *Manager) dismiss(id string) {
	if id == "" {
		return
	}

	m.sendRequest("", Request{ID: id, Expired: true, CreatedAt: time.Now()})
}

func (m *Manager) resolve(response *Response) {
	if response == nil || response.ID == "" {
		return
	}

	m.mu.Lock()
	pending, ok := m.pending[response.ID]
	if ok {
		delete(m.pending, response.ID)
	}
	m.mu.Unlock()

	if !ok {
		return
	}

	select {
	case pending.ch <- response:
	default:
	}
}

func (m *Manager) delete(id string) {
	m.mu.Lock()
	defer m.mu.Unlock()
	delete(m.pending, id)
}

func decode(in interface{}, out interface{}) error {
	bytes, err := json.Marshal(in)
	if err != nil {
		return err
	}
	return json.Unmarshal(bytes, out)
}
