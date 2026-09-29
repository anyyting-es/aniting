//go:build !darwin

package util

func ClearMacAppQuarantine(string) error {
	return nil
}
