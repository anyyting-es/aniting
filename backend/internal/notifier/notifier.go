package notifier

import (
	"fmt"
	"path/filepath"
	"seanime/internal/database/models"
	"seanime/internal/util"
	"sync"

	"github.com/rs/zerolog"
	"github.com/samber/mo"
)

type (
	notificationPusher func(title, message, icon string) error

	Notifier struct {
		dataDir  mo.Option[string]
		settings mo.Option[*models.NotificationSettings]
		mu       sync.Mutex
		logoPath string
		push     notificationPusher
		logger   mo.Option[*zerolog.Logger]
	}

	Notification string
)

const (
	AutoDownloader Notification = "Auto Downloader"
	AutoScanner    Notification = "Auto Scanner"
	Debrid         Notification = "Debrid"
)

var GlobalNotifier = NewNotifier()

func init() {
	GlobalNotifier = NewNotifier()
}

func NewNotifier() *Notifier {
	return &Notifier{
		dataDir:  mo.None[string](),
		settings: mo.None[*models.NotificationSettings](),
		mu:       sync.Mutex{},
		push:     defaultPush,
		logger:   mo.None[*zerolog.Logger](),
	}
}

func (n *Notifier) SetSettings(datadir string, settings *models.NotificationSettings, logger *zerolog.Logger) {
	if datadir == "" || settings == nil {
		return
	}

	n.mu.Lock()
	n.dataDir = mo.Some(datadir)
	n.settings = mo.Some(settings)
	n.logoPath = filepath.Join(datadir, "seanime-logo.png")
	if logger != nil {
		n.logger = mo.Some(logger)
	} else {
		n.logger = mo.None[*zerolog.Logger]()
	}
	n.mu.Unlock()
}

func (n *Notifier) canProceed(id Notification) bool {
	n.mu.Lock()
	defer n.mu.Unlock()

	return n.canProceedLocked(id)
}

func (n *Notifier) canProceedLocked(id Notification) bool {
	if !n.dataDir.IsPresent() || !n.settings.IsPresent() {
		return false
	}

	settings := n.settings.MustGet()
	if settings.DisableNotifications {
		return false
	}

	switch id {
	case AutoDownloader:
		return !settings.DisableAutoDownloaderNotifications
	case AutoScanner:
		return !settings.DisableAutoScannerNotifications
	default:
		return true
	}
}

func (n *Notifier) Notify(id Notification, message string) {
	go func() {
		defer util.HandlePanicInModuleThen("notifier/Notify", func() {})

		n.mu.Lock()
		if !n.canProceedLocked(id) {
			n.mu.Unlock()
			return
		}

		push := n.push
		logoPath := n.logoPath
		logger := n.logger.OrElse(nil)
		n.mu.Unlock()

		if push == nil {
			return
		}

		err := push(fmt.Sprintf("Seanime: %s", id), message, logoPath)
		if err != nil {
			if logger != nil {
				logger.Trace().Msgf("notifier: Failed to push notification: %v", err)
			}
			return
		}

		if logger != nil {
			logger.Trace().Msgf("notifier: Pushed notification: %v", id)
		}
	}()
}
