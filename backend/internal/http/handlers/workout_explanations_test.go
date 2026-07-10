package handlers

import (
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

type fakeWorkoutExplanationService struct {
	result    coaching.WorkoutExplanationResult
	err       error
	workoutID int64
	force     bool
}

func (f *fakeWorkoutExplanationService) ExplainWorkout(_ context.Context, _ auth.User, workoutID int64, force bool) (coaching.WorkoutExplanationResult, error) {
	f.workoutID = workoutID
	f.force = force
	if f.err != nil {
		return coaching.WorkoutExplanationResult{}, f.err
	}
	return f.result, nil
}

func TestWorkoutExplanationHandlerCreate(t *testing.T) {
	t.Parallel()

	gin.SetMode(gin.TestMode)

	service := &fakeWorkoutExplanationService{
		result: coaching.WorkoutExplanationResult{
			WorkoutID:      42,
			Provider:       "mock",
			Model:          "mock-v1",
			PromptVersion:  "workout-explanation-v1",
			Explanation:    "Generated explanation",
			Generated:      true,
			CreatedAt:      time.Date(2026, 7, 8, 10, 0, 0, 0, time.UTC),
			UpdatedAt:      time.Date(2026, 7, 8, 10, 0, 0, 0, time.UTC),
			DailyLimit:     3,
			GeneratedToday: 1,
			RemainingToday: 2,
		},
	}
	handler := NewWorkoutExplanationHandler(service)

	recorder := httptest.NewRecorder()
	c, _ := gin.CreateTestContext(recorder)
	req := httptest.NewRequest(http.MethodPost, "/api/v1/workouts/42/explanation?force=true", nil)
	c.Request = req
	c.Params = gin.Params{{Key: "id", Value: "42"}}
	c.Set("auth_user", auth.User{ID: "user-1"})

	handler.Create(c)

	if recorder.Code != http.StatusCreated {
		t.Fatalf("expected status %d, got %d with body %s", http.StatusCreated, recorder.Code, recorder.Body.String())
	}
	if service.workoutID != 42 {
		t.Fatalf("expected workout id 42, got %d", service.workoutID)
	}
	if !service.force {
		t.Fatalf("expected force=true")
	}

	var response map[string]any
	if err := json.Unmarshal(recorder.Body.Bytes(), &response); err != nil {
		t.Fatalf("json.Unmarshal returned error: %v", err)
	}
	if response["provider"] != "mock" {
		t.Fatalf("expected provider mock, got %#v", response["provider"])
	}
}

func TestWorkoutExplanationHandlerReturnsQuotaError(t *testing.T) {
	t.Parallel()

	gin.SetMode(gin.TestMode)

	service := &fakeWorkoutExplanationService{
		err: coaching.ErrDailyLimitReached,
	}
	handler := NewWorkoutExplanationHandler(service)

	recorder := httptest.NewRecorder()
	c, _ := gin.CreateTestContext(recorder)
	req := httptest.NewRequest(http.MethodPost, "/api/v1/workouts/42/explanation", nil)
	c.Request = req
	c.Params = gin.Params{{Key: "id", Value: "42"}}
	c.Set("auth_user", auth.User{ID: "user-1"})

	handler.Create(c)

	if recorder.Code != http.StatusTooManyRequests {
		t.Fatalf("expected status %d, got %d with body %s", http.StatusTooManyRequests, recorder.Code, recorder.Body.String())
	}
}

func TestWorkoutExplanationHandlerReturnsProviderDisabled(t *testing.T) {
	t.Parallel()

	gin.SetMode(gin.TestMode)

	service := &fakeWorkoutExplanationService{
		err: ai.ErrProviderDisabled,
	}
	handler := NewWorkoutExplanationHandler(service)

	recorder := httptest.NewRecorder()
	c, _ := gin.CreateTestContext(recorder)
	req := httptest.NewRequest(http.MethodPost, "/api/v1/workouts/42/explanation", nil)
	c.Request = req
	c.Params = gin.Params{{Key: "id", Value: "42"}}
	c.Set("auth_user", auth.User{ID: "user-1"})

	handler.Create(c)

	if recorder.Code != http.StatusServiceUnavailable {
		t.Fatalf("expected status %d, got %d with body %s", http.StatusServiceUnavailable, recorder.Code, recorder.Body.String())
	}
}

func TestWorkoutExplanationHandlerReturnsNotFound(t *testing.T) {
	t.Parallel()

	gin.SetMode(gin.TestMode)

	service := &fakeWorkoutExplanationService{
		err: coaching.ErrWorkoutNotFound,
	}
	handler := NewWorkoutExplanationHandler(service)

	recorder := httptest.NewRecorder()
	c, _ := gin.CreateTestContext(recorder)
	req := httptest.NewRequest(http.MethodPost, "/api/v1/workouts/42/explanation", nil)
	c.Request = req
	c.Params = gin.Params{{Key: "id", Value: "42"}}
	c.Set("auth_user", auth.User{ID: "user-1"})

	handler.Create(c)

	if recorder.Code != http.StatusNotFound {
		t.Fatalf("expected status %d, got %d with body %s", http.StatusNotFound, recorder.Code, recorder.Body.String())
	}
}
