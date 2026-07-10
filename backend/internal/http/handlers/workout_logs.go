package handlers

import (
	"context"
	"errors"
	"net/http"
	"strconv"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/josefkarasek/ai-fitness-coach/backend/internal/ai"
	"github.com/josefkarasek/ai-fitness-coach/backend/internal/auth"
	"github.com/josefkarasek/ai-fitness-coach/backend/internal/coaching"
	"github.com/josefkarasek/ai-fitness-coach/backend/internal/http/middleware"
)

type WorkoutLogStore interface {
	UpsertWorkoutLogForUser(ctx context.Context, user auth.User, request WorkoutLogUpsertRequest) (WorkoutLogRecord, error)
	ListWorkoutLogsForUser(ctx context.Context, user auth.User, trainingPlanID int64, limit int) ([]WorkoutLogRecord, error)
}

type WorkoutLogUpsertRequest struct {
	TrainingPlanID  int64
	WeekNumber      int
	DayNumber       int
	Title           string
	Focus           string
	SessionNotes    string
	DurationMinutes *int
	PerformedAt     time.Time
	Exercises       []WorkoutLogExerciseRecord
}

type WorkoutLogRecord struct {
	ID              int64
	TrainingPlanID  int64
	WeekNumber      int
	DayNumber       int
	Title           string
	Focus           string
	SessionNotes    string
	DurationMinutes *int
	PerformedAt     time.Time
	CreatedAt       time.Time
	UpdatedAt       time.Time
	Exercises       []WorkoutLogExerciseRecord
	Review          *WorkoutLogReviewRecord
}

type WorkoutLogExerciseRecord struct {
	SequenceNumber int
	Title          string
	Notes          string
	Sets           []WorkoutLogSetRecord
}

type WorkoutLogSetRecord struct {
	SequenceNumber int
	Reps           *float64
	Value          *float64
	Unit           string
	LoadValue      *float64
	LoadUnit       string
	Completed      bool
}

type WorkoutLogReviewRecord struct {
	WorkoutLogID   int64
	Provider       string
	Model          string
	PromptVersion  string
	Review         string
	Generated      bool
	CreatedAt      time.Time
	UpdatedAt      time.Time
	DailyLimit     int
	GeneratedToday int
	RemainingToday int
}

type WorkoutLogsHandler struct {
	store         WorkoutLogStore
	reviewService WorkoutLogReviewService
}

type WorkoutLogReviewService interface {
	ReviewWorkoutLog(ctx context.Context, user auth.User, workoutLogID int64) (coaching.WorkoutLogReviewResult, error)
}

type createWorkoutLogRequest struct {
	TrainingPlanID  int64                      `json:"training_plan_id"`
	WeekNumber      int                        `json:"week_number"`
	DayNumber       int                        `json:"day_number"`
	Title           string                     `json:"title"`
	Focus           string                     `json:"focus"`
	SessionNotes    string                     `json:"session_notes"`
	DurationMinutes *int                       `json:"duration_minutes"`
	PerformedAt     string                     `json:"performed_at"`
	Exercises       []createWorkoutLogExercise `json:"exercises"`
}

type createWorkoutLogExercise struct {
	Title string                    `json:"title"`
	Notes string                    `json:"notes"`
	Sets  []createWorkoutLogSetItem `json:"sets"`
}

type createWorkoutLogSetItem struct {
	Reps      *float64 `json:"reps"`
	Value     *float64 `json:"value"`
	Unit      string   `json:"unit"`
	LoadValue *float64 `json:"load_value"`
	LoadUnit  string   `json:"load_unit"`
	Completed *bool    `json:"completed"`
}

func NewWorkoutLogsHandler(store WorkoutLogStore, reviewService WorkoutLogReviewService) *WorkoutLogsHandler {
	return &WorkoutLogsHandler{store: store, reviewService: reviewService}
}

func (h *WorkoutLogsHandler) Create(c *gin.Context) {
	user, ok := middleware.UserFromGinContext(c)
	if !ok {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "authenticated user missing from request context"})
		return
	}

	var requestBody createWorkoutLogRequest
	if err := c.ShouldBindJSON(&requestBody); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid request body"})
		return
	}

	request, err := validateWorkoutLogRequest(requestBody)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	logRecord, err := h.store.UpsertWorkoutLogForUser(c.Request.Context(), user, request)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "save workout log"})
		return
	}

	if h.reviewService != nil {
		review, err := h.reviewService.ReviewWorkoutLog(c.Request.Context(), user, logRecord.ID)
		if err != nil {
			switch {
			case errors.Is(err, coaching.ErrWorkoutLogReviewDailyLimit):
			case errors.Is(err, coaching.ErrWorkoutLogNotFound):
			case errors.Is(err, ai.ErrProviderDisabled):
			default:
				c.JSON(http.StatusInternalServerError, gin.H{"error": "generate workout review"})
				return
			}
		} else {
			logRecord.Review = &WorkoutLogReviewRecord{
				WorkoutLogID:   review.WorkoutLogID,
				Provider:       review.Provider,
				Model:          review.Model,
				PromptVersion:  review.PromptVersion,
				Review:         review.Review,
				Generated:      review.Generated,
				CreatedAt:      review.CreatedAt,
				UpdatedAt:      review.UpdatedAt,
				DailyLimit:     review.DailyLimit,
				GeneratedToday: review.GeneratedToday,
				RemainingToday: review.RemainingToday,
			}
		}
	}

	c.JSON(http.StatusCreated, serializeWorkoutLog(logRecord))
}

func (h *WorkoutLogsHandler) List(c *gin.Context) {
	user, ok := middleware.UserFromGinContext(c)
	if !ok {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "authenticated user missing from request context"})
		return
	}

	trainingPlanID, err := parseOptionalInt64(c.Query("training_plan_id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "training_plan_id must be a positive integer"})
		return
	}

	limit, err := parseOptionalInt(c.Query("limit"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "limit must be a positive integer"})
		return
	}

	logs, err := h.store.ListWorkoutLogsForUser(c.Request.Context(), user, trainingPlanID, limit)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "list workout logs"})
		return
	}

	response := make([]gin.H, 0, len(logs))
	for _, logRecord := range logs {
		response = append(response, serializeWorkoutLog(logRecord))
	}

	c.JSON(http.StatusOK, gin.H{"workout_logs": response})
}

func validateWorkoutLogRequest(request createWorkoutLogRequest) (WorkoutLogUpsertRequest, error) {
	if request.TrainingPlanID <= 0 {
		return WorkoutLogUpsertRequest{}, errors.New("training_plan_id is required")
	}
	if request.WeekNumber <= 0 {
		return WorkoutLogUpsertRequest{}, errors.New("week_number must be greater than zero")
	}
	if request.DayNumber <= 0 {
		return WorkoutLogUpsertRequest{}, errors.New("day_number must be greater than zero")
	}

	title := strings.TrimSpace(request.Title)
	if title == "" {
		return WorkoutLogUpsertRequest{}, errors.New("title is required")
	}
	if len(request.Exercises) == 0 {
		return WorkoutLogUpsertRequest{}, errors.New("at least one exercise is required")
	}

	performedAt := time.Now().UTC()
	if trimmed := strings.TrimSpace(request.PerformedAt); trimmed != "" {
		parsed, err := time.Parse(time.RFC3339, trimmed)
		if err != nil {
			return WorkoutLogUpsertRequest{}, errors.New("performed_at must be an RFC3339 timestamp")
		}
		performedAt = parsed.UTC()
	}

	if request.DurationMinutes != nil && *request.DurationMinutes <= 0 {
		return WorkoutLogUpsertRequest{}, errors.New("duration_minutes must be greater than zero")
	}

	exercises := make([]WorkoutLogExerciseRecord, 0, len(request.Exercises))
	for exerciseIdx, exercise := range request.Exercises {
		exerciseTitle := strings.TrimSpace(exercise.Title)
		if exerciseTitle == "" {
			return WorkoutLogUpsertRequest{}, errors.New("exercise title is required")
		}

		sets := make([]WorkoutLogSetRecord, 0, len(exercise.Sets))
		for setIdx, set := range exercise.Sets {
			completed := false
			if set.Completed != nil {
				completed = *set.Completed
			}
			sets = append(sets, WorkoutLogSetRecord{
				SequenceNumber: setIdx + 1,
				Reps:           set.Reps,
				Value:          set.Value,
				Unit:           strings.TrimSpace(set.Unit),
				LoadValue:      set.LoadValue,
				LoadUnit:       strings.TrimSpace(set.LoadUnit),
				Completed:      completed,
			})
		}

		exercises = append(exercises, WorkoutLogExerciseRecord{
			SequenceNumber: exerciseIdx + 1,
			Title:          exerciseTitle,
			Notes:          strings.TrimSpace(exercise.Notes),
			Sets:           sets,
		})
	}

	return WorkoutLogUpsertRequest{
		TrainingPlanID:  request.TrainingPlanID,
		WeekNumber:      request.WeekNumber,
		DayNumber:       request.DayNumber,
		Title:           title,
		Focus:           strings.TrimSpace(request.Focus),
		SessionNotes:    strings.TrimSpace(request.SessionNotes),
		DurationMinutes: request.DurationMinutes,
		PerformedAt:     performedAt,
		Exercises:       exercises,
	}, nil
}

func serializeWorkoutLog(record WorkoutLogRecord) gin.H {
	exercises := make([]gin.H, 0, len(record.Exercises))
	totalSets := 0
	totalCompletedSets := 0
	totalReps := 0.0
	estimatedVolumeByUnit := map[string]float64{}

	for _, exercise := range record.Exercises {
		sets := make([]gin.H, 0, len(exercise.Sets))
		for _, set := range exercise.Sets {
			totalSets++
			if set.Completed {
				totalCompletedSets++
			}
			if set.Completed && set.Reps != nil {
				totalReps += *set.Reps
			}
			appendTrackedVolume(estimatedVolumeByUnit, set)

			sets = append(sets, gin.H{
				"sequence_number": set.SequenceNumber,
				"reps":            set.Reps,
				"value":           set.Value,
				"unit":            set.Unit,
				"load_value":      set.LoadValue,
				"load_unit":       set.LoadUnit,
				"completed":       set.Completed,
			})
		}

		exercises = append(exercises, gin.H{
			"sequence_number": exercise.SequenceNumber,
			"title":           exercise.Title,
			"notes":           exercise.Notes,
			"sets":            sets,
		})
	}

	var (
		estimatedVolume     *float64
		estimatedVolumeUnit string
	)
	if len(estimatedVolumeByUnit) == 1 {
		for unit, value := range estimatedVolumeByUnit {
			estimatedVolumeUnit = unit
			estimatedVolume = &value
		}
	}

	return gin.H{
		"id":                    record.ID,
		"training_plan_id":      record.TrainingPlanID,
		"week_number":           record.WeekNumber,
		"day_number":            record.DayNumber,
		"title":                 record.Title,
		"focus":                 record.Focus,
		"session_notes":         record.SessionNotes,
		"duration_minutes":      record.DurationMinutes,
		"performed_at":          record.PerformedAt,
		"created_at":            record.CreatedAt,
		"updated_at":            record.UpdatedAt,
		"exercise_count":        len(record.Exercises),
		"set_count":             totalSets,
		"completed_set_count":   totalCompletedSets,
		"total_reps":            totalReps,
		"estimated_volume":      estimatedVolume,
		"estimated_volume_unit": estimatedVolumeUnit,
		"exercises":             exercises,
		"review":                serializeWorkoutLogReview(record.Review),
	}
}

func appendTrackedVolume(target map[string]float64, set WorkoutLogSetRecord) {
	if !set.Completed {
		return
	}

	var (
		value *float64
		unit  string
	)

	if isTrackedLoadUnit(set.LoadUnit) && set.LoadValue != nil && *set.LoadValue > 0 {
		value = set.LoadValue
		unit = strings.TrimSpace(set.LoadUnit)
	} else if isTrackedLoadUnit(set.Unit) && set.Value != nil && *set.Value > 0 {
		value = set.Value
		unit = strings.TrimSpace(set.Unit)
	}

	if value == nil || unit == "" {
		return
	}

	multiplier := 1.0
	if set.Reps != nil && *set.Reps > 0 {
		multiplier = *set.Reps
	}

	target[unit] += multiplier * *value
}

func isTrackedLoadUnit(unit string) bool {
	switch strings.ToLower(strings.TrimSpace(unit)) {
	case "kg", "kilogram", "kilograms", "lb", "lbs", "pound", "pounds":
		return true
	default:
		return false
	}
}

func serializeWorkoutLogReview(review *WorkoutLogReviewRecord) gin.H {
	if review == nil {
		return nil
	}

	return gin.H{
		"workout_log_id":  review.WorkoutLogID,
		"provider":        review.Provider,
		"model":           review.Model,
		"prompt_version":  review.PromptVersion,
		"review":          review.Review,
		"generated":       review.Generated,
		"created_at":      review.CreatedAt,
		"updated_at":      review.UpdatedAt,
		"daily_limit":     review.DailyLimit,
		"generated_today": review.GeneratedToday,
		"remaining_today": review.RemainingToday,
	}
}

func parseOptionalInt64(raw string) (int64, error) {
	trimmed := strings.TrimSpace(raw)
	if trimmed == "" {
		return 0, nil
	}
	value, err := strconv.ParseInt(trimmed, 10, 64)
	if err != nil || value <= 0 {
		return 0, errors.New("invalid integer")
	}
	return value, nil
}

func parseOptionalInt(raw string) (int, error) {
	trimmed := strings.TrimSpace(raw)
	if trimmed == "" {
		return 20, nil
	}
	value, err := strconv.Atoi(trimmed)
	if err != nil || value <= 0 {
		return 0, errors.New("invalid integer")
	}
	return value, nil
}
