package coaching

import (
	"context"
	"errors"
	"testing"
	"time"

	"github.com/josefkarasek/ai-fitness-coach/backend/internal/ai"
	"github.com/josefkarasek/ai-fitness-coach/backend/internal/auth"
)

type fakeTrainingPlanStore struct {
	history        ai.TrainingHistorySummary
	stored         StoredTrainingPlan
	found          bool
	generatedToday int
	saveCalls      int
}

func (f *fakeTrainingPlanStore) SummarizeTrainingHistoryForUser(_ context.Context, _ auth.User) (ai.TrainingHistorySummary, error) {
	return f.history, nil
}

func (f *fakeTrainingPlanStore) SaveTrainingPlanForUser(_ context.Context, _ auth.User, request ai.TrainingPlanRequest, generated ai.GeneratedTrainingPlan) (StoredTrainingPlan, error) {
	f.saveCalls++
	f.stored = StoredTrainingPlan{
		ID:                  7,
		Objective:           request.Objective,
		DurationWeeks:       request.DurationWeeks,
		DaysPerWeek:         request.DaysPerWeek,
		MeasurementSystem:   request.MeasurementSystem,
		Constraints:         request.Constraints,
		Equipment:           request.Equipment,
		Notes:               request.Notes,
		Provider:            generated.Provider,
		Model:               generated.Model,
		PromptVersion:       generated.PromptVersion,
		Summary:             generated.Summary,
		Philosophy:          generated.Philosophy,
		ProgressionStrategy: generated.ProgressionStrategy,
		Risks:               generated.Risks,
		SuccessCriteria:     generated.SuccessCriteria,
		CreatedAt:           time.Date(2026, 7, 8, 10, 0, 0, 0, time.UTC),
		UpdatedAt:           time.Date(2026, 7, 8, 10, 0, 0, 0, time.UTC),
	}
	f.found = true
	return f.stored, nil
}

func (f *fakeTrainingPlanStore) GetLatestTrainingPlanForUser(_ context.Context, _ auth.User) (StoredTrainingPlan, bool, error) {
	return f.stored, f.found, nil
}

func (f *fakeTrainingPlanStore) GetTrainingPlanForUser(_ context.Context, _ auth.User, _ int64) (StoredTrainingPlan, bool, error) {
	return f.stored, f.found, nil
}

func (f *fakeTrainingPlanStore) SaveTrainingPlanWorkoutForUser(_ context.Context, _ auth.User, _ int64, weekNumber int, workout StoredPlannedWorkout) error {
	for idx := range f.stored.Weeks {
		if f.stored.Weeks[idx].WeekNumber == weekNumber {
			f.stored.Weeks[idx].Workouts = append(f.stored.Weeks[idx].Workouts, workout)
			return nil
		}
	}
	f.stored.Weeks = append(f.stored.Weeks, StoredTrainingPlanWeek{
		WeekNumber: weekNumber,
		Workouts:   []StoredPlannedWorkout{workout},
	})
	return nil
}

func (f *fakeTrainingPlanStore) DeleteTrainingPlanWorkoutForUser(_ context.Context, _ auth.User, _ int64, weekNumber int, dayNumber int) error {
	for idx := range f.stored.Weeks {
		if f.stored.Weeks[idx].WeekNumber != weekNumber {
			continue
		}
		filtered := f.stored.Weeks[idx].Workouts[:0]
		for _, workout := range f.stored.Weeks[idx].Workouts {
			if workout.DayNumber == dayNumber {
				continue
			}
			filtered = append(filtered, workout)
		}
		f.stored.Weeks[idx].Workouts = filtered
		return nil
	}
	return nil
}

func (f *fakeTrainingPlanStore) CountTrainingPlansGeneratedSince(_ context.Context, _ auth.User, _ time.Time) (int, error) {
	return f.generatedToday, nil
}

type fakePlanner struct {
	result    ai.GeneratedTrainingPlan
	dayResult ai.GeneratedPlannedWorkout
	err       error
	calls     int
}

func (f *fakePlanner) GenerateTrainingPlan(_ context.Context, _ ai.TrainingHistorySummary, _ ai.TrainingPlanRequest) (ai.GeneratedTrainingPlan, error) {
	f.calls++
	if f.err != nil {
		return ai.GeneratedTrainingPlan{}, f.err
	}
	return f.result, nil
}

func (f *fakePlanner) GenerateWorkoutForDay(_ context.Context, _ ai.TrainingHistorySummary, _ ai.TrainingDayRequest) (ai.GeneratedPlannedWorkout, error) {
	if f.err != nil {
		return ai.GeneratedPlannedWorkout{}, f.err
	}
	return f.dayResult, nil
}

func TestTrainingPlannerServiceGeneratePlan(t *testing.T) {
	t.Parallel()

	store := &fakeTrainingPlanStore{
		history: ai.TrainingHistorySummary{WorkoutCount: 40},
	}
	planner := &fakePlanner{
		result: ai.GeneratedTrainingPlan{
			Provider:            "mock",
			Model:               "mock-v1",
			PromptVersion:       "training-plan-v1",
			Summary:             "Summary",
			Philosophy:          "Philosophy",
			ProgressionStrategy: "Progression",
			Risks:               "Risks",
			SuccessCriteria:     "Success",
		},
	}
	service := NewTrainingPlannerService(store, planner, 1)
	service.now = func() time.Time { return time.Date(2026, 7, 8, 15, 0, 0, 0, time.UTC) }

	result, err := service.GenerateTrainingPlan(context.Background(), auth.User{ID: "user-1"}, ai.TrainingPlanRequest{
		Objective:     "Build a 12-week strength block",
		DurationWeeks: 12,
		DaysPerWeek:   4,
	})
	if err != nil {
		t.Fatalf("GenerateTrainingPlan returned error: %v", err)
	}
	if !result.Generated {
		t.Fatalf("expected generated result")
	}
	if store.saveCalls != 1 {
		t.Fatalf("expected one save call, got %d", store.saveCalls)
	}
}

func TestTrainingPlannerServiceRejectsWhenDailyLimitReached(t *testing.T) {
	t.Parallel()

	store := &fakeTrainingPlanStore{generatedToday: 1}
	planner := &fakePlanner{}
	service := NewTrainingPlannerService(store, planner, 1)
	service.now = func() time.Time { return time.Date(2026, 7, 8, 15, 0, 0, 0, time.UTC) }

	_, err := service.GenerateTrainingPlan(context.Background(), auth.User{ID: "user-1"}, ai.TrainingPlanRequest{
		Objective:     "Build a 12-week strength block",
		DurationWeeks: 12,
		DaysPerWeek:   4,
	})
	if !errors.Is(err, ErrDailyTrainingPlanLimitReached) {
		t.Fatalf("expected ErrDailyTrainingPlanLimitReached, got %v", err)
	}
	if planner.calls != 0 {
		t.Fatalf("expected no planner call, got %d", planner.calls)
	}
}
