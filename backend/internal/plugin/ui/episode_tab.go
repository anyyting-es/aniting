package plugin_ui

import (
	"context"
	"fmt"
	"seanime/internal/library/anime"
	gojautil "seanime/internal/util/goja"
	"seanime/internal/util/result"

	"github.com/dop251/goja"
	"github.com/goccy/go-json"
	"github.com/google/uuid"
)

type EpisodeTabManager struct {
	ctx  *Context
	tabs *result.Map[string, *EpisodeTab]
}

type EpisodeTab struct {
	Name string
	Icon string

	openState   goja.Value
	openStateID string
	shouldShow  goja.Callable
	onOpen      goja.Callable
	onSelect    goja.Callable
}

type EpisodeTabItem struct {
	Name string `json:"name"`
	Icon string `json:"icon,omitempty"`
}

type episodeTabOptions struct {
	Name string `json:"name"`
	Icon string `json:"icon,omitempty"`
}

func NewEpisodeTabManager(ctx *Context) *EpisodeTabManager {
	m := &EpisodeTabManager{
		ctx:  ctx,
		tabs: result.NewMap[string, *EpisodeTab](),
	}

	m.listenRender()
	m.listenOpen()
	m.listenSelection()
	m.listenStateChanges()

	return m
}

func (m *EpisodeTabManager) bindAnime(animeObj *goja.Object) {
	_ = animeObj.Set("registerEntryEpisodeTab", m.jsRegisterEntryEpisodeTab)
}

func (m *EpisodeTabManager) UnmountAll() {
	m.tabs.Range(func(_ string, tab *EpisodeTab) bool {
		m.setIsOpen(tab, false)
		return true
	})

	if m.tabs.ClearN() > 0 {
		m.renderSelectTabs(nil)
	}
}

func (m *EpisodeTabManager) ListTabs() []*EpisodeTabItem {
	tabs := make([]*EpisodeTabItem, 0)
	m.tabs.Range(func(_ string, tab *EpisodeTab) bool {
		tabs = append(tabs, &EpisodeTabItem{
			Name: tab.Name,
			Icon: tab.Icon,
		})
		return true
	})
	return tabs
}

func (m *EpisodeTabManager) jsRegisterEntryEpisodeTab(call goja.FunctionCall) goja.Value {
	if len(call.Arguments) < 1 {
		m.ctx.handleTypeError("registerEntryEpisodeTab requires an options object")
	}

	arg := call.Argument(0)
	if goja.IsUndefined(arg) || goja.IsNull(arg) {
		m.ctx.handleTypeError("registerEntryEpisodeTab requires an options object")
	}

	obj := arg.ToObject(m.ctx.vm)
	options, err := m.getOptions(obj)
	if err != nil {
		m.ctx.handleTypeError(err.Error())
	}
	if options.Name == "" {
		m.ctx.handleTypeError("registerEntryEpisodeTab requires a name")
	}

	if options.Icon != "" {
		if containsDangerousHTML(options.Icon) {
			m.ctx.logger.Warn().Msg("plugin: Icon contains dangerous HTML, it will not be rendered")
			options.Icon = ""
		}
	}

	tab := &EpisodeTab{
		Name:        options.Name,
		Icon:        options.Icon,
		openStateID: uuid.New().String(),
	}

	if shouldShow, ok := goja.AssertFunction(obj.Get("shouldShow")); ok {
		tab.shouldShow = shouldShow
	}
	if onEpisodeCollection, ok := goja.AssertFunction(obj.Get("onEpisodeCollection")); ok {
		tab.onOpen = onEpisodeCollection
	}
	if onSelectEpisode, ok := goja.AssertFunction(obj.Get("onSelectEpisode")); ok {
		tab.onSelect = onSelectEpisode
	}

	m.ctx.states.Set(tab.openStateID, &State{ID: tab.openStateID, Value: m.ctx.vm.ToValue(false)})
	tab.openState = m.ctx.createStateObject(tab.openStateID, func(goja.FunctionCall) goja.Value {
		state, _ := m.ctx.states.Get(tab.openStateID)
		return state.Value
	}, nil)

	m.tabs.Set(m.ctx.ext.ID, tab)

	ret := m.ctx.vm.NewObject()
	_ = ret.Set("name", tab.Name)
	_ = ret.Set("icon", tab.Icon)
	_ = ret.Set("getIsOpen", func() goja.Value {
		return tab.openState
	})

	return ret
}

func (m *EpisodeTabManager) listenRender() {
	listener := m.ctx.RegisterEventListener(ClientAnimeEntryEpisodeTabsRenderEvent)
	listener.SetCallback(func(event *ClientPluginEvent) {
		payload := ClientAnimeEntryEpisodeTabsRenderEventPayload{}
		if !event.ParsePayloadAs(ClientAnimeEntryEpisodeTabsRenderEvent, &payload) {
			return
		}

		visibleTabs := make([]*EpisodeTab, 0)
		m.tabs.Range(func(_ string, tab *EpisodeTab) bool {
			visible, err := m.shouldShowTab(tab, payload.MediaID)
			if err != nil {
				m.ctx.handleException(err)
				return true
			}
			if visible {
				visibleTabs = append(visibleTabs, tab)
			}
			return true
		})

		m.renderSelectTabs(visibleTabs)
	})
}

func (m *EpisodeTabManager) listenOpen() {
	listener := m.ctx.RegisterEventListener(ClientAnimeEntryEpisodeTabOpenEvent)
	listener.SetCallback(func(event *ClientPluginEvent) {
		payload := ClientAnimeEntryEpisodeTabOpenEventPayload{}
		if !event.ParsePayloadAs(ClientAnimeEntryEpisodeTabOpenEvent, &payload) {
			return
		}

		tab, ok := m.tabs.Get(m.ctx.ext.ID)
		if !ok {
			return
		}

		m.setIsOpen(tab, true)

		episodeCollection, err := m.getEpisodeCollection(payload.MediaID)
		if err != nil {
			m.ctx.handleException(err)
			return
		}

		if tab.onOpen != nil {
			modifiedCollection, err := m.callEpisodeCollectionHandler(tab.onOpen, map[string]interface{}{
				"mediaId":           payload.MediaID,
				"episodeCollection": episodeCollection,
			}, episodeCollection)
			if err != nil {
				m.ctx.handleException(err)
			} else {
				episodeCollection = modifiedCollection
			}
		}

		m.ctx.SendEventToClient(ServerAnimeEntryEpisodeTabEpisodeCollectionEvent, ServerAnimeEntryEpisodeTabEpisodeCollectionEventPayload{
			EpisodeCollection: episodeCollection,
		})
	})
}

func (m *EpisodeTabManager) listenSelection() {
	listener := m.ctx.RegisterEventListener(ClientAnimeEntryEpisodeTabSelectEpisodeEvent)
	listener.SetCallback(func(event *ClientPluginEvent) {
		payload := ClientAnimeEntryEpisodeTabSelectEpisodeEventPayload{}
		if !event.ParsePayloadAs(ClientAnimeEntryEpisodeTabSelectEpisodeEvent, &payload) {
			return
		}

		tab, ok := m.tabs.Get(m.ctx.ext.ID)
		if !ok || tab.onSelect == nil {
			return
		}

		if err := m.callVoidHandler(tab.onSelect, map[string]interface{}{
			"mediaId":       payload.MediaID,
			"episodeNumber": payload.EpisodeNumber,
			"aniDbEpisode":  payload.AniDbEpisode,
			"episode":       payload.Episode,
		}); err != nil {
			m.ctx.handleException(err)
		}
	})
}

func (m *EpisodeTabManager) listenStateChanges() {
	listener := m.ctx.RegisterEventListener(ClientAnimeEntryEpisodeTabStateChangedEvent)
	listener.SetCallback(func(event *ClientPluginEvent) {
		payload := ClientAnimeEntryEpisodeTabStateChangedEventPayload{}
		if !event.ParsePayloadAs(ClientAnimeEntryEpisodeTabStateChangedEvent, &payload) {
			return
		}

		tab, ok := m.tabs.Get(m.ctx.ext.ID)
		if !ok {
			return
		}

		m.setIsOpen(tab, payload.IsOpen)
	})
}

func (m *EpisodeTabManager) renderSelectTabs(t []*EpisodeTab) {
	tabs := make([]*EpisodeTabItem, 0, len(t))
	for _, tab := range t {
		tabs = append(tabs, &EpisodeTabItem{
			Name: tab.Name,
			Icon: tab.Icon,
		})
	}

	m.ctx.SendEventToClient(ServerAnimeEntryEpisodeTabsUpdatedEvent, ServerAnimeEntryEpisodeTabsUpdatedEventPayload{
		Tabs: tabs,
	})
}

func (m *EpisodeTabManager) renderTabs() {
	m.renderSelectTabs(m.tabs.Values())
}

func (m *EpisodeTabManager) setIsOpen(tab *EpisodeTab, isOpen bool) {
	m.ctx.states.Set(tab.openStateID, &State{
		ID:    tab.openStateID,
		Value: m.ctx.vm.ToValue(isOpen),
	})
	m.ctx.queueStateUpdate(tab.openStateID)
}

func (m *EpisodeTabManager) shouldShowTab(tab *EpisodeTab, mediaID int) (bool, error) {
	if tab.shouldShow == nil {
		return true, nil
	}

	exported, err := m.callHandler(tab.shouldShow, map[string]interface{}{
		"mediaId": mediaID,
	})
	if err != nil {
		return false, err
	}

	visible, ok := exported.(bool)
	if ok {
		return visible, nil
	}

	return exported != nil, nil
}

func (m *EpisodeTabManager) getEpisodeCollection(mediaID int) (*anime.EpisodeCollection, error) {
	anilistPlatformRef, ok := m.ctx.ui.appContext.AnilistPlatformRef().Get()
	if !ok {
		return nil, fmt.Errorf("anilist platform not found")
	}

	metadataProviderRef, ok := m.ctx.ui.appContext.MetadataProviderRef().Get()
	if !ok {
		return nil, fmt.Errorf("metadata provider not found")
	}

	media, err := anilistPlatformRef.Get().GetAnime(context.Background(), mediaID)
	if err != nil {
		return nil, err
	}

	return anime.NewEpisodeCollection(anime.NewEpisodeCollectionOptions{
		Media:               media,
		MetadataProviderRef: metadataProviderRef,
		Logger:              m.ctx.logger,
	})
}

func (m *EpisodeTabManager) callEpisodeCollectionHandler(callback goja.Callable, payload map[string]interface{}, fallback *anime.EpisodeCollection) (*anime.EpisodeCollection, error) {
	exported, err := m.callHandler(callback, payload)
	if err != nil {
		return nil, err
	}

	if exported == nil {
		return fallback, nil
	}

	marshaled, err := json.Marshal(exported)
	if err != nil {
		return nil, err
	}

	ret := new(anime.EpisodeCollection)
	if err = json.Unmarshal(marshaled, ret); err != nil {
		return nil, err
	}

	return ret, nil
}

func (m *EpisodeTabManager) callVoidHandler(callback goja.Callable, payload map[string]interface{}) error {
	_, err := m.callHandler(callback, payload)
	return err
}

func (m *EpisodeTabManager) callHandler(callback goja.Callable, payload map[string]interface{}) (interface{}, error) {
	var promise *goja.Promise
	var exported interface{}

	err := m.ctx.scheduler.Schedule(func() error {
		value, err := callback(goja.Undefined(), m.ctx.vm.ToValue(payload))
		if err != nil {
			return err
		}

		if retPromise, ok := value.Export().(*goja.Promise); ok {
			promise = retPromise
			return nil
		}

		exported = value.Export()
		return nil
	})
	if err != nil {
		return nil, err
	}

	if promise == nil {
		return exported, nil
	}

	if err = gojautil.WaitForPromise(context.Background(), promise); err != nil {
		return nil, err
	}

	err = m.ctx.scheduler.Schedule(func() error {
		if promise.State() == goja.PromiseStateRejected {
			return fmt.Errorf("promise rejected: %v", promise.Result().Export())
		}

		exported = promise.Result().Export()
		return nil
	})
	if err != nil {
		return nil, err
	}

	return exported, nil
}

func (m *EpisodeTabManager) getOptions(obj *goja.Object) (*episodeTabOptions, error) {
	if obj == nil {
		return nil, fmt.Errorf("expected props object")
	}

	options := &episodeTabOptions{}

	nameVal := obj.Get("name")
	if nameVal == nil || goja.IsUndefined(nameVal) || goja.IsNull(nameVal) {
		return nil, fmt.Errorf("registerEntryEpisodeTab requires a name")
	}
	name, ok := nameVal.Export().(string)
	if !ok {
		return nil, fmt.Errorf("registerEntryEpisodeTab name must be a string")
	}
	options.Name = name

	iconVal := obj.Get("icon")
	if iconVal != nil && !goja.IsUndefined(iconVal) && !goja.IsNull(iconVal) {
		icon, ok := iconVal.Export().(string)
		if !ok {
			return nil, fmt.Errorf("registerEntryEpisodeTab icon must be a string")
		}
		options.Icon = icon
	}

	return options, nil
}
