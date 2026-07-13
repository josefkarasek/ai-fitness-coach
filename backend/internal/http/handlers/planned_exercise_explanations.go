package handlers

import (
	"context"
	"errors"
	"net/http"
	"strconv"
	"strings"

	"github.com/gin-gonic/gin"
	"github.com/josefkarasek/ai-fitness-coach/backend/internal/auth"
	"github.com/josefkarasek/ai-fitness-coach/backend/internal/coaching"
	"github.com/josefkarasek/ai-fitness-coach/backend/internal/http/middleware"
)

type PlannedExerciseExplanationService interface {
	ExplainPlannedExercise(ctx context.Context, user auth.User, trainingPlanID int64, weekNumber int, dayNumber int, exerciseIndex int) (coaching.PlannedExerciseExplanationResult, error)
}

type PlannedExerciseExplanationHandler struct {
	service PlannedExerciseExplanationService
}

type createPlannedExerciseExplanationRequest struct {
	WeekNumber    int `json:"week_number"`
	DayNumber     int `json:"day_number"`
	ExerciseIndex int `json:"exercise_index"`
}

func NewPlannedExerciseExplanationHandler(service PlannedExerciseExplanationService) *PlannedExerciseExplanationHandler {
	return &PlannedExerciseExplanationHandler{service: service}
}

func (h *PlannedExerciseExplanationHandler) Create(c *gin.Context) {
	user, ok := middleware.UserFromGinContext(c)
	if !ok {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "authenticated user missing from request context"})
		return
	}

	trainingPlanID, err := strconv.ParseInt(strings.TrimSpace(c.Param("id")), 10, 64)
	if err != nil || trainingPlanID <= 0 {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid training plan id"})
		return
	}

	var requestBody createPlannedExerciseExplanationRequest
	if err := c.ShouldBindJSON(&requestBody); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid request body"})
		return
	}
	if requestBody.WeekNumber <= 0 || requestBody.DayNumber <= 0 || requestBody.DayNumber > 7 || requestBody.ExerciseIndex < 0 {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid week_number, day_number, or exercise_index"})
		return
	}

	result, err := h.service.ExplainPlannedExercise(
		c.Request.Context(),
		user,
		trainingPlanID,
		requestBody.WeekNumber,
		requestBody.DayNumber,
		requestBody.ExerciseIndex,
	)
	if err != nil {
		switch {
		case errors.Is(err, coaching.ErrNoTrainingPlanFound):
			c.JSON(http.StatusNotFound, gin.H{"error": "training plan not found"})
		case errors.Is(err, coaching.ErrPlannedExerciseNotFound):
			c.JSON(http.StatusNotFound, gin.H{"error": "planned exercise not found"})
		default:
			c.JSON(http.StatusInternalServerError, gin.H{"error": "generate planned exercise explanation"})
		}
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"training_plan_id":   result.TrainingPlanID,
		"week_number":        result.WeekNumber,
		"day_number":         result.DayNumber,
		"exercise_index":     result.ExerciseIndex,
		"exercise_title":     result.ExerciseTitle,
		"reason":             result.Reason,
		"support":            result.Support,
		"execution":          result.Execution,
		"movement_pattern":   result.MovementPattern,
		"measurement_system": result.MeasurementSystem,
	})
}
