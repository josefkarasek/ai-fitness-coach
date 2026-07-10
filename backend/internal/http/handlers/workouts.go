package handlers

import (
	"context"
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/josefkarasek/ai-fitness-coach/backend/internal/auth"
	"github.com/josefkarasek/ai-fitness-coach/backend/internal/http/middleware"
)

type WorkoutHistoryStore interface {
	ListWorkoutsForUser(ctx context.Context, user auth.User, limit int) ([]WorkoutHistoryItem, error)
}

type WorkoutHistoryItem struct {
	ID                 int64
	Source             string
	SourceWorkoutTitle string
	ScheduledDate      time.Time
	RescheduledDate    *time.Time
	WorkoutNotes       string
	BlockValue         *float64
	BlockUnits         string
	BlockInstructions  string
	BlockNotes         string
	Exercises          []WorkoutExerciseHistoryItem
}

type WorkoutExerciseHistoryItem struct {
	ID              int64
	SequenceNumber  int
	Title           string
	Notes           string
	RawExerciseData string
	Sets            []WorkoutSetHistoryItem
}

type WorkoutSetHistoryItem struct {
	SequenceNumber  int
	MeasurementUnit string
	Reps            *float64
	DistanceMeters  *float64
	LoadValue       *float64
	LoadUnit        string
	RawPrimaryValue string
	RawLoadValue    string
}

type WorkoutsHandler struct {
	store WorkoutHistoryStore
}

func NewWorkoutsHandler(store WorkoutHistoryStore) *WorkoutsHandler {
	return &WorkoutsHandler{store: store}
}

func (h *WorkoutsHandler) List(c *gin.Context) {
	user, ok := middleware.UserFromGinContext(c)
	if !ok {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "authenticated user missing from request context",
		})
		return
	}

	workouts, err := h.store.ListWorkoutsForUser(c.Request.Context(), user, 50)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "list workouts",
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"workouts": serializeWorkouts(workouts),
	})
}

type workoutResponse struct {
	ID                 int64                     `json:"id"`
	Source             string                    `json:"source"`
	SourceWorkoutTitle string                    `json:"source_workout_title"`
	ScheduledDate      string                    `json:"scheduled_date"`
	RescheduledDate    *string                   `json:"rescheduled_date,omitempty"`
	WorkoutNotes       string                    `json:"workout_notes,omitempty"`
	BlockValue         *float64                  `json:"block_value,omitempty"`
	BlockUnits         string                    `json:"block_units,omitempty"`
	BlockInstructions  string                    `json:"block_instructions,omitempty"`
	BlockNotes         string                    `json:"block_notes,omitempty"`
	Exercises          []workoutExerciseResponse `json:"exercises"`
}

type workoutExerciseResponse struct {
	ID              int64                `json:"id"`
	SequenceNumber  int                  `json:"sequence_number"`
	Title           string               `json:"title"`
	Notes           string               `json:"notes,omitempty"`
	RawExerciseData string               `json:"raw_exercise_data,omitempty"`
	Sets            []workoutSetResponse `json:"sets"`
}

type workoutSetResponse struct {
	SequenceNumber  int      `json:"sequence_number"`
	MeasurementUnit string   `json:"measurement_unit,omitempty"`
	Reps            *float64 `json:"reps,omitempty"`
	DistanceMeters  *float64 `json:"distance_meters,omitempty"`
	LoadValue       *float64 `json:"load_value,omitempty"`
	LoadUnit        string   `json:"load_unit,omitempty"`
	RawPrimaryValue string   `json:"raw_primary_value,omitempty"`
	RawLoadValue    string   `json:"raw_load_value,omitempty"`
}

func serializeWorkouts(workouts []WorkoutHistoryItem) []workoutResponse {
	response := make([]workoutResponse, 0, len(workouts))
	for _, workout := range workouts {
		var rescheduledDate *string
		if workout.RescheduledDate != nil {
			formatted := workout.RescheduledDate.Format("2006-01-02")
			rescheduledDate = &formatted
		}

		exercises := make([]workoutExerciseResponse, 0, len(workout.Exercises))
		for _, exercise := range workout.Exercises {
			sets := make([]workoutSetResponse, 0, len(exercise.Sets))
			for _, set := range exercise.Sets {
				sets = append(sets, workoutSetResponse{
					SequenceNumber:  set.SequenceNumber,
					MeasurementUnit: set.MeasurementUnit,
					Reps:            set.Reps,
					DistanceMeters:  set.DistanceMeters,
					LoadValue:       set.LoadValue,
					LoadUnit:        set.LoadUnit,
					RawPrimaryValue: set.RawPrimaryValue,
					RawLoadValue:    set.RawLoadValue,
				})
			}

			exercises = append(exercises, workoutExerciseResponse{
				ID:              exercise.ID,
				SequenceNumber:  exercise.SequenceNumber,
				Title:           exercise.Title,
				Notes:           exercise.Notes,
				RawExerciseData: exercise.RawExerciseData,
				Sets:            sets,
			})
		}

		response = append(response, workoutResponse{
			ID:                 workout.ID,
			Source:             workout.Source,
			SourceWorkoutTitle: workout.SourceWorkoutTitle,
			ScheduledDate:      workout.ScheduledDate.Format("2006-01-02"),
			RescheduledDate:    rescheduledDate,
			WorkoutNotes:       workout.WorkoutNotes,
			BlockValue:         workout.BlockValue,
			BlockUnits:         workout.BlockUnits,
			BlockInstructions:  workout.BlockInstructions,
			BlockNotes:         workout.BlockNotes,
			Exercises:          exercises,
		})
	}

	return response
}
