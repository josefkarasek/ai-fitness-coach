package ai

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"log/slog"
	"net/http"
	"strings"
	"time"
)

const defaultOpenAIBaseURL = "https://api.openai.com/v1"

type OpenAIClient struct {
	baseURL    string
	apiKey     string
	model      string
	httpClient *http.Client
}

func NewOpenAIClient(baseURL string, apiKey string, model string) (*OpenAIClient, error) {
	if strings.TrimSpace(apiKey) == "" {
		return nil, fmt.Errorf("openai api key is required")
	}
	if strings.TrimSpace(model) == "" {
		return nil, fmt.Errorf("openai model is required")
	}

	trimmedBaseURL := strings.TrimRight(strings.TrimSpace(baseURL), "/")
	if trimmedBaseURL == "" {
		trimmedBaseURL = defaultOpenAIBaseURL
	}

	return &OpenAIClient{
		baseURL: trimmedBaseURL,
		apiKey:  strings.TrimSpace(apiKey),
		model:   strings.TrimSpace(model),
		httpClient: &http.Client{
			Timeout: 300 * time.Second,
		},
	}, nil
}

func (c *OpenAIClient) GenerateJSON(ctx context.Context, systemPrompt string, userPayload any, out any) error {
	payloadJSON, err := json.MarshalIndent(userPayload, "", "  ")
	if err != nil {
		return fmt.Errorf("marshal prompt payload: %w", err)
	}

	requestBody := openAIResponsesRequest{
		Model: c.model,
		Input: []openAIInputMessage{
			{
				Role:    "system",
				Content: systemPrompt,
			},
			{
				Role: "user",
				Content: strings.TrimSpace(
					"Return exactly one JSON object and no markdown.\n\nContext JSON:\n" + string(payloadJSON),
				),
			},
		},
	}

	rawBody, err := json.Marshal(requestBody)
	if err != nil {
		return fmt.Errorf("marshal openai request: %w", err)
	}

	slog.Info("openai request",
		"base_url", c.baseURL,
		"endpoint", "/responses",
		"model", c.model,
		"system_prompt", systemPrompt,
		"user_payload_json", string(payloadJSON),
		"request_body_json", string(rawBody),
	)

	req, err := http.NewRequestWithContext(ctx, http.MethodPost, c.baseURL+"/responses", bytes.NewReader(rawBody))
	if err != nil {
		return fmt.Errorf("create openai request: %w", err)
	}

	req.Header.Set("Authorization", "Bearer "+c.apiKey)
	req.Header.Set("Content-Type", "application/json")

	resp, err := c.httpClient.Do(req)
	if err != nil {
		return fmt.Errorf("perform openai request: %w", err)
	}
	defer resp.Body.Close()

	responseBody, err := io.ReadAll(resp.Body)
	if err != nil {
		return fmt.Errorf("read openai response: %w", err)
	}

	slog.Info("openai response",
		"base_url", c.baseURL,
		"endpoint", "/responses",
		"model", c.model,
		"status_code", resp.StatusCode,
		"status", resp.Status,
		"response_body", strings.TrimSpace(string(responseBody)),
	)

	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return fmt.Errorf("openai responses api returned %s: %s", resp.Status, strings.TrimSpace(string(responseBody)))
	}

	var response openAIResponsesResponse
	if err := json.Unmarshal(responseBody, &response); err != nil {
		return fmt.Errorf("decode openai response envelope: %w", err)
	}

	outputText := strings.TrimSpace(response.OutputText)
	if outputText == "" {
		outputText = strings.TrimSpace(response.fallbackText())
	}
	if outputText == "" {
		return fmt.Errorf("openai response did not contain text output")
	}

	jsonText, err := extractJSONObject(outputText)
	if err != nil {
		return fmt.Errorf("extract json from openai response: %w", err)
	}

	if err := json.Unmarshal([]byte(jsonText), out); err != nil {
		return fmt.Errorf("decode generated json: %w", err)
	}

	return nil
}

type openAIResponsesRequest struct {
	Model string               `json:"model"`
	Input []openAIInputMessage `json:"input"`
}

type openAIInputMessage struct {
	Role    string `json:"role"`
	Content string `json:"content"`
}

type openAIResponsesResponse struct {
	OutputText string                 `json:"output_text"`
	Output     []openAIResponseOutput `json:"output"`
}

type openAIResponseOutput struct {
	Content []openAIResponseContent `json:"content"`
}

type openAIResponseContent struct {
	Type string `json:"type"`
	Text string `json:"text"`
}

func (r openAIResponsesResponse) fallbackText() string {
	var builder strings.Builder
	for _, item := range r.Output {
		for _, content := range item.Content {
			if strings.TrimSpace(content.Text) == "" {
				continue
			}
			if builder.Len() > 0 {
				builder.WriteString("\n")
			}
			builder.WriteString(content.Text)
		}
	}

	return builder.String()
}

func extractJSONObject(text string) (string, error) {
	start := strings.Index(text, "{")
	end := strings.LastIndex(text, "}")
	if start < 0 || end < 0 || end < start {
		return "", fmt.Errorf("no json object found")
	}

	return text[start : end+1], nil
}
