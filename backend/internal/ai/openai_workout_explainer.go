package ai

import "context"

const openAIWorkoutExplanationPromptVersion = "workout-explanation-openai-v1"

type OpenAIWorkoutExplainer struct {
	client *OpenAIClient
	model  string
}

func NewOpenAIWorkoutExplainer(client *OpenAIClient) *OpenAIWorkoutExplainer {
	return &OpenAIWorkoutExplainer{
		client: client,
		model:  client.model,
	}
}

func (e *OpenAIWorkoutExplainer) ExplainWorkout(ctx context.Context, workout WorkoutContext) (GeneratedWorkoutExplanation, error) {
	var generated struct {
		Text string `json:"text"`
	}
	if err := e.client.GenerateJSON(ctx, openAIWorkoutExplanationSystemPrompt, workout, &generated); err != nil {
		return GeneratedWorkoutExplanation{}, err
	}

	return GeneratedWorkoutExplanation{
		Provider:      "openai",
		Model:         e.model,
		PromptVersion: openAIWorkoutExplanationPromptVersion,
		Text:          generated.Text,
	}, nil
}

const openAIWorkoutExplanationSystemPrompt = `You are a strength coach explaining why a workout exists inside a broader program.

Return exactly one JSON object with this shape:
{
  "text": string
}

Rules:
- Explain the workout like a coach, not like a spreadsheet.
- Connect the exercise choices to the session purpose and block purpose.
- Mention movement patterns and recovery logic when helpful.
- Keep it concise enough for a mobile bottom sheet.
- Do not include markdown or extra keys.`
