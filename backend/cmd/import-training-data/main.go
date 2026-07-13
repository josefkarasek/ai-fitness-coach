package main

import (
	"context"
	"flag"
	"log/slog"
	"os"
	"time"

	"github.com/josefkarasek/ai-fitness-coach/backend/internal/config"
	"github.com/josefkarasek/ai-fitness-coach/backend/internal/storage/postgres"
	"github.com/josefkarasek/ai-fitness-coach/backend/internal/traininghistory"
	"github.com/josefkarasek/ai-fitness-coach/backend/migrations"
)

func main() {
	var (
		csvPath         = flag.String("csv", "test/training_data.csv", "path to exported training CSV")
		athleteName     = flag.String("athlete-name", "Josef Karasek", "athlete name to attach imported workouts to")
		sourceAthleteID = flag.String("source-athlete-id", "", "optional source athlete ID from the upstream export")
	)
	flag.Parse()

	cfg := config.Load()
	logger := slog.New(slog.NewJSONHandler(os.Stderr, &slog.HandlerOptions{
		AddSource: true,
		Level:     cfg.LogLevel,
	}))
	slog.SetDefault(logger)

	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

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

	file, err := os.Open(*csvPath)
	if err != nil {
		logger.Error("open csv", "path", *csvPath, "error", err)
		os.Exit(1)
	}
	defer file.Close()

	workouts, err := traininghistory.ParseTrainingDataCSV(file)
	if err != nil {
		logger.Error("parse training csv", "path", *csvPath, "error", err)
		os.Exit(1)
	}

	store := postgres.NewTrainingHistoryStore(db)
	if err := store.ImportWorkouts(ctx, *athleteName, "trainheroic_csv", *sourceAthleteID, workouts); err != nil {
		logger.Error("import workouts", "error", err)
		os.Exit(1)
	}

	logger.Info("training data imported", "path", *csvPath, "workouts", len(workouts), "athlete_name", *athleteName)
}
