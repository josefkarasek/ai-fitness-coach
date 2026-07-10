package ai

import (
	"context"
	"fmt"
	"math"
	"strings"
)

type MockTrainingPlanner struct {
	model string
}

func NewMockTrainingPlanner(model string) *MockTrainingPlanner {
	return &MockTrainingPlanner{model: model}
}

func (p *MockTrainingPlanner) GenerateTrainingPlan(_ context.Context, history TrainingHistorySummary, request TrainingPlanRequest) (GeneratedTrainingPlan, error) {
	topExercises := "compound lifts"
	if len(history.TopExercises) > 0 {
		topExercises = strings.Join(history.TopExercises, ", ")
	}

	recentTitles := "recent training sessions"
	if len(history.RecentWorkoutTitles) > 0 {
		recentTitles = strings.Join(history.RecentWorkoutTitles, ", ")
	}

	goalLabel := strings.TrimSpace(request.Profile.PrimaryGoal)
	if goalLabel == "" {
		goalLabel = request.Objective
	}

	experienceLabel := strings.TrimSpace(request.Profile.TrainingExperience)
	if experienceLabel == "" {
		experienceLabel = "general"
	}

	weeks := make([]GeneratedTrainingPlanWeek, 0, request.DurationWeeks)
	for week := 1; week <= request.DurationWeeks; week++ {
		workouts := make([]GeneratedPlannedWorkout, 0, request.DaysPerWeek)
		for day := 1; day <= request.DaysPerWeek; day++ {
			workouts = append(workouts, GeneratedPlannedWorkout{
				DayNumber: day,
				Title:     fmt.Sprintf("Week %d Day %d", week, day),
				Focus:     mockWorkoutFocus(day),
				Exercises: mockWorkoutExercises(day, goalLabel, request.MeasurementSystem),
			})
		}

		weeks = append(weeks, GeneratedTrainingPlanWeek{
			WeekNumber: week,
			Theme:      mockWeekTheme(week, request.Objective),
			Workouts:   workouts,
		})
	}

	return GeneratedTrainingPlan{
		Provider:            "mock",
		Model:               p.model,
		PromptVersion:       "training-plan-v1",
		Summary:             fmt.Sprintf("This %d-week plan is oriented around %s with %d sessions per week, accounts for a %s training background, and builds on %d imported workouts.", request.DurationWeeks, request.Objective, request.DaysPerWeek, strings.ToLower(experienceLabel), history.WorkoutCount),
		Philosophy:          fmt.Sprintf("Bias the plan toward sustainable progressive overload, keep movement variety manageable, and reuse patterns already visible in %s while keeping %s the main coaching target.", topExercises, strings.ToLower(goalLabel)),
		ProgressionStrategy: fmt.Sprintf("Start with repeatable baseline work, then add load or density across the block while rotating emphasis across %s and the athlete's preferred training rhythm.", recentTitles),
		Risks:               mockRisks(request.Constraints),
		SuccessCriteria:     fmt.Sprintf("Complete %d sessions per week, keep fatigue manageable, and finish the block with clearer progress markers for %s.", request.DaysPerWeek, request.Objective),
		Weeks:               weeks,
	}, nil
}

func (p *MockTrainingPlanner) GenerateWorkoutForDay(_ context.Context, history TrainingHistorySummary, request TrainingDayRequest) (GeneratedPlannedWorkout, error) {
	goalLabel := strings.TrimSpace(request.Profile.PrimaryGoal)
	if goalLabel == "" {
		goalLabel = request.Objective
	}

	dayLabel := mockWeekdayLabel(request.DayNumber)
	title := fmt.Sprintf("Week %d %s", request.WeekNumber, dayLabel)
	if len(request.CurrentWeekWorkouts) >= request.DaysPerWeek {
		title = fmt.Sprintf("Week %d %s Extra Session", request.WeekNumber, dayLabel)
	}

	focus := mockWorkoutFocus(request.DayNumber)
	if history.WorkoutCount > 0 {
		focus = fmt.Sprintf("%s built around patterns you already tolerate well.", focus)
	}

	return GeneratedPlannedWorkout{
		DayNumber: request.DayNumber,
		Title:     title,
		Focus:     focus,
		Exercises: mockWorkoutExercises(request.DayNumber, goalLabel, request.MeasurementSystem),
	}, nil
}

func mockWeekTheme(week int, objective string) string {
	switch {
	case week <= 2:
		return fmt.Sprintf("Base building for %s", objective)
	case week%4 == 0:
		return "Deload and consolidation"
	default:
		return fmt.Sprintf("Progressive overload toward %s", objective)
	}
}

func mockWorkoutFocus(day int) string {
	focuses := []string{
		"Lower body strength and trunk stability",
		"Upper body press and pull balance",
		"Hinge pattern, posterior chain, and conditioning",
		"Hypertrophy support and unilateral accessories",
	}

	return focuses[(day-1)%len(focuses)]
}

func mockWeekdayLabel(day int) string {
	labels := []string{
		"Monday",
		"Tuesday",
		"Wednesday",
		"Thursday",
		"Friday",
		"Saturday",
		"Sunday",
	}

	if day >= 1 && day <= len(labels) {
		return labels[day-1]
	}

	return fmt.Sprintf("Day %d", day)
}

func mockWorkoutExercises(day int, goal string, measurementSystem string) []GeneratedPlannedExercise {
	loadUnit := normalizeLoadUnit(measurementSystem)

	options := [][]GeneratedPlannedExercise{
		{
			mockPlannedExercise("Squat variation", fmt.Sprintf("Primary lower-body lift for the block. Keep this honest and technically repeatable so %s can progress week to week.", strings.ToLower(goal)), loadUnit, []float64{5, 5, 5}, convertProgression([]float64{100, 102.5, 105}, loadUnit)),
			mockPlannedExercise("Romanian deadlift", "Build posterior-chain strength without the systemic cost of another maximal pull.", loadUnit, []float64{8, 8, 8}, convertProgression([]float64{80, 80, 80}, loadUnit)),
			mockPlannedExercise("Split squat", "Use unilateral work to keep positions clean and expose left-right drift before it leaks into the main lift.", loadUnit, []float64{10, 10, 10}, convertProgression([]float64{20, 20, 20}, loadUnit)),
			mockCarryExercise(loadUnit),
		},
		{
			mockPlannedExercise("Bench press variation", "This anchors upper-body intensity and gives the block a stable press you can measure.", loadUnit, []float64{5, 5, 5}, convertProgression([]float64{85, 87.5, 90}, loadUnit)),
			mockPlannedExercise("Chest-supported row", "Support the press with upper-back volume that does not turn into lower-back fatigue.", loadUnit, []float64{10, 10, 10}, convertProgression([]float64{32.5, 32.5, 32.5}, loadUnit)),
			mockPlannedExercise("Overhead press", "Keep intent high, but leave enough room for weekly repeatability.", loadUnit, []float64{8, 8, 8}, convertProgression([]float64{42.5, 42.5, 42.5}, loadUnit)),
			mockPlannedExercise("Pulldown", "Use the band or stack for clean vertical pulling volume when absolute load is less important than position.", "band", []float64{12, 12, 12}, nil),
		},
		{
			mockPlannedExercise("Deadlift variation", "This is the highest-output hinge of the week, so the goal is crisp force production rather than grindy hero reps.", loadUnit, []float64{4, 4, 4}, convertProgression([]float64{140, 145, 150}, loadUnit)),
			mockPlannedExercise("Hip hinge accessory", "Reinforce the hinge pattern with less emotional cost than the main pull.", loadUnit, []float64{8, 8, 8}, convertProgression([]float64{50, 50, 50}, loadUnit)),
			mockPlannedExercise("Hamstring curl", "Accumulate tissue-tolerance work where the exact external load matters less than owning the contraction.", "", []float64{12, 12, 12}, nil),
			mockPlannedExercise("Plank", "Own the position and breathe behind the brace.", "sec", nil, []float64{45, 45, 45}),
		},
		{
			mockPlannedExercise("Single-leg lower body", "Treat this as control work that keeps the main lifts honest later in the block.", loadUnit, []float64{10, 10, 10}, convertProgression([]float64{16, 16, 16}, loadUnit)),
			mockPlannedExercise("DB incline press", "Build upper-body volume with a shoulder-friendly press that does not steal recovery from the primary lift.", loadUnit, []float64{10, 10, 10}, convertProgression([]float64{28, 28, 28}, loadUnit)),
			mockPlannedExercise("Cable row", "Use this for repeatable back volume and clean scapular movement.", "", []float64{12, 12, 12}, nil),
			mockPlannedExercise("Arm and trunk accessories", "Chase quality, not load.", "", []float64{15, 15, 15}, nil),
		},
	}

	return options[(day-1)%len(options)]
}

func mockPlannedExercise(title string, notes string, unit string, repsValues []float64, targetValues []float64) GeneratedPlannedExercise {
	setCount := len(repsValues)
	if len(targetValues) > setCount {
		setCount = len(targetValues)
	}

	sets := make([]GeneratedPlannedSet, 0, setCount)
	for idx := 0; idx < setCount; idx++ {
		var reps *float64
		if idx < len(repsValues) {
			value := repsValues[idx]
			reps = &value
		}

		var targetValue *float64
		if idx < len(targetValues) {
			value := targetValues[idx]
			targetValue = &value
		}

		sets = append(sets, GeneratedPlannedSet{
			Reps:        reps,
			TargetValue: targetValue,
			TargetUnit:  unit,
		})
	}

	return GeneratedPlannedExercise{
		Title: title,
		Notes: notes,
		Sets:  sets,
	}
}

func mockCarryExercise(loadUnit string) GeneratedPlannedExercise {
	distance := 30.0
	sets := make([]GeneratedPlannedSet, 0, 3)
	for i := 0; i < 3; i++ {
		sets = append(sets, GeneratedPlannedSet{
			TargetValue: &distance,
			TargetUnit:  "m",
			LoadUnit:    loadUnit,
		})
	}

	return GeneratedPlannedExercise{
		Title: "Carries",
		Notes: "Treat this as 3 trips of 30 meters. Add the carried load only if you actually used implements like dumbbells or kettlebells.",
		Sets:  sets,
	}
}

func normalizeLoadUnit(measurementSystem string) string {
	if strings.EqualFold(strings.TrimSpace(measurementSystem), "Imperial") {
		return "lb"
	}

	return "kg"
}

func convertProgression(metricValues []float64, loadUnit string) []float64 {
	if loadUnit != "lb" {
		return metricValues
	}

	converted := make([]float64, 0, len(metricValues))
	for _, value := range metricValues {
		converted = append(converted, roundToNearest(value*2.2046226218, 5))
	}

	return converted
}

func roundToNearest(value float64, step float64) float64 {
	if step <= 0 {
		return value
	}

	return math.Round(value/step) * step
}

func mockRisks(constraints string) string {
	if strings.TrimSpace(constraints) == "" {
		return "Main risks are progressing too quickly, adding unnecessary variation, or underestimating recovery needs."
	}

	return fmt.Sprintf("Main risks are violating these constraints (%s), progressing too quickly, or accumulating fatigue faster than recovery supports.", constraints)
}
