package traininghistory

import "testing"

func TestParseExerciseDataRepLoadUnit(t *testing.T) {
	t.Parallel()

	sets, err := ParseExerciseData("8, 8, 8, 8, 8 rep x 138.89, 160.94, 182.98, 205.03, 216.05 kilogram")
	if err != nil {
		t.Fatalf("ParseExerciseData returned error: %v", err)
	}

	if len(sets) != 5 {
		t.Fatalf("expected 5 sets, got %d", len(sets))
	}

	if sets[0].MeasurementUnit != "rep" {
		t.Fatalf("expected measurement unit rep, got %q", sets[0].MeasurementUnit)
	}

	if sets[0].Reps == nil || *sets[0].Reps != 8 {
		t.Fatalf("expected first set reps 8, got %#v", sets[0].Reps)
	}

	if sets[4].LoadValue == nil || *sets[4].LoadValue != 216.05 {
		t.Fatalf("expected fifth set load 216.05, got %#v", sets[4].LoadValue)
	}

	if sets[4].LoadUnit != "kilogram" {
		t.Fatalf("expected fifth set load unit kilogram, got %q", sets[4].LoadUnit)
	}
}

func TestParseExerciseDataMeterOnly(t *testing.T) {
	t.Parallel()

	sets, err := ParseExerciseData("30, 30, 30, 30 meter x")
	if err != nil {
		t.Fatalf("ParseExerciseData returned error: %v", err)
	}

	if len(sets) != 4 {
		t.Fatalf("expected 4 sets, got %d", len(sets))
	}

	if sets[0].DistanceMeters == nil || *sets[0].DistanceMeters != 30 {
		t.Fatalf("expected first set distance 30, got %#v", sets[0].DistanceMeters)
	}

	if sets[0].LoadValue != nil {
		t.Fatalf("expected nil load, got %#v", sets[0].LoadValue)
	}
}

func TestParseExerciseDataEmptyValues(t *testing.T) {
	t.Parallel()

	sets, err := ParseExerciseData("rep x kilogram")
	if err != nil {
		t.Fatalf("ParseExerciseData returned error: %v", err)
	}

	if len(sets) != 0 {
		t.Fatalf("expected 0 sets, got %d", len(sets))
	}
}

func TestParseExerciseDataUnknownLoadUnit(t *testing.T) {
	t.Parallel()

	sets, err := ParseExerciseData("8 rep x 45 pound")
	if err != nil {
		t.Fatalf("ParseExerciseData returned error: %v", err)
	}

	if len(sets) != 1 {
		t.Fatalf("expected 1 set, got %d", len(sets))
	}

	if sets[0].LoadValue == nil || *sets[0].LoadValue != 45 {
		t.Fatalf("expected load 45, got %#v", sets[0].LoadValue)
	}

	if sets[0].LoadUnit != "pound" {
		t.Fatalf("expected load unit pound, got %q", sets[0].LoadUnit)
	}
}

func TestParseExerciseDataUnknownMeasurementUnit(t *testing.T) {
	t.Parallel()

	sets, err := ParseExerciseData("time x")
	if err != nil {
		t.Fatalf("ParseExerciseData returned error: %v", err)
	}

	if len(sets) != 0 {
		t.Fatalf("expected 0 sets, got %d", len(sets))
	}
}

func TestParseExerciseDataRepWithMaxToken(t *testing.T) {
	t.Parallel()

	sets, err := ParseExerciseData("25, 20, MAX rep x 5.51, 5.51 kilogram")
	if err != nil {
		t.Fatalf("ParseExerciseData returned error: %v", err)
	}

	if len(sets) != 3 {
		t.Fatalf("expected 3 sets, got %d", len(sets))
	}

	if sets[0].Reps == nil || *sets[0].Reps != 25 {
		t.Fatalf("expected first set reps 25, got %#v", sets[0].Reps)
	}

	if sets[2].RawPrimaryValue != "MAX" {
		t.Fatalf("expected third raw primary value MAX, got %q", sets[2].RawPrimaryValue)
	}

	if sets[2].Reps != nil {
		t.Fatalf("expected third set reps to stay nil, got %#v", sets[2].Reps)
	}
}
