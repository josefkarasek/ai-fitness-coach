package handlers

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/josefkarasek/ai-fitness-coach/backend/internal/auth"
)

type fakeWorkoutHistoryStore struct {
	user     auth.User
	workouts []WorkoutHistoryItem
}

func (f *fakeWorkoutHistoryStore) ListWorkoutsForUser(_ context.Context, user auth.User, _ int) ([]WorkoutHistoryItem, error) {
	f.user = user
	return f.workouts, nil
}

func TestWorkoutsHandlerList(t *testing.T) {
	t.Parallel()

	gin.SetMode(gin.TestMode)

	scheduledDate := time.Date(2024, 7, 23, 0, 0, 0, 0, time.UTC)
	reps := 10.0
	load := 33.07

	store := &fakeWorkoutHistoryStore{
		workouts: []WorkoutHistoryItem{
			{
				ID:                 101,
				Source:             "trainheroic_csv",
				SourceWorkoutTitle: "Upper A",
				ScheduledDate:      scheduledDate,
				Exercises: []WorkoutExerciseHistoryItem{
					{
						ID:             201,
						SequenceNumber: 1,
						Title:          "DB Bench Press",
						Sets: []WorkoutSetHistoryItem{
							{
								SequenceNumber:  1,
								MeasurementUnit: "rep",
								Reps:            &reps,
								LoadValue:       &load,
								LoadUnit:        "kilogram",
								RawPrimaryValue: "10",
								RawLoadValue:    "33.07",
							},
						},
					},
				},
			},
		},
	}
	handler := NewWorkoutsHandler(store)

	recorder := httptest.NewRecorder()
	c, _ := gin.CreateTestContext(recorder)
	req := httptest.NewRequest(http.MethodGet, "/api/v1/workouts", nil)
	c.Request = req
	c.Set("auth_user", auth.User{
		ID:          "user-1",
		FirebaseUID: "firebase-user-1",
		Email:       "jk@example.com",
		DisplayName: "Josef",
	})

	handler.List(c)

	if recorder.Code != http.StatusOK {
		t.Fatalf("expected status %d, got %d with body %s", http.StatusOK, recorder.Code, recorder.Body.String())
	}

	if store.user.ID != "user-1" {
		t.Fatalf("expected user id user-1, got %q", store.user.ID)
	}

	var response map[string]any
	if err := json.Unmarshal(recorder.Body.Bytes(), &response); err != nil {
		t.Fatalf("json.Unmarshal returned error: %v", err)
	}

	workouts, ok := response["workouts"].([]any)
	if !ok || len(workouts) != 1 {
		t.Fatalf("expected one workout, got %#v", response["workouts"])
	}

	workout := workouts[0].(map[string]any)
	if workout["source_workout_title"] != "Upper A" {
		t.Fatalf("expected source_workout_title Upper A, got %#v", workout["source_workout_title"])
	}

	exercises := workout["exercises"].([]any)
	if len(exercises) != 1 {
		t.Fatalf("expected one exercise, got %#v", workout["exercises"])
	}
}
