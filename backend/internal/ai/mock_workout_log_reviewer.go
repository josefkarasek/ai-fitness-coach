package ai

import (
	"context"
	"fmt"
	"strings"
)

type MockWorkoutLogReviewer struct {
	model string
}

func NewMockWorkoutLogReviewer(model string) *MockWorkoutLogReviewer {
	return &MockWorkoutLogReviewer{model: model}
}

func (r *MockWorkoutLogReviewer) ReviewWorkoutLog(_ context.Context, workout WorkoutReviewContext) (GeneratedWorkoutLogReview, error) {
	totalPlannedSets := 0
	for _, exercise := range workout.PlannedExercises {
		totalPlannedSets += len(exercise.Sets)
	}

	totalLoggedSets := 0
	completedLoggedSets := 0
	completedWithLoad := 0
	for _, exercise := range workout.LoggedExercises {
		totalLoggedSets += len(exercise.Sets)
		for _, set := range exercise.Sets {
			if !set.Completed {
				continue
			}
			completedLoggedSets++
			if set.Value != nil && strings.TrimSpace(set.Unit) != "" {
				completedWithLoad++
			}
		}
	}

	complianceLine := fmt.Sprintf(
		"You completed %d of %d logged sets against %d planned sets for %s.",
		completedLoggedSets,
		totalLoggedSets,
		totalPlannedSets,
		workout.WorkoutTitle,
	)

	loadLine := "Most of the signal today is execution quality and consistency."
	if completedWithLoad > 0 {
		loadLine = fmt.Sprintf(
			"%d completed sets included a tracked target value, which gives the coach enough signal to compare this session against future repeats honestly.",
			completedWithLoad,
		)
	}

	durationLine := "The session duration stayed within a normal range for a repeatable training day."
	if workout.DurationMinutes != nil && *workout.DurationMinutes > 110 {
		durationLine = "This session ran long, so the next programming decision should be to tighten density before adding more work."
	}

	noteLine := "No athlete note was recorded, so the next best signal is whether performance stayed aligned with the day’s purpose."
	if trimmed := strings.TrimSpace(workout.SessionNotes); trimmed != "" {
		noteLine = fmt.Sprintf("Athlete feedback matters here: %q. The next coaching decision should respect that note, not ignore it.", trimmed)
	}

	phaseLine := fmt.Sprintf(
		"This day belongs to Week %d (%s) and should still serve the larger block objective: %s.",
		workout.WeekNumber,
		fallbackWorkoutReviewValue(workout.WeekTheme, "current block phase"),
		fallbackWorkoutReviewValue(workout.TrainingPlanObjective, "the active training objective"),
	)

	return GeneratedWorkoutLogReview{
		Provider:      "mock",
		Model:         r.model,
		PromptVersion: "workout-log-review-v1",
		Review: strings.Join([]string{
			complianceLine,
			loadLine,
			durationLine,
			noteLine,
			phaseLine,
		}, " "),
	}, nil
}

type DisabledWorkoutLogReviewer struct{}

func NewDisabledWorkoutLogReviewer() *DisabledWorkoutLogReviewer {
	return &DisabledWorkoutLogReviewer{}
}

func (r *DisabledWorkoutLogReviewer) ReviewWorkoutLog(_ context.Context, _ WorkoutReviewContext) (GeneratedWorkoutLogReview, error) {
	return GeneratedWorkoutLogReview{}, ErrProviderDisabled
}

func fallbackWorkoutReviewValue(value string, fallback string) string {
	trimmed := strings.TrimSpace(value)
	if trimmed == "" {
		return fallback
	}

	return trimmed
}
