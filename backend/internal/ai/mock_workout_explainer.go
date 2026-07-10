package ai

import (
	"context"
	"fmt"
	"strings"
)

type MockWorkoutExplainer struct {
	model string
}

func NewMockWorkoutExplainer(model string) *MockWorkoutExplainer {
	return &MockWorkoutExplainer{model: model}
}

func (e *MockWorkoutExplainer) ExplainWorkout(_ context.Context, workout WorkoutContext) (GeneratedWorkoutExplanation, error) {
	exerciseLines := make([]string, 0, len(workout.Exercises))
	for _, exercise := range workout.Exercises {
		exerciseLines = append(exerciseLines, summarizeExercise(exercise))
	}

	var builder strings.Builder
	builder.WriteString("This session looks like a focused training day built from your logged history. ")
	builder.WriteString(fmt.Sprintf("The workout \"%s\" on %s includes %d exercises. ",
		workout.SourceWorkoutTitle,
		workout.ScheduledDate.Format("2006-01-02"),
		len(workout.Exercises),
	))

	if workout.BlockInstructions != "" {
		builder.WriteString("The block instructions suggest the broader intent was: ")
		builder.WriteString(workout.BlockInstructions)
		builder.WriteString(". ")
	}

	if len(exerciseLines) > 0 {
		builder.WriteString("Exercise emphasis: ")
		builder.WriteString(strings.Join(exerciseLines, " "))
		builder.WriteString(" ")
	}

	if workout.WorkoutNotes != "" {
		builder.WriteString("Your logged notes for the session were: ")
		builder.WriteString(workout.WorkoutNotes)
		builder.WriteString(". ")
	}

	if workout.BlockNotes != "" {
		builder.WriteString("Block notes captured alongside the plan were: ")
		builder.WriteString(workout.BlockNotes)
		builder.WriteString(".")
	}

	return GeneratedWorkoutExplanation{
		Provider:      "mock",
		Model:         e.model,
		PromptVersion: "workout-explanation-v1",
		Text:          strings.TrimSpace(builder.String()),
	}, nil
}

func summarizeExercise(exercise WorkoutExerciseContext) string {
	if len(exercise.Sets) == 0 {
		return fmt.Sprintf("%s appears without recorded set details.", exercise.Title)
	}

	totalSets := len(exercise.Sets)
	var setDescriptors []string
	for _, set := range exercise.Sets {
		if descriptor := summarizeSet(set); descriptor != "" {
			setDescriptors = append(setDescriptors, descriptor)
		}
	}

	if len(setDescriptors) == 0 {
		return fmt.Sprintf("%s carries %d logged sets.", exercise.Title, totalSets)
	}

	return fmt.Sprintf("%s uses %d sets (%s).", exercise.Title, totalSets, strings.Join(setDescriptors, ", "))
}

func summarizeSet(set WorkoutSetContext) string {
	switch {
	case set.Reps != nil && set.LoadValue != nil && strings.TrimSpace(set.LoadUnit) != "":
		return fmt.Sprintf("%.0f reps at %.2f %s", *set.Reps, *set.LoadValue, set.LoadUnit)
	case set.Reps != nil && set.LoadValue != nil:
		return fmt.Sprintf("%.0f reps at %.2f load", *set.Reps, *set.LoadValue)
	case set.Reps != nil:
		return fmt.Sprintf("%.0f reps", *set.Reps)
	case set.DistanceMeters != nil:
		return fmt.Sprintf("%.0f meters", *set.DistanceMeters)
	case set.RawPrimaryValue != "":
		if set.RawLoadValue != "" {
			return fmt.Sprintf("%s at %s", set.RawPrimaryValue, set.RawLoadValue)
		}
		return set.RawPrimaryValue
	default:
		return ""
	}
}
