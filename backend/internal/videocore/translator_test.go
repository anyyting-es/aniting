package videocore

import (
	"context"
	"io"
	"net/http"
	"net/http/httptest"
	"seanime/internal/util"
	"seanime/internal/util/result"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/goccy/go-json"
	"github.com/rs/zerolog"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"golang.org/x/time/rate"
)

type translatorCall struct {
	targetLang string
	texts      []string
}

type recordingTranslator struct {
	mu    sync.Mutex
	calls []translatorCall
}

func (t *recordingTranslator) TranslateBatch(_ context.Context, texts []string, targetLang string) ([]string, error) {
	t.mu.Lock()
	t.calls = append(t.calls, translatorCall{targetLang: targetLang, texts: append([]string(nil), texts...)})
	t.mu.Unlock()

	ret := make([]string, len(texts))
	for i, text := range texts {
		ret[i] = targetLang + ":" + text
	}
	return ret, nil
}

func (t *recordingTranslator) snapshot() []translatorCall {
	t.mu.Lock()
	defer t.mu.Unlock()
	return append([]translatorCall(nil), t.calls...)
}

func newTestTranslatorService(t *testing.T, translator Translator) *TranslatorService {
	t.Helper()

	logger := util.NewLogger()
	service := &TranslatorService{
		vc:         &VideoCore{logger: logger},
		translator: translator,
		targetLang: "en",
		cache:      result.NewBoundedCache[string, string](10000),
		queue:      make(chan request, 1000),
		close:      make(chan struct{}),
		logSampler: new(logger.Sample(&zerolog.BasicSampler{N: 500})),
	}
	go service.processQueue()
	t.Cleanup(service.Shutdown)
	return service
}

func TestTranslatorBatchByTargetLanguage(t *testing.T) {
	translator := &recordingTranslator{}
	service := newTestTranslatorService(t, translator)

	ctx, cancel := context.WithTimeout(context.Background(), time.Second)
	defer cancel()

	type translationResult struct {
		text string
		err  error
	}
	esCh := make(chan translationResult, 1)
	frCh := make(chan translationResult, 1)

	// different languages can arrive in the same queue window during playback
	go func() {
		text, err := service.TranslateText(ctx, "hello", "es")
		esCh <- translationResult{text: text, err: err}
	}()
	go func() {
		text, err := service.TranslateText(ctx, "world", "fr")
		frCh <- translationResult{text: text, err: err}
	}()

	es := <-esCh
	fr := <-frCh
	require.NoError(t, es.err)
	require.NoError(t, fr.err)
	assert.Equal(t, "es:hello", es.text)
	assert.Equal(t, "fr:world", fr.text)

	calls := translator.snapshot()
	require.Len(t, calls, 2)
	byLang := map[string][]string{}
	for _, call := range calls {
		byLang[call.targetLang] = call.texts
	}
	assert.Equal(t, []string{"hello"}, byLang["es"])
	assert.Equal(t, []string{"world"}, byLang["fr"])
}

func TestTranslatorQueueShutdown(t *testing.T) {
	service := newTestTranslatorService(t, &recordingTranslator{})
	service.Shutdown()

	// callers should not sit on a request that no worker can consume
	_, err := service.TranslateText(context.Background(), "hello", "es")
	require.ErrorIs(t, err, errTranslatorClosed)
}

func TestOAIComp_TranslatorUsesCustomEndpoint(t *testing.T) {
	logger := util.NewLogger()
	var requestPath string
	var authHeader string
	var payload openAIRequest

	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		requestPath = r.URL.Path
		authHeader = r.Header.Get("Authorization")
		require.NoError(t, json.NewDecoder(r.Body).Decode(&payload))

		var translationPayload openAITranslationPayload
		require.NoError(t, json.Unmarshal([]byte(payload.Messages[1].Content), &translationPayload))
		responseContent, err := json.Marshal(openAITranslationObjectResponse{
			RequestID:    translationPayload.RequestID,
			Translations: []openAITranslationItem{{ID: 0, Text: "hola"}},
		})
		require.NoError(t, err)
		response, err := json.Marshal(openAIResponse{Choices: []struct {
			Message struct {
				Content string `json:"content"`
			} `json:"message"`
		}{{Message: struct {
			Content string `json:"content"`
		}{Content: string(responseContent)}}}})
		require.NoError(t, err)
		_, _ = w.Write(response)
	}))
	t.Cleanup(server.Close)

	translator := NewOpenAITranslator(openAITranslatorOptions{
		BaseUrl: server.URL + "/v1",
		Model:   "local-model",
		Logger:  logger,
	})
	translator.client = server.Client()

	translated, err := translator.TranslateBatch(context.Background(), []string{"hello"}, "tr")
	require.NoError(t, err)

	assert.Equal(t, "/v1/chat/completions", requestPath)
	assert.Empty(t, authHeader)
	assert.Equal(t, "local-model", payload.Model)
	assert.False(t, payload.Stream)
	assert.Zero(t, payload.Temperature)
	assert.Contains(t, payload.Messages[0].Content, "Turkish (tr)")
	assert.Equal(t, []string{"hola"}, translated)
}

func TestOAIComp_RetryResponseFormat(t *testing.T) {
	logger := util.NewLogger()
	var payloads []openAIRequest

	translator := NewOpenAITranslator(openAITranslatorOptions{
		BaseUrl:      "http://example.test/v1",
		Model:        "local-model",
		MaxBatchSize: 8,
		JSONMode:     true,
		Logger:       logger,
	})
	translator.client = &http.Client{Transport: roundTripFunc(func(req *http.Request) (*http.Response, error) {
		var payload openAIRequest
		require.NoError(t, json.NewDecoder(req.Body).Decode(&payload))
		payloads = append(payloads, payload)

		if len(payloads) == 1 {
			return testHTTPResponse(req, http.StatusBadRequest, `{"error":"'response_format.type' must be 'json_schema' or 'text'"}`), nil
		}

		responseContent := `{"translations":[{"id":0,"text":"something translated"}]}`
		response, err := json.Marshal(openAIResponse{Choices: []struct {
			Message struct {
				Content string `json:"content"`
			} `json:"message"`
		}{{Message: struct {
			Content string `json:"content"`
		}{Content: responseContent}}}})
		require.NoError(t, err)
		return testHTTPResponse(req, http.StatusOK, string(response)), nil
	})}

	translated, err := translator.TranslateBatch(context.Background(), []string{"hello"}, "tr")
	require.NoError(t, err)

	require.Len(t, payloads, 2)
	require.NotNil(t, payloads[0].ResponseFormat)
	assert.Equal(t, "json_schema", payloads[0].ResponseFormat.Type)
	require.NotNil(t, payloads[0].ResponseFormat.JSONSchema)
	assert.Equal(t, "subtitle_translation_batch", payloads[0].ResponseFormat.JSONSchema.Name)
	assert.Nil(t, payloads[1].ResponseFormat)
	assert.Equal(t, []string{"something translated"}, translated)
}

func TestOAI_RejectStaleArrayWhenRequestIDExpected(t *testing.T) {
	// local runners can return stale valid-looking arrays from prompt cache; require the nonce
	_, err := parseOpenAITranslations(`["still english"]`, 1, "request-1")
	require.Error(t, err)
	assert.Contains(t, err.Error(), "translations object")
}

func TestOAI_AllowObjectWithoutRequestID(t *testing.T) {
	// some local instruct models follow the object shape but drop the nonce
	translated, err := parseOpenAITranslations(`{"translations":[{"id":0,"text":"something translated"}]}`, 1, "request-1")
	require.NoError(t, err)
	assert.Equal(t, []string{"something translated"}, translated)
}

func TestNormalizeOpenAIEndpoint(t *testing.T) {
	assert.Equal(t, "http://localhost:11434/v1/chat/completions", normalizeOpenAiEndpoint("localhost:11434/v1"))
	assert.Equal(t, "http://localhost:1234/v1/chat/completions", normalizeOpenAiEndpoint("http://localhost:1234/v1/chat/completions"))
}

func TestFreeGoogleTranslatorReturnsLimiterCancellation(t *testing.T) {
	logger := util.NewLogger()
	limiter := rate.NewLimiter(rate.Every(time.Hour), 1)
	require.NoError(t, limiter.Wait(context.Background()))

	translator := &FreeGoogleTranslator{
		limiter: limiter,
		client:  &http.Client{},
		logger:  logger,
	}
	ctx, cancel := context.WithCancel(context.Background())
	cancel()

	// canceled playback should not be treated as an empty successful translation
	_, err := translator.TranslateBatch(ctx, []string{"hello"}, "es")
	require.ErrorIs(t, err, context.Canceled)
}

type roundTripFunc func(*http.Request) (*http.Response, error)

func (fn roundTripFunc) RoundTrip(req *http.Request) (*http.Response, error) {
	return fn(req)
}

func testHTTPResponse(req *http.Request, statusCode int, body string) *http.Response {
	return &http.Response{
		StatusCode: statusCode,
		Header:     make(http.Header),
		Body:       io.NopCloser(strings.NewReader(body)),
		Request:    req,
	}
}
