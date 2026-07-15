package coaching

import (
	"context"
	"fmt"
	"log/slog"
	"sync"
	"time"

	"github.com/josefkarasek/ai-fitness-coach/backend/internal/ai"
	"github.com/josefkarasek/ai-fitness-coach/backend/internal/auth"
)

const (
	TrainingPlanJobStatusQueued    = "queued"
	TrainingPlanJobStatusRunning   = "running"
	TrainingPlanJobStatusCompleted = "completed"
	TrainingPlanJobStatusFailed    = "failed"
)

type TrainingPlanJob struct {
	ID             string
	UserID         string
	Request        ai.TrainingPlanRequest
	Status         string
	TrainingPlanID *int64
	ErrorMessage   string
	CreatedAt      time.Time
	UpdatedAt      time.Time
	StartedAt      *time.Time
	CompletedAt    *time.Time
}

type TrainingPlanJobStore interface {
	CreateOrGetActiveTrainingPlanJob(ctx context.Context, user auth.User, request ai.TrainingPlanRequest) (TrainingPlanJob, bool, error)
	GetTrainingPlanJobForUser(ctx context.Context, user auth.User, jobID string) (TrainingPlanJob, bool, error)
	ListRunnableTrainingPlanJobs(ctx context.Context) ([]TrainingPlanJob, error)
	MarkTrainingPlanJobRunning(ctx context.Context, jobID string) error
	CompleteTrainingPlanJob(ctx context.Context, jobID string, trainingPlanID int64) (TrainingPlanJob, error)
	FailTrainingPlanJob(ctx context.Context, jobID string, errorMessage string) (TrainingPlanJob, error)
}

type TrainingPlanJobNotifier interface {
	NotifyTrainingPlanReady(ctx context.Context, userID string, job TrainingPlanJob) error
	NotifyTrainingPlanFailed(ctx context.Context, userID string, job TrainingPlanJob) error
}

type AsyncTrainingPlanService struct {
	jobs      TrainingPlanJobStore
	planner   *TrainingPlannerService
	notifier  TrainingPlanJobNotifier
	timeout   time.Duration
	mu        sync.Mutex
	startedBy map[string]struct{}
}

func NewAsyncTrainingPlanService(jobs TrainingPlanJobStore, planner *TrainingPlannerService, notifier TrainingPlanJobNotifier, timeout time.Duration) *AsyncTrainingPlanService {
	if timeout <= 0 {
		timeout = 5 * time.Minute
	}

	return &AsyncTrainingPlanService{
		jobs:      jobs,
		planner:   planner,
		notifier:  notifier,
		timeout:   timeout,
		startedBy: map[string]struct{}{},
	}
}

func (s *AsyncTrainingPlanService) Submit(ctx context.Context, user auth.User, request ai.TrainingPlanRequest) (TrainingPlanJob, bool, error) {
	job, created, err := s.jobs.CreateOrGetActiveTrainingPlanJob(ctx, user, request)
	if err != nil {
		return TrainingPlanJob{}, false, fmt.Errorf("enqueue training plan job: %w", err)
	}

	s.startJob(job)
	return job, created, nil
}

func (s *AsyncTrainingPlanService) Get(ctx context.Context, user auth.User, jobID string) (TrainingPlanJob, error) {
	job, found, err := s.jobs.GetTrainingPlanJobForUser(ctx, user, jobID)
	if err != nil {
		return TrainingPlanJob{}, fmt.Errorf("load training plan job: %w", err)
	}
	if !found {
		return TrainingPlanJob{}, ErrNoTrainingPlanFound
	}

	return job, nil
}

func (s *AsyncTrainingPlanService) ResumePendingJobs(ctx context.Context) error {
	jobs, err := s.jobs.ListRunnableTrainingPlanJobs(ctx)
	if err != nil {
		return fmt.Errorf("list runnable training plan jobs: %w", err)
	}

	for _, job := range jobs {
		s.startJob(job)
	}

	return nil
}

func (s *AsyncTrainingPlanService) startJob(job TrainingPlanJob) {
	s.mu.Lock()
	defer s.mu.Unlock()
	if _, exists := s.startedBy[job.ID]; exists {
		return
	}
	s.startedBy[job.ID] = struct{}{}

	go func() {
		defer func() {
			s.mu.Lock()
			delete(s.startedBy, job.ID)
			s.mu.Unlock()
		}()
		s.processJob(job)
	}()
}

func (s *AsyncTrainingPlanService) processJob(job TrainingPlanJob) {
	ctx, cancel := context.WithTimeout(context.Background(), s.timeout)
	defer cancel()

	if err := s.jobs.MarkTrainingPlanJobRunning(ctx, job.ID); err != nil {
		slog.Error("mark training plan job running", "job_id", job.ID, "user_id", job.UserID, "error", err)
		return
	}

	result, err := s.planner.GenerateTrainingPlan(ctx, auth.User{ID: job.UserID}, job.Request)
	if err != nil {
		failedJob, failErr := s.jobs.FailTrainingPlanJob(ctx, job.ID, err.Error())
		if failErr != nil {
			slog.Error("fail training plan job", "job_id", job.ID, "user_id", job.UserID, "error", failErr, "original_error", err)
			return
		}
		if s.notifier != nil {
			if notifyErr := s.notifier.NotifyTrainingPlanFailed(context.Background(), job.UserID, failedJob); notifyErr != nil {
				slog.Warn("notify training plan job failure", "job_id", job.ID, "user_id", job.UserID, "error", notifyErr)
			}
		}
		slog.Error("training plan job failed", "job_id", job.ID, "user_id", job.UserID, "error", err)
		return
	}

	completedJob, err := s.jobs.CompleteTrainingPlanJob(ctx, job.ID, result.PlanID)
	if err != nil {
		slog.Error("complete training plan job", "job_id", job.ID, "user_id", job.UserID, "training_plan_id", result.PlanID, "error", err)
		return
	}

	if s.notifier != nil {
		if notifyErr := s.notifier.NotifyTrainingPlanReady(context.Background(), job.UserID, completedJob); notifyErr != nil {
			slog.Warn("notify training plan ready", "job_id", job.ID, "user_id", job.UserID, "training_plan_id", result.PlanID, "error", notifyErr)
		}
	}

	slog.Info("training plan job completed", "job_id", job.ID, "user_id", job.UserID, "training_plan_id", result.PlanID)
}
