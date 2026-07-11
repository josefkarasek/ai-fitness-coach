package ai

import "context"

const openAIWorkoutLogReviewPromptVersion = "workout-log-review-openai-v1"

type OpenAIWorkoutLogReviewer struct {
	client *OpenAIClient
	model  string
}

func NewOpenAIWorkoutLogReviewer(client *OpenAIClient) *OpenAIWorkoutLogReviewer {
	return &OpenAIWorkoutLogReviewer{
		client: client,
		model:  client.model,
	}
}

func (r *OpenAIWorkoutLogReviewer) ReviewWorkoutLog(ctx context.Context, workout WorkoutReviewContext) (GeneratedWorkoutLogReview, error) {
	var generated struct {
		Review string `json:"review"`
	}
	if err := r.client.GenerateJSON(ctx, openAIWorkoutLogReviewSystemPrompt, workout, &generated); err != nil {
		return GeneratedWorkoutLogReview{}, err
	}

	return GeneratedWorkoutLogReview{
		Provider:      "openai",
		Model:         r.model,
		PromptVersion: openAIWorkoutLogReviewPromptVersion,
		Review:        generated.Review,
	}, nil
}

const openAIWorkoutLogReviewSystemPrompt = `You are reviewing a completed workout as a strength coach.

Return exactly one JSON object with this shape:
{
  "review": string
}

Rules:
- Focus on coaching signal: completion, execution, density, recovery, and notes.
- Keep the tone constructive and specific.
- Keep it concise enough for an in-app post-workout review.
- Do not include markdown or extra keys.`
