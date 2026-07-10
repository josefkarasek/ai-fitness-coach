package ai

import (
	"context"
	"errors"
	"time"
)

var ErrProviderDisabled = errors.New("ai provider is disabled")

type WorkoutContext struct {
	WorkoutID          int64
	Source             string
	SourceWorkoutTitle string
	ScheduledDate      time.Time
	WorkoutNotes       string
	BlockInstructions  string
	BlockNotes         string
	Exercises          []WorkoutExerciseContext
}

type WorkoutExerciseContext struct {
	SequenceNumber int
	Title          string
	Notes          string
	Sets           []WorkoutSetContext
}

type WorkoutSetContext struct {
	SequenceNumber  int
	MeasurementUnit string
	Reps            *float64
	DistanceMeters  *float64
	LoadValue       *float64
	LoadUnit        string
	RawPrimaryValue string
	RawLoadValue    string
}

type GeneratedWorkoutExplanation struct {
	Provider      string
	Model         string
	PromptVersion string
	Text          string
}

type WorkoutExplainer interface {
	ExplainWorkout(ctx context.Context, workout WorkoutContext) (GeneratedWorkoutExplanation, error)
}

type TrainingHistorySummary struct {
	WorkoutCount        int
	RecentWorkoutTitles []string
	TopExercises        []string
}

type AthleteProfile struct {
	DisplayName        string
	TrainingExperience string
	PrimaryGoal        string
	PreferredDays      []string
}

type TrainingPlanRequest struct {
	Objective         string
	DurationWeeks     int
	DaysPerWeek       int
	MeasurementSystem string
	Constraints       string
	Equipment         string
	Notes             string
	Profile           AthleteProfile
}

type TrainingDayRequest struct {
	TrainingPlanID       int64
	Objective            string
	DurationWeeks        int
	DaysPerWeek          int
	MeasurementSystem    string
	Constraints          string
	Equipment            string
	Notes                string
	Profile              AthleteProfile
	WeekNumber           int
	WeekTheme            string
	DayNumber            int
	CurrentWeekWorkouts  []GeneratedPlannedWorkout
	ProgressionStrategy  string
	ExistingWorkoutCount int
}

type GeneratedTrainingPlan struct {
	Provider            string
	Model               string
	PromptVersion       string
	Summary             string
	Philosophy          string
	ProgressionStrategy string
	Risks               string
	SuccessCriteria     string
	Weeks               []GeneratedTrainingPlanWeek
}

type GeneratedTrainingPlanWeek struct {
	WeekNumber int
	Theme      string
	Workouts   []GeneratedPlannedWorkout
}

type GeneratedPlannedExercise struct {
	Title string
	Notes string
	Sets  []GeneratedPlannedSet
}

type GeneratedPlannedSet struct {
	Reps        *float64
	TargetValue *float64
	TargetUnit  string
	LoadValue   *float64
	LoadUnit    string
}

type GeneratedPlannedWorkout struct {
	DayNumber int
	Title     string
	Focus     string
	Exercises []GeneratedPlannedExercise
}

type TrainingPlanner interface {
	GenerateTrainingPlan(ctx context.Context, history TrainingHistorySummary, request TrainingPlanRequest) (GeneratedTrainingPlan, error)
	GenerateWorkoutForDay(ctx context.Context, history TrainingHistorySummary, request TrainingDayRequest) (GeneratedPlannedWorkout, error)
}

type WeeklyCoachingPreviewContext struct {
	TrainingPlanID        int64
	TrainingPlanObjective string
	CurrentWeekNumber     int
	PreviewWeekNumber     int
	PreviewWeekTheme      string
	PreviewWorkoutTitles  []string
	ProgressionStrategy   string
	SuccessCriteria       string
}

type GeneratedWeeklyCoachingPreview struct {
	Provider      string
	Model         string
	PromptVersion string
	Feedback      string
	Motivation    string
}

type WeeklyCoachingPreviewer interface {
	GenerateWeeklyCoachingPreview(ctx context.Context, preview WeeklyCoachingPreviewContext) (GeneratedWeeklyCoachingPreview, error)
}

type WorkoutReviewContext struct {
	TrainingPlanObjective string
	WeekNumber            int
	WeekTheme             string
	DayNumber             int
	WorkoutTitle          string
	WorkoutFocus          string
	SessionNotes          string
	DurationMinutes       *int
	PlannedExercises      []GeneratedPlannedExercise
	LoggedExercises       []LoggedWorkoutExercise
}

type LoggedWorkoutExercise struct {
	Title string
	Notes string
	Sets  []LoggedWorkoutSet
}

type LoggedWorkoutSet struct {
	Reps      *float64
	Value     *float64
	Unit      string
	LoadValue *float64
	LoadUnit  string
	Completed bool
}

type GeneratedWorkoutLogReview struct {
	Provider      string
	Model         string
	PromptVersion string
	Review        string
}

type WorkoutLogReviewer interface {
	ReviewWorkoutLog(ctx context.Context, workout WorkoutReviewContext) (GeneratedWorkoutLogReview, error)
}
