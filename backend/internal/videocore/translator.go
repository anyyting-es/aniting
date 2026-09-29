package videocore

import (
	"bytes"
	"context"
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"fmt"
	"io"
	"math/rand"
	"net/http"
	"net/url"
	"regexp"
	"seanime/internal/mkvparser"
	"seanime/internal/util/result"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/5rahim/go-astisub"
	"github.com/goccy/go-json"
	"github.com/google/uuid"
	"github.com/rs/zerolog"
	"golang.org/x/text/language"
	"golang.org/x/text/language/display"
	"golang.org/x/time/rate"
)

const (
	translatorProviderGoogle           = "google"
	translatorProviderDeepL            = "deepl"
	translatorProviderOpenAI           = "openai"
	translatorProviderOpenAICompatible = "openai-compatible"

	defaultOpenAIBaseUrl             = "https://api.openai.com/v1"
	defaultOpenAIModel               = "gpt-4o-mini"
	defaultOpenAICompatibleBaseUrl   = "http://localhost:1234/v1"
	defaultOpenAICompatibleModel     = "local-model"
	defaultOpenAICompatibleBatchSize = 8
	translationBatchTimeout          = 60 * time.Second
	translationWaitTimeout           = translationBatchTimeout + 5*time.Second
)

var (
	errTranslatorClosed = errors.New("translator service closed")
	errOpenAIParse      = errors.New("failed to parse openai response")
	subtitleTagPattern  = regexp.MustCompile(`\{.*?\}`)
)

type openAIAPIError struct {
	statusCode int
	body       string
}

func (e *openAIAPIError) Error() string {
	return fmt.Sprintf("openai API error: %d: %s", e.statusCode, e.body)
}

type translationSettings struct {
	apiKey     string
	provider   string
	targetLang string
	baseUrl    string
	model      string
}

// Translator implemented by different providers
type Translator interface {
	TranslateBatch(ctx context.Context, texts []string, targetLang string) ([]string, error)
}

type TranslatorService struct {
	cache      *result.BoundedCache[string, string]
	translator Translator
	targetLang string
	vc         *VideoCore
	logSampler *zerolog.Logger
	queue      chan request
	close      chan struct{}
	closeOnce  sync.Once
}

func newTranslatorService(vc *VideoCore, settings translationSettings) *TranslatorService {
	t := newTranslator(settings, vc.logger)

	s := &TranslatorService{
		vc:         vc,
		translator: t,
		targetLang: normalizeTargetLang(settings.provider, settings.targetLang),
		cache:      result.NewBoundedCache[string, string](10000),
		queue:      make(chan request, 1000),
		close:      make(chan struct{}),
		logSampler: new(vc.logger.Sample(&zerolog.BasicSampler{N: 500})),
	}

	go s.processQueue()

	return s
}

func newTranslator(settings translationSettings, logger *zerolog.Logger) Translator {
	switch normalizeTranslatorProvider(settings.provider) {
	case translatorProviderOpenAI:
		model := firstNonEmpty(settings.model, defaultOpenAIModel)
		if strings.EqualFold(model, defaultOpenAICompatibleModel) {
			model = defaultOpenAIModel
		}
		return NewOpenAITranslator(openAITranslatorOptions{
			Token:     settings.apiKey,
			BaseUrl:   defaultOpenAIBaseUrl,
			Model:     model,
			NeedsAuth: true,
			Logger:    logger,
		})
	case translatorProviderOpenAICompatible:
		return NewOpenAITranslator(openAITranslatorOptions{
			Token:        settings.apiKey,
			BaseUrl:      firstNonEmpty(settings.baseUrl, defaultOpenAICompatibleBaseUrl),
			Model:        firstNonEmpty(settings.model, defaultOpenAICompatibleModel),
			MaxBatchSize: defaultOpenAICompatibleBatchSize,
			JSONMode:     true,
			Logger:       logger,
		})
	case translatorProviderDeepL:
		return &DeepLTranslator{Token: strings.TrimSpace(settings.apiKey), logger: logger, client: &http.Client{Timeout: 30 * time.Second}}
	default:
		return NewFreeGoogleTranslator(logger)
	}
}

func (s *TranslatorService) Shutdown() {
	s.closeOnce.Do(func() {
		close(s.close)
	})
}

func (s *TranslatorService) TranslateContent(ctx context.Context, content string, format int, targetLang string) (string, error) {
	targetLang = normalizeTargetLang("", targetLang)
	s.vc.logger.Debug().Msgf("videocore: Translating content of type %d to %s", format, targetLang)
	reader := strings.NewReader(content)
	var subs *astisub.Subtitles
	var err error

read:
	switch format {
	case mkvparser.SubtitleTypeASS:
		subs, err = astisub.ReadFromSSA(reader)
	case mkvparser.SubtitleTypeSSA:
		subs, err = astisub.ReadFromSSA(reader)
	case mkvparser.SubtitleTypeSRT:
		subs, err = astisub.ReadFromSRT(reader)
	case mkvparser.SubtitleTypeSTL:
		subs, err = astisub.ReadFromSTL(reader, astisub.STLOptions{IgnoreTimecodeStartOfProgramme: true})
	case mkvparser.SubtitleTypeTTML:
		subs, err = astisub.ReadFromTTML(reader)
	case mkvparser.SubtitleTypeWEBVTT:
		subs, err = astisub.ReadFromWebVTT(reader)
	case mkvparser.SubtitleTypeUnknown:
		detectedType := mkvparser.DetectSubtitleType(content)
		if detectedType == mkvparser.SubtitleTypeUnknown {
			s.vc.logger.Error().Msg("videocore: Failed to detect subtitle format")
			return "", fmt.Errorf("failed to detect subtitle format")
		}
		format = detectedType
		reader = strings.NewReader(content)
		goto read
	default:
		s.vc.logger.Error().Msgf("videocore: Unsupported subtitle format: %d", format)
		return "", fmt.Errorf("unsupported subtitle format: %d", format)
	}

	if err != nil {
		s.vc.logger.Error().Err(err).Msg("videocore: Failed to parse subtitles")
		return "", fmt.Errorf("parsing failed: %w", err)
	}

	type lineRef struct {
		itemIndex int
		cleaned   string
	}

	var linesToTranslate []lineRef

	// Scan items, check cache, and queue missing lines
	for i, item := range subs.Items {
		var textBuilder strings.Builder
		for _, line := range item.Lines {
			for _, lineItem := range line.Items {
				textBuilder.WriteString(lineItem.Text)
			}
			textBuilder.WriteString(" ")
		}
		fullText := strings.TrimSpace(textBuilder.String())

		if fullText == "" {
			continue
		}

		cleaned := cleanSubtitleText(fullText)
		cacheKey := generateCacheKey(cleaned, targetLang)

		if val, ok := s.cache.Get(cacheKey); ok {
			// Cache hit, update immediately
			updateItemText(item, val)
		} else {
			// Cache miss, queue it
			linesToTranslate = append(linesToTranslate, lineRef{
				itemIndex: i,
				cleaned:   cleaned,
			})
		}
	}

	// Process in batches
	batchSize := 50
	totalNeeded := len(linesToTranslate)

	for start := 0; start < totalNeeded; start += batchSize {
		end := start + batchSize
		if end > totalNeeded {
			end = totalNeeded
		}

		var batchTexts []string
		for k := start; k < end; k++ {
			batchTexts = append(batchTexts, linesToTranslate[k].cleaned)
		}

		translatedBatch, err := s.translator.TranslateBatch(ctx, batchTexts, targetLang)
		if err != nil {
			s.vc.logger.Error().Err(err).Msgf("videocore: Failed to translate batch at index %d", start)
			return "", fmt.Errorf("batch translation failed at index %d: %w", start, err)
		}
		if len(translatedBatch) != len(batchTexts) {
			return "", fmt.Errorf("batch translation failed at index %d: got %d results, expected %d", start, len(translatedBatch), len(batchTexts))
		}

		// Map results back to original items and cache
		for k, translatedText := range translatedBatch {
			originalRef := linesToTranslate[start+k]

			cacheKey := generateCacheKey(originalRef.cleaned, targetLang)
			s.cache.Set(cacheKey, translatedText)

			updateItemText(subs.Items[originalRef.itemIndex], translatedText)
		}
	}

	s.vc.logger.Debug().Msgf("videocore: Translated %d lines", len(linesToTranslate))

	// Write output
	w := &bytes.Buffer{}
	switch format {
	case mkvparser.SubtitleTypeSSA, mkvparser.SubtitleTypeASS:
		err = subs.WriteToSSA(w)
	case mkvparser.SubtitleTypeSRT:
		err = subs.WriteToSRT(w)
	case mkvparser.SubtitleTypeSTL:
		err = subs.WriteToSTL(w)
	case mkvparser.SubtitleTypeTTML:
		err = subs.WriteToTTML(w)
	case mkvparser.SubtitleTypeWEBVTT:
		err = subs.WriteToWebVTT(w)
	default:
		err = subs.WriteToWebVTT(w)
	}

	if err != nil {
		s.vc.logger.Error().Err(err).Msg("videocore: Failed to write subtitles")
		return "", fmt.Errorf("failed to write subtitles: %w", err)
	}

	return w.String(), nil
}

// TranslateEvent handles single subtitle events from the mkv parser
func (s *TranslatorService) TranslateEvent(ctx context.Context, evt *mkvparser.SubtitleEvent, targetLang string) error {
	targetLang = normalizeTargetLang("", targetLang)
	clean := cleanSubtitleText(evt.Text)
	if clean == "" {
		return nil
	}

	cacheKey := generateCacheKey(clean, targetLang)
	if val, ok := s.cache.Get(cacheKey); ok {
		evt.Text = val
		return nil
	}

	resCh := make(chan textResult, 1)
	if err := s.enqueue(ctx, request{text: clean, targetLang: targetLang, resultChan: resCh}); err != nil {
		return err
	}

	// block until the batch processor finishes (or timeout)
	select {
	case res := <-resCh:
		if res.err != nil {
			s.logSampler.Error().Err(res.err).Msg("videocore: Failed to translate subtitle event")
			return res.err
		}
		// save to cache
		s.cache.Set(cacheKey, res.text)
		evt.Text = res.text
		s.logSampler.Debug().Msgf("videocore: Translated subtitle event: %s", evt.Text)
		return nil
	case <-ctx.Done():
		return ctx.Err()
	case <-time.After(translationWaitTimeout):
		return fmt.Errorf("translation timed out")
	}
}

func (s *TranslatorService) TranslateText(ctx context.Context, text string, targetLang string) (string, error) {
	targetLang = normalizeTargetLang("", targetLang)
	clean := cleanSubtitleText(text)
	if clean == "" {
		return "", nil
	}

	cacheKey := generateCacheKey(clean, targetLang)
	if val, ok := s.cache.Get(cacheKey); ok {
		return val, nil
	}

	resCh := make(chan textResult, 1)
	if err := s.enqueue(ctx, request{text: clean, targetLang: targetLang, resultChan: resCh}); err != nil {
		return "", err
	}

	// block until the batch processor finishes (or timeout)
	select {
	case res := <-resCh:
		if res.err != nil {
			s.logSampler.Error().Err(res.err).Msg("videocore: Failed to translate text")
			return "", res.err
		}
		// save to cache
		s.cache.Set(cacheKey, res.text)
		s.logSampler.Debug().Msgf("videocore: Translated text: %s", res.text)
		return res.text, nil
	case <-ctx.Done():
		return "", ctx.Err()
	case <-time.After(translationWaitTimeout):
		return "", fmt.Errorf("translation timed out")
	}
}

type request struct {
	text       string
	targetLang string
	resultChan chan textResult // response channel for the waiter
}

type textResult struct {
	text string
	err  error
}

func (s *TranslatorService) enqueue(ctx context.Context, req request) error {
	select {
	case <-s.close:
		return errTranslatorClosed
	default:
	}

	select {
	case s.queue <- req:
		return nil
	case <-s.close:
		return errTranslatorClosed
	case <-ctx.Done():
		return ctx.Err()
	}
}

func (s *TranslatorService) processQueue() {
	const maxBatchSize = 50
	const batchTimeout = 100 * time.Millisecond // Wait max to fill a batch

	// buffer holds the current batch of requests
	buffer := make([]request, 0, maxBatchSize)

	flush := func() {
		if len(buffer) == 0 {
			return
		}

		batches := make(map[string][]request)
		for _, req := range buffer {
			batches[req.targetLang] = append(batches[req.targetLang], req)
		}
		buffer = buffer[:0]

		for _, batch := range batches {
			go s.executeBatch(batch)
		}
	}

	fail := func(err error) {
		for {
			select {
			case req := <-s.queue:
				buffer = append(buffer, req)
			default:
				for _, req := range buffer {
					req.resultChan <- textResult{err: err}
					close(req.resultChan)
				}
				buffer = buffer[:0]
				return
			}
		}
	}

	ticker := time.NewTicker(batchTimeout)
	defer ticker.Stop()

	for {
		select {
		case req := <-s.queue:
			buffer = append(buffer, req)
			if len(buffer) >= maxBatchSize {
				flush()
				ticker.Reset(batchTimeout)
			}

		case <-ticker.C:
			flush()

		case <-s.close:
			fail(errTranslatorClosed)
			return
		}
	}
}

// executeBatch performs the actual API call
func (s *TranslatorService) executeBatch(batch []request) {
	if len(batch) == 0 {
		return
	}

	// We assume all in this batch target the same language
	targetLang := batch[0].targetLang
	texts := make([]string, len(batch))

	for i, req := range batch {
		texts[i] = req.text
	}

	// Call the API
	ctx, cancel := context.WithTimeout(context.Background(), translationBatchTimeout)
	defer cancel()

	translatedTexts, err := s.translator.TranslateBatch(ctx, texts, targetLang)

	// Distribute results back to the waiters
	for i, req := range batch {
		if err != nil {
			req.resultChan <- textResult{err: err}
		} else if i < len(translatedTexts) {
			req.resultChan <- textResult{text: translatedTexts[i]}
		} else {
			req.resultChan <- textResult{err: fmt.Errorf("missing translation result")}
		}
		close(req.resultChan)
	}
}

func normalizeTranslatorProvider(provider string) string {
	switch strings.ToLower(strings.TrimSpace(provider)) {
	case translatorProviderDeepL:
		return translatorProviderDeepL
	case translatorProviderOpenAI:
		return translatorProviderOpenAI
	case translatorProviderOpenAICompatible, "openai_compatible", "openai-compatible-api", "custom-openai":
		return translatorProviderOpenAICompatible
	default:
		return translatorProviderGoogle
	}
}

func normalizeTargetLang(provider string, lang string) string {
	lang = strings.TrimSpace(lang)
	if lang == "" {
		lang = "en"
	}
	lang = strings.ReplaceAll(lang, "_", "-")
	if strings.TrimSpace(provider) == "" {
		return lang
	}

	switch normalizeTranslatorProvider(provider) {
	case translatorProviderDeepL:
		return strings.ToUpper(lang)
	case translatorProviderGoogle:
		switch strings.ToLower(lang) {
		case "zh-hans":
			return "zh-cn"
		case "zh-hant":
			return "zh-tw"
		case "nb":
			return "no"
		default:
			return strings.ToLower(lang)
		}
	default:
		return lang
	}
}

// cmp.Or doesn't trim
func firstNonEmpty(values ...string) string {
	for _, value := range values {
		if strings.TrimSpace(value) != "" {
			return strings.TrimSpace(value)
		}
	}
	return ""
}

func updateItemText(item *astisub.Item, text string) {
	item.Lines = []astisub.Line{{
		Items: []astisub.LineItem{{
			Text: text,
		}},
	}}
}

func generateCacheKey(text, lang string) string {
	hash := sha256.Sum256([]byte(text + "|" + lang))
	return hex.EncodeToString(hash[:])
}

func cleanSubtitleText(input string) string {
	return strings.TrimSpace(subtitleTagPattern.ReplaceAllString(input, ""))
}

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

type DeepLTranslator struct {
	Token  string
	logger *zerolog.Logger
	client *http.Client
}

type deepLRequest struct {
	Text       []string `json:"text"`
	TargetLang string   `json:"target_lang"`
}

type deepLResponse struct {
	Translations []struct {
		Text string `json:"text"`
	} `json:"translations"`
}

func (d *DeepLTranslator) TranslateBatch(ctx context.Context, texts []string, targetLang string) ([]string, error) {
	if len(texts) == 0 {
		return []string{}, nil
	}
	if strings.TrimSpace(d.Token) == "" {
		return nil, fmt.Errorf("deepl API key is required")
	}

	targetLang = normalizeTargetLang(translatorProviderDeepL, targetLang)

	u := "https://api-free.deepl.com/v2/translate"
	if !strings.HasSuffix(d.Token, ":fx") {
		u = "https://api.deepl.com/v2/translate"
	}

	payload := deepLRequest{Text: texts, TargetLang: targetLang}
	jsonData, err := json.Marshal(payload)
	if err != nil {
		return nil, err
	}

	for i := 0; i < 3; i++ {
		req, err := http.NewRequestWithContext(ctx, "POST", u, bytes.NewBuffer(jsonData))
		if err != nil {
			return nil, err
		}
		req.Header.Add("Authorization", "DeepL-Auth-Key "+d.Token)
		req.Header.Add("Content-Type", "application/json")

		client := d.client
		if client == nil {
			client = &http.Client{Timeout: 30 * time.Second}
		}
		resp, err := client.Do(req)
		if err != nil {
			if ctx.Err() != nil {
				return nil, ctx.Err()
			}
			return nil, err
		}

		if resp.StatusCode == 429 {
			resp.Body.Close()
			if err := sleepRetry(ctx, resp, i); err != nil {
				return nil, err
			}
			continue
		}

		if resp.StatusCode != http.StatusOK {
			body, _ := io.ReadAll(io.LimitReader(resp.Body, 2048))
			resp.Body.Close()
			return nil, fmt.Errorf("deepl API error: %d: %s", resp.StatusCode, strings.TrimSpace(string(body)))
		}

		var result deepLResponse
		if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
			resp.Body.Close()
			return nil, err
		}
		resp.Body.Close()

		output := make([]string, len(result.Translations))
		for j, t := range result.Translations {
			output[j] = t.Text
		}
		if len(output) != len(texts) {
			return nil, fmt.Errorf("deepl returned mismatching count: got %d, expected %d", len(output), len(texts))
		}
		return output, nil
	}

	return nil, fmt.Errorf("deepl API rate limit exceeded")
}

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

type OpenAITranslator struct {
	Token        string
	endpoint     string
	model        string
	needsAuth    bool
	maxBatchSize int
	jsonMode     bool
	client       *http.Client
	logger       *zerolog.Logger
}

type openAITranslatorOptions struct {
	Token        string
	BaseUrl      string
	Model        string
	NeedsAuth    bool
	MaxBatchSize int
	JSONMode     bool
	Logger       *zerolog.Logger
}

type openAIRequest struct {
	Model          string                `json:"model"`
	Messages       []message             `json:"messages"`
	Temperature    float64               `json:"temperature"`
	Stream         bool                  `json:"stream"`
	ResponseFormat *openAIResponseFormat `json:"response_format,omitempty"`
}

type openAIResponseFormat struct {
	Type       string            `json:"type"`
	JSONSchema *openAIJSONSchema `json:"json_schema,omitempty"`
}

type openAIJSONSchema struct {
	Name   string         `json:"name"`
	Schema map[string]any `json:"schema"`
}

type message struct {
	Role    string `json:"role"`
	Content string `json:"content"`
}

type openAIResponse struct {
	Choices []struct {
		Message struct {
			Content string `json:"content"`
		} `json:"message"`
	} `json:"choices"`
}

type openAITranslationPayload struct {
	RequestID      string                  `json:"request_id"`
	TargetLanguage string                  `json:"target_language"`
	Count          int                     `json:"count"`
	Items          []openAITranslationItem `json:"items"`
}

type openAITranslationItem struct {
	ID   int    `json:"id"`
	Text string `json:"text"`
}

type openAITranslationObjectResponse struct {
	RequestID    string                  `json:"request_id"`
	Translations []openAITranslationItem `json:"translations"`
}

type openAITranslationMapResponse struct {
	RequestID    string            `json:"request_id"`
	Translations map[string]string `json:"translations"`
}

type openAITranslationStringResponse struct {
	RequestID    string   `json:"request_id"`
	Translations []string `json:"translations"`
}

type openAISingleTranslationPayload struct {
	RequestID      string `json:"request_id"`
	TargetLanguage string `json:"target_language"`
	Text           string `json:"text"`
}

type openAISingleTranslationResponse struct {
	RequestID   string `json:"request_id"`
	Translation string `json:"translation"`
}

func NewOpenAITranslator(opts openAITranslatorOptions) *OpenAITranslator {
	endpoint := normalizeOpenAiEndpoint(opts.BaseUrl)
	return &OpenAITranslator{
		Token:        strings.TrimSpace(opts.Token),
		endpoint:     endpoint,
		model:        strings.TrimSpace(opts.Model),
		needsAuth:    opts.NeedsAuth,
		maxBatchSize: opts.MaxBatchSize,
		jsonMode:     opts.JSONMode,
		client:       &http.Client{Timeout: 90 * time.Second},
		logger:       opts.Logger,
	}
}

func (o *OpenAITranslator) TranslateBatch(ctx context.Context, texts []string, targetLang string) ([]string, error) {
	if len(texts) == 0 {
		return []string{}, nil
	}
	if o.needsAuth && o.Token == "" {
		return nil, fmt.Errorf("openai API key is required")
	}
	if strings.TrimSpace(o.model) == "" {
		return nil, fmt.Errorf("openai model is required")
	}

	if o.maxBatchSize > 0 && len(texts) > o.maxBatchSize {
		translatedTexts := make([]string, 0, len(texts))
		for start := 0; start < len(texts); start += o.maxBatchSize {
			end := start + o.maxBatchSize
			if end > len(texts) {
				end = len(texts)
			}

			chunk, err := o.translateCompatibleBatch(ctx, texts[start:end], targetLang)
			if err != nil {
				return nil, err
			}
			translatedTexts = append(translatedTexts, chunk...)
		}
		return translatedTexts, nil
	}
	if o.maxBatchSize > 0 {
		return o.translateCompatibleBatch(ctx, texts, targetLang)
	}

	return o.translateBatch(ctx, texts, targetLang)
}

func (o *OpenAITranslator) translateCompatibleBatch(ctx context.Context, texts []string, targetLang string) ([]string, error) {
	translatedTexts, err := o.translateBatch(ctx, texts, targetLang)
	if err == nil {
		return translatedTexts, nil
	}
	if !errors.Is(err, errOpenAIParse) {
		return nil, err
	}

	if o.logger != nil {
		o.logger.Debug().Err(err).Int("lines", len(texts)).Msg("videocore: OpenAI-compatible batch response failed, retrying smaller batch")
	}
	if len(texts) <= 1 {
		return o.translateSingleBatch(ctx, texts, targetLang)
	}

	mid := len(texts) / 2
	left, err := o.translateCompatibleBatch(ctx, texts[:mid], targetLang)
	if err != nil {
		return nil, err
	}
	right, err := o.translateCompatibleBatch(ctx, texts[mid:], targetLang)
	if err != nil {
		return nil, err
	}
	return append(left, right...), nil
}

func (o *OpenAITranslator) translateBatch(ctx context.Context, texts []string, targetLang string) ([]string, error) {
	targetLanguage := nameTargetLangCode(targetLang)
	requestID := uuid.NewString()
	items := make([]openAITranslationItem, len(texts))
	for i, text := range texts {
		items[i] = openAITranslationItem{ID: i, Text: text}
	}

	systemPrompt := fmt.Sprintf(`You are a subtitle translation engine. Translate every input item to %s.
Return only valid JSON in this exact shape: {"request_id":"%s","translations":[{"id":0,"text":"translated text"}]}.
Return exactly %d translations.
Rules:
- copy request_id exactly as provided
- preserve every id and the input order exactly
- translate each item independently; do not invent, continue, summarize, or replace dialogue
- keep names, honorifics, punctuation, and subtitle line breaks when possible
- do not output the source language except for names, titles, sound effects, or text already in the target language
- no markdown, notes, explanations, or extra keys`, targetLanguage, requestID, len(texts))
	userContent, err := json.Marshal(openAITranslationPayload{
		RequestID:      requestID,
		TargetLanguage: targetLanguage,
		Count:          len(texts),
		Items:          items,
	})
	if err != nil {
		return nil, err
	}

	payload := openAIRequest{
		Model: o.model,
		Messages: []message{
			{Role: "system", Content: systemPrompt},
			{Role: "user", Content: string(userContent)},
		},
		Temperature: 0,
		Stream:      false,
	}
	o.applyBatchResponseFormat(&payload)

	content, err := o.complete(ctx, payload)
	if err != nil {
		return nil, err
	}

	return parseOpenAITranslations(content, len(texts), requestID)
}

func (o *OpenAITranslator) translateSingleBatch(ctx context.Context, texts []string, targetLang string) ([]string, error) {
	translatedTexts := make([]string, len(texts))
	for i, text := range texts {
		translatedText, err := o.translateSingle(ctx, text, targetLang)
		if err != nil {
			return nil, err
		}
		translatedTexts[i] = translatedText
	}
	return translatedTexts, nil
}

func (o *OpenAITranslator) translateSingle(ctx context.Context, text string, targetLang string) (string, error) {
	targetLanguage := nameTargetLangCode(targetLang)
	requestID := uuid.NewString()
	systemPrompt := fmt.Sprintf(`Translate the subtitle text to %s.
Return only valid JSON in this exact shape: {"request_id":"%s","translation":"translated text"}.
Rules:
- copy request_id exactly as provided
- translate only the provided text; do not continue surrounding dialogue
- keep names, punctuation, and line breaks when possible
- no markdown, notes, explanations, or extra keys`, targetLanguage, requestID)
	userContent, err := json.Marshal(openAISingleTranslationPayload{
		RequestID:      requestID,
		TargetLanguage: targetLanguage,
		Text:           text,
	})
	if err != nil {
		return "", err
	}

	payload := openAIRequest{
		Model: o.model,
		Messages: []message{
			{Role: "system", Content: systemPrompt},
			{Role: "user", Content: string(userContent)},
		},
		Temperature: 0,
		Stream:      false,
	}
	o.applySingleResponseFormat(&payload)

	content, err := o.complete(ctx, payload)
	if err != nil {
		return "", err
	}

	return parseOpenAISingleTranslation(content, requestID)
}

func (o *OpenAITranslator) applyBatchResponseFormat(payload *openAIRequest) {
	if !o.jsonMode {
		return
	}
	payload.ResponseFormat = &openAIResponseFormat{
		Type: "json_schema",
		JSONSchema: &openAIJSONSchema{
			Name: "subtitle_translation_batch",
			Schema: map[string]any{
				"type": "object",
				"properties": map[string]any{
					"request_id": map[string]any{"type": "string"},
					"translations": map[string]any{
						"type": "array",
						"items": map[string]any{
							"type": "object",
							"properties": map[string]any{
								"id":   map[string]any{"type": "integer"},
								"text": map[string]any{"type": "string"},
							},
							"required":             []string{"id", "text"},
							"additionalProperties": false,
						},
					},
				},
				"required":             []string{"translations"},
				"additionalProperties": false,
			},
		},
	}
}

func (o *OpenAITranslator) applySingleResponseFormat(payload *openAIRequest) {
	if !o.jsonMode {
		return
	}
	payload.ResponseFormat = &openAIResponseFormat{
		Type: "json_schema",
		JSONSchema: &openAIJSONSchema{
			Name: "subtitle_translation_single",
			Schema: map[string]any{
				"type": "object",
				"properties": map[string]any{
					"request_id":  map[string]any{"type": "string"},
					"translation": map[string]any{"type": "string"},
				},
				"required":             []string{"translation"},
				"additionalProperties": false,
			},
		},
	}
}

func (o *OpenAITranslator) complete(ctx context.Context, payload openAIRequest) (string, error) {
	content, err := o.completeOnce(ctx, payload)
	if err == nil || payload.ResponseFormat == nil || !isResponseFormatError(err) {
		return content, err
	}

	if o.logger != nil {
		o.logger.Debug().Err(err).Msg("videocore: OpenAI-compatible server rejected response_format, retrying without it")
	}
	payload.ResponseFormat = nil
	return o.completeOnce(ctx, payload)
}

func (o *OpenAITranslator) completeOnce(ctx context.Context, payload openAIRequest) (string, error) {
	jsonData, err := json.Marshal(payload)
	if err != nil {
		return "", err
	}

	for i := 0; i < 3; i++ {
		req, err := http.NewRequestWithContext(ctx, "POST", o.endpoint, bytes.NewBuffer(jsonData))
		if err != nil {
			return "", err
		}
		if o.Token != "" {
			req.Header.Add("Authorization", "Bearer "+o.Token)
		}
		req.Header.Add("Content-Type", "application/json")

		client := o.client
		if client == nil {
			client = &http.Client{Timeout: 90 * time.Second}
		}
		resp, err := client.Do(req)
		if err != nil {
			if ctx.Err() != nil {
				return "", ctx.Err()
			}
			return "", err
		}

		if resp.StatusCode == 429 {
			resp.Body.Close()
			if err := sleepRetry(ctx, resp, i); err != nil {
				return "", err
			}
			continue
		}

		if resp.StatusCode != http.StatusOK {
			body, _ := io.ReadAll(io.LimitReader(resp.Body, 2048))
			resp.Body.Close()
			return "", &openAIAPIError{statusCode: resp.StatusCode, body: strings.TrimSpace(string(body))}
		}

		var result openAIResponse
		if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
			resp.Body.Close()
			return "", err
		}
		resp.Body.Close()

		if len(result.Choices) == 0 {
			return "", fmt.Errorf("openai returned no choices")
		}

		return result.Choices[0].Message.Content, nil
	}

	return "", fmt.Errorf("openai API rate limit exceeded")
}

func isResponseFormatError(err error) bool {
	var apiErr *openAIAPIError
	if !errors.As(err, &apiErr) || apiErr.statusCode != http.StatusBadRequest {
		return false
	}
	body := strings.ToLower(apiErr.body)
	return strings.Contains(body, "response_format") || strings.Contains(body, "json_schema") || strings.Contains(body, "json_object")
}

func nameTargetLangCode(lang string) string {
	lang = strings.TrimSpace(strings.ReplaceAll(lang, "_", "-"))
	if lang == "" {
		lang = "en"
	}

	tag, err := language.Parse(lang)
	if err != nil {
		return lang
	}

	name := display.Tags(language.English).Name(tag)
	if name == "" || strings.EqualFold(name, lang) {
		return tag.String()
	}
	return fmt.Sprintf("%s (%s)", name, tag.String())
}

func normalizeOpenAiEndpoint(rawBaseUrl string) string {
	rawBaseUrl = firstNonEmpty(rawBaseUrl, defaultOpenAIBaseUrl)
	if !strings.Contains(rawBaseUrl, "://") {
		rawBaseUrl = "http://" + rawBaseUrl
	}

	parsedUrl, err := url.Parse(rawBaseUrl)
	if err != nil || parsedUrl.Scheme == "" || parsedUrl.Host == "" {
		return rawBaseUrl
	}

	path := strings.TrimRight(parsedUrl.Path, "/")
	if !strings.HasSuffix(path, "/chat/completions") {
		path += "/chat/completions"
	}
	parsedUrl.Path = path
	parsedUrl.RawQuery = ""
	parsedUrl.Fragment = ""
	return parsedUrl.String()
}

func parseOpenAITranslations(content string, expected int, requestID string) ([]string, error) {
	content = strings.TrimSpace(content)
	var lastErr error
	for _, candidate := range openAIJSONCandidates(content) {
		translatedTexts, err := parseOpenAITranslationCandidate(candidate, expected, requestID)
		if err == nil {
			return translatedTexts, nil
		}
		lastErr = err
	}
	if lastErr != nil {
		return nil, fmt.Errorf("%w: %w", errOpenAIParse, lastErr)
	}
	return nil, errOpenAIParse
}

func parseOpenAITranslationCandidate(content string, expected int, requestID string) ([]string, error) {
	var objectResponse openAITranslationObjectResponse
	if err := json.Unmarshal([]byte(content), &objectResponse); err == nil && objectResponse.Translations != nil {
		if requestID != "" && objectResponse.RequestID != "" && objectResponse.RequestID != requestID {
			return nil, fmt.Errorf("openai returned mismatching request_id")
		}
		return collectOpenAITranslationItems(objectResponse.Translations, expected)
	}

	var stringResponse openAITranslationStringResponse
	if err := json.Unmarshal([]byte(content), &stringResponse); err == nil && stringResponse.Translations != nil {
		if requestID != "" && stringResponse.RequestID != "" && stringResponse.RequestID != requestID {
			return nil, fmt.Errorf("openai returned mismatching request_id")
		}
		return collectOpenAITranslationStrings(stringResponse.Translations, expected)
	}

	var mapResponse openAITranslationMapResponse
	if err := json.Unmarshal([]byte(content), &mapResponse); err == nil && mapResponse.Translations != nil {
		if requestID != "" && mapResponse.RequestID != "" && mapResponse.RequestID != requestID {
			return nil, fmt.Errorf("openai returned mismatching request_id")
		}
		return collectOpenAITranslationMap(mapResponse.Translations, expected)
	}
	if requestID != "" {
		return nil, fmt.Errorf("openai response omitted translations object")
	}

	var itemResponse []openAITranslationItem
	if err := json.Unmarshal([]byte(content), &itemResponse); err == nil && itemResponse != nil {
		return collectOpenAITranslationItems(itemResponse, expected)
	}

	var translatedTexts []string
	if err := json.Unmarshal([]byte(content), &translatedTexts); err != nil {
		return nil, err
	}

	if len(translatedTexts) != expected {
		return nil, fmt.Errorf("openai returned mismatching count: got %d, expected %d", len(translatedTexts), expected)
	}
	return translatedTexts, nil
}

func parseOpenAISingleTranslation(content string, requestID string) (string, error) {
	content = strings.TrimSpace(content)
	var lastErr error
	for _, candidate := range openAIJSONCandidates(content) {
		translation, err := parseOpenAISingleTranslationCandidate(candidate, requestID)
		if err == nil {
			return translation, nil
		}
		lastErr = err
	}
	if lastErr != nil {
		return "", fmt.Errorf("%w: %w", errOpenAIParse, lastErr)
	}
	return "", errOpenAIParse
}

func parseOpenAISingleTranslationCandidate(content string, requestID string) (string, error) {
	var objectResponse openAISingleTranslationResponse
	if err := json.Unmarshal([]byte(content), &objectResponse); err == nil && objectResponse.Translation != "" {
		if requestID != "" && objectResponse.RequestID != "" && objectResponse.RequestID != requestID {
			return "", fmt.Errorf("openai returned mismatching request_id")
		}
		return objectResponse.Translation, nil
	}

	var translations []string
	if err := json.Unmarshal([]byte(content), &translations); err == nil && len(translations) == 1 {
		return translations[0], nil
	}

	var translation string
	if err := json.Unmarshal([]byte(content), &translation); err == nil && strings.TrimSpace(translation) != "" {
		return translation, nil
	}

	if content != "" && !strings.HasPrefix(content, "{") && !strings.HasPrefix(content, "[") {
		return content, nil
	}

	return "", fmt.Errorf("openai response omitted translation")
}

func collectOpenAITranslationItems(items []openAITranslationItem, expected int) ([]string, error) {
	if len(items) != expected {
		return nil, fmt.Errorf("openai returned mismatching count: got %d, expected %d", len(items), expected)
	}

	translatedTexts := make([]string, expected)
	seen := make([]bool, expected)
	for _, item := range items {
		if item.ID < 0 || item.ID >= expected {
			return nil, fmt.Errorf("openai returned invalid translation id: %d", item.ID)
		}
		if seen[item.ID] {
			return nil, fmt.Errorf("openai returned duplicate translation id: %d", item.ID)
		}
		seen[item.ID] = true
		translatedTexts[item.ID] = item.Text
	}
	for i, ok := range seen {
		if !ok {
			return nil, fmt.Errorf("openai omitted translation id: %d", i)
		}
	}
	return translatedTexts, nil
}

func collectOpenAITranslationStrings(items []string, expected int) ([]string, error) {
	if len(items) != expected {
		return nil, fmt.Errorf("openai returned mismatching count: got %d, expected %d", len(items), expected)
	}
	return items, nil
}

func collectOpenAITranslationMap(translations map[string]string, expected int) ([]string, error) {
	if len(translations) != expected {
		return nil, fmt.Errorf("openai returned mismatching count: got %d, expected %d", len(translations), expected)
	}

	translatedTexts := make([]string, expected)
	for i := 0; i < expected; i++ {
		text, ok := translations[strconv.Itoa(i)]
		if !ok {
			return nil, fmt.Errorf("openai omitted translation id: %d", i)
		}
		translatedTexts[i] = text
	}
	return translatedTexts, nil
}

func openAIJSONCandidates(content string) []string {
	content = stripMarkdownFence(content)
	candidates := []string{content}
	if object := sliceJSON(content, "{", "}"); object != "" && object != content {
		candidates = append(candidates, object)
	}
	if array := sliceJSON(content, "[", "]"); array != "" && array != content {
		candidates = append(candidates, array)
	}
	return candidates
}

func stripMarkdownFence(content string) string {
	content = strings.TrimSpace(content)
	if !strings.HasPrefix(content, "```") {
		return content
	}

	lines := strings.Split(content, "\n")
	if len(lines) < 2 {
		return content
	}
	if strings.HasPrefix(strings.TrimSpace(lines[0]), "```") {
		lines = lines[1:]
	}
	if len(lines) > 0 && strings.HasPrefix(strings.TrimSpace(lines[len(lines)-1]), "```") {
		lines = lines[:len(lines)-1]
	}
	return strings.TrimSpace(strings.Join(lines, "\n"))
}

func sliceJSON(content string, left string, right string) string {
	start := strings.Index(content, left)
	end := strings.LastIndex(content, right)
	if start == -1 || end <= start {
		return ""
	}
	return strings.TrimSpace(content[start : end+len(right)])
}

func sleepRetry(ctx context.Context, resp *http.Response, attempt int) error {
	delay := time.Duration(1<<attempt) * time.Second
	if resp != nil {
		if retryAfter := strings.TrimSpace(resp.Header.Get("Retry-After")); retryAfter != "" {
			if seconds, err := strconv.Atoi(retryAfter); err == nil && seconds >= 0 {
				delay = time.Duration(seconds) * time.Second
			} else if retryAt, err := http.ParseTime(retryAfter); err == nil {
				delay = time.Until(retryAt)
				if delay < 0 {
					delay = 0
				}
			}
		}
	}

	timer := time.NewTimer(delay)
	defer timer.Stop()
	select {
	case <-timer.C:
		return nil
	case <-ctx.Done():
		return ctx.Err()
	}
}

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

type FreeGoogleTranslator struct {
	limiter *rate.Limiter
	client  *http.Client
	logger  *zerolog.Logger
}

func NewFreeGoogleTranslator(logger *zerolog.Logger) *FreeGoogleTranslator {
	return &FreeGoogleTranslator{
		limiter: rate.NewLimiter(rate.Every(500*time.Millisecond), 50),
		client:  &http.Client{Timeout: 10 * time.Second},
		logger:  logger,
	}
}

func (g *FreeGoogleTranslator) TranslateBatch(ctx context.Context, texts []string, targetLang string) ([]string, error) {
	if len(texts) == 0 {
		return []string{}, nil
	}

	results := make([]string, len(texts))
	var wg sync.WaitGroup
	var errMutex sync.Mutex
	var firstErr error

	g.logger.Debug().Msgf("videocore: (google) Translating %d lines", len(texts))

	for i, text := range texts {
		wg.Add(1)

		go func(idx int, txt string) {
			defer wg.Done()

			if err := g.limiter.Wait(ctx); err != nil {
				errMutex.Lock()
				if firstErr == nil {
					firstErr = err
				}
				errMutex.Unlock()
				return
			}

			// Add a tiny random jitter
			time.Sleep(time.Duration(rand.Intn(200)) * time.Millisecond)

			translated, err := g.translateSingle(ctx, txt, targetLang)
			if err != nil {
				errMutex.Lock()
				if firstErr == nil {
					firstErr = err
				}
				errMutex.Unlock()
				return
			}
			results[idx] = translated
		}(i, text)
	}

	wg.Wait()

	if firstErr != nil {
		return nil, firstErr
	}
	return results, nil
}

func (g *FreeGoogleTranslator) translateSingle(ctx context.Context, text, targetLang string) (string, error) {
	endpoint := "https://translate.googleapis.com/translate_a/single"
	targetLang = normalizeTargetLang(translatorProviderGoogle, targetLang)

	params := url.Values{}
	params.Add("client", "gtx")
	params.Add("sl", "auto")
	params.Add("tl", targetLang)
	params.Add("dt", "t")
	params.Add("q", text)

	req, err := http.NewRequestWithContext(ctx, "GET", endpoint+"?"+params.Encode(), nil)
	if err != nil {
		return "", err
	}

	req.Header.Set("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/96.0.4664.45 Safari/537.36")

	resp, err := g.client.Do(req)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()

	if resp.StatusCode == 429 {
		return "", fmt.Errorf("google rate limited")
	}
	if resp.StatusCode != http.StatusOK {
		return "", fmt.Errorf("google api error: %d", resp.StatusCode)
	}

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return "", err
	}

	// The response is a messy JSON array of arrays: [[["Hola","Hello",null,null,1]],...]
	var result []interface{}
	if err := json.Unmarshal(body, &result); err != nil {
		return "", err
	}

	if len(result) > 0 {
		// The first element is an array of sentences
		if sentences, ok := result[0].([]interface{}); ok {
			var sb strings.Builder
			for _, s := range sentences {
				// Each sentence is an array where index 0 is the translated text
				if parts, ok := s.([]interface{}); ok && len(parts) > 0 {
					if translatedPart, ok := parts[0].(string); ok {
						sb.WriteString(translatedPart)
					}
				}
			}
			return sb.String(), nil
		}
	}

	return "", fmt.Errorf("failed to parse google response")
}

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

// TranslateContent translates the file content based on saved settings
func (vc *VideoCore) TranslateContent(ctx context.Context, content string, format int) string {
	if vc.translatorService == nil {
		return content
	}
	translated, err := vc.translatorService.TranslateContent(ctx, content, format, vc.translatorService.targetLang)
	if err != nil {
		vc.logger.Error().Err(err).Msg("videocore: Failed to translate content")
		return content
	}

	return translated
}

// TranslateEvent translates the subtitle event based on saved settings
func (vc *VideoCore) TranslateEvent(ctx context.Context, event *mkvparser.SubtitleEvent) {
	if vc.translatorService == nil {
		return
	}
	err := vc.translatorService.TranslateEvent(ctx, event, vc.translatorService.targetLang)
	if err != nil {
		return
	}
}

// TranslateText translates the text based on saved settings
func (vc *VideoCore) TranslateText(ctx context.Context, text string) string {
	if vc.translatorService == nil {
		return text
	}
	ret, err := vc.translatorService.TranslateText(ctx, text, vc.translatorService.targetLang)
	if err != nil {
		return text
	}
	return ret
}

func (vc *VideoCore) GetTranslationTargetLanguage() string {
	if vc.translatorService == nil {
		return ""
	}
	return vc.translatorService.targetLang
}
