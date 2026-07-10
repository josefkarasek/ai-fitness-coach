package traininghistory

import (
	"archive/zip"
	"bytes"
	"testing"
)

func TestParseTrainHeroicExportZIP(t *testing.T) {
	t.Parallel()

	var buffer bytes.Buffer
	writer := zip.NewWriter(&buffer)

	fileWriter, err := writer.Create("training_data.csv")
	if err != nil {
		t.Fatalf("Create returned error: %v", err)
	}

	_, err = fileWriter.Write([]byte(`WorkoutTitle,ScheduledDate,RescheduledDate,WorkoutNotes,BlockValue,BlockUnits,BlockInstructions,BlockNotes,ExerciseTitle,ExerciseData,ExerciseNotes
W1T1,2022-11-15,,Felt good,0.00,,,,Trap bar deadlift,"8, 8 rep x 100, 120 kilogram",
`))
	if err != nil {
		t.Fatalf("Write returned error: %v", err)
	}

	if err := writer.Close(); err != nil {
		t.Fatalf("Close returned error: %v", err)
	}

	workouts, err := ParseTrainHeroicExportZIP(buffer.Bytes())
	if err != nil {
		t.Fatalf("ParseTrainHeroicExportZIP returned error: %v", err)
	}

	if len(workouts) != 1 {
		t.Fatalf("expected 1 workout, got %d", len(workouts))
	}
}
