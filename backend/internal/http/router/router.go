package router

import (
	"github.com/gin-gonic/gin"
	"github.com/josefkarasek/ai-fitness-coach/backend/internal/http/handlers"
	"github.com/josefkarasek/ai-fitness-coach/backend/internal/http/middleware"
)

func New(
	landingHandler *handlers.LandingHandler,
	healthHandler *handlers.HealthHandler,
	authHandler *handlers.AuthHandler,
	promoCodeHandler *handlers.PromoCodeHandler,
	importHandler *handlers.ImportHandler,
	workoutsHandler *handlers.WorkoutsHandler,
	workoutLogsHandler *handlers.WorkoutLogsHandler,
	workoutExplanationHandler *handlers.WorkoutExplanationHandler,
	plannedExerciseExplanationHandler *handlers.PlannedExerciseExplanationHandler,
	trainingPlansHandler *handlers.TrainingPlansHandler,
	authentication *middleware.Authentication,
) *gin.Engine {
	r := gin.New()
	r.Use(gin.Logger(), gin.Recovery())
	if landingHandler != nil {
		r.GET("/", landingHandler.Home)
		r.GET("/privacy", landingHandler.Privacy)
		r.GET("/deleteme", landingHandler.DeleteMe)
		r.GET("/favicon.svg", landingHandler.Favicon)
	}

	v1 := r.Group("/api/v1")
	{
		v1.GET("/health/live", healthHandler.Liveness)
		v1.GET("/health/ready", healthHandler.Readiness)
	}

	if authentication != nil && authHandler != nil {
		protected := v1.Group("")
		protected.Use(authentication.RequireAuth())
		protected.GET("/me", authHandler.Me)
		if promoCodeHandler != nil {
			protected.POST("/promo-codes/redeem", promoCodeHandler.Redeem)
		}
		if workoutsHandler != nil {
			protected.GET("/workouts", workoutsHandler.List)
			if workoutExplanationHandler != nil {
				protected.POST("/workouts/:id/explanation", workoutExplanationHandler.Create)
			}
		}
		if workoutLogsHandler != nil {
			protected.GET("/workout-logs", workoutLogsHandler.List)
			protected.POST("/workout-logs", workoutLogsHandler.Create)
		}
		if importHandler != nil {
			protected.POST("/imports", importHandler.Create)
		}
		if trainingPlansHandler != nil {
			protected.POST("/training-plans", trainingPlansHandler.Create)
			protected.GET("/training-plans/latest", trainingPlansHandler.Latest)
			if plannedExerciseExplanationHandler != nil {
				protected.POST("/training-plans/:id/exercise-explanation", plannedExerciseExplanationHandler.Create)
			}
			protected.POST("/training-plans/:id/weekly-preview", trainingPlansHandler.GenerateWeeklyPreview)
			protected.POST("/training-plans/:id/generate-day", trainingPlansHandler.GenerateDay)
			protected.POST("/training-plans/:id/move-workout", trainingPlansHandler.MoveWorkout)
			protected.POST("/training-plans/:id/skip-workout", trainingPlansHandler.SkipWorkout)
		}
	}

	return r
}
