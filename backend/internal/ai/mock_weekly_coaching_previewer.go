package ai

import (
	"context"
	"fmt"
	"strings"
)

type MockWeeklyCoachingPreviewer struct {
	model string
}

func NewMockWeeklyCoachingPreviewer(model string) *MockWeeklyCoachingPreviewer {
	return &MockWeeklyCoachingPreviewer{model: model}
}

func (p *MockWeeklyCoachingPreviewer) GenerateWeeklyCoachingPreview(_ context.Context, preview WeeklyCoachingPreviewContext) (GeneratedWeeklyCoachingPreview, error) {
	workoutLabel := "the planned sessions"
	if len(preview.PreviewWorkoutTitles) > 0 {
		workoutLabel = strings.Join(preview.PreviewWorkoutTitles, ", ")
	}

	feedback := fmt.Sprintf(
		"Week %d shifts the block toward %s. The coach wants you to arrive organized, keep execution crisp, and treat %s as the anchor sessions for this phase.",
		preview.PreviewWeekNumber,
		fallbackValue(preview.PreviewWeekTheme, "the next training phase"),
		workoutLabel,
	)

	motivation := fmt.Sprintf(
		"You are no longer just accumulating work. Week %d is where %s starts to look more intentional, and small disciplined sessions set up the bigger outcomes later in the block.",
		preview.PreviewWeekNumber,
		strings.ToLower(fallbackValue(preview.TrainingPlanObjective, "this plan")),
	)

	return GeneratedWeeklyCoachingPreview{
		Provider:      "mock",
		Model:         p.model,
		PromptVersion: "weekly-coaching-preview-v1",
		Feedback:      feedback,
		Motivation:    motivation,
	}, nil
}

type DisabledWeeklyCoachingPreviewer struct{}

func NewDisabledWeeklyCoachingPreviewer() *DisabledWeeklyCoachingPreviewer {
	return &DisabledWeeklyCoachingPreviewer{}
}

func (p *DisabledWeeklyCoachingPreviewer) GenerateWeeklyCoachingPreview(_ context.Context, _ WeeklyCoachingPreviewContext) (GeneratedWeeklyCoachingPreview, error) {
	return GeneratedWeeklyCoachingPreview{}, ErrProviderDisabled
}

func fallbackValue(value string, fallback string) string {
	if strings.TrimSpace(value) == "" {
		return fallback
	}

	return value
}
