package handlers

import (
	"context"
	"errors"
	"net/http"
	"strconv"

	"github.com/gin-gonic/gin"
	"github.com/josefkarasek/ai-fitness-coach/backend/internal/ai"
	"github.com/josefkarasek/ai-fitness-coach/backend/internal/auth"
	"github.com/josefkarasek/ai-fitness-coach/backend/internal/coaching"
	"github.com/josefkarasek/ai-fitness-coach/backend/internal/http/middleware"
)

type WorkoutExplanationService interface {
	ExplainWorkout(ctx context.Context, user auth.User, workoutID int64, force bool) (coaching.WorkoutExplanationResult, error)
}

type WorkoutExplanationHandler struct {
	service WorkoutExplanationService
}

func NewWorkoutExplanationHandler(service WorkoutExplanationService) *WorkoutExplanationHandler {
	return &WorkoutExplanationHandler{service: service}
}

func (h *WorkoutExplanationHandler) Create(c *gin.Context) {
	user, ok := middleware.UserFromGinContext(c)
	if !ok {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "authenticated user missing from request context",
		})
		return
	}

	workoutID, err := strconv.ParseInt(c.Param("id"), 10, 64)
	if err != nil || workoutID <= 0 {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "invalid workout id",
		})
		return
	}

	force := c.Query("force") == "true"
	result, err := h.service.ExplainWorkout(c.Request.Context(), user, workoutID, force)
	if err != nil {
		switch {
		case errors.Is(err, coaching.ErrWorkoutNotFound):
			c.JSON(http.StatusNotFound, gin.H{"error": "workout not found"})
		case errors.Is(err, coaching.ErrDailyLimitReached):
			c.JSON(http.StatusTooManyRequests, gin.H{"error": "daily workout explanation limit reached"})
		case errors.Is(err, ai.ErrProviderDisabled):
			c.JSON(http.StatusServiceUnavailable, gin.H{"error": "ai provider is disabled"})
		default:
			c.JSON(http.StatusInternalServerError, gin.H{"error": "generate workout explanation"})
		}
		return
	}

	status := http.StatusOK
	if result.Generated {
		status = http.StatusCreated
	}

	c.JSON(status, gin.H{
		"workout_id":      result.WorkoutID,
		"generated":       result.Generated,
		"provider":        result.Provider,
		"model":           result.Model,
		"prompt_version":  result.PromptVersion,
		"explanation":     result.Explanation,
		"created_at":      result.CreatedAt,
		"updated_at":      result.UpdatedAt,
		"daily_limit":     result.DailyLimit,
		"generated_today": result.GeneratedToday,
		"remaining_today": result.RemainingToday,
	})
}
