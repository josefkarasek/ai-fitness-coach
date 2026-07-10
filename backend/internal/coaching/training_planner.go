package coaching

import (
	"context"
	"errors"
	"fmt"
	"slices"
	"time"

	"github.com/josefkarasek/ai-fitness-coach/backend/internal/ai"
	"github.com/josefkarasek/ai-fitness-coach/backend/internal/auth"
)

var (
	ErrNoTrainingPlanFound           = errors.New("training plan not found")
	ErrDailyTrainingPlanLimitReached = errors.New("daily training plan limit reached")
)

type TrainingPlanStore interface {
	SummarizeTrainingHistoryForUser(ctx context.Context, user auth.User) (ai.TrainingHistorySummary, error)
	SaveTrainingPlanForUser(ctx context.Context, user auth.User, request ai.TrainingPlanRequest, generated ai.GeneratedTrainingPlan) (StoredTrainingPlan, error)
	GetLatestTrainingPlanForUser(ctx context.Context, user auth.User) (StoredTrainingPlan, bool, error)
	GetTrainingPlanForUser(ctx context.Context, user auth.User, trainingPlanID int64) (StoredTrainingPlan, bool, error)
	SaveTrainingPlanWorkoutForUser(ctx context.Context, user auth.User, trainingPlanID int64, weekNumber int, workout StoredPlannedWorkout) error
	DeleteTrainingPlanWorkoutForUser(ctx context.Context, user auth.User, trainingPlanID int64, weekNumber int, dayNumber int) error
	CountTrainingPlansGeneratedSince(ctx context.Context, user auth.User, since time.Time) (int, error)
}

type StoredTrainingPlan struct {
	ID                  int64
	Objective           string
	DurationWeeks       int
	DaysPerWeek         int
	MeasurementSystem   string
	Constraints         string
	Equipment           string
	Notes               string
	Provider            string
	Model               string
	PromptVersion       string
	Summary             string
	Philosophy          string
	ProgressionStrategy string
	Risks               string
	SuccessCriteria     string
	Weeks               []StoredTrainingPlanWeek
	CreatedAt           time.Time
	UpdatedAt           time.Time
}

type StoredTrainingPlanWeek struct {
	WeekNumber int
	Theme      string
	Workouts   []StoredPlannedWorkout
}

type StoredPlannedExercise struct {
	Title string
	Notes string
	Sets  []StoredPlannedSet
}

type StoredPlannedSet struct {
	Reps        *float64
	TargetValue *float64
	TargetUnit  string
	LoadValue   *float64
	LoadUnit    string
}

type StoredPlannedWorkout struct {
	DayNumber int
	Title     string
	Focus     string
	Exercises []StoredPlannedExercise
}

type TrainingPlanResult struct {
	PlanID              int64
	Objective           string
	DurationWeeks       int
	DaysPerWeek         int
	MeasurementSystem   string
	Constraints         string
	Equipment           string
	Notes               string
	Provider            string
	Model               string
	PromptVersion       string
	Summary             string
	Philosophy          string
	ProgressionStrategy string
	Risks               string
	SuccessCriteria     string
	Weeks               []StoredTrainingPlanWeek
	Generated           bool
	CreatedAt           time.Time
	UpdatedAt           time.Time
	DailyLimit          int
	GeneratedToday      int
	RemainingToday      int
}

type TrainingPlannerService struct {
	store      TrainingPlanStore
	access     AIAccessStore
	freeAI     ai.TrainingPlanner
	paidAI     ai.TrainingPlanner
	dailyLimit int
	now        func() time.Time
}

func NewTrainingPlannerService(store TrainingPlanStore, planner ai.TrainingPlanner, dailyLimit int) *TrainingPlannerService {
	return NewTrainingPlannerServiceWithAccessControl(store, nil, planner, planner, dailyLimit)
}

func NewTrainingPlannerServiceWithAccessControl(store TrainingPlanStore, access AIAccessStore, freeAI ai.TrainingPlanner, paidAI ai.TrainingPlanner, dailyLimit int) *TrainingPlannerService {
	return &TrainingPlannerService{
		store:      store,
		access:     access,
		freeAI:     freeAI,
		paidAI:     paidAI,
		dailyLimit: dailyLimit,
		now:        time.Now,
	}
}

func (s *TrainingPlannerService) GenerateTrainingPlan(ctx context.Context, user auth.User, request ai.TrainingPlanRequest) (TrainingPlanResult, error) {
	generatedToday, err := s.countGeneratedToday(ctx, user)
	if err != nil {
		return TrainingPlanResult{}, err
	}
	if s.dailyLimit > 0 && generatedToday >= s.dailyLimit {
		return TrainingPlanResult{}, ErrDailyTrainingPlanLimitReached
	}

	history, err := s.store.SummarizeTrainingHistoryForUser(ctx, user)
	if err != nil {
		return TrainingPlanResult{}, fmt.Errorf("summarize training history: %w", err)
	}

	planner, err := s.plannerForUser(ctx, user)
	if err != nil {
		return TrainingPlanResult{}, err
	}

	generated, err := planner.GenerateTrainingPlan(ctx, history, request)
	if err != nil {
		return TrainingPlanResult{}, fmt.Errorf("generate training plan: %w", err)
	}
	generated = assignPlannedWeekdays(generated, request.Profile.PreferredDays)

	stored, err := s.store.SaveTrainingPlanForUser(ctx, user, request, generated)
	if err != nil {
		return TrainingPlanResult{}, fmt.Errorf("save training plan: %w", err)
	}

	return buildTrainingPlanResult(stored, true, s.dailyLimit, generatedToday+1), nil
}

func (s *TrainingPlannerService) GenerateWorkoutForDay(ctx context.Context, user auth.User, trainingPlanID int64, weekNumber int, dayNumber int) (TrainingPlanResult, error) {
	generatedToday, err := s.countGeneratedToday(ctx, user)
	if err != nil {
		return TrainingPlanResult{}, err
	}
	if s.dailyLimit > 0 && generatedToday >= s.dailyLimit {
		return TrainingPlanResult{}, ErrDailyTrainingPlanLimitReached
	}

	stored, found, err := s.store.GetTrainingPlanForUser(ctx, user, trainingPlanID)
	if err != nil {
		return TrainingPlanResult{}, fmt.Errorf("get training plan: %w", err)
	}
	if !found {
		return TrainingPlanResult{}, ErrNoTrainingPlanFound
	}

	week := stored.findWeek(weekNumber)
	if week == nil {
		return TrainingPlanResult{}, ErrNoTrainingPlanFound
	}
	if week.findWorkout(dayNumber) != nil {
		return TrainingPlanResult{}, fmt.Errorf("workout already scheduled for day %d", dayNumber)
	}

	history, err := s.store.SummarizeTrainingHistoryForUser(ctx, user)
	if err != nil {
		return TrainingPlanResult{}, fmt.Errorf("summarize training history: %w", err)
	}

	planner, err := s.plannerForUser(ctx, user)
	if err != nil {
		return TrainingPlanResult{}, err
	}

	generatedWorkout, err := planner.GenerateWorkoutForDay(ctx, history, ai.TrainingDayRequest{
		TrainingPlanID:       stored.ID,
		Objective:            stored.Objective,
		DurationWeeks:        stored.DurationWeeks,
		DaysPerWeek:          stored.DaysPerWeek,
		MeasurementSystem:    stored.MeasurementSystem,
		Constraints:          stored.Constraints,
		Equipment:            stored.Equipment,
		Notes:                stored.Notes,
		Profile:              buildAthleteProfileFromPlan(stored),
		WeekNumber:           week.WeekNumber,
		WeekTheme:            week.Theme,
		DayNumber:            dayNumber,
		CurrentWeekWorkouts:  buildGeneratedWorkouts(week.Workouts),
		ProgressionStrategy:  stored.ProgressionStrategy,
		ExistingWorkoutCount: len(week.Workouts),
	})
	if err != nil {
		return TrainingPlanResult{}, fmt.Errorf("generate workout for day: %w", err)
	}

	if generatedWorkout.DayNumber <= 0 {
		generatedWorkout.DayNumber = dayNumber
	}

	if err := s.store.SaveTrainingPlanWorkoutForUser(ctx, user, stored.ID, week.WeekNumber, buildStoredWorkout(generatedWorkout)); err != nil {
		return TrainingPlanResult{}, fmt.Errorf("save generated workout: %w", err)
	}

	updated, found, err := s.store.GetTrainingPlanForUser(ctx, user, stored.ID)
	if err != nil {
		return TrainingPlanResult{}, fmt.Errorf("reload updated training plan: %w", err)
	}
	if !found {
		return TrainingPlanResult{}, ErrNoTrainingPlanFound
	}

	return buildTrainingPlanResult(updated, true, s.dailyLimit, generatedToday+1), nil
}

func (s *TrainingPlannerService) plannerForUser(ctx context.Context, user auth.User) (ai.TrainingPlanner, error) {
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

func (s *TrainingPlannerService) MoveWorkout(ctx context.Context, user auth.User, trainingPlanID int64, weekNumber int, fromDayNumber int, toDayNumber int) (TrainingPlanResult, error) {
	stored, found, err := s.store.GetTrainingPlanForUser(ctx, user, trainingPlanID)
	if err != nil {
		return TrainingPlanResult{}, fmt.Errorf("get training plan: %w", err)
	}
	if !found {
		return TrainingPlanResult{}, ErrNoTrainingPlanFound
	}

	week := stored.findWeek(weekNumber)
	if week == nil {
		return TrainingPlanResult{}, ErrNoTrainingPlanFound
	}

	workout := week.findWorkout(fromDayNumber)
	if workout == nil {
		return TrainingPlanResult{}, ErrNoTrainingPlanFound
	}
	if week.findWorkout(toDayNumber) != nil {
		return TrainingPlanResult{}, fmt.Errorf("workout already scheduled for day %d", toDayNumber)
	}

	if err := s.store.DeleteTrainingPlanWorkoutForUser(ctx, user, stored.ID, weekNumber, fromDayNumber); err != nil {
		return TrainingPlanResult{}, fmt.Errorf("delete original workout before move: %w", err)
	}

	moved := *workout
	moved.DayNumber = toDayNumber
	if err := s.store.SaveTrainingPlanWorkoutForUser(ctx, user, stored.ID, weekNumber, moved); err != nil {
		return TrainingPlanResult{}, fmt.Errorf("save moved workout: %w", err)
	}

	updated, found, err := s.store.GetTrainingPlanForUser(ctx, user, stored.ID)
	if err != nil {
		return TrainingPlanResult{}, fmt.Errorf("reload updated training plan: %w", err)
	}
	if !found {
		return TrainingPlanResult{}, ErrNoTrainingPlanFound
	}

	generatedToday, err := s.countGeneratedToday(ctx, user)
	if err != nil {
		return TrainingPlanResult{}, err
	}

	return buildTrainingPlanResult(updated, false, s.dailyLimit, generatedToday), nil
}

func (s *TrainingPlannerService) SkipWorkout(ctx context.Context, user auth.User, trainingPlanID int64, weekNumber int, dayNumber int) (TrainingPlanResult, error) {
	if err := s.store.DeleteTrainingPlanWorkoutForUser(ctx, user, trainingPlanID, weekNumber, dayNumber); err != nil {
		return TrainingPlanResult{}, fmt.Errorf("delete skipped workout: %w", err)
	}

	updated, found, err := s.store.GetTrainingPlanForUser(ctx, user, trainingPlanID)
	if err != nil {
		return TrainingPlanResult{}, fmt.Errorf("reload updated training plan: %w", err)
	}
	if !found {
		return TrainingPlanResult{}, ErrNoTrainingPlanFound
	}

	generatedToday, err := s.countGeneratedToday(ctx, user)
	if err != nil {
		return TrainingPlanResult{}, err
	}

	return buildTrainingPlanResult(updated, false, s.dailyLimit, generatedToday), nil
}

func (s *TrainingPlannerService) GetLatestTrainingPlan(ctx context.Context, user auth.User) (TrainingPlanResult, error) {
	stored, found, err := s.store.GetLatestTrainingPlanForUser(ctx, user)
	if err != nil {
		return TrainingPlanResult{}, fmt.Errorf("get latest training plan: %w", err)
	}
	if !found {
		return TrainingPlanResult{}, ErrNoTrainingPlanFound
	}

	generatedToday, err := s.countGeneratedToday(ctx, user)
	if err != nil {
		return TrainingPlanResult{}, err
	}

	return buildTrainingPlanResult(stored, false, s.dailyLimit, generatedToday), nil
}

func (s *TrainingPlannerService) countGeneratedToday(ctx context.Context, user auth.User) (int, error) {
	now := s.now().UTC()
	startOfDay := time.Date(now.Year(), now.Month(), now.Day(), 0, 0, 0, 0, time.UTC)
	count, err := s.store.CountTrainingPlansGeneratedSince(ctx, user, startOfDay)
	if err != nil {
		return 0, fmt.Errorf("count training plans generated today: %w", err)
	}

	return count, nil
}

func buildTrainingPlanResult(stored StoredTrainingPlan, generated bool, dailyLimit int, generatedToday int) TrainingPlanResult {
	remaining := 0
	if dailyLimit > 0 && generatedToday < dailyLimit {
		remaining = dailyLimit - generatedToday
	}

	return TrainingPlanResult{
		PlanID:              stored.ID,
		Objective:           stored.Objective,
		DurationWeeks:       stored.DurationWeeks,
		DaysPerWeek:         stored.DaysPerWeek,
		MeasurementSystem:   stored.MeasurementSystem,
		Constraints:         stored.Constraints,
		Equipment:           stored.Equipment,
		Notes:               stored.Notes,
		Provider:            stored.Provider,
		Model:               stored.Model,
		PromptVersion:       stored.PromptVersion,
		Summary:             stored.Summary,
		Philosophy:          stored.Philosophy,
		ProgressionStrategy: stored.ProgressionStrategy,
		Risks:               stored.Risks,
		SuccessCriteria:     stored.SuccessCriteria,
		Weeks:               stored.Weeks,
		Generated:           generated,
		CreatedAt:           stored.CreatedAt,
		UpdatedAt:           stored.UpdatedAt,
		DailyLimit:          dailyLimit,
		GeneratedToday:      generatedToday,
		RemainingToday:      remaining,
	}
}

func assignPlannedWeekdays(plan ai.GeneratedTrainingPlan, preferredDays []string) ai.GeneratedTrainingPlan {
	weekdayOrder := weekdayIndexesFromLabels(preferredDays)
	for weekIdx := range plan.Weeks {
		for workoutIdx := range plan.Weeks[weekIdx].Workouts {
			if workoutIdx < len(weekdayOrder) {
				plan.Weeks[weekIdx].Workouts[workoutIdx].DayNumber = weekdayOrder[workoutIdx]
				continue
			}
			if plan.Weeks[weekIdx].Workouts[workoutIdx].DayNumber <= 0 {
				plan.Weeks[weekIdx].Workouts[workoutIdx].DayNumber = workoutIdx + 1
			}
		}
	}

	return plan
}

func weekdayIndexesFromLabels(labels []string) []int {
	allLabels := []string{"Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"}
	indexes := make([]int, 0, len(labels))
	for _, label := range labels {
		idx := slices.Index(allLabels, label)
		if idx >= 0 {
			indexes = append(indexes, idx+1)
		}
	}
	if len(indexes) > 0 {
		return indexes
	}

	return []int{1, 2, 3, 4, 5, 6, 7}
}

func buildAthleteProfileFromPlan(plan StoredTrainingPlan) ai.AthleteProfile {
	return ai.AthleteProfile{}
}

func buildGeneratedWorkouts(workouts []StoredPlannedWorkout) []ai.GeneratedPlannedWorkout {
	generated := make([]ai.GeneratedPlannedWorkout, 0, len(workouts))
	for _, workout := range workouts {
		generated = append(generated, ai.GeneratedPlannedWorkout{
			DayNumber: workout.DayNumber,
			Title:     workout.Title,
			Focus:     workout.Focus,
			Exercises: buildGeneratedExercises(workout.Exercises),
		})
	}

	return generated
}

func buildGeneratedExercises(exercises []StoredPlannedExercise) []ai.GeneratedPlannedExercise {
	generated := make([]ai.GeneratedPlannedExercise, 0, len(exercises))
	for _, exercise := range exercises {
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
		generated = append(generated, ai.GeneratedPlannedExercise{
			Title: exercise.Title,
			Notes: exercise.Notes,
			Sets:  sets,
		})
	}

	return generated
}

func buildStoredWorkout(workout ai.GeneratedPlannedWorkout) StoredPlannedWorkout {
	return StoredPlannedWorkout{
		DayNumber: workout.DayNumber,
		Title:     workout.Title,
		Focus:     workout.Focus,
		Exercises: buildStoredExercises(workout.Exercises),
	}
}

func buildStoredExercises(exercises []ai.GeneratedPlannedExercise) []StoredPlannedExercise {
	stored := make([]StoredPlannedExercise, 0, len(exercises))
	for _, exercise := range exercises {
		sets := make([]StoredPlannedSet, 0, len(exercise.Sets))
		for _, set := range exercise.Sets {
			sets = append(sets, StoredPlannedSet{
				Reps:        set.Reps,
				TargetValue: set.TargetValue,
				TargetUnit:  set.TargetUnit,
				LoadValue:   set.LoadValue,
				LoadUnit:    set.LoadUnit,
			})
		}
		stored = append(stored, StoredPlannedExercise{
			Title: exercise.Title,
			Notes: exercise.Notes,
			Sets:  sets,
		})
	}

	return stored
}

func (p StoredTrainingPlan) findWeek(weekNumber int) *StoredTrainingPlanWeek {
	for idx := range p.Weeks {
		if p.Weeks[idx].WeekNumber == weekNumber {
			return &p.Weeks[idx]
		}
	}

	return nil
}

func (w *StoredTrainingPlanWeek) findWorkout(dayNumber int) *StoredPlannedWorkout {
	for idx := range w.Workouts {
		if w.Workouts[idx].DayNumber == dayNumber {
			return &w.Workouts[idx]
		}
	}

	return nil
}
