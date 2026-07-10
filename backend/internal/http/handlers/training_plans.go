package handlers

import (
	"context"
	"errors"
	"net/http"
	"strconv"
	"strings"

	"github.com/gin-gonic/gin"
	"github.com/josefkarasek/ai-fitness-coach/backend/internal/ai"
	"github.com/josefkarasek/ai-fitness-coach/backend/internal/auth"
	"github.com/josefkarasek/ai-fitness-coach/backend/internal/coaching"
	"github.com/josefkarasek/ai-fitness-coach/backend/internal/http/middleware"
)

type TrainingPlanService interface {
	GenerateTrainingPlan(ctx context.Context, user auth.User, request ai.TrainingPlanRequest) (coaching.TrainingPlanResult, error)
	GetLatestTrainingPlan(ctx context.Context, user auth.User) (coaching.TrainingPlanResult, error)
	GenerateWorkoutForDay(ctx context.Context, user auth.User, trainingPlanID int64, weekNumber int, dayNumber int) (coaching.TrainingPlanResult, error)
	MoveWorkout(ctx context.Context, user auth.User, trainingPlanID int64, weekNumber int, fromDayNumber int, toDayNumber int) (coaching.TrainingPlanResult, error)
	SkipWorkout(ctx context.Context, user auth.User, trainingPlanID int64, weekNumber int, dayNumber int) (coaching.TrainingPlanResult, error)
}

type WeeklyCoachingPreviewService interface {
	GenerateForNextWeek(ctx context.Context, user auth.User, trainingPlanID int64, currentWeek int) (coaching.WeeklyCoachingPreviewResult, error)
}

type TrainingPlansHandler struct {
	service   TrainingPlanService
	previewer WeeklyCoachingPreviewService
}

type createTrainingPlanRequest struct {
	Objective         string `json:"objective"`
	DurationWeeks     int    `json:"duration_weeks"`
	DaysPerWeek       int    `json:"days_per_week"`
	MeasurementSystem string `json:"measurement_system"`
	Constraints       string `json:"constraints"`
	Equipment         string `json:"equipment"`
	Notes             string `json:"notes"`
	Profile           struct {
		DisplayName        string   `json:"display_name"`
		TrainingExperience string   `json:"training_experience"`
		PrimaryGoal        string   `json:"primary_goal"`
		PreferredDays      []string `json:"preferred_days"`
	} `json:"profile"`
}

func NewTrainingPlansHandler(service TrainingPlanService, previewer WeeklyCoachingPreviewService) *TrainingPlansHandler {
	return &TrainingPlansHandler{
		service:   service,
		previewer: previewer,
	}
}

func (h *TrainingPlansHandler) Create(c *gin.Context) {
	user, ok := middleware.UserFromGinContext(c)
	if !ok {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "authenticated user missing from request context"})
		return
	}

	var requestBody createTrainingPlanRequest
	if err := c.ShouldBindJSON(&requestBody); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid request body"})
		return
	}

	request, err := validateTrainingPlanRequest(requestBody)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	result, err := h.service.GenerateTrainingPlan(c.Request.Context(), user, request)
	if err != nil {
		switch {
		case errors.Is(err, coaching.ErrDailyTrainingPlanLimitReached):
			c.JSON(http.StatusTooManyRequests, gin.H{"error": "daily training plan limit reached"})
		case errors.Is(err, ai.ErrProviderDisabled):
			c.JSON(http.StatusServiceUnavailable, gin.H{"error": "ai provider is disabled"})
		default:
			c.JSON(http.StatusInternalServerError, gin.H{"error": "generate training plan"})
		}
		return
	}

	c.JSON(http.StatusCreated, serializeTrainingPlanResult(result))
}

func (h *TrainingPlansHandler) Latest(c *gin.Context) {
	user, ok := middleware.UserFromGinContext(c)
	if !ok {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "authenticated user missing from request context"})
		return
	}

	result, err := h.service.GetLatestTrainingPlan(c.Request.Context(), user)
	if err != nil {
		switch {
		case errors.Is(err, coaching.ErrNoTrainingPlanFound):
			c.JSON(http.StatusNotFound, gin.H{"error": "training plan not found"})
		default:
			c.JSON(http.StatusInternalServerError, gin.H{"error": "load latest training plan"})
		}
		return
	}

	c.JSON(http.StatusOK, serializeTrainingPlanResult(result))
}

func (h *TrainingPlansHandler) GenerateWeeklyPreview(c *gin.Context) {
	user, ok := middleware.UserFromGinContext(c)
	if !ok {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "authenticated user missing from request context"})
		return
	}
	if h.previewer == nil {
		c.JSON(http.StatusServiceUnavailable, gin.H{"error": "weekly coaching preview unavailable"})
		return
	}

	trainingPlanID, err := strconv.ParseInt(strings.TrimSpace(c.Param("id")), 10, 64)
	if err != nil || trainingPlanID <= 0 {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid training plan id"})
		return
	}

	var requestBody struct {
		CurrentWeek int `json:"current_week"`
	}
	if err := c.ShouldBindJSON(&requestBody); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid request body"})
		return
	}
	if requestBody.CurrentWeek <= 0 {
		c.JSON(http.StatusBadRequest, gin.H{"error": "current_week must be positive"})
		return
	}

	result, err := h.previewer.GenerateForNextWeek(c.Request.Context(), user, trainingPlanID, requestBody.CurrentWeek)
	if err != nil {
		switch {
		case errors.Is(err, coaching.ErrNoTrainingPlanFound):
			c.JSON(http.StatusNotFound, gin.H{"error": "training plan not found"})
		case errors.Is(err, ai.ErrProviderDisabled):
			c.JSON(http.StatusServiceUnavailable, gin.H{"error": "ai provider is disabled"})
		default:
			c.JSON(http.StatusInternalServerError, gin.H{"error": "generate weekly coaching preview"})
		}
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"training_plan_id": result.TrainingPlanID,
		"current_week":     result.CurrentWeek,
		"preview_week":     result.PreviewWeek,
		"preview_theme":    result.PreviewTheme,
		"provider":         result.Provider,
		"model":            result.Model,
		"prompt_version":   result.PromptVersion,
		"feedback":         result.Feedback,
		"motivation":       result.Motivation,
	})
}

func (h *TrainingPlansHandler) GenerateDay(c *gin.Context) {
	user, planID, ok := h.userAndPlanID(c)
	if !ok {
		return
	}

	var requestBody struct {
		WeekNumber int `json:"week_number"`
		DayNumber  int `json:"day_number"`
	}
	if err := c.ShouldBindJSON(&requestBody); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid request body"})
		return
	}
	if requestBody.WeekNumber <= 0 || requestBody.DayNumber <= 0 || requestBody.DayNumber > 7 {
		c.JSON(http.StatusBadRequest, gin.H{"error": "week_number and day_number must be positive, and day_number must be at most 7"})
		return
	}

	result, err := h.service.GenerateWorkoutForDay(c.Request.Context(), user, planID, requestBody.WeekNumber, requestBody.DayNumber)
	if err != nil {
		h.respondTrainingPlanError(c, err, "generate day workout")
		return
	}

	c.JSON(http.StatusCreated, serializeTrainingPlanResult(result))
}

func (h *TrainingPlansHandler) MoveWorkout(c *gin.Context) {
	user, planID, ok := h.userAndPlanID(c)
	if !ok {
		return
	}

	var requestBody struct {
		WeekNumber    int `json:"week_number"`
		FromDayNumber int `json:"from_day_number"`
		ToDayNumber   int `json:"to_day_number"`
	}
	if err := c.ShouldBindJSON(&requestBody); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid request body"})
		return
	}
	if requestBody.WeekNumber <= 0 || requestBody.FromDayNumber <= 0 || requestBody.ToDayNumber <= 0 || requestBody.ToDayNumber > 7 {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid week or day numbers"})
		return
	}

	result, err := h.service.MoveWorkout(c.Request.Context(), user, planID, requestBody.WeekNumber, requestBody.FromDayNumber, requestBody.ToDayNumber)
	if err != nil {
		h.respondTrainingPlanError(c, err, "move workout")
		return
	}

	c.JSON(http.StatusOK, serializeTrainingPlanResult(result))
}

func (h *TrainingPlansHandler) SkipWorkout(c *gin.Context) {
	user, planID, ok := h.userAndPlanID(c)
	if !ok {
		return
	}

	var requestBody struct {
		WeekNumber int `json:"week_number"`
		DayNumber  int `json:"day_number"`
	}
	if err := c.ShouldBindJSON(&requestBody); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid request body"})
		return
	}
	if requestBody.WeekNumber <= 0 || requestBody.DayNumber <= 0 || requestBody.DayNumber > 7 {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid week or day numbers"})
		return
	}

	result, err := h.service.SkipWorkout(c.Request.Context(), user, planID, requestBody.WeekNumber, requestBody.DayNumber)
	if err != nil {
		h.respondTrainingPlanError(c, err, "skip workout")
		return
	}

	c.JSON(http.StatusOK, serializeTrainingPlanResult(result))
}

func (h *TrainingPlansHandler) userAndPlanID(c *gin.Context) (auth.User, int64, bool) {
	user, ok := middleware.UserFromGinContext(c)
	if !ok {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "authenticated user missing from request context"})
		return auth.User{}, 0, false
	}

	trainingPlanID, err := strconv.ParseInt(strings.TrimSpace(c.Param("id")), 10, 64)
	if err != nil || trainingPlanID <= 0 {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid training plan id"})
		return auth.User{}, 0, false
	}

	return user, trainingPlanID, true
}

func (h *TrainingPlansHandler) respondTrainingPlanError(c *gin.Context, err error, fallback string) {
	switch {
	case errors.Is(err, coaching.ErrDailyTrainingPlanLimitReached):
		c.JSON(http.StatusTooManyRequests, gin.H{"error": "daily training plan limit reached"})
	case errors.Is(err, coaching.ErrNoTrainingPlanFound):
		c.JSON(http.StatusNotFound, gin.H{"error": "training plan not found"})
	case errors.Is(err, ai.ErrProviderDisabled):
		c.JSON(http.StatusServiceUnavailable, gin.H{"error": "ai provider is disabled"})
	default:
		c.JSON(http.StatusInternalServerError, gin.H{"error": fallback})
	}
}

func validateTrainingPlanRequest(request createTrainingPlanRequest) (ai.TrainingPlanRequest, error) {
	objective := strings.TrimSpace(request.Objective)
	if objective == "" {
		return ai.TrainingPlanRequest{}, errors.New("objective is required")
	}
	if request.DurationWeeks <= 0 || request.DurationWeeks > 24 {
		return ai.TrainingPlanRequest{}, errors.New("duration_weeks must be between 1 and 24")
	}
	if request.DaysPerWeek <= 0 || request.DaysPerWeek > 7 {
		return ai.TrainingPlanRequest{}, errors.New("days_per_week must be between 1 and 7")
	}
	measurementSystem := strings.TrimSpace(request.MeasurementSystem)
	if measurementSystem == "" {
		measurementSystem = "Metric"
	}
	if measurementSystem != "Metric" && measurementSystem != "Imperial" {
		return ai.TrainingPlanRequest{}, errors.New("measurement_system must be Metric or Imperial")
	}

	return ai.TrainingPlanRequest{
		Objective:         objective,
		DurationWeeks:     request.DurationWeeks,
		DaysPerWeek:       request.DaysPerWeek,
		MeasurementSystem: measurementSystem,
		Constraints:       strings.TrimSpace(request.Constraints),
		Equipment:         strings.TrimSpace(request.Equipment),
		Notes:             strings.TrimSpace(request.Notes),
		Profile: ai.AthleteProfile{
			DisplayName:        strings.TrimSpace(request.Profile.DisplayName),
			TrainingExperience: strings.TrimSpace(request.Profile.TrainingExperience),
			PrimaryGoal:        strings.TrimSpace(request.Profile.PrimaryGoal),
			PreferredDays:      trimNonEmptyStrings(request.Profile.PreferredDays),
		},
	}, nil
}

func trimNonEmptyStrings(values []string) []string {
	trimmed := make([]string, 0, len(values))
	for _, value := range values {
		clean := strings.TrimSpace(value)
		if clean == "" {
			continue
		}
		trimmed = append(trimmed, clean)
	}

	return trimmed
}

func serializeTrainingPlanResult(result coaching.TrainingPlanResult) gin.H {
	weeks := make([]gin.H, 0, len(result.Weeks))
	for _, week := range result.Weeks {
		workouts := make([]gin.H, 0, len(week.Workouts))
		for _, workout := range week.Workouts {
			exercises := make([]gin.H, 0, len(workout.Exercises))
			for _, exercise := range workout.Exercises {
				sets := make([]gin.H, 0, len(exercise.Sets))
				for _, set := range exercise.Sets {
					sets = append(sets, gin.H{
						"reps":         set.Reps,
						"target_value": set.TargetValue,
						"target_unit":  set.TargetUnit,
						"load_value":   set.LoadValue,
						"load_unit":    set.LoadUnit,
					})
				}

				exercises = append(exercises, gin.H{
					"title": exercise.Title,
					"notes": exercise.Notes,
					"sets":  sets,
				})
			}

			workouts = append(workouts, gin.H{
				"day_number": workout.DayNumber,
				"title":      workout.Title,
				"focus":      workout.Focus,
				"exercises":  exercises,
			})
		}

		weeks = append(weeks, gin.H{
			"week_number": week.WeekNumber,
			"theme":       week.Theme,
			"workouts":    workouts,
		})
	}

	return gin.H{
		"id":                   result.PlanID,
		"objective":            result.Objective,
		"duration_weeks":       result.DurationWeeks,
		"days_per_week":        result.DaysPerWeek,
		"measurement_system":   result.MeasurementSystem,
		"constraints":          result.Constraints,
		"equipment":            result.Equipment,
		"notes":                result.Notes,
		"provider":             result.Provider,
		"model":                result.Model,
		"prompt_version":       result.PromptVersion,
		"summary":              result.Summary,
		"philosophy":           result.Philosophy,
		"progression_strategy": result.ProgressionStrategy,
		"risks":                result.Risks,
		"success_criteria":     result.SuccessCriteria,
		"weeks":                weeks,
		"generated":            result.Generated,
		"created_at":           result.CreatedAt,
		"updated_at":           result.UpdatedAt,
		"daily_limit":          result.DailyLimit,
		"generated_today":      result.GeneratedToday,
		"remaining_today":      result.RemainingToday,
	}
}
