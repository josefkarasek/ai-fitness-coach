package coaching

import (
	"context"
	"fmt"

	"github.com/josefkarasek/ai-fitness-coach/backend/internal/ai"
	"github.com/josefkarasek/ai-fitness-coach/backend/internal/auth"
)

type WeeklyCoachingPreviewStore interface {
	GetLatestTrainingPlanForUser(ctx context.Context, user auth.User) (StoredTrainingPlan, bool, error)
}

type WeeklyCoachingPreviewResult struct {
	TrainingPlanID  int64
	CurrentWeek     int
	PreviewWeek     int
	PreviewTheme    string
	Provider        string
	Model           string
	PromptVersion   string
	Feedback        string
	Motivation      string
}

type WeeklyCoachingPreviewService struct {
	store     WeeklyCoachingPreviewStore
	previewer ai.WeeklyCoachingPreviewer
}

func NewWeeklyCoachingPreviewService(store WeeklyCoachingPreviewStore, previewer ai.WeeklyCoachingPreviewer) *WeeklyCoachingPreviewService {
	return &WeeklyCoachingPreviewService{
		store:     store,
		previewer: previewer,
	}
}

func (s *WeeklyCoachingPreviewService) GenerateForNextWeek(ctx context.Context, user auth.User, trainingPlanID int64, currentWeek int) (WeeklyCoachingPreviewResult, error) {
	plan, found, err := s.store.GetLatestTrainingPlanForUser(ctx, user)
	if err != nil {
		return WeeklyCoachingPreviewResult{}, fmt.Errorf("load latest training plan: %w", err)
	}
	if !found || plan.ID != trainingPlanID {
		return WeeklyCoachingPreviewResult{}, ErrNoTrainingPlanFound
	}

	previewWeek := currentWeek + 1
	if previewWeek > len(plan.Weeks) {
		previewWeek = len(plan.Weeks)
	}
	if previewWeek <= 0 {
		return WeeklyCoachingPreviewResult{}, ErrNoTrainingPlanFound
	}

	var previewPlanWeek *StoredTrainingPlanWeek
	for i := range plan.Weeks {
		if plan.Weeks[i].WeekNumber == previewWeek {
			previewPlanWeek = &plan.Weeks[i]
			break
		}
	}
	if previewPlanWeek == nil {
		return WeeklyCoachingPreviewResult{}, ErrNoTrainingPlanFound
	}

	workoutTitles := make([]string, 0, len(previewPlanWeek.Workouts))
	for _, workout := range previewPlanWeek.Workouts {
		workoutTitles = append(workoutTitles, workout.Title)
	}

	generated, err := s.previewer.GenerateWeeklyCoachingPreview(ctx, ai.WeeklyCoachingPreviewContext{
		TrainingPlanID:        plan.ID,
		TrainingPlanObjective: plan.Objective,
		CurrentWeekNumber:     currentWeek,
		PreviewWeekNumber:     previewWeek,
		PreviewWeekTheme:      previewPlanWeek.Theme,
		PreviewWorkoutTitles:  workoutTitles,
		ProgressionStrategy:   plan.ProgressionStrategy,
		SuccessCriteria:       plan.SuccessCriteria,
	})
	if err != nil {
		return WeeklyCoachingPreviewResult{}, fmt.Errorf("generate weekly coaching preview: %w", err)
	}

	return WeeklyCoachingPreviewResult{
		TrainingPlanID: trainingPlanID,
		CurrentWeek:    currentWeek,
		PreviewWeek:    previewWeek,
		PreviewTheme:   previewPlanWeek.Theme,
		Provider:       generated.Provider,
		Model:          generated.Model,
		PromptVersion:  generated.PromptVersion,
		Feedback:       generated.Feedback,
		Motivation:     generated.Motivation,
	}, nil
}
