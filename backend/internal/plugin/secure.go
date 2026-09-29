package plugin

import (
	"fmt"
	"seanime/internal/extension"
	"seanime/internal/extension_repo/prompt"
	"seanime/internal/util/result"
	"strings"
)

func (a *AppContextImpl) secureOn() bool {
	database, ok := a.database.Get()
	if !ok {
		return false
	}

	settings, err := database.GetSettings()
	if err != nil || settings == nil || settings.Library == nil {
		return false
	}

	return settings.Library.EnableExtensionSecureMode
}

func (a *AppContextImpl) securePath(ext *extension.Extension, cache *result.Cache[string, bool], kind string, action string, paths ...string) error {
	if !a.secureOn() {
		return nil
	}

	details := cleanDetails(paths...)
	if len(details) == 0 {
		return nil
	}
	resource := "the requested path"
	if len(details) == 1 {
		resource = details[0]
	} else if len(details) > 1 {
		resource = "these paths"
	}
	messageResource := "this path"
	if len(details) > 1 {
		messageResource = "these paths"
	}

	return a.ask(ext, prompt.Options{
		Kind:     kind,
		Action:   action + " \"" + resource + "\"",
		Resource: resource,
		Message:  fmt.Sprintf("Allow \"%s\" to %s %s?", extName(ext), action, messageResource),
		Details:  details,
		Cache:    cache,
		CacheKey: promptKey(append([]string{kind, action}, details...)...),
	})
}

func (a *AppContextImpl) secureCmd(ext *extension.Extension, cache *result.Cache[string, bool], name string, args ...string) error {
	if !a.secureOn() {
		return nil
	}

	command := strings.TrimSpace(strings.Join(append([]string{name}, args...), " "))
	return a.ask(ext, prompt.Options{
		Kind:     "system",
		Action:   "run \"" + command + "\"",
		Resource: command,
		Message:  fmt.Sprintf("Allow \"%s\" to run this command?", extName(ext)),
		Details:  []string{command},
		Cache:    cache,
		CacheKey: promptKey("system", "run", command),
	})
}

func (a *AppContextImpl) secureDownload(ext *extension.Extension, cache *result.Cache[string, bool], url string, destination string) error {
	if !a.secureOn() {
		return nil
	}

	details := cleanDetails(destination, url)
	return a.ask(ext, prompt.Options{
		Kind:     "download",
		Action:   "download a file to \"" + destination + "\"",
		Resource: destination,
		Message:  fmt.Sprintf("Allow \"%s\" to download a file here?", extName(ext)),
		Details:  details,
		Cache:    cache,
		CacheKey: promptKey("download", destination, url),
	})
}

func extName(ext *extension.Extension) string {
	if ext == nil || strings.TrimSpace(ext.Name) == "" {
		return "Extension"
	}
	return ext.Name
}

func cleanDetails(paths ...string) []string {
	ret := make([]string, 0, len(paths))
	for _, path := range paths {
		path = strings.TrimSpace(path)
		if path != "" {
			ret = append(ret, path)
		}
	}
	return ret
}
