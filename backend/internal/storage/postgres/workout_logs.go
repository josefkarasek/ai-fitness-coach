package postgres

import (
	"context"
	"encoding/json"
	"fmt"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/josefkarasek/ai-fitness-coach/backend/internal/ai"
	"github.com/josefkarasek/ai-fitness-coach/backend/internal/auth"
	"github.com/josefkarasek/ai-fitness-coach/backend/internal/coaching"
	"github.com/josefkarasek/ai-fitness-coach/backend/internal/http/handlers"
)

type WorkoutLogStore struct {
	db *pgxpool.Pool
}

func NewWorkoutLogStore(db *pgxpool.Pool) *WorkoutLogStore {
	return &WorkoutLogStore{db: db}
}

func (s *WorkoutLogStore) UpsertWorkoutLogForUser(ctx context.Context, user auth.User, request handlers.WorkoutLogUpsertRequest) (handlers.WorkoutLogRecord, error) {
	tx, err := s.db.BeginTx(ctx, pgx.TxOptions{})
	if err != nil {
		return handlers.WorkoutLogRecord{}, fmt.Errorf("begin tx: %w", err)
	}
	defer tx.Rollback(ctx)

	var record handlers.WorkoutLogRecord
	err = tx.QueryRow(ctx, `
		insert into workout_logs (
			user_id,
			training_plan_id,
			week_number,
			day_number,
			title,
			focus,
			session_notes,
			duration_minutes,
			performed_at
		)
		select
			$1::uuid,
			tp.id,
			$3,
			$4,
			$5,
			nullif($6, ''),
			nullif($7, ''),
			$8,
			$9
		from training_plans tp
		where tp.id = $2
		  and tp.user_id = $1::uuid
		on conflict (user_id, training_plan_id, week_number, day_number)
		do update set
			title = excluded.title,
			focus = excluded.focus,
			session_notes = excluded.session_notes,
			duration_minutes = excluded.duration_minutes,
			performed_at = excluded.performed_at,
			updated_at = now()
		returning
			id,
			training_plan_id,
			week_number,
			day_number,
			title,
			coalesce(focus, ''),
			coalesce(session_notes, ''),
			duration_minutes,
			performed_at,
			created_at,
			updated_at
	`, user.ID, request.TrainingPlanID, request.WeekNumber, request.DayNumber, request.Title, request.Focus, request.SessionNotes, request.DurationMinutes, request.PerformedAt).Scan(
		&record.ID,
		&record.TrainingPlanID,
		&record.WeekNumber,
		&record.DayNumber,
		&record.Title,
		&record.Focus,
		&record.SessionNotes,
		&record.DurationMinutes,
		&record.PerformedAt,
		&record.CreatedAt,
		&record.UpdatedAt,
	)
	if err != nil {
		if err == pgx.ErrNoRows {
			return handlers.WorkoutLogRecord{}, fmt.Errorf("training plan %d does not belong to user", request.TrainingPlanID)
		}
		return handlers.WorkoutLogRecord{}, fmt.Errorf("upsert workout log: %w", err)
	}

	if _, err := tx.Exec(ctx, `delete from workout_log_exercises where workout_log_id = $1`, record.ID); err != nil {
		return handlers.WorkoutLogRecord{}, fmt.Errorf("delete workout log exercises: %w", err)
	}

	record.Exercises = make([]handlers.WorkoutLogExerciseRecord, 0, len(request.Exercises))
	for _, exercise := range request.Exercises {
		var exerciseID int64
		if err := tx.QueryRow(ctx, `
			insert into workout_log_exercises (
				workout_log_id,
				sequence_number,
				title,
				notes
			)
			values ($1, $2, $3, nullif($4, ''))
			returning id
		`, record.ID, exercise.SequenceNumber, exercise.Title, exercise.Notes).Scan(&exerciseID); err != nil {
			return handlers.WorkoutLogRecord{}, fmt.Errorf("insert workout log exercise: %w", err)
		}

		storedExercise := handlers.WorkoutLogExerciseRecord{
			SequenceNumber: exercise.SequenceNumber,
			Title:          exercise.Title,
			Notes:          exercise.Notes,
			Sets:           make([]handlers.WorkoutLogSetRecord, 0, len(exercise.Sets)),
		}

		for _, set := range exercise.Sets {
			if _, err := tx.Exec(ctx, `
				insert into workout_log_sets (
					workout_log_exercise_id,
					sequence_number,
					reps,
					value,
					unit,
					load_value,
					load_unit,
					completed
				)
				values ($1, $2, $3, $4, nullif($5, ''), $6, nullif($7, ''), $8)
			`, exerciseID, set.SequenceNumber, set.Reps, set.Value, set.Unit, set.LoadValue, set.LoadUnit, set.Completed); err != nil {
				return handlers.WorkoutLogRecord{}, fmt.Errorf("insert workout log set: %w", err)
			}

			storedExercise.Sets = append(storedExercise.Sets, handlers.WorkoutLogSetRecord{
				SequenceNumber: set.SequenceNumber,
				Reps:           set.Reps,
				Value:          set.Value,
				Unit:           set.Unit,
				LoadValue:      set.LoadValue,
				LoadUnit:       set.LoadUnit,
				Completed:      set.Completed,
			})
		}

		record.Exercises = append(record.Exercises, storedExercise)
	}

	if err := tx.Commit(ctx); err != nil {
		return handlers.WorkoutLogRecord{}, fmt.Errorf("commit tx: %w", err)
	}

	return record, nil
}

func (s *WorkoutLogStore) ListWorkoutLogsForUser(ctx context.Context, user auth.User, trainingPlanID int64, limit int) ([]handlers.WorkoutLogRecord, error) {
	if limit <= 0 {
		limit = 20
	}

	var (
		rows pgx.Rows
		err  error
	)
	if trainingPlanID > 0 {
		rows, err = s.db.Query(ctx, `
			select
				id,
				training_plan_id,
				week_number,
				day_number,
				title,
				coalesce(focus, ''),
				coalesce(session_notes, ''),
				duration_minutes,
				performed_at,
				created_at,
				updated_at
			from workout_logs
			where user_id = $1::uuid
			  and training_plan_id = $2
			order by week_number asc, day_number asc, updated_at asc
			limit $3
		`, user.ID, trainingPlanID, limit)
	} else {
		rows, err = s.db.Query(ctx, `
			select
				id,
				training_plan_id,
				week_number,
				day_number,
				title,
				coalesce(focus, ''),
				coalesce(session_notes, ''),
				duration_minutes,
				performed_at,
				created_at,
				updated_at
			from workout_logs
			where user_id = $1::uuid
			order by performed_at desc, id desc
			limit $2
		`, user.ID, limit)
	}
	if err != nil {
		return nil, fmt.Errorf("query workout logs: %w", err)
	}
	defer rows.Close()

	logs := make([]handlers.WorkoutLogRecord, 0)
	for rows.Next() {
		var record handlers.WorkoutLogRecord
		if err := rows.Scan(
			&record.ID,
			&record.TrainingPlanID,
			&record.WeekNumber,
			&record.DayNumber,
			&record.Title,
			&record.Focus,
			&record.SessionNotes,
			&record.DurationMinutes,
			&record.PerformedAt,
			&record.CreatedAt,
			&record.UpdatedAt,
		); err != nil {
			return nil, fmt.Errorf("scan workout log: %w", err)
		}
		logs = append(logs, record)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("iterate workout logs: %w", err)
	}
	if len(logs) == 0 {
		return []handlers.WorkoutLogRecord{}, nil
	}

	if err := s.attachWorkoutLogExercises(ctx, logs); err != nil {
		return nil, err
	}
	if err := s.attachWorkoutLogReviews(ctx, logs); err != nil {
		return nil, err
	}

	return logs, nil
}

func (s *WorkoutLogStore) attachWorkoutLogExercises(ctx context.Context, logs []handlers.WorkoutLogRecord) error {
	logIDs := make([]int64, 0, len(logs))
	logIndex := make(map[int64]*handlers.WorkoutLogRecord, len(logs))
	for idx := range logs {
		logIDs = append(logIDs, logs[idx].ID)
		logIndex[logs[idx].ID] = &logs[idx]
	}

	rows, err := s.db.Query(ctx, `
		select
			id,
			workout_log_id,
			sequence_number,
			title,
			coalesce(notes, '')
		from workout_log_exercises
		where workout_log_id = any($1)
		order by workout_log_id, sequence_number
	`, logIDs)
	if err != nil {
		return fmt.Errorf("query workout log exercises: %w", err)
	}
	defer rows.Close()

	exerciseIndex := make(map[int64]*handlers.WorkoutLogExerciseRecord)
	for rows.Next() {
		var (
			exerciseID int64
			logID      int64
			exercise   handlers.WorkoutLogExerciseRecord
		)
		if err := rows.Scan(&exerciseID, &logID, &exercise.SequenceNumber, &exercise.Title, &exercise.Notes); err != nil {
			return fmt.Errorf("scan workout log exercise: %w", err)
		}

		record := logIndex[logID]
		record.Exercises = append(record.Exercises, exercise)
		exerciseIndex[exerciseID] = &record.Exercises[len(record.Exercises)-1]
	}
	if err := rows.Err(); err != nil {
		return fmt.Errorf("iterate workout log exercises: %w", err)
	}
	if len(exerciseIndex) == 0 {
		return nil
	}

	exerciseIDs := make([]int64, 0, len(exerciseIndex))
	for exerciseID := range exerciseIndex {
		exerciseIDs = append(exerciseIDs, exerciseID)
	}

	setRows, err := s.db.Query(ctx, `
		select
			workout_log_exercise_id,
			sequence_number,
			reps,
			value,
			coalesce(unit, ''),
			load_value,
			coalesce(load_unit, ''),
			completed
		from workout_log_sets
		where workout_log_exercise_id = any($1)
		order by workout_log_exercise_id, sequence_number
	`, exerciseIDs)
	if err != nil {
		return fmt.Errorf("query workout log sets: %w", err)
	}
	defer setRows.Close()

	for setRows.Next() {
		var (
			exerciseID int64
			set        handlers.WorkoutLogSetRecord
		)
		if err := setRows.Scan(&exerciseID, &set.SequenceNumber, &set.Reps, &set.Value, &set.Unit, &set.LoadValue, &set.LoadUnit, &set.Completed); err != nil {
			return fmt.Errorf("scan workout log set: %w", err)
		}
		exerciseIndex[exerciseID].Sets = append(exerciseIndex[exerciseID].Sets, set)
	}
	if err := setRows.Err(); err != nil {
		return fmt.Errorf("iterate workout log sets: %w", err)
	}

	return nil
}

func (s *WorkoutLogStore) attachWorkoutLogReviews(ctx context.Context, logs []handlers.WorkoutLogRecord) error {
	logIDs := make([]int64, 0, len(logs))
	logIndex := make(map[int64]*handlers.WorkoutLogRecord, len(logs))
	for idx := range logs {
		logIDs = append(logIDs, logs[idx].ID)
		logIndex[logs[idx].ID] = &logs[idx]
	}

	rows, err := s.db.Query(ctx, `
		select
			workout_log_id,
			provider,
			model,
			prompt_version,
			review,
			created_at,
			updated_at
		from workout_log_reviews
		where workout_log_id = any($1)
		order by workout_log_id
	`, logIDs)
	if err != nil {
		return fmt.Errorf("query workout log reviews: %w", err)
	}
	defer rows.Close()

	for rows.Next() {
		var review handlers.WorkoutLogReviewRecord
		if err := rows.Scan(
			&review.WorkoutLogID,
			&review.Provider,
			&review.Model,
			&review.PromptVersion,
			&review.Review,
			&review.CreatedAt,
			&review.UpdatedAt,
		); err != nil {
			return fmt.Errorf("scan workout log review: %w", err)
		}

		record := logIndex[review.WorkoutLogID]
		if record != nil {
			record.Review = &review
		}
	}
	if err := rows.Err(); err != nil {
		return fmt.Errorf("iterate workout log reviews: %w", err)
	}

	return nil
}

func (s *WorkoutLogStore) GetWorkoutLogForUser(ctx context.Context, user auth.User, workoutLogID int64) (coaching.StoredWorkoutLogForReview, bool, error) {
	rows, err := s.ListWorkoutLogsForUser(ctx, user, 0, 500)
	if err != nil {
		return coaching.StoredWorkoutLogForReview{}, false, err
	}

	for _, row := range rows {
		if row.ID != workoutLogID {
			continue
		}

		exercises := make([]coaching.StoredLoggedWorkoutExercise, 0, len(row.Exercises))
		for _, exercise := range row.Exercises {
			sets := make([]coaching.StoredLoggedWorkoutSet, 0, len(exercise.Sets))
			for _, set := range exercise.Sets {
				sets = append(sets, coaching.StoredLoggedWorkoutSet{
					Reps:      set.Reps,
					Value:     set.Value,
					Unit:      set.Unit,
					LoadValue: set.LoadValue,
					LoadUnit:  set.LoadUnit,
					Completed: set.Completed,
				})
			}

			exercises = append(exercises, coaching.StoredLoggedWorkoutExercise{
				Title: exercise.Title,
				Notes: exercise.Notes,
				Sets:  sets,
			})
		}

		return coaching.StoredWorkoutLogForReview{
			ID:              row.ID,
			TrainingPlanID:  row.TrainingPlanID,
			WeekNumber:      row.WeekNumber,
			DayNumber:       row.DayNumber,
			Title:           row.Title,
			Focus:           row.Focus,
			SessionNotes:    row.SessionNotes,
			DurationMinutes: row.DurationMinutes,
			Exercises:       exercises,
		}, true, nil
	}

	return coaching.StoredWorkoutLogForReview{}, false, nil
}

func (s *WorkoutLogStore) GetTrainingPlanWorkoutContextForUser(ctx context.Context, user auth.User, trainingPlanID int64, weekNumber int, dayNumber int) (coaching.StoredTrainingPlanWorkoutContext, bool, error) {
	var (
		contextRow    coaching.StoredTrainingPlanWorkoutContext
		exercisesJSON []byte
	)

	err := s.db.QueryRow(ctx, `
		select
			tp.objective,
			coalesce(tpw.theme, ''),
			tpwk.title,
			coalesce(tpwk.focus, ''),
			coalesce(tpwk.exercises_json, '[]'::jsonb)
		from training_plans tp
		join training_plan_workouts tpwk on tpwk.training_plan_id = tp.id
		left join training_plan_weeks tpw
			on tpw.training_plan_id = tp.id
			and tpw.week_number = tpwk.week_number
		where tp.id = $1
		  and tp.user_id = $2::uuid
		  and tpwk.week_number = $3
		  and tpwk.day_number = $4
	`, trainingPlanID, user.ID, weekNumber, dayNumber).Scan(
		&contextRow.Objective,
		&contextRow.WeekTheme,
		&contextRow.Title,
		&contextRow.Focus,
		&exercisesJSON,
	)
	if err != nil {
		if err == pgx.ErrNoRows {
			return coaching.StoredTrainingPlanWorkoutContext{}, false, nil
		}
		return coaching.StoredTrainingPlanWorkoutContext{}, false, fmt.Errorf("query training plan workout context: %w", err)
	}

	if len(exercisesJSON) > 0 {
		if err := json.Unmarshal(exercisesJSON, &contextRow.Exercises); err != nil {
			return coaching.StoredTrainingPlanWorkoutContext{}, false, fmt.Errorf("unmarshal planned workout exercises: %w", err)
		}
	}

	return contextRow, true, nil
}

func (s *WorkoutLogStore) GetWorkoutLogReviewForUser(ctx context.Context, user auth.User, workoutLogID int64) (coaching.StoredWorkoutLogReview, bool, error) {
	var review coaching.StoredWorkoutLogReview
	err := s.db.QueryRow(ctx, `
		select
			wlr.workout_log_id,
			wlr.provider,
			wlr.model,
			wlr.prompt_version,
			wlr.review,
			wlr.created_at,
			wlr.updated_at
		from workout_log_reviews wlr
		join workout_logs wl on wl.id = wlr.workout_log_id
		where wlr.workout_log_id = $1
		  and wl.user_id = $2::uuid
	`, workoutLogID, user.ID).Scan(
		&review.WorkoutLogID,
		&review.Provider,
		&review.Model,
		&review.PromptVersion,
		&review.Review,
		&review.CreatedAt,
		&review.UpdatedAt,
	)
	if err != nil {
		if err == pgx.ErrNoRows {
			return coaching.StoredWorkoutLogReview{}, false, nil
		}
		return coaching.StoredWorkoutLogReview{}, false, fmt.Errorf("query workout log review: %w", err)
	}

	return review, true, nil
}

func (s *WorkoutLogStore) SaveWorkoutLogReviewForUser(ctx context.Context, user auth.User, workoutLogID int64, generated ai.GeneratedWorkoutLogReview) (coaching.StoredWorkoutLogReview, error) {
	var review coaching.StoredWorkoutLogReview
	err := s.db.QueryRow(ctx, `
		insert into workout_log_reviews (
			workout_log_id,
			user_id,
			provider,
			model,
			prompt_version,
			review
		)
		values ($1, $2::uuid, $3, $4, $5, $6)
		on conflict (workout_log_id)
		do update set
			provider = excluded.provider,
			model = excluded.model,
			prompt_version = excluded.prompt_version,
			review = excluded.review,
			updated_at = now()
		returning
			workout_log_id,
			provider,
			model,
			prompt_version,
			review,
			created_at,
			updated_at
	`, workoutLogID, user.ID, generated.Provider, generated.Model, generated.PromptVersion, generated.Review).Scan(
		&review.WorkoutLogID,
		&review.Provider,
		&review.Model,
		&review.PromptVersion,
		&review.Review,
		&review.CreatedAt,
		&review.UpdatedAt,
	)
	if err != nil {
		return coaching.StoredWorkoutLogReview{}, fmt.Errorf("upsert workout log review: %w", err)
	}

	return review, nil
}

func (s *WorkoutLogStore) CountWorkoutLogReviewsGeneratedSince(ctx context.Context, user auth.User, since time.Time) (int, error) {
	var count int
	err := s.db.QueryRow(ctx, `
		select count(*)
		from workout_log_reviews
		where user_id = $1::uuid
		  and created_at >= $2
	`, user.ID, since).Scan(&count)
	if err != nil {
		return 0, fmt.Errorf("count workout log reviews: %w", err)
	}

	return count, nil
}
