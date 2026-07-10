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
	ErrWorkoutLogNotFound         = errors.New("workout log not found")
	ErrWorkoutLogReviewDailyLimit = errors.New("daily workout log review limit reached")
)

type WorkoutLogReviewStore interface {
	GetWorkoutLogForUser(ctx context.Context, user auth.User, workoutLogID int64) (StoredWorkoutLogForReview, bool, error)
	GetTrainingPlanWorkoutContextForUser(ctx context.Context, user auth.User, trainingPlanID int64, weekNumber int, dayNumber int) (StoredTrainingPlanWorkoutContext, bool, error)
	GetWorkoutLogReviewForUser(ctx context.Context, user auth.User, workoutLogID int64) (StoredWorkoutLogReview, bool, error)
	SaveWorkoutLogReviewForUser(ctx context.Context, user auth.User, workoutLogID int64, generated ai.GeneratedWorkoutLogReview) (StoredWorkoutLogReview, error)
	CountWorkoutLogReviewsGeneratedSince(ctx context.Context, user auth.User, since time.Time) (int, error)
}

type StoredWorkoutLogForReview struct {
	ID              int64
	TrainingPlanID  int64
	WeekNumber      int
	DayNumber       int
	Title           string
	Focus           string
	SessionNotes    string
	DurationMinutes *int
	Exercises       []StoredLoggedWorkoutExercise
}

type StoredLoggedWorkoutExercise struct {
	Title string
	Notes string
	Sets  []StoredLoggedWorkoutSet
}

type StoredLoggedWorkoutSet struct {
	Reps      *float64
	Value     *float64
	Unit      string
	LoadValue *float64
	LoadUnit  string
	Completed bool
}

type StoredTrainingPlanWorkoutContext struct {
	Objective string
	WeekTheme string
	Title     string
	Focus     string
	Exercises []StoredPlannedExercise
}

type StoredWorkoutLogReview struct {
	WorkoutLogID  int64
	Provider      string
	Model         string
	PromptVersion string
	Review        string
	CreatedAt     time.Time
	UpdatedAt     time.Time
}

type WorkoutLogReviewResult struct {
	WorkoutLogID   int64
	Provider       string
	Model          string
	PromptVersion  string
	Review         string
	Generated      bool
	CreatedAt      time.Time
	UpdatedAt      time.Time
	DailyLimit     int
	GeneratedToday int
	RemainingToday int
}

type WorkoutLogReviewerService struct {
	store      WorkoutLogReviewStore
	access     AIAccessStore
	freeAI     ai.WorkoutLogReviewer
	paidAI     ai.WorkoutLogReviewer
	dailyLimit int
	now        func() time.Time
}

func NewWorkoutLogReviewerService(store WorkoutLogReviewStore, reviewer ai.WorkoutLogReviewer, dailyLimit int) *WorkoutLogReviewerService {
	return NewWorkoutLogReviewerServiceWithAccessControl(store, nil, reviewer, reviewer, dailyLimit)
}

func NewWorkoutLogReviewerServiceWithAccessControl(store WorkoutLogReviewStore, access AIAccessStore, freeAI ai.WorkoutLogReviewer, paidAI ai.WorkoutLogReviewer, dailyLimit int) *WorkoutLogReviewerService {
	return &WorkoutLogReviewerService{
		store:      store,
		access:     access,
		freeAI:     freeAI,
		paidAI:     paidAI,
		dailyLimit: dailyLimit,
		now:        time.Now,
	}
}

func (s *WorkoutLogReviewerService) ReviewWorkoutLog(ctx context.Context, user auth.User, workoutLogID int64) (WorkoutLogReviewResult, error) {
	existing, found, err := s.store.GetWorkoutLogReviewForUser(ctx, user, workoutLogID)
	if err != nil {
		return WorkoutLogReviewResult{}, fmt.Errorf("get existing workout log review: %w", err)
	}
	if found {
		generatedToday, err := s.countGeneratedToday(ctx, user)
		if err != nil {
			return WorkoutLogReviewResult{}, err
		}
		return buildWorkoutLogReviewResult(existing, false, s.dailyLimit, generatedToday), nil
	}

	generatedToday, err := s.countGeneratedToday(ctx, user)
	if err != nil {
		return WorkoutLogReviewResult{}, err
	}
	if s.dailyLimit > 0 && generatedToday >= s.dailyLimit {
		return WorkoutLogReviewResult{}, ErrWorkoutLogReviewDailyLimit
	}

	workoutLog, found, err := s.store.GetWorkoutLogForUser(ctx, user, workoutLogID)
	if err != nil {
		return WorkoutLogReviewResult{}, fmt.Errorf("get workout log: %w", err)
	}
	if !found {
		return WorkoutLogReviewResult{}, ErrWorkoutLogNotFound
	}

	plannedWorkout, found, err := s.store.GetTrainingPlanWorkoutContextForUser(ctx, user, workoutLog.TrainingPlanID, workoutLog.WeekNumber, workoutLog.DayNumber)
	if err != nil {
		return WorkoutLogReviewResult{}, fmt.Errorf("get planned workout context: %w", err)
	}
	if !found {
		return WorkoutLogReviewResult{}, ErrWorkoutLogNotFound
	}

	reviewer, err := s.reviewerForUser(ctx, user)
	if err != nil {
		return WorkoutLogReviewResult{}, err
	}

	generated, err := reviewer.ReviewWorkoutLog(ctx, buildWorkoutReviewContext(plannedWorkout, workoutLog))
	if err != nil {
		return WorkoutLogReviewResult{}, fmt.Errorf("generate workout log review: %w", err)
	}

	stored, err := s.store.SaveWorkoutLogReviewForUser(ctx, user, workoutLogID, generated)
	if err != nil {
		return WorkoutLogReviewResult{}, fmt.Errorf("save workout log review: %w", err)
	}

	return buildWorkoutLogReviewResult(stored, true, s.dailyLimit, generatedToday+1), nil
}

func (s *WorkoutLogReviewerService) reviewerForUser(ctx context.Context, user auth.User) (ai.WorkoutLogReviewer, error) {
	if s.access == nil {
		return s.paidAI, nil
	}

	enabled, err := s.access.HasPaidAIAccessForUser(ctx, user)
	if err != nil {
		return nil, fmt.Errorf("check ai access: %w", err)
	}
	if enabled {
		return s.paidAI, nil
	}

	return s.freeAI, nil
}

func (s *WorkoutLogReviewerService) countGeneratedToday(ctx context.Context, user auth.User) (int, error) {
	now := s.now().UTC()
	startOfDay := time.Date(now.Year(), now.Month(), now.Day(), 0, 0, 0, 0, time.UTC)
	count, err := s.store.CountWorkoutLogReviewsGeneratedSince(ctx, user, startOfDay)
	if err != nil {
		return 0, fmt.Errorf("count workout log reviews generated today: %w", err)
	}

	return count, nil
}

func buildWorkoutReviewContext(planned StoredTrainingPlanWorkoutContext, log StoredWorkoutLogForReview) ai.WorkoutReviewContext {
	loggedExercises := make([]ai.LoggedWorkoutExercise, 0, len(log.Exercises))
	for _, exercise := range log.Exercises {
		loggedSets := make([]ai.LoggedWorkoutSet, 0, len(exercise.Sets))
		for _, set := range exercise.Sets {
			loggedSets = append(loggedSets, ai.LoggedWorkoutSet{
				Reps:      set.Reps,
				Value:     set.Value,
				Unit:      set.Unit,
				LoadValue: set.LoadValue,
				LoadUnit:  set.LoadUnit,
				Completed: set.Completed,
			})
		}

		loggedExercises = append(loggedExercises, ai.LoggedWorkoutExercise{
			Title: exercise.Title,
			Notes: exercise.Notes,
			Sets:  loggedSets,
		})
	}

	plannedExercises := make([]ai.GeneratedPlannedExercise, 0, len(planned.Exercises))
	for _, exercise := range planned.Exercises {
		sets := make([]ai.GeneratedPlannedSet, 0, len(exercise.Sets))
		for _, set := range exercise.Sets {
			sets = append(sets, ai.GeneratedPlannedSet{
				Reps:        set.Reps,
				TargetValue: set.TargetValue,
				TargetUnit:  set.TargetUnit,
				LoadValue:   set.LoadValue,
				LoadUnit:    set.LoadUnit,
			})
		}

		plannedExercises = append(plannedExercises, ai.GeneratedPlannedExercise{
			Title: exercise.Title,
			Notes: exercise.Notes,
			Sets:  sets,
		})
	}

	return ai.WorkoutReviewContext{
		TrainingPlanObjective: planned.Objective,
		WeekNumber:            log.WeekNumber,
		WeekTheme:             planned.WeekTheme,
		DayNumber:             log.DayNumber,
		WorkoutTitle:          log.Title,
		WorkoutFocus:          log.Focus,
		SessionNotes:          log.SessionNotes,
		DurationMinutes:       log.DurationMinutes,
		PlannedExercises:      plannedExercises,
		LoggedExercises:       loggedExercises,
	}
}

func buildWorkoutLogReviewResult(stored StoredWorkoutLogReview, generated bool, dailyLimit int, generatedToday int) WorkoutLogReviewResult {
	remaining := 0
	if dailyLimit > 0 && generatedToday < dailyLimit {
		remaining = dailyLimit - generatedToday
	}

	return WorkoutLogReviewResult{
		WorkoutLogID:   stored.WorkoutLogID,
		Provider:       stored.Provider,
		Model:          stored.Model,
		PromptVersion:  stored.PromptVersion,
		Review:         stored.Review,
		Generated:      generated,
		CreatedAt:      stored.CreatedAt,
		UpdatedAt:      stored.UpdatedAt,
		DailyLimit:     dailyLimit,
		GeneratedToday: generatedToday,
		RemainingToday: remaining,
	}
}
