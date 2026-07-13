package main

import (
	"context"
	"fmt"
	"log/slog"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/josefkarasek/ai-fitness-coach/backend/internal/ai"
	backendAuth "github.com/josefkarasek/ai-fitness-coach/backend/internal/auth/firebase"
	"github.com/josefkarasek/ai-fitness-coach/backend/internal/coaching"
	"github.com/josefkarasek/ai-fitness-coach/backend/internal/config"
	httpHandlers "github.com/josefkarasek/ai-fitness-coach/backend/internal/http/handlers"
	httpMiddleware "github.com/josefkarasek/ai-fitness-coach/backend/internal/http/middleware"
	httpRouter "github.com/josefkarasek/ai-fitness-coach/backend/internal/http/router"
	"github.com/josefkarasek/ai-fitness-coach/backend/internal/storage/postgres"
	"github.com/josefkarasek/ai-fitness-coach/backend/migrations"
)

func main() {
	cfg := config.Load()

	if ginMode := os.Getenv("GIN_MODE"); ginMode != "" {
		gin.SetMode(ginMode)
	}

	logger := slog.New(slog.NewJSONHandler(os.Stderr, &slog.HandlerOptions{
		AddSource: true,
		Level:     cfg.LogLevel,
	}))
	slog.SetDefault(logger)

	ctx, stop := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
	defer stop()

	db, err := postgres.Open(ctx, cfg.DatabaseURL)
	if err != nil {
		logger.Error("open database", "error", err)
		os.Exit(1)
	}
	defer db.Close()

	if err := migrations.Apply(ctx, db); err != nil {
		logger.Error("apply migrations", "error", err)
		os.Exit(1)
	}

	healthHandler := httpHandlers.NewHealthHandler(db)
	authHandler := httpHandlers.NewAuthHandler()
	userStore := postgres.NewUserStore(db)
	promoCodeHandler := httpHandlers.NewPromoCodeHandler(userStore)
	importHandler := httpHandlers.NewImportHandler(postgres.NewTrainingHistoryStore(db))
	workoutStore := postgres.NewWorkoutStore(db)
	workoutLogStore := postgres.NewWorkoutLogStore(db)
	workoutsHandler := httpHandlers.NewWorkoutsHandler(workoutStore)
	trainingPlanStore := postgres.NewTrainingPlanStore(db)

	authentication, err := buildAuthentication(ctx, cfg, userStore)
	if err != nil {
		logger.Error("build authentication", "error", err)
		os.Exit(1)
	}

	freeWorkoutExplainer := ai.NewMockWorkoutExplainer(cfg.AIModel)
	paidWorkoutExplainer, err := buildWorkoutExplainer(cfg)
	if err != nil {
		logger.Error("build workout explainer", "error", err)
		os.Exit(1)
	}

	workoutExplanationHandler := httpHandlers.NewWorkoutExplanationHandler(
		coaching.NewWorkoutExplainerServiceWithAccessControl(workoutStore, userStore, freeWorkoutExplainer, paidWorkoutExplainer, cfg.AIDailyWorkoutExplanationLimit),
	)

	freeWorkoutLogReviewer := ai.NewMockWorkoutLogReviewer(cfg.AIModel)
	paidWorkoutLogReviewer, err := buildWorkoutLogReviewer(cfg)
	if err != nil {
		logger.Error("build workout log reviewer", "error", err)
		os.Exit(1)
	}

	workoutLogsHandler := httpHandlers.NewWorkoutLogsHandler(
		workoutLogStore,
		coaching.NewWorkoutLogReviewerServiceWithAccessControl(workoutLogStore, userStore, freeWorkoutLogReviewer, paidWorkoutLogReviewer, cfg.AIDailyWorkoutReviewLimit),
	)

	freeTrainingPlanner := ai.NewMockTrainingPlanner(cfg.AIModel)
	paidTrainingPlanner, err := buildTrainingPlanner(cfg)
	if err != nil {
		logger.Error("build training planner", "error", err)
		os.Exit(1)
	}

	freeWeeklyCoachingPreviewer := ai.NewMockWeeklyCoachingPreviewer(cfg.AIModel)
	paidWeeklyCoachingPreviewer, err := buildWeeklyCoachingPreviewer(cfg)
	if err != nil {
		logger.Error("build weekly coaching previewer", "error", err)
		os.Exit(1)
	}

	trainingPlansHandler := httpHandlers.NewTrainingPlansHandler(
		coaching.NewTrainingPlannerServiceWithAccessControl(trainingPlanStore, userStore, freeTrainingPlanner, paidTrainingPlanner, cfg.AIDailyTrainingPlanLimit),
		coaching.NewWeeklyCoachingPreviewServiceWithAccessControl(trainingPlanStore, userStore, freeWeeklyCoachingPreviewer, paidWeeklyCoachingPreviewer),
	)

	router := httpRouter.New(healthHandler, authHandler, promoCodeHandler, importHandler, workoutsHandler, workoutLogsHandler, workoutExplanationHandler, trainingPlansHandler, authentication)

	server := &http.Server{
		Addr:              cfg.HTTPAddress(),
		Handler:           router,
		ReadHeaderTimeout: 5 * time.Second,
	}

	go func() {
		logger.Info("backend listening", "address", cfg.HTTPAddress(), "log_level", cfg.LogLevel.String())
		if err := server.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			logger.Error("listen and serve", "error", err)
			os.Exit(1)
		}
	}()

	<-ctx.Done()
	logger.Info("shutdown signal received")

	shutdownCtx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	if err := server.Shutdown(shutdownCtx); err != nil {
		logger.Error("shutdown server", "error", err)
		os.Exit(1)
	}

	logger.Info("server stopped")
}

func buildAuthentication(ctx context.Context, cfg config.Config, users *postgres.UserStore) (*httpMiddleware.Authentication, error) {
	switch cfg.AuthMode {
	case "", "disabled":
		return nil, nil
	case "firebase":
		verifier, err := backendAuth.NewVerifier(ctx, cfg.FirebaseProjectID)
		if err != nil {
			return nil, err
		}

		return httpMiddleware.NewAuthentication(verifier, users), nil
	default:
		return nil, fmt.Errorf("unsupported auth mode %q", cfg.AuthMode)
	}
}

func buildWorkoutExplainer(cfg config.Config) (ai.WorkoutExplainer, error) {
	switch cfg.AIProvider {
	case "", "mock":
		return ai.NewMockWorkoutExplainer(cfg.AIModel), nil
	case "openai":
		client, err := ai.NewOpenAIClient(cfg.AIBaseURL, cfg.AIAPIKey, cfg.AIModel)
		if err != nil {
			return nil, err
		}

		return ai.NewOpenAIWorkoutExplainer(client), nil
	case "disabled":
		return ai.NewDisabledWorkoutExplainer(), nil
	default:
		return nil, fmt.Errorf("unsupported ai provider %q", cfg.AIProvider)
	}
}

func buildTrainingPlanner(cfg config.Config) (ai.TrainingPlanner, error) {
	switch cfg.AIProvider {
	case "", "mock":
		return ai.NewMockTrainingPlanner(cfg.AIModel), nil
	case "openai":
		client, err := ai.NewOpenAIClient(cfg.AIBaseURL, cfg.AIAPIKey, cfg.AIModel)
		if err != nil {
			return nil, err
		}

		return ai.NewOpenAITrainingPlanner(client), nil
	case "disabled":
		return ai.NewDisabledTrainingPlanner(), nil
	default:
		return nil, fmt.Errorf("unsupported ai provider %q", cfg.AIProvider)
	}
}

func buildWorkoutLogReviewer(cfg config.Config) (ai.WorkoutLogReviewer, error) {
	switch cfg.AIProvider {
	case "", "mock":
		return ai.NewMockWorkoutLogReviewer(cfg.AIModel), nil
	case "openai":
		client, err := ai.NewOpenAIClient(cfg.AIBaseURL, cfg.AIAPIKey, cfg.AIModel)
		if err != nil {
			return nil, err
		}

		return ai.NewOpenAIWorkoutLogReviewer(client), nil
	case "disabled":
		return ai.NewDisabledWorkoutLogReviewer(), nil
	default:
		return nil, fmt.Errorf("unsupported ai provider %q", cfg.AIProvider)
	}
}

func buildWeeklyCoachingPreviewer(cfg config.Config) (ai.WeeklyCoachingPreviewer, error) {
	switch cfg.AIProvider {
	case "", "mock":
		return ai.NewMockWeeklyCoachingPreviewer(cfg.AIModel), nil
	case "openai":
		client, err := ai.NewOpenAIClient(cfg.AIBaseURL, cfg.AIAPIKey, cfg.AIModel)
		if err != nil {
			return nil, err
		}

		return ai.NewOpenAIWeeklyCoachingPreviewer(client), nil
	case "disabled":
		return ai.NewDisabledWeeklyCoachingPreviewer(), nil
	default:
		return nil, fmt.Errorf("unsupported ai provider %q", cfg.AIProvider)
	}
}
