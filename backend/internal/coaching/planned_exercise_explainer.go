package coaching

import (
	"context"
	"errors"
	"fmt"
	"strings"

	"github.com/josefkarasek/ai-fitness-coach/backend/internal/auth"
)

var ErrPlannedExerciseNotFound = errors.New("planned exercise not found")

type PlannedExerciseExplanationStore interface {
	GetTrainingPlanForUser(ctx context.Context, user auth.User, trainingPlanID int64) (StoredTrainingPlan, bool, error)
}

type PlannedExerciseExplanationResult struct {
	TrainingPlanID   int64
	WeekNumber       int
	DayNumber        int
	ExerciseIndex    int
	ExerciseTitle    string
	Reason           string
	Support          string
	Execution        string
	MovementPattern  string
	MeasurementSystem string
}

type PlannedExerciseExplainerService struct {
	store PlannedExerciseExplanationStore
}

func NewPlannedExerciseExplainerService(store PlannedExerciseExplanationStore) *PlannedExerciseExplainerService {
	return &PlannedExerciseExplainerService{store: store}
}

func (s *PlannedExerciseExplainerService) ExplainPlannedExercise(
	ctx context.Context,
	user auth.User,
	trainingPlanID int64,
	weekNumber int,
	dayNumber int,
	exerciseIndex int,
) (PlannedExerciseExplanationResult, error) {
	stored, found, err := s.store.GetTrainingPlanForUser(ctx, user, trainingPlanID)
	if err != nil {
		return PlannedExerciseExplanationResult{}, fmt.Errorf("get training plan: %w", err)
	}
	if !found {
		return PlannedExerciseExplanationResult{}, ErrNoTrainingPlanFound
	}

	week := stored.findWeek(weekNumber)
	if week == nil {
		return PlannedExerciseExplanationResult{}, ErrNoTrainingPlanFound
	}

	workout := week.findWorkout(dayNumber)
	if workout == nil {
		return PlannedExerciseExplanationResult{}, ErrNoTrainingPlanFound
	}

	if exerciseIndex < 0 || exerciseIndex >= len(workout.Exercises) {
		return PlannedExerciseExplanationResult{}, ErrPlannedExerciseNotFound
	}

	exercise := workout.Exercises[exerciseIndex]

	return PlannedExerciseExplanationResult{
		TrainingPlanID:   stored.ID,
		WeekNumber:       weekNumber,
		DayNumber:        dayNumber,
		ExerciseIndex:    exerciseIndex,
		ExerciseTitle:    exercise.Title,
		Reason:           buildPlannedExerciseReason(stored, *week, *workout, exercise),
		Support:          buildPlannedExerciseSupport(stored, weekNumber),
		Execution:        buildPlannedExerciseExecution(exercise),
		MovementPattern:  plannedExerciseMovementPattern(exercise.Title),
		MeasurementSystem: stored.MeasurementSystem,
	}, nil
}

func buildPlannedExerciseReason(plan StoredTrainingPlan, week StoredTrainingPlanWeek, workout StoredPlannedWorkout, exercise StoredPlannedExercise) string {
	parts := make([]string, 0, 3)
	if focus := strings.TrimSpace(workout.Focus); focus != "" {
		parts = append(parts, firstSentence(focus))
	}

	lower := strings.ToLower(strings.TrimSpace(exercise.Title))
	switch {
	case strings.Contains(lower, "squat"):
		parts = append(parts, "It reinforces lower-body strength, bracing, and confidence in the squat pattern under fatigue.")
	case strings.Contains(lower, "deadlift"), strings.Contains(lower, "rdl"), strings.Contains(lower, "hinge"):
		parts = append(parts, "It builds posterior-chain strength and keeps the hinge pattern sharp without drifting away from the block goal.")
	case strings.Contains(lower, "bench"), strings.Contains(lower, "press"):
		parts = append(parts, "It develops pressing force while keeping the upper body contributing to the larger block objective.")
	case strings.Contains(lower, "row"), strings.Contains(lower, "pull"), strings.Contains(lower, "pulldown"):
		parts = append(parts, "It supports upper-back strength and better positions on the main lifts.")
	case strings.Contains(lower, "carry"):
		parts = append(parts, "It ties trunk stability, grip, and whole-body tension together in a way that carries into heavier lifting.")
	case strings.Contains(lower, "split squat"), strings.Contains(lower, "lunge"):
		parts = append(parts, "It builds single-leg strength and control so your main bilateral lifts stay cleaner.")
	case strings.Contains(lower, "plank"), strings.Contains(lower, "rotation"):
		parts = append(parts, "It gives the block trunk control so heavier work has a more stable base.")
	default:
		parts = append(parts, "It is here to support the day objective with repeatable, coachable work.")
	}

	if theme := strings.TrimSpace(week.Theme); theme != "" {
		parts = append(parts, "This fits the current week theme: "+theme+".")
	}

	return strings.Join(parts, " ")
}

func buildPlannedExerciseSupport(plan StoredTrainingPlan, weekNumber int) string {
	nextWeek := plan.findWeek(weekNumber + 1)
	if nextWeek != nil && strings.TrimSpace(nextWeek.Theme) != "" {
		return "This supports the next stage of the block: " + strings.TrimSpace(nextWeek.Theme) + "."
	}

	if strategy := strings.TrimSpace(plan.ProgressionStrategy); strategy != "" {
		return firstSentence(strategy)
	}

	if objective := strings.TrimSpace(plan.Objective); objective != "" {
		return "This keeps the block moving toward " + objective + "."
	}

	return "This sets up stronger work later in the block by keeping the signal clean now."
}

func buildPlannedExerciseExecution(exercise StoredPlannedExercise) string {
	if notes := strings.TrimSpace(exercise.Notes); notes != "" {
		return notes
	}

	switch plannedExerciseMovementPattern(exercise.Title) {
	case "Squat":
		return "Own your brace, move with control, and avoid chasing ugly reps."
	case "Hinge":
		return "Keep the hinge crisp and stop the set when position starts to leak."
	case "Press":
		return "Move with intent, but keep enough room in reserve for the rest of the session."
	case "Pull":
		return "Treat this as quality upper-back work rather than momentum work."
	case "Carry":
		return "Stay tall, keep tension through the trunk, and make every step look deliberate."
	case "Single-leg":
		return "Stay balanced, move cleanly, and let control matter more than speed."
	case "Trunk":
		return "Keep tension honest and posture organized from the first second to the last."
	default:
		return "Move well, log honestly, and keep this exercise connected to the purpose of the day."
	}
}

func plannedExerciseMovementPattern(title string) string {
	lower := strings.ToLower(strings.TrimSpace(title))
	switch {
	case strings.Contains(lower, "squat"):
		return "Squat"
	case strings.Contains(lower, "deadlift"), strings.Contains(lower, "rdl"), strings.Contains(lower, "hinge"):
		return "Hinge"
	case strings.Contains(lower, "bench"), strings.Contains(lower, "press"):
		return "Press"
	case strings.Contains(lower, "row"), strings.Contains(lower, "pull"), strings.Contains(lower, "pulldown"):
		return "Pull"
	case strings.Contains(lower, "carry"):
		return "Carry"
	case strings.Contains(lower, "split squat"), strings.Contains(lower, "lunge"):
		return "Single-leg"
	case strings.Contains(lower, "plank"), strings.Contains(lower, "rotation"):
		return "Trunk"
	default:
		return "Assistance"
	}
}

func firstSentence(text string) string {
	trimmed := strings.TrimSpace(text)
	if trimmed == "" {
		return ""
	}

	for _, delimiter := range []string{". ", "! ", "? "} {
		if index := strings.Index(trimmed, delimiter); index >= 0 {
			return strings.TrimSpace(trimmed[:index+1])
		}
	}

	return trimmed
}
