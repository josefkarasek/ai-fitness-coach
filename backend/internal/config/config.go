package config

import (
	"bufio"
	"fmt"
	"log/slog"
	"os"
	"path/filepath"
	"strconv"
	"strings"
)

const (
	defaultHTTPHost = "0.0.0.0"
	defaultHTTPPort = "8080"
)

type Config struct {
	HTTPHost                       string
	HTTPPort                       string
	DatabaseURL                    string
	LogLevel                       slog.Level
	AuthMode                       string
	FirebaseProjectID              string
	AIProvider                     string
	AIModel                        string
	AIBaseURL                      string
	AIAPIKey                       string
	AIDailyWorkoutExplanationLimit int
	AIDailyWorkoutReviewLimit      int
	AIDailyTrainingPlanLimit       int
}

func Load() Config {
	loadDotEnv()
	prepareFirebaseCredentials()

	return Config{
		HTTPHost:                       getEnv("HTTP_HOST", defaultHTTPHost),
		HTTPPort:                       getEnv("HTTP_PORT", defaultHTTPPort),
		DatabaseURL:                    getEnv("DATABASE_URL", "postgres://postgres:postgres@localhost:5432/ai_fitness_coach?sslmode=disable"),
		LogLevel:                       getLogLevel("LOG_LEVEL", slog.LevelInfo),
		AuthMode:                       getEnv("AUTH_MODE", "disabled"),
		FirebaseProjectID:              getEnv("FIREBASE_PROJECT_ID", ""),
		AIProvider:                     getEnv("AI_PROVIDER", "mock"),
		AIModel:                        getEnv("AI_MODEL", "mock-workout-explainer-v1"),
		AIBaseURL:                      getEnv("AI_BASE_URL", ""),
		AIAPIKey:                       getEnv("AI_API_KEY", ""),
		AIDailyWorkoutExplanationLimit: getIntEnv("AI_DAILY_WORKOUT_EXPLANATIONS_LIMIT", 3),
		AIDailyWorkoutReviewLimit:      getIntEnv("AI_DAILY_WORKOUT_REVIEWS_LIMIT", 12),
		AIDailyTrainingPlanLimit:       getIntEnv("AI_DAILY_TRAINING_PLANS_LIMIT", 3),
	}
}

func prepareFirebaseCredentials() {
	if strings.TrimSpace(os.Getenv("GOOGLE_APPLICATION_CREDENTIALS")) != "" {
		return
	}

	firebaseAdminJSON := strings.TrimSpace(os.Getenv("FIREBASE_ADMIN_JSON"))
	if firebaseAdminJSON == "" {
		return
	}

	file, err := os.CreateTemp("", "firebase-admin-*.json")
	if err != nil {
		slog.Warn("failed to create firebase credentials file", "error", err)
		return
	}
	defer file.Close()

	if _, err := file.WriteString(firebaseAdminJSON); err != nil {
		slog.Warn("failed to write firebase credentials file", "path", file.Name(), "error", err)
		return
	}

	if err := file.Chmod(0o600); err != nil {
		slog.Warn("failed to chmod firebase credentials file", "path", file.Name(), "error", err)
	}

	if err := os.Setenv("GOOGLE_APPLICATION_CREDENTIALS", file.Name()); err != nil {
		slog.Warn("failed to export firebase credentials path", "path", file.Name(), "error", err)
	}
}

func loadDotEnv() {
	for _, path := range []string{".env", "../.env"} {
		loadDotEnvFile(path)
	}
}

func loadDotEnvFile(path string) {
	file, err := os.Open(filepath.Clean(path))
	if err != nil {
		return
	}
	defer file.Close()

	scanner := bufio.NewScanner(file)
	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}

		key, value, ok := strings.Cut(line, "=")
		if !ok {
			continue
		}

		key = strings.TrimSpace(key)
		if key == "" || os.Getenv(key) != "" {
			continue
		}

		value = strings.TrimSpace(value)
		value = strings.Trim(value, `"'`)
		_ = os.Setenv(key, value)
	}
}

func (c Config) HTTPAddress() string {
	return c.HTTPHost + ":" + c.HTTPPort
}

func getEnv(key, fallback string) string {
	value := os.Getenv(key)
	if value == "" {
		return fallback
	}

	return value
}

func getLogLevel(key string, fallback slog.Level) slog.Level {
	value := strings.TrimSpace(strings.ToLower(os.Getenv(key)))
	if value == "" {
		return fallback
	}

	var level slog.Level
	if err := level.UnmarshalText([]byte(value)); err != nil {
		return fallback
	}

	return level
}

func getIntEnv(key string, fallback int) int {
	value := strings.TrimSpace(os.Getenv(key))
	if value == "" {
		return fallback
	}

	parsed, err := strconv.Atoi(value)
	if err != nil || parsed < 0 {
		slog.Warn("invalid integer env var, using fallback", "key", key, "value", value, "fallback", fallback, "error", fmt.Sprintf("%v", err))
		return fallback
	}

	return parsed
}
