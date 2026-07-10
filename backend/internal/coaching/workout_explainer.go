package coaching

import (
	"context"
	"errors"
	"fmt"
	"time"

	"github.com/josefkarasek/ai-fitness-coach/backend/internal/ai"
	"github.com/josefkarasek/ai-fitness-coach/backend/internal/auth"
)

var (
	ErrWorkoutNotFound   = errors.New("workout not found")
	ErrDailyLimitReached = errors.New("daily workout explanation limit reached")
)

type WorkoutExplanationStore interface {
	GetWorkoutForUser(ctx context.Context, user auth.User, workoutID int64) (ai.WorkoutContext, error)
	GetWorkoutExplanationForUser(ctx context.Context, user auth.User, workoutID int64) (StoredWorkoutExplanation, bool, error)
	SaveWorkoutExplanationForUser(ctx context.Context, user auth.User, workoutID int64, generated ai.GeneratedWorkoutExplanation) (StoredWorkoutExplanation, error)
	CountWorkoutExplanationsGeneratedSince(ctx context.Context, user auth.User, since time.Time) (int, error)
}

type StoredWorkoutExplanation struct {
	WorkoutID     int64
	Provider      string
	Model         string
	PromptVersion string
	Explanation   string
	CreatedAt     time.Time
	UpdatedAt     time.Time
}

type WorkoutExplanationResult struct {
	WorkoutID      int64
	Provider       string
	Model          string
	PromptVersion  string
	Explanation    string
	Generated      bool
	CreatedAt      time.Time
	UpdatedAt      time.Time
	DailyLimit     int
	GeneratedToday int
	RemainingToday int
}

type WorkoutExplainerService struct {
	store      WorkoutExplanationStore
	explainer  ai.WorkoutExplainer
	dailyLimit int
	now        func() time.Time
}

func NewWorkoutExplainerService(store WorkoutExplanationStore, explainer ai.WorkoutExplainer, dailyLimit int) *WorkoutExplainerService {
	return &WorkoutExplainerService{
		store:      store,
		explainer:  explainer,
		dailyLimit: dailyLimit,
		now:        time.Now,
	}
}

func (s *WorkoutExplainerService) ExplainWorkout(ctx context.Context, user auth.User, workoutID int64, force bool) (WorkoutExplanationResult, error) {
	_ = force

	existing, found, err := s.store.GetWorkoutExplanationForUser(ctx, user, workoutID)
	if err != nil {
		return WorkoutExplanationResult{}, fmt.Errorf("get existing workout explanation: %w", err)
	}
	if found {
		generatedToday, err := s.countGeneratedToday(ctx, user)
		if err != nil {
			return WorkoutExplanationResult{}, err
		}
		return buildResult(existing, false, s.dailyLimit, generatedToday), nil
	}

	generatedToday, err := s.countGeneratedToday(ctx, user)
	if err != nil {
		return WorkoutExplanationResult{}, err
	}
	if s.dailyLimit > 0 && generatedToday >= s.dailyLimit {
		return WorkoutExplanationResult{}, ErrDailyLimitReached
	}

	workout, err := s.store.GetWorkoutForUser(ctx, user, workoutID)
	if err != nil {
		return WorkoutExplanationResult{}, fmt.Errorf("get workout: %w", err)
	}
	if workout.WorkoutID == 0 {
		return WorkoutExplanationResult{}, ErrWorkoutNotFound
	}

	generated, err := s.explainer.ExplainWorkout(ctx, workout)
	if err != nil {
		return WorkoutExplanationResult{}, fmt.Errorf("generate workout explanation: %w", err)
	}

	stored, err := s.store.SaveWorkoutExplanationForUser(ctx, user, workoutID, generated)
	if err != nil {
		return WorkoutExplanationResult{}, fmt.Errorf("save workout explanation: %w", err)
	}

	return buildResult(stored, true, s.dailyLimit, generatedToday+1), nil
}

func (s *WorkoutExplainerService) countGeneratedToday(ctx context.Context, user auth.User) (int, error) {
	now := s.now().UTC()
	startOfDay := time.Date(now.Year(), now.Month(), now.Day(), 0, 0, 0, 0, time.UTC)
	count, err := s.store.CountWorkoutExplanationsGeneratedSince(ctx, user, startOfDay)
	if err != nil {
		return 0, fmt.Errorf("count workout explanations generated today: %w", err)
	}

	return count, nil
}

func buildResult(stored StoredWorkoutExplanation, generated bool, dailyLimit int, generatedToday int) WorkoutExplanationResult {
	remaining := 0
	if dailyLimit <= 0 {
		remaining = 0
	} else if generatedToday < dailyLimit {
		remaining = dailyLimit - generatedToday
	}

	return WorkoutExplanationResult{
		WorkoutID:      stored.WorkoutID,
		Provider:       stored.Provider,
		Model:          stored.Model,
		PromptVersion:  stored.PromptVersion,
		Explanation:    stored.Explanation,
		Generated:      generated,
		CreatedAt:      stored.CreatedAt,
		UpdatedAt:      stored.UpdatedAt,
		DailyLimit:     dailyLimit,
		GeneratedToday: generatedToday,
		RemainingToday: remaining,
	}
}
