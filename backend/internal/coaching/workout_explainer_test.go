package coaching

import (
	"context"
	"errors"
	"testing"
	"time"

	"github.com/josefkarasek/ai-fitness-coach/backend/internal/ai"
	"github.com/josefkarasek/ai-fitness-coach/backend/internal/auth"
)

type fakeWorkoutExplanationStore struct {
	workout        ai.WorkoutContext
	stored         StoredWorkoutExplanation
	found          bool
	generatedToday int
	saved          ai.GeneratedWorkoutExplanation
	saveCalls      int
}

func (f *fakeWorkoutExplanationStore) GetWorkoutForUser(_ context.Context, _ auth.User, _ int64) (ai.WorkoutContext, error) {
	return f.workout, nil
}

func (f *fakeWorkoutExplanationStore) GetWorkoutExplanationForUser(_ context.Context, _ auth.User, _ int64) (StoredWorkoutExplanation, bool, error) {
	return f.stored, f.found, nil
}

func (f *fakeWorkoutExplanationStore) SaveWorkoutExplanationForUser(_ context.Context, _ auth.User, workoutID int64, generated ai.GeneratedWorkoutExplanation) (StoredWorkoutExplanation, error) {
	f.saveCalls++
	f.saved = generated
	f.stored = StoredWorkoutExplanation{
		WorkoutID:     workoutID,
		Provider:      generated.Provider,
		Model:         generated.Model,
		PromptVersion: generated.PromptVersion,
		Explanation:   generated.Text,
		CreatedAt:     time.Date(2026, 7, 8, 10, 0, 0, 0, time.UTC),
		UpdatedAt:     time.Date(2026, 7, 8, 10, 0, 0, 0, time.UTC),
	}
	f.found = true
	return f.stored, nil
}

func (f *fakeWorkoutExplanationStore) CountWorkoutExplanationsGeneratedSince(_ context.Context, _ auth.User, _ time.Time) (int, error) {
	return f.generatedToday, nil
}

type fakeWorkoutAI struct {
	result ai.GeneratedWorkoutExplanation
	err    error
	calls  int
}

func (f *fakeWorkoutAI) ExplainWorkout(_ context.Context, _ ai.WorkoutContext) (ai.GeneratedWorkoutExplanation, error) {
	f.calls++
	if f.err != nil {
		return ai.GeneratedWorkoutExplanation{}, f.err
	}
	return f.result, nil
}

func TestWorkoutExplainerServiceReturnsCachedExplanation(t *testing.T) {
	t.Parallel()

	store := &fakeWorkoutExplanationStore{
		found: true,
		stored: StoredWorkoutExplanation{
			WorkoutID:     42,
			Provider:      "mock",
			Model:         "mock-v1",
			PromptVersion: "workout-explanation-v1",
			Explanation:   "Cached explanation",
			CreatedAt:     time.Date(2026, 7, 8, 9, 0, 0, 0, time.UTC),
			UpdatedAt:     time.Date(2026, 7, 8, 9, 0, 0, 0, time.UTC),
		},
		generatedToday: 1,
	}
	explainer := &fakeWorkoutAI{}
	service := NewWorkoutExplainerService(store, explainer, 3)
	service.now = func() time.Time {
		return time.Date(2026, 7, 8, 15, 0, 0, 0, time.UTC)
	}

	result, err := service.ExplainWorkout(context.Background(), auth.User{ID: "user-1"}, 42, false)
	if err != nil {
		t.Fatalf("ExplainWorkout returned error: %v", err)
	}

	if result.Generated {
		t.Fatalf("expected cached explanation, got generated=true")
	}
	if result.Explanation != "Cached explanation" {
		t.Fatalf("expected cached explanation text, got %q", result.Explanation)
	}
	if explainer.calls != 0 {
		t.Fatalf("expected no AI call, got %d", explainer.calls)
	}
}

func TestWorkoutExplainerServiceGeneratesAndPersists(t *testing.T) {
	t.Parallel()

	store := &fakeWorkoutExplanationStore{
		workout: ai.WorkoutContext{
			WorkoutID:          42,
			SourceWorkoutTitle: "Upper A",
			ScheduledDate:      time.Date(2026, 7, 8, 0, 0, 0, 0, time.UTC),
		},
	}
	explainer := &fakeWorkoutAI{
		result: ai.GeneratedWorkoutExplanation{
			Provider:      "mock",
			Model:         "mock-v1",
			PromptVersion: "workout-explanation-v1",
			Text:          "Generated explanation",
		},
	}
	service := NewWorkoutExplainerService(store, explainer, 3)
	service.now = func() time.Time {
		return time.Date(2026, 7, 8, 15, 0, 0, 0, time.UTC)
	}

	result, err := service.ExplainWorkout(context.Background(), auth.User{ID: "user-1"}, 42, false)
	if err != nil {
		t.Fatalf("ExplainWorkout returned error: %v", err)
	}

	if !result.Generated {
		t.Fatalf("expected generated explanation")
	}
	if result.RemainingToday != 2 {
		t.Fatalf("expected remaining_today 2, got %d", result.RemainingToday)
	}
	if store.saveCalls != 1 {
		t.Fatalf("expected one save call, got %d", store.saveCalls)
	}
}

func TestWorkoutExplainerServiceRejectsWhenDailyLimitReached(t *testing.T) {
	t.Parallel()

	store := &fakeWorkoutExplanationStore{
		generatedToday: 3,
	}
	explainer := &fakeWorkoutAI{}
	service := NewWorkoutExplainerService(store, explainer, 3)
	service.now = func() time.Time {
		return time.Date(2026, 7, 8, 15, 0, 0, 0, time.UTC)
	}

	_, err := service.ExplainWorkout(context.Background(), auth.User{ID: "user-1"}, 42, false)
	if !errors.Is(err, ErrDailyLimitReached) {
		t.Fatalf("expected ErrDailyLimitReached, got %v", err)
	}
	if explainer.calls != 0 {
		t.Fatalf("expected no AI call when limit reached, got %d", explainer.calls)
	}
}
