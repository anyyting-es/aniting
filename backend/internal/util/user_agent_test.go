package util

import (
	"encoding/json"
	"errors"
	"io"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestGetOnlineUserAgentsExternal(t *testing.T) {
	if os.Getenv("SEANIME_RUN_EXTERNAL_TESTS") != "true" {
		t.Skip("external network test; set SEANIME_RUN_EXTERNAL_TESTS=true to enable")
	}

	userAgents, err := getOnlineUserAgents()
	if err != nil {
		t.Fatalf("Failed to get online user agents: %v", err)
	}
	if len(userAgents) == 0 {
		t.Fatal("expected at least one user agent")
	}
}

func TestTransformUserAgentDataToSliceFile(t *testing.T) {

	jsonlFilePath := filepath.Join("data", "user_agents.jsonl")

	jsonlFile, err := os.Open(jsonlFilePath)
	if err != nil {
		t.Fatalf("Failed to open JSONL file: %v", err)
	}
	defer jsonlFile.Close()

	sliceFilePath := filepath.Join(t.TempDir(), "user_agent_list.go")
	sliceFile, err := os.Create(sliceFilePath)
	if err != nil {
		t.Fatalf("Failed to create slice file: %v", err)
	}
	defer sliceFile.Close()

	sliceFile.WriteString("package util\n\nvar UserAgentList = []string{\n")

	type UserAgent struct {
		UserAgent string `json:"useragent"`
	}

	decoder := json.NewDecoder(jsonlFile)
	count := 0
	for {
		var ua UserAgent
		if err := decoder.Decode(&ua); err != nil {
			if errors.Is(err, io.EOF) {
				break
			}
			t.Fatalf("Failed to decode user agent data: %v", err)
		}
		if strings.TrimSpace(ua.UserAgent) == "" {
			continue
		}
		sliceFile.WriteString("\t\"" + ua.UserAgent + "\",\n")
		count++
	}
	sliceFile.WriteString("}\n")

	if count == 0 {
		t.Fatal("expected to transform at least one user agent")
	}

	generated, err := os.ReadFile(sliceFilePath)
	if err != nil {
		t.Fatalf("Failed to read generated slice file: %v", err)
	}
	if !strings.Contains(string(generated), "var UserAgentList = []string{") {
		t.Fatalf("generated slice file did not contain UserAgentList declaration")
	}
}
