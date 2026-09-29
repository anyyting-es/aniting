package handlers

import (
	"testing"

	"github.com/stretchr/testify/assert"
)

func TestAddClientIdsInPayload(t *testing.T) {
	payload := map[string]interface{}{
		"clientId": "client-a",
		"payload": map[string]interface{}{
			"clientId": "client-b",
			"events": []interface{}{
				map[string]interface{}{"type": "video-status", "clientId": "client-c"},
				map[string]interface{}{"type": "other", "payload": map[string]interface{}{"clientId": "client-d"}},
			},
		},
	}

	stamped := addClientIdToPayload(payload, "server-client").(map[string]interface{})
	nested := stamped["payload"].(map[string]interface{})
	events := nested["events"].([]interface{})
	first := events[0].(map[string]interface{})
	second := events[1].(map[string]interface{})
	secondPayload := second["payload"].(map[string]interface{})

	assert.Equal(t, "server-client", stamped["clientId"])
	assert.Equal(t, "server-client", nested["clientId"])
	assert.Equal(t, "server-client", first["clientId"])
	assert.Equal(t, "server-client", secondPayload["clientId"])
}
