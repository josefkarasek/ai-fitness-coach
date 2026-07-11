package ai

import "context"

const openAIWeeklyCoachingPreviewPromptVersion = "weekly-coaching-preview-openai-v1"

type OpenAIWeeklyCoachingPreviewer struct {
	client *OpenAIClient
	model  string
}

func NewOpenAIWeeklyCoachingPreviewer(client *OpenAIClient) *OpenAIWeeklyCoachingPreviewer {
	return &OpenAIWeeklyCoachingPreviewer{
		client: client,
		model:  client.model,
	}
}

func (p *OpenAIWeeklyCoachingPreviewer) GenerateWeeklyCoachingPreview(ctx context.Context, preview WeeklyCoachingPreviewContext) (GeneratedWeeklyCoachingPreview, error) {
	var generated struct {
		Feedback   string `json:"feedback"`
		Motivation string `json:"motivation"`
	}
	if err := p.client.GenerateJSON(ctx, openAIWeeklyCoachingPreviewSystemPrompt, preview, &generated); err != nil {
		return GeneratedWeeklyCoachingPreview{}, err
	}

	return GeneratedWeeklyCoachingPreview{
		Provider:      "openai",
		Model:         p.model,
		PromptVersion: openAIWeeklyCoachingPreviewPromptVersion,
		Feedback:      generated.Feedback,
		Motivation:    generated.Motivation,
	}, nil
}

const openAIWeeklyCoachingPreviewSystemPrompt = `You are writing a Monday morning coach briefing for the next week of a strength program.

Return exactly one JSON object with this shape:
{
  "feedback": string,
  "motivation": string
}

Rules:
- Feedback should preview the upcoming week clearly and concretely.
- Motivation should feel calm, serious, and coaching-oriented, not gamified.
- Keep both fields concise enough for a mobile card.
- Do not include markdown or extra keys.`
