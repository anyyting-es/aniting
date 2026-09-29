package util

import (
	"bufio"
	"encoding/json"
	"math/rand"
	"net/http"
	"sync"
	"time"
)

var (
	userAgentList []string
	uaMu          sync.RWMutex
)

var UserAgentList = []string{
	"Mozilla/5.0 (Macintosh; Intel Mac OS X 14_0) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36",
	"Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36",
	"Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36",
	"Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1",
	"Mozilla/5.0 (Linux; Android 15; Pixel 9) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Mobile Safari/537.36",
}

func getOnlineUserAgents() ([]string, error) {
	link := "https://raw.githubusercontent.com/fake-useragent/fake-useragent/refs/heads/main/src/fake_useragent/data/browsers.jsonl"

	client := &http.Client{
		Timeout: 10 * time.Second,
	}
	response, err := client.Get(link)
	if err != nil {
		return nil, err
	}
	defer response.Body.Close()

	var agents []string
	type UserAgent struct {
		UserAgent string `json:"useragent"`
	}

	scanner := bufio.NewScanner(response.Body)
	for scanner.Scan() {
		line := scanner.Text()
		var ua UserAgent
		if err := json.Unmarshal([]byte(line), &ua); err != nil {
			return nil, err
		}
		agents = append(agents, ua.UserAgent)
	}

	return agents, nil
}

func GetRandomUserAgent() string {
	uaMu.RLock()
	defer uaMu.RUnlock()

	if len(userAgentList) > 0 {
		return userAgentList[rand.Intn(len(userAgentList))]
	}
	return UserAgentList[rand.Intn(len(UserAgentList))]
}
