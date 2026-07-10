package ai

import "context"

type DisabledWorkoutExplainer struct{}

func NewDisabledWorkoutExplainer() *DisabledWorkoutExplainer {
	return &DisabledWorkoutExplainer{}
}

func (e *DisabledWorkoutExplainer) ExplainWorkout(_ context.Context, _ WorkoutContext) (GeneratedWorkoutExplanation, error) {
	return GeneratedWorkoutExplanation{}, ErrProviderDisabled
}
