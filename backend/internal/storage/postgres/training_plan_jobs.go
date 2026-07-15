package postgres

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"strings"

	"github.com/jackc/pgx/v5/pgconn"
	"github.com/jackc/pgx/v5"
	"github.com/josefkarasek/ai-fitness-coach/backend/internal/ai"
	"github.com/josefkarasek/ai-fitness-coach/backend/internal/auth"
	"github.com/josefkarasek/ai-fitness-coach/backend/internal/coaching"
)

func (s *TrainingPlanStore) CreateOrGetActiveTrainingPlanJob(ctx context.Context, user auth.User, request ai.TrainingPlanRequest) (coaching.TrainingPlanJob, bool, error) {
	payload, err := json.Marshal(request)
	if err != nil {
		return coaching.TrainingPlanJob{}, false, fmt.Errorf("marshal request payload: %w", err)
	}

	var job coaching.TrainingPlanJob
	err = s.db.QueryRow(ctx, `
		insert into training_plan_generation_jobs (user_id, request_json, status)
		values ($1::uuid, $2::jsonb, 'queued')
		returning id::text, user_id::text, request_json, status, training_plan_id,
			coalesce(error_message, ''), created_at, updated_at, started_at, completed_at
	`, user.ID, string(payload)).Scan(
		&job.ID,
		&job.UserID,
		&payload,
		&job.Status,
		&job.TrainingPlanID,
		&job.ErrorMessage,
		&job.CreatedAt,
		&job.UpdatedAt,
		&job.StartedAt,
		&job.CompletedAt,
	)
	if err == nil {
		if err := json.Unmarshal(payload, &job.Request); err != nil {
			return coaching.TrainingPlanJob{}, false, fmt.Errorf("unmarshal created job request: %w", err)
		}
		return job, true, nil
	}

	var pgErr *pgconn.PgError
	if !errors.As(err, &pgErr) || pgErr.Code != "23505" {
		return coaching.TrainingPlanJob{}, false, fmt.Errorf("insert training plan job: %w", err)
	}

	job, found, loadErr := s.lookupActiveTrainingPlanJobForUser(ctx, user.ID)
	if loadErr != nil {
		return coaching.TrainingPlanJob{}, false, fmt.Errorf("load conflicting active job: %w", loadErr)
	}
	if !found {
		return coaching.TrainingPlanJob{}, false, fmt.Errorf("active training plan job conflict but no job found")
	}

	return job, false, nil
}

func (s *TrainingPlanStore) GetTrainingPlanJobForUser(ctx context.Context, user auth.User, jobID string) (coaching.TrainingPlanJob, bool, error) {
	return s.scanTrainingPlanJob(ctx, `
		select id::text, user_id::text, request_json, status, training_plan_id,
			coalesce(error_message, ''), created_at, updated_at, started_at, completed_at
		from training_plan_generation_jobs
		where user_id = $1::uuid and id = $2::uuid
	`, user.ID, jobID)
}

func (s *TrainingPlanStore) ListRunnableTrainingPlanJobs(ctx context.Context) ([]coaching.TrainingPlanJob, error) {
	rows, err := s.db.Query(ctx, `
		select id::text, user_id::text, request_json, status, training_plan_id,
			coalesce(error_message, ''), created_at, updated_at, started_at, completed_at
		from training_plan_generation_jobs
		where status in ('queued', 'running')
		order by created_at asc
	`)
	if err != nil {
		return nil, fmt.Errorf("query runnable training plan jobs: %w", err)
	}
	defer rows.Close()

	var jobs []coaching.TrainingPlanJob
	for rows.Next() {
		job, err := scanTrainingPlanJobRow(rows)
		if err != nil {
			return nil, err
		}
		jobs = append(jobs, job)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("iterate runnable training plan jobs: %w", err)
	}

	return jobs, nil
}

func (s *TrainingPlanStore) MarkTrainingPlanJobRunning(ctx context.Context, jobID string) error {
	commandTag, err := s.db.Exec(ctx, `
		update training_plan_generation_jobs
		set status = 'running',
			started_at = coalesce(started_at, now()),
			updated_at = now()
		where id = $1::uuid
		  and status in ('queued', 'running')
	`, jobID)
	if err != nil {
		return fmt.Errorf("update training plan job running status: %w", err)
	}
	if commandTag.RowsAffected() == 0 {
		return fmt.Errorf("training plan job %s not found or not runnable", jobID)
	}

	return nil
}

func (s *TrainingPlanStore) CompleteTrainingPlanJob(ctx context.Context, jobID string, trainingPlanID int64) (coaching.TrainingPlanJob, error) {
	return s.updateTrainingPlanJobStatus(
		ctx,
		jobID,
		`update training_plan_generation_jobs
		 set status = 'completed',
		     training_plan_id = $2,
		     error_message = null,
		     completed_at = now(),
		     updated_at = now()
		 where id = $1::uuid
		 returning id::text, user_id::text, request_json, status, training_plan_id,
		   coalesce(error_message, ''), created_at, updated_at, started_at, completed_at`,
		trainingPlanID,
	)
}

func (s *TrainingPlanStore) FailTrainingPlanJob(ctx context.Context, jobID string, errorMessage string) (coaching.TrainingPlanJob, error) {
	if strings.TrimSpace(errorMessage) == "" {
		errorMessage = "training plan generation failed"
	}

	return s.updateTrainingPlanJobStatus(
		ctx,
		jobID,
		`update training_plan_generation_jobs
		 set status = 'failed',
		     error_message = $2,
		     completed_at = now(),
		     updated_at = now()
		 where id = $1::uuid
		 returning id::text, user_id::text, request_json, status, training_plan_id,
		   coalesce(error_message, ''), created_at, updated_at, started_at, completed_at`,
		errorMessage,
	)
}

func (s *TrainingPlanStore) lookupActiveTrainingPlanJobForUser(ctx context.Context, userID string) (coaching.TrainingPlanJob, bool, error) {
	return s.scanTrainingPlanJob(ctx, `
		select id::text, user_id::text, request_json, status, training_plan_id,
			coalesce(error_message, ''), created_at, updated_at, started_at, completed_at
		from training_plan_generation_jobs
		where user_id = $1::uuid
		  and status in ('queued', 'running')
		order by created_at desc, id desc
		limit 1
	`, userID)
}

func (s *TrainingPlanStore) scanTrainingPlanJob(ctx context.Context, query string, args ...any) (coaching.TrainingPlanJob, bool, error) {
	row := s.db.QueryRow(ctx, query, args...)
	var rawRequest []byte
	var job coaching.TrainingPlanJob
	err := row.Scan(
		&job.ID,
		&job.UserID,
		&rawRequest,
		&job.Status,
		&job.TrainingPlanID,
		&job.ErrorMessage,
		&job.CreatedAt,
		&job.UpdatedAt,
		&job.StartedAt,
		&job.CompletedAt,
	)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return coaching.TrainingPlanJob{}, false, nil
		}
		return coaching.TrainingPlanJob{}, false, fmt.Errorf("scan training plan job: %w", err)
	}

	if err := json.Unmarshal(rawRequest, &job.Request); err != nil {
		return coaching.TrainingPlanJob{}, false, fmt.Errorf("unmarshal training plan job request: %w", err)
	}

	return job, true, nil
}

func scanTrainingPlanJobRow(rows pgx.Rows) (coaching.TrainingPlanJob, error) {
	var rawRequest []byte
	var job coaching.TrainingPlanJob
	if err := rows.Scan(
		&job.ID,
		&job.UserID,
		&rawRequest,
		&job.Status,
		&job.TrainingPlanID,
		&job.ErrorMessage,
		&job.CreatedAt,
		&job.UpdatedAt,
		&job.StartedAt,
		&job.CompletedAt,
	); err != nil {
		return coaching.TrainingPlanJob{}, fmt.Errorf("scan training plan job row: %w", err)
	}
	if err := json.Unmarshal(rawRequest, &job.Request); err != nil {
		return coaching.TrainingPlanJob{}, fmt.Errorf("unmarshal training plan job row: %w", err)
	}

	return job, nil
}

func (s *TrainingPlanStore) updateTrainingPlanJobStatus(ctx context.Context, jobID string, query string, arg any) (coaching.TrainingPlanJob, error) {
	var rawRequest []byte
	var job coaching.TrainingPlanJob
	err := s.db.QueryRow(ctx, query, jobID, arg).Scan(
		&job.ID,
		&job.UserID,
		&rawRequest,
		&job.Status,
		&job.TrainingPlanID,
		&job.ErrorMessage,
		&job.CreatedAt,
		&job.UpdatedAt,
		&job.StartedAt,
		&job.CompletedAt,
	)
	if err != nil {
		return coaching.TrainingPlanJob{}, fmt.Errorf("update training plan job status: %w", err)
	}
	if err := json.Unmarshal(rawRequest, &job.Request); err != nil {
		return coaching.TrainingPlanJob{}, fmt.Errorf("unmarshal updated training plan job request: %w", err)
	}

	return job, nil
}
