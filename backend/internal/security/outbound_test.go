package security

import "testing"

func TestValidateOutboundURL(t *testing.T) {
	t.Cleanup(func() {
		SetSecureMode("")
	})

	t.Run("allows localhost outside strict mode", func(t *testing.T) {
		SetSecureMode("")
		if err := ValidateOutboundUrl("http://127.0.0.1:8080"); err != nil {
			t.Fatalf("expected localhost to be allowed outside strict mode: %v", err)
		}
	})

	t.Run("blocks localhost in strict mode", func(t *testing.T) {
		SetSecureMode(SecureModeStrict)
		if err := ValidateOutboundUrl("http://localhost:8080"); err == nil {
			t.Fatal("expected localhost to be blocked in strict mode")
		}
	})

	t.Run("blocks loopback ip in strict mode", func(t *testing.T) {
		SetSecureMode(SecureModeStrict)
		if err := ValidateOutboundUrl("http://127.0.0.1:8080"); err == nil {
			t.Fatal("expected loopback ip to be blocked in strict mode")
		}
	})

	t.Run("blocks private ip in strict mode", func(t *testing.T) {
		SetSecureMode(SecureModeStrict)
		if err := ValidateOutboundUrl("http://192.168.1.10:8080"); err == nil {
			t.Fatal("expected private ip to be blocked in strict mode")
		}
	})

	t.Run("allows public ip in strict mode", func(t *testing.T) {
		SetSecureMode(SecureModeStrict)
		if err := ValidateOutboundUrl("https://1.1.1.1"); err != nil {
			t.Fatalf("expected public ip to be allowed in strict mode: %v", err)
		}
	})
}
