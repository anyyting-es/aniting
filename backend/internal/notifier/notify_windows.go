//go:build windows

package notifier

import (
	"github.com/go-toast/toast"
)

func defaultPush(title, message, icon string) error {
	notification := toast.Notification{
		AppID:   "Aniting",
		Title:   title,
		Message: message,
		Icon:    icon,
	}

	return notification.Push()
}
