package handlers

import (
	"bytes"
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/josefkarasek/ai-fitness-coach/backend/internal/ai"
	"github.com/josefkarasek/ai-fitness-coach/backend/internal/auth"
	"github.com/josefkarasek/ai-fitness-coach/backend/internal/coaching"
)

type fakeTrainingPlanService struct {
	request ai.TrainingPlanRequest
	result  coaching.TrainingPlanResult
	err     error
}

func (f *fakeTrainingPlanService) GenerateTrainingPlan(_ context.Context, _ auth.User, request ai.TrainingPlanRequest) (coaching.TrainingPlanResult, error) {
	f.request = request
	if f.err != nil {
		return coaching.TrainingPlanResult{}, f.err
	}
	return f.result, nil
}

func (f *fakeTrainingPlanService) GetLatestTrainingPlan(_ context.Context, _ auth.User) (coaching.TrainingPlanResult, error) {
	if f.err != nil {
		return coaching.TrainingPlanResult{}, f.err
	}
	return f.result, nil
}

func (f *fakeTrainingPlanService) GenerateWorkoutForDay(_ context.Context, _ auth.User, _ int64, _ int, _ int) (coaching.TrainingPlanResult, error) {
	if f.err != nil {
		return coaching.TrainingPlanResult{}, f.err
	}
	return f.result, nil
}

func (f *fakeTrainingPlanService) MoveWorkout(_ context.Context, _ auth.User, _ int64, _ int, _ int, _ int) (coaching.TrainingPlanResult, error) {
	if f.err != nil {
		return coaching.TrainingPlanResult{}, f.err
	}
	return f.result, nil
}

func (f *fakeTrainingPlanService) SkipWorkout(_ context.Context, _ auth.User, _ int64, _ int, _ int) (coaching.TrainingPlanResult, error) {
	if f.err != nil {
		return coaching.TrainingPlanResult{}, f.err
	}
	return f.result, nil
}

func TestTrainingPlansHandlerCreate(t *testing.T) {
	t.Parallel()

	gin.SetMode(gin.TestMode)

	service := &fakeTrainingPlanService{
		result: coaching.TrainingPlanResult{
			PlanID:              7,
			Objective:           "Build a 12-week strength block",
			DurationWeeks:       12,
			DaysPerWeek:         4,
			Provider:            "mock",
			Model:               "mock-v1",
			PromptVersion:       "training-plan-v1",
			Summary:             "Summary",
			Philosophy:          "Philosophy",
			ProgressionStrategy: "Progression",
			Risks:               "Risks",
			SuccessCriteria:     "Success",
			Generated:           true,
			CreatedAt:           time.Date(2026, 7, 8, 10, 0, 0, 0, time.UTC),
			UpdatedAt:           time.Date(2026, 7, 8, 10, 0, 0, 0, time.UTC),
			DailyLimit:          1,
			GeneratedToday:      1,
			RemainingToday:      0,
			Weeks: []coaching.StoredTrainingPlanWeek{
				{
					WeekNumber: 1,
					Theme:      "Base building",
					Workouts: []coaching.StoredPlannedWorkout{
						{
							DayNumber: 1,
							Title:     "Week 1 Day 1",
							Focus:     "Lower body",
							Exercises: []coaching.StoredPlannedExercise{
								{
									Title: "Squat",
									Sets: []coaching.StoredPlannedSet{
										{
											Reps:        floatPtr(5),
											TargetValue: floatPtr(100),
											TargetUnit:  "kg",
										},
									},
								},
								{Title: "RDL"},
							},
						},
					},
				},
			},
		},
	}
	handler := NewTrainingPlansHandler(service, nil)

	body := bytes.NewBufferString(`{"objective":"Build a 12-week strength block","duration_weeks":12,"days_per_week":4,"measurement_system":"Metric","constraints":"Protect low back","equipment":"Barbell, dumbbells","notes":"Bias squat and deadlift"}`)
	recorder := httptest.NewRecorder()
	c, _ := gin.CreateTestContext(recorder)
	req := httptest.NewRequest(http.MethodPost, "/api/v1/training-plans", body)
	req.Header.Set("Content-Type", "application/json")
	c.Request = req
	c.Set("auth_user", auth.User{ID: "user-1"})

	handler.Create(c)

	if recorder.Code != http.StatusCreated {
		t.Fatalf("expected status %d, got %d with body %s", http.StatusCreated, recorder.Code, recorder.Body.String())
	}
	if service.request.Objective != "Build a 12-week strength block" {
		t.Fatalf("expected objective to be forwarded, got %q", service.request.Objective)
	}
	if service.request.MeasurementSystem != "Metric" {
		t.Fatalf("expected measurement system Metric, got %q", service.request.MeasurementSystem)
	}

	var response map[string]any
	if err := json.Unmarshal(recorder.Body.Bytes(), &response); err != nil {
		t.Fatalf("json.Unmarshal returned error: %v", err)
	}
	if response["provider"] != "mock" {
		t.Fatalf("expected provider mock, got %#v", response["provider"])
	}
}

func floatPtr(value float64) *float64 {
	return &value
}

func TestTrainingPlansHandlerLatest(t *testing.T) {
	t.Parallel()

	gin.SetMode(gin.TestMode)

	service := &fakeTrainingPlanService{
		result: coaching.TrainingPlanResult{
			PlanID:              7,
			Objective:           "Build a 12-week strength block",
			DurationWeeks:       12,
			DaysPerWeek:         4,
			Provider:            "mock",
			Model:               "mock-v1",
			PromptVersion:       "training-plan-v1",
			Summary:             "Summary",
			Philosophy:          "Philosophy",
			ProgressionStrategy: "Progression",
			Risks:               "Risks",
			SuccessCriteria:     "Success",
			Generated:           false,
			CreatedAt:           time.Date(2026, 7, 8, 10, 0, 0, 0, time.UTC),
			UpdatedAt:           time.Date(2026, 7, 8, 10, 0, 0, 0, time.UTC),
		},
	}
	handler := NewTrainingPlansHandler(service, nil)

	recorder := httptest.NewRecorder()
	c, _ := gin.CreateTestContext(recorder)
	req := httptest.NewRequest(http.MethodGet, "/api/v1/training-plans/latest", nil)
	c.Request = req
	c.Set("auth_user", auth.User{ID: "user-1"})

	handler.Latest(c)

	if recorder.Code != http.StatusOK {
		t.Fatalf("expected status %d, got %d with body %s", http.StatusOK, recorder.Code, recorder.Body.String())
	}
}
