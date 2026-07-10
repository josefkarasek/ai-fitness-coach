package ai

import (
	"context"
	"testing"
)

func TestMockTrainingPlannerUsesRequestedMeasurementSystem(t *testing.T) {
	t.Parallel()

	planner := NewMockTrainingPlanner("mock-v1")

	metricPlan, err := planner.GenerateTrainingPlan(context.Background(), TrainingHistorySummary{}, TrainingPlanRequest{
		Objective:         "Build a strength block",
		DurationWeeks:     1,
		DaysPerWeek:       2,
		MeasurementSystem: "Metric",
	})
	if err != nil {
		t.Fatalf("GenerateTrainingPlan metric returned error: %v", err)
	}

	imperialPlan, err := planner.GenerateTrainingPlan(context.Background(), TrainingHistorySummary{}, TrainingPlanRequest{
		Objective:         "Build a strength block",
		DurationWeeks:     1,
		DaysPerWeek:       2,
		MeasurementSystem: "Imperial",
	})
	if err != nil {
		t.Fatalf("GenerateTrainingPlan imperial returned error: %v", err)
	}

	metricLoad := metricPlan.Weeks[0].Workouts[1].Exercises[0].Sets[0]
	if metricLoad.TargetUnit != "kg" {
		t.Fatalf("expected metric load unit kg, got %q", metricLoad.TargetUnit)
	}
	if metricLoad.TargetValue == nil || *metricLoad.TargetValue != 85 {
		t.Fatalf("expected metric bench target 85kg, got %#v", metricLoad.TargetValue)
	}

	imperialLoad := imperialPlan.Weeks[0].Workouts[1].Exercises[0].Sets[0]
	if imperialLoad.TargetUnit != "lb" {
		t.Fatalf("expected imperial load unit lb, got %q", imperialLoad.TargetUnit)
	}
	if imperialLoad.TargetValue == nil || *imperialLoad.TargetValue != 185 {
		t.Fatalf("expected imperial bench target 185lb, got %#v", imperialLoad.TargetValue)
	}
}
