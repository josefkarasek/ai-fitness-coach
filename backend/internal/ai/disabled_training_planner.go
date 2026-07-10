package ai

import "context"

type DisabledTrainingPlanner struct{}

func NewDisabledTrainingPlanner() *DisabledTrainingPlanner {
	return &DisabledTrainingPlanner{}
}

func (p *DisabledTrainingPlanner) GenerateTrainingPlan(_ context.Context, _ TrainingHistorySummary, _ TrainingPlanRequest) (GeneratedTrainingPlan, error) {
	return GeneratedTrainingPlan{}, ErrProviderDisabled
}

func (p *DisabledTrainingPlanner) GenerateWorkoutForDay(_ context.Context, _ TrainingHistorySummary, _ TrainingDayRequest) (GeneratedPlannedWorkout, error) {
	return GeneratedPlannedWorkout{}, ErrProviderDisabled
}
