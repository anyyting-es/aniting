package plugin

import (
	"encoding/json"
	"errors"
	"seanime/internal/database/models"
	"seanime/internal/extension"
	gojautil "seanime/internal/util/goja"
	"seanime/internal/util/result"
	"strings"
	"sync"

	"github.com/dop251/goja"
	"github.com/rs/zerolog"
	"gorm.io/gorm"
)

// Storage is used to store data for an extension.
// A new binding is created for each runtime, but the cache and watchers are shared per extension.
type Storage struct {
	ctx       *AppContextImpl
	ext       *extension.Extension
	logger    *zerolog.Logger
	runtime   *goja.Runtime
	state     *storageState
	scheduler *gojautil.Scheduler
}

type storageState struct {
	keyDataCache   *result.Map[string, interface{}]
	keySubscribers *result.Map[string, []*storageSubscriber]
	stopOnce       sync.Once
}

type storageSubscriber struct {
	channel   chan interface{}
	closeOnce sync.Once
}

var (
	ErrDatabaseNotInitialized = errors.New("database is not initialized")
	storageStates             = result.NewMap[string, *storageState]()
	storageStatesMu           sync.Mutex
)

func getOrCreateStorageState(extID string) *storageState {
	if state, ok := storageStates.Get(extID); ok {
		return state
	}

	storageStatesMu.Lock()
	defer storageStatesMu.Unlock()

	if state, ok := storageStates.Get(extID); ok {
		return state
	}

	state := &storageState{
		keyDataCache:   result.NewMap[string, interface{}](),
		keySubscribers: result.NewMap[string, []*storageSubscriber](),
	}
	storageStates.Set(extID, state)
	return state
}

func (s *storageSubscriber) notify(value interface{}) {
	defer func() {
		_ = recover()
	}()

	select {
	case s.channel <- value:
	default:
	}
}

func (s *storageSubscriber) close() {
	s.closeOnce.Do(func() {
		close(s.channel)
	})
}

func (s *storageState) stop() {
	s.stopOnce.Do(func() {
		s.keySubscribers.Range(func(key string, subscribers []*storageSubscriber) bool {
			for _, subscriber := range subscribers {
				subscriber.close()
			}
			return true
		})
		s.keySubscribers.Clear()
		s.keyDataCache.Clear()
	})
}

// BindStorage binds the storage API to the Goja runtime.
// Permissions need to be checked by the caller.
// Permissions needed: storage
func (a *AppContextImpl) BindStorage(vm *goja.Runtime, logger *zerolog.Logger, ext *extension.Extension, scheduler *gojautil.Scheduler) *Storage {
	storage := &Storage{
		ctx:       a,
		ext:       ext,
		logger:    new(logger.With().Str("id", ext.ID).Logger()),
		runtime:   vm,
		state:     getOrCreateStorageState(ext.ID),
		scheduler: scheduler,
	}
	storageObj := vm.NewObject()
	_ = storageObj.Set("get", func(key string) (interface{}, error) {
		value, err := storage.Get(key)
		if err != nil {
			return nil, err
		}
		// devnote: clone the value so we don't run into concurrent map write panics
		return cloneRefValue(value), nil
	})
	_ = storageObj.Set("getUnsafe", storage.Get)
	_ = storageObj.Set("set", storage.Set)
	_ = storageObj.Set("remove", storage.Delete)
	_ = storageObj.Set("drop", storage.Drop)
	_ = storageObj.Set("clear", storage.Clear)
	_ = storageObj.Set("keys", storage.Keys)
	_ = storageObj.Set("has", storage.Has)
	_ = storageObj.Set("watch", storage.Watch)
	_ = vm.Set("$storage", storageObj)

	return storage
}

// Stop closes all subscriber channels.
func (s *Storage) Stop() {
	s.state.stop()
	storageStatesMu.Lock()
	defer storageStatesMu.Unlock()
	storageStates.Delete(s.ext.ID)
}

// getDB returns the database instance or an error if not initialized
func (s *Storage) getDB() (*gorm.DB, error) {
	db, ok := s.ctx.database.Get()
	if !ok {
		return nil, ErrDatabaseNotInitialized
	}
	return db.Gorm(), nil
}

// getPluginData retrieves the plugin data from the database
// If createIfNotExists is true, it will create an empty record if none exists
// This method always fetches fresh data from the database
func (s *Storage) getPluginData(createIfNotExists bool) (*models.PluginData, error) {
	db, err := s.getDB()
	if err != nil {
		return nil, err
	}

	var pluginData models.PluginData
	if err := db.Where("plugin_id = ?", s.ext.ID).First(&pluginData).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) && createIfNotExists {
			// Create empty data structure
			baseData := make(map[string]interface{})
			baseDataMarshaled, err := json.Marshal(baseData)
			if err != nil {
				return nil, err
			}

			newPluginData := &models.PluginData{
				PluginID: s.ext.ID,
				Data:     baseDataMarshaled,
			}

			if err := db.Create(newPluginData).Error; err != nil {
				return nil, err
			}

			return newPluginData, nil
		}
		return nil, err
	}

	return &pluginData, nil
}

// getDataMap unmarshals the plugin data into a map
func (s *Storage) getDataMap(pluginData *models.PluginData) (map[string]interface{}, error) {
	var data map[string]interface{}
	if err := json.Unmarshal(pluginData.Data, &data); err != nil {
		return make(map[string]interface{}), err
	}
	return data, nil
}

// saveDataMap marshals and saves the data map to the database
func (s *Storage) saveDataMap(pluginData *models.PluginData, data map[string]interface{}) error {
	marshaled, err := json.Marshal(data)
	if err != nil {
		return err
	}

	pluginData.Data = marshaled

	db, err := s.getDB()
	if err != nil {
		return err
	}

	err = db.Save(pluginData).Error
	if err != nil {
		return err
	}

	// Clear all caches
	s.state.keyDataCache.Clear()

	return nil
}

// getNestedValue retrieves a value from a nested map using dot notation
func getNestedValue(data map[string]interface{}, path string) interface{} {
	if !strings.Contains(path, ".") {
		return data[path]
	}

	parts := strings.Split(path, ".")
	current := data

	// Navigate through all parts except the last one
	for i := 0; i < len(parts)-1; i++ {
		part := parts[i]
		next, ok := current[part]
		if !ok {
			return nil
		}

		// Try to convert to map for next level
		nextMap, ok := next.(map[string]interface{})
		if !ok {
			// Try to convert from unmarshaled JSON
			jsonMap, ok := next.(map[string]interface{})
			if !ok {
				return nil
			}
			nextMap = jsonMap
		}

		current = nextMap
	}

	// Return the value at the final part
	return current[parts[len(parts)-1]]
}

// setNestedValue sets a value in a nested map using dot notation
// It creates intermediate maps as needed
func setNestedValue(data map[string]interface{}, path string, value interface{}) {
	if !strings.Contains(path, ".") {
		data[path] = value
		return
	}

	parts := strings.Split(path, ".")
	current := data

	// Navigate and create intermediate maps as needed
	for i := 0; i < len(parts)-1; i++ {
		part := parts[i]
		next, ok := current[part]
		if !ok {
			// Create new map if key doesn't exist
			next = make(map[string]interface{})
			current[part] = next
		}

		// Try to convert to map for next level
		nextMap, ok := next.(map[string]interface{})
		if !ok {
			// Try to convert from unmarshaled JSON
			jsonMap, ok := next.(map[string]interface{})
			if !ok {
				// Replace with a new map if not convertible
				nextMap = make(map[string]interface{})
				current[part] = nextMap
			} else {
				nextMap = jsonMap
				current[part] = nextMap
			}
		}

		current = nextMap
	}

	// Set the value at the final part
	current[parts[len(parts)-1]] = value
}

// deleteNestedValue deletes a value from a nested map using dot notation
// Returns true if the key was found and deleted
func deleteNestedValue(data map[string]interface{}, path string) bool {
	if !strings.Contains(path, ".") {
		_, exists := data[path]
		if exists {
			delete(data, path)
			return true
		}
		return false
	}

	parts := strings.Split(path, ".")
	current := data

	// Navigate through all parts except the last one
	for i := 0; i < len(parts)-1; i++ {
		part := parts[i]
		next, ok := current[part]
		if !ok {
			return false
		}

		// Try to convert to map for next level
		nextMap, ok := next.(map[string]interface{})
		if !ok {
			// Try to convert from unmarshaled JSON
			jsonMap, ok := next.(map[string]interface{})
			if !ok {
				return false
			}
			nextMap = jsonMap
		}

		current = nextMap
	}

	// Delete the value at the final part
	lastPart := parts[len(parts)-1]
	_, exists := current[lastPart]
	if exists {
		delete(current, lastPart)
		return true
	}
	return false
}

// hasNestedKey checks if a nested key exists using dot notation
func hasNestedKey(data map[string]interface{}, path string) bool {
	if !strings.Contains(path, ".") {
		_, exists := data[path]
		return exists
	}

	parts := strings.Split(path, ".")
	current := data

	// Navigate through all parts except the last one
	for i := 0; i < len(parts)-1; i++ {
		part := parts[i]
		next, ok := current[part]
		if !ok {
			return false
		}

		// Try to convert to map for next level
		nextMap, ok := next.(map[string]interface{})
		if !ok {
			// Try to convert from unmarshaled JSON
			jsonMap, ok := next.(map[string]interface{})
			if !ok {
				return false
			}
			nextMap = jsonMap
		}

		current = nextMap
	}

	// Check if the final key exists
	_, exists := current[parts[len(parts)-1]]
	return exists
}

// getAllKeys recursively gets all keys from a nested map using dot notation
func getAllKeys(data map[string]interface{}, prefix string) []string {
	keys := make([]string, 0)

	for key, value := range data {
		fullKey := key
		if prefix != "" {
			fullKey = prefix + "." + key
		}

		keys = append(keys, fullKey)

		// If value is a map, recursively get its keys
		if nestedMap, ok := value.(map[string]interface{}); ok {
			nestedKeys := getAllKeys(nestedMap, fullKey)
			keys = append(keys, nestedKeys...)
		}
	}

	return keys
}

// notifyKeyAndParents sends notifications to subscribers of the given key and its parent keys
// If the value is nil, it indicates the key was deleted
func (s *Storage) notifyKeyAndParents(key string, value interface{}, data map[string]interface{}) {
	// Notify direct subscribers of this key
	if subscribers, ok := s.state.keySubscribers.Get(key); ok {
		for _, subscriber := range subscribers {
			subscriber.notify(value)
		}
	}

	// Also notify parent key subscribers if this is a nested key
	if strings.Contains(key, ".") {
		parts := strings.Split(key, ".")
		for i := 1; i < len(parts); i++ {
			parentKey := strings.Join(parts[:i], ".")
			if subscribers, ok := s.state.keySubscribers.Get(parentKey); ok {
				// Get the current parent value
				parentValue := getNestedValue(data, parentKey)
				for _, subscriber := range subscribers {
					subscriber.notify(parentValue)
				}
			}
		}
	}
}

// invalidateKeyAndChildren removes a key and all its nested children from the cache
func (s *Storage) invalidateKeyAndChildren(key string) {
	// Remove the key itself
	s.state.keyDataCache.Delete(key)

	// Remove all child keys (keys that start with "key.")
	prefix := key + "."
	var keysToDelete []string
	s.state.keyDataCache.Range(func(k string, v interface{}) bool {
		if strings.HasPrefix(k, prefix) {
			keysToDelete = append(keysToDelete, k)
		}
		return true
	})

	for _, k := range keysToDelete {
		s.state.keyDataCache.Delete(k)
	}
}

func (s *Storage) removeSubscriber(key string, target *storageSubscriber) {
	existingSubscribers, ok := s.state.keySubscribers.Get(key)
	if !ok {
		return
	}

	newSubscribers := make([]*storageSubscriber, 0, len(existingSubscribers))
	for _, subscriber := range existingSubscribers {
		if subscriber != target {
			newSubscribers = append(newSubscribers, subscriber)
		}
	}

	if len(newSubscribers) > 0 {
		s.state.keySubscribers.Set(key, newSubscribers)
	} else {
		s.state.keySubscribers.Delete(key)
	}
}

func (s *Storage) Watch(key string, callback goja.Callable) goja.Value {
	s.logger.Trace().Msgf("plugin: Watching key %s", key)

	// Create a channel to receive updates
	subscriber := &storageSubscriber{channel: make(chan interface{}, 100)}

	// Add this channel to the subscribers for this key
	subscribers := []*storageSubscriber{}
	if existingSubscribers, ok := s.state.keySubscribers.Get(key); ok {
		subscribers = existingSubscribers
	}
	subscribers = append(subscribers, subscriber)
	s.state.keySubscribers.Set(key, subscribers)

	// Start a goroutine to listen for updates
	go func() {
		for value := range subscriber.channel {
			// Call the callback with the new value
			s.scheduler.ScheduleAsync(func() error {
				_, err := callback(goja.Undefined(), s.runtime.ToValue(cloneRefValue(value)))
				if err != nil {
					s.logger.Error().Err(err).Msgf("plugin: Error calling watch callback for key %s", key)
				}
				return nil
			})
		}
	}()

	// Check if the key currently exists and immediately send its value
	// This allows watchers to get the current value right away
	currentValue, _ := s.Get(key)
	if currentValue != nil {
		subscriber.notify(currentValue)
	}

	// Return a function that can be used to cancel the watch
	cancelFn := func() {
		subscriber.close()
		s.removeSubscriber(key, subscriber)
	}

	return s.runtime.ToValue(cancelFn)
}

func (s *Storage) Delete(key string) error {
	s.logger.Trace().Msgf("plugin: Deleting key %s", key)

	// Remove from key cache and all nested keys
	s.invalidateKeyAndChildren(key)

	pluginData, err := s.getPluginData(false)
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil
		}
		return err
	}

	data, err := s.getDataMap(pluginData)
	if err != nil {
		return err
	}

	if deleteNestedValue(data, key) {
		if err := s.saveDataMap(pluginData, data); err != nil {
			return err
		}
		// Notify subscribers that the key was deleted
		s.notifyKeyAndParents(key, nil, data)
	}

	return nil
}

func (s *Storage) Drop() error {
	s.logger.Trace().Msg("plugin: Dropping storage")

	// // Close all subscriber channels
	// s.keySubscribers.Range(func(key string, subscribers []chan interface{}) bool {
	// 	for _, ch := range subscribers {
	// 		close(ch)
	// 	}
	// 	return true
	// })
	// s.keySubscribers.Clear()

	// Clear caches
	s.state.keyDataCache.Clear()

	db, err := s.getDB()
	if err != nil {
		return err
	}

	return db.Where("plugin_id = ?", s.ext.ID).Delete(&models.PluginData{}).Error
}

func (s *Storage) Clear() error {
	s.logger.Trace().Msg("plugin: Clearing storage")

	// Clear key cache
	s.state.keyDataCache.Clear()

	pluginData, err := s.getPluginData(true)
	if err != nil {
		return err
	}

	// Get all keys before clearing
	data, err := s.getDataMap(pluginData)
	if err != nil {
		return err
	}

	// Get all keys to notify subscribers
	keys := getAllKeys(data, "")

	// Create empty data map
	cleanData := make(map[string]interface{})

	// Save the empty data first
	if err := s.saveDataMap(pluginData, cleanData); err != nil {
		return err
	}

	// Notify all subscribers that their keys were cleared
	for _, key := range keys {
		s.notifyKeyAndParents(key, nil, cleanData)
	}

	return nil
}

func (s *Storage) Keys() ([]string, error) {
	pluginData, err := s.getPluginData(false)
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return []string{}, nil
		}
		return nil, err
	}

	data, err := s.getDataMap(pluginData)
	if err != nil {
		return nil, err
	}

	return getAllKeys(data, ""), nil
}

func (s *Storage) Has(key string) (bool, error) {
	// Check key cache first
	if s.state.keyDataCache.Has(key) {
		return true, nil
	}

	pluginData, err := s.getPluginData(false)
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return false, nil
		}
		return false, err
	}

	data, err := s.getDataMap(pluginData)
	if err != nil {
		return false, err
	}

	exists := hasNestedKey(data, key)

	// If key exists, we can also cache its value for future Get calls
	if exists {
		value := getNestedValue(data, key)
		if value != nil {
			s.state.keyDataCache.Set(key, value)
		}
	}

	return exists, nil
}

func (s *Storage) Get(key string) (interface{}, error) {
	// Check key cache first
	if cachedValue, ok := s.state.keyDataCache.Get(key); ok {
		return cachedValue, nil
	}

	pluginData, err := s.getPluginData(true)
	if err != nil {
		return nil, err
	}

	data, err := s.getDataMap(pluginData)
	if err != nil {
		return nil, err
	}

	value := getNestedValue(data, key)

	// Cache the value
	if value != nil {
		s.state.keyDataCache.Set(key, value)
	}

	return value, nil
}

func (s *Storage) Set(key string, value interface{}) error {
	s.logger.Trace().Msgf("plugin: Setting key %s", key)

	// Invalidate this key and all its children in cache
	s.invalidateKeyAndChildren(key)

	pluginData, err := s.getPluginData(true)
	if err != nil {
		return err
	}

	data, err := s.getDataMap(pluginData)
	if err != nil {
		data = make(map[string]interface{})
	}

	setNestedValue(data, key, value)

	// Save first to ensure data is persisted
	if err := s.saveDataMap(pluginData, data); err != nil {
		return err
	}

	// Update key cache
	s.state.keyDataCache.Set(key, value)

	// Notify subscribers
	s.notifyKeyAndParents(key, value, data)

	return nil
}
