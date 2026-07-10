package traininghistory

import (
	"strings"
	"testing"
)

func TestParseTrainingDataCSVGroupsWorkoutRows(t *testing.T) {
	t.Parallel()

	csvData := strings.NewReader(`WorkoutTitle,ScheduledDate,RescheduledDate,WorkoutNotes,BlockValue,BlockUnits,BlockInstructions,BlockNotes,ExerciseTitle,ExerciseData,ExerciseNotes
W1T1,2022-11-15,,Felt good,0.00,,,,Trap bar deadlift,"8, 8 rep x 100, 120 kilogram",
W1T1,2022-11-15,,Felt good,0.00,,,,DB Row,"10, 10 rep x 30, 30 kilogram",Controlled
`)

	workouts, err := ParseTrainingDataCSV(csvData)
	if err != nil {
		t.Fatalf("ParseTrainingDataCSV returned error: %v", err)
	}

	if len(workouts) != 1 {
		t.Fatalf("expected 1 workout, got %d", len(workouts))
	}

	workout := workouts[0]
	if workout.SourceWorkoutTitle != "W1T1" {
		t.Fatalf("expected workout title W1T1, got %q", workout.SourceWorkoutTitle)
	}

	if len(workout.Exercises) != 2 {
		t.Fatalf("expected 2 exercises, got %d", len(workout.Exercises))
	}

	if workout.Exercises[1].Notes != "Controlled" {
		t.Fatalf("expected second exercise notes Controlled, got %q", workout.Exercises[1].Notes)
	}
}
