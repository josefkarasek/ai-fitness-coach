package handlers

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/gin-gonic/gin"
	"github.com/josefkarasek/ai-fitness-coach/backend/internal/auth"
	"github.com/josefkarasek/ai-fitness-coach/backend/internal/coaching"
)

type fakePlannedExerciseExplanationService struct {
	result         coaching.PlannedExerciseExplanationResult
	err            error
	trainingPlanID int64
	weekNumber     int
	dayNumber      int
	exerciseIndex  int
}

func (f *fakePlannedExerciseExplanationService) ExplainPlannedExercise(_ context.Context, _ auth.User, trainingPlanID int64, weekNumber int, dayNumber int, exerciseIndex int) (coaching.PlannedExerciseExplanationResult, error) {
	f.trainingPlanID = trainingPlanID
	f.weekNumber = weekNumber
	f.dayNumber = dayNumber
	f.exerciseIndex = exerciseIndex
	if f.err != nil {
		return coaching.PlannedExerciseExplanationResult{}, f.err
	}
	return f.result, nil
}

func TestPlannedExerciseExplanationHandlerCreate(t *testing.T) {
	t.Parallel()

	gin.SetMode(gin.TestMode)

	service := &fakePlannedExerciseExplanationService{
		result: coaching.PlannedExerciseExplanationResult{
			TrainingPlanID:  12,
			WeekNumber:      2,
			DayNumber:       4,
			ExerciseIndex:   1,
			ExerciseTitle:   "Romanian Deadlift",
			Reason:          "Build posterior-chain strength.",
			Support:         "Supports next week's progression.",
			Execution:       "Move with control.",
			MovementPattern: "Hinge",
		},
	}
	handler := NewPlannedExerciseExplanationHandler(service)

	recorder := httptest.NewRecorder()
	c, _ := gin.CreateTestContext(recorder)
	req := httptest.NewRequest(http.MethodPost, "/api/v1/training-plans/12/exercise-explanation", strings.NewReader(`{"week_number":2,"day_number":4,"exercise_index":1}`))
	req.Header.Set("Content-Type", "application/json")
	c.Request = req
	c.Params = gin.Params{{Key: "id", Value: "12"}}
	c.Set("auth_user", auth.User{ID: "user-1"})

	handler.Create(c)

	if recorder.Code != http.StatusOK {
		t.Fatalf("expected status %d, got %d with body %s", http.StatusOK, recorder.Code, recorder.Body.String())
	}
	if service.trainingPlanID != 12 || service.weekNumber != 2 || service.dayNumber != 4 || service.exerciseIndex != 1 {
		t.Fatalf("unexpected captured request values: %#v", service)
	}

	var response map[string]any
	if err := json.Unmarshal(recorder.Body.Bytes(), &response); err != nil {
		t.Fatalf("json.Unmarshal returned error: %v", err)
	}
	if response["movement_pattern"] != "Hinge" {
		t.Fatalf("expected movement pattern Hinge, got %#v", response["movement_pattern"])
	}
}

func TestPlannedExerciseExplanationHandlerNotFound(t *testing.T) {
	t.Parallel()

	gin.SetMode(gin.TestMode)

	service := &fakePlannedExerciseExplanationService{
		err: coaching.ErrPlannedExerciseNotFound,
	}
	handler := NewPlannedExerciseExplanationHandler(service)

	recorder := httptest.NewRecorder()
	c, _ := gin.CreateTestContext(recorder)
	req := httptest.NewRequest(http.MethodPost, "/api/v1/training-plans/12/exercise-explanation", strings.NewReader(`{"week_number":2,"day_number":4,"exercise_index":1}`))
	req.Header.Set("Content-Type", "application/json")
	c.Request = req
	c.Params = gin.Params{{Key: "id", Value: "12"}}
	c.Set("auth_user", auth.User{ID: "user-1"})

	handler.Create(c)

	if recorder.Code != http.StatusNotFound {
		t.Fatalf("expected status %d, got %d with body %s", http.StatusNotFound, recorder.Code, recorder.Body.String())
	}
}
