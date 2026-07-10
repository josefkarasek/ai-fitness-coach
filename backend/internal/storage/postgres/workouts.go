package postgres

import (
	"context"
	"fmt"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/josefkarasek/ai-fitness-coach/backend/internal/ai"
	"github.com/josefkarasek/ai-fitness-coach/backend/internal/auth"
	"github.com/josefkarasek/ai-fitness-coach/backend/internal/coaching"
	"github.com/josefkarasek/ai-fitness-coach/backend/internal/http/handlers"
)

type WorkoutStore struct {
	db *pgxpool.Pool
}

func NewWorkoutStore(db *pgxpool.Pool) *WorkoutStore {
	return &WorkoutStore{db: db}
}

func (s *WorkoutStore) ListWorkoutsForUser(ctx context.Context, user auth.User, limit int) ([]handlers.WorkoutHistoryItem, error) {
	if limit <= 0 {
		limit = 50
	}

	workouts, err := s.listWorkoutRows(ctx, user, limit)
	if err != nil {
		return nil, err
	}
	if len(workouts) == 0 {
		return []handlers.WorkoutHistoryItem{}, nil
	}

	exercisesByWorkoutID, err := s.listExerciseRows(ctx, workouts)
	if err != nil {
		return nil, err
	}

	if err := s.attachSetRows(ctx, exercisesByWorkoutID); err != nil {
		return nil, err
	}

	for idx := range workouts {
		workouts[idx].Exercises = exercisesByWorkoutID[workouts[idx].ID]
	}

	return workouts, nil
}

func (s *WorkoutStore) GetWorkoutForUser(ctx context.Context, user auth.User, workoutID int64) (ai.WorkoutContext, error) {
	row := s.db.QueryRow(ctx, `
		select
			w.id,
			w.source,
			w.source_workout_title,
			w.scheduled_date,
			coalesce(w.workout_notes, ''),
			coalesce(w.block_instructions, ''),
			coalesce(w.block_notes, '')
		from workouts w
		join athletes a on a.id = w.athlete_id
		where a.owner_user_id = $1::uuid
		  and w.id = $2
	`, user.ID, workoutID)

	var workout ai.WorkoutContext
	if err := row.Scan(
		&workout.WorkoutID,
		&workout.Source,
		&workout.SourceWorkoutTitle,
		&workout.ScheduledDate,
		&workout.WorkoutNotes,
		&workout.BlockInstructions,
		&workout.BlockNotes,
	); err != nil {
		if isNoRows(err) {
			return ai.WorkoutContext{}, nil
		}
		return ai.WorkoutContext{}, fmt.Errorf("query workout: %w", err)
	}

	exercises, err := s.listWorkoutExerciseContexts(ctx, workoutID)
	if err != nil {
		return ai.WorkoutContext{}, err
	}

	workout.Exercises = exercises
	return workout, nil
}

func (s *WorkoutStore) GetWorkoutExplanationForUser(ctx context.Context, user auth.User, workoutID int64) (coaching.StoredWorkoutExplanation, bool, error) {
	row := s.db.QueryRow(ctx, `
		select
			we.workout_id,
			we.provider,
			we.model,
			we.prompt_version,
			we.explanation,
			we.created_at,
			we.updated_at
		from workout_explanations we
		join workouts w on w.id = we.workout_id
		join athletes a on a.id = w.athlete_id
		where a.owner_user_id = $1::uuid
		  and we.workout_id = $2
	`, user.ID, workoutID)

	var stored coaching.StoredWorkoutExplanation
	if err := row.Scan(
		&stored.WorkoutID,
		&stored.Provider,
		&stored.Model,
		&stored.PromptVersion,
		&stored.Explanation,
		&stored.CreatedAt,
		&stored.UpdatedAt,
	); err != nil {
		if isNoRows(err) {
			return coaching.StoredWorkoutExplanation{}, false, nil
		}
		return coaching.StoredWorkoutExplanation{}, false, fmt.Errorf("query workout explanation: %w", err)
	}

	return stored, true, nil
}

func (s *WorkoutStore) SaveWorkoutExplanationForUser(ctx context.Context, user auth.User, workoutID int64, generated ai.GeneratedWorkoutExplanation) (coaching.StoredWorkoutExplanation, error) {
	row := s.db.QueryRow(ctx, `
		insert into workout_explanations (
			workout_id,
			user_id,
			provider,
			model,
			prompt_version,
			explanation
		)
		select
			w.id,
			$2::uuid,
			$3,
			$4,
			$5,
			$6
		from workouts w
		join athletes a on a.id = w.athlete_id
		where a.owner_user_id = $1::uuid
		  and w.id = $7
		on conflict (workout_id)
		do update set
			user_id = excluded.user_id,
			provider = excluded.provider,
			model = excluded.model,
			prompt_version = excluded.prompt_version,
			explanation = excluded.explanation,
			updated_at = now()
		returning
			workout_id,
			provider,
			model,
			prompt_version,
			explanation,
			created_at,
			updated_at
	`, user.ID, user.ID, generated.Provider, generated.Model, generated.PromptVersion, generated.Text, workoutID)

	var stored coaching.StoredWorkoutExplanation
	if err := row.Scan(
		&stored.WorkoutID,
		&stored.Provider,
		&stored.Model,
		&stored.PromptVersion,
		&stored.Explanation,
		&stored.CreatedAt,
		&stored.UpdatedAt,
	); err != nil {
		if isNoRows(err) {
			return coaching.StoredWorkoutExplanation{}, fmt.Errorf("workout %d does not belong to user", workoutID)
		}
		return coaching.StoredWorkoutExplanation{}, fmt.Errorf("save workout explanation: %w", err)
	}

	return stored, nil
}

func (s *WorkoutStore) CountWorkoutExplanationsGeneratedSince(ctx context.Context, user auth.User, since time.Time) (int, error) {
	var count int
	err := s.db.QueryRow(ctx, `
		select count(*)
		from workout_explanations
		where user_id = $1::uuid
		  and created_at >= $2
	`, user.ID, since).Scan(&count)
	if err != nil {
		return 0, fmt.Errorf("count workout explanations: %w", err)
	}

	return count, nil
}

func (s *WorkoutStore) listWorkoutRows(ctx context.Context, user auth.User, limit int) ([]handlers.WorkoutHistoryItem, error) {
	rows, err := s.db.Query(ctx, `
		select
			w.id,
			w.source,
			w.source_workout_title,
			w.scheduled_date,
			w.rescheduled_date,
			coalesce(w.workout_notes, ''),
			w.block_value,
			coalesce(w.block_units, ''),
			coalesce(w.block_instructions, ''),
			coalesce(w.block_notes, '')
		from workouts w
		join athletes a on a.id = w.athlete_id
		where a.owner_user_id = $1::uuid
		order by w.scheduled_date desc, w.id desc
		limit $2
	`, user.ID, limit)
	if err != nil {
		return nil, fmt.Errorf("query workouts: %w", err)
	}
	defer rows.Close()

	workouts := make([]handlers.WorkoutHistoryItem, 0)
	for rows.Next() {
		var workout handlers.WorkoutHistoryItem
		if err := rows.Scan(
			&workout.ID,
			&workout.Source,
			&workout.SourceWorkoutTitle,
			&workout.ScheduledDate,
			&workout.RescheduledDate,
			&workout.WorkoutNotes,
			&workout.BlockValue,
			&workout.BlockUnits,
			&workout.BlockInstructions,
			&workout.BlockNotes,
		); err != nil {
			return nil, fmt.Errorf("scan workout: %w", err)
		}
		workouts = append(workouts, workout)
	}

	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("iterate workouts: %w", err)
	}

	return workouts, nil
}

func (s *WorkoutStore) listExerciseRows(ctx context.Context, workouts []handlers.WorkoutHistoryItem) (map[int64][]handlers.WorkoutExerciseHistoryItem, error) {
	workoutIDs := make([]int64, 0, len(workouts))
	for _, workout := range workouts {
		workoutIDs = append(workoutIDs, workout.ID)
	}

	rows, err := s.db.Query(ctx, `
		select
			we.id,
			we.workout_id,
			we.sequence_number,
			ec.title,
			coalesce(we.notes, ''),
			coalesce(we.raw_exercise_data, '')
		from workout_exercises we
		join exercise_catalog ec on ec.id = we.exercise_id
		where we.workout_id = any($1)
		order by we.workout_id, we.sequence_number
	`, workoutIDs)
	if err != nil {
		return nil, fmt.Errorf("query workout exercises: %w", err)
	}
	defer rows.Close()

	exercisesByWorkoutID := make(map[int64][]handlers.WorkoutExerciseHistoryItem, len(workouts))
	for rows.Next() {
		var (
			exercise  handlers.WorkoutExerciseHistoryItem
			workoutID int64
		)
		if err := rows.Scan(
			&exercise.ID,
			&workoutID,
			&exercise.SequenceNumber,
			&exercise.Title,
			&exercise.Notes,
			&exercise.RawExerciseData,
		); err != nil {
			return nil, fmt.Errorf("scan workout exercise: %w", err)
		}

		exercisesByWorkoutID[workoutID] = append(exercisesByWorkoutID[workoutID], exercise)
	}

	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("iterate workout exercises: %w", err)
	}

	return exercisesByWorkoutID, nil
}

func (s *WorkoutStore) attachSetRows(ctx context.Context, exercisesByWorkoutID map[int64][]handlers.WorkoutExerciseHistoryItem) error {
	exerciseIDs := make([]int64, 0)
	exerciseIndex := make(map[int64]*handlers.WorkoutExerciseHistoryItem)

	for workoutID := range exercisesByWorkoutID {
		for idx := range exercisesByWorkoutID[workoutID] {
			exercise := &exercisesByWorkoutID[workoutID][idx]
			exerciseIDs = append(exerciseIDs, exercise.ID)
			exerciseIndex[exercise.ID] = exercise
		}
	}

	if len(exerciseIDs) == 0 {
		return nil
	}

	rows, err := s.db.Query(ctx, `
		select
			workout_exercise_id,
			sequence_number,
			coalesce(measurement_unit, ''),
			reps,
			distance_meters,
			load_value,
			coalesce(load_unit, ''),
			coalesce(raw_primary_value, ''),
			coalesce(raw_load_value, '')
		from workout_sets
		where workout_exercise_id = any($1)
		order by workout_exercise_id, sequence_number
	`, exerciseIDs)
	if err != nil {
		return fmt.Errorf("query workout sets: %w", err)
	}
	defer rows.Close()

	for rows.Next() {
		var (
			exerciseID int64
			set        handlers.WorkoutSetHistoryItem
		)
		if err := rows.Scan(
			&exerciseID,
			&set.SequenceNumber,
			&set.MeasurementUnit,
			&set.Reps,
			&set.DistanceMeters,
			&set.LoadValue,
			&set.LoadUnit,
			&set.RawPrimaryValue,
			&set.RawLoadValue,
		); err != nil {
			return fmt.Errorf("scan workout set: %w", err)
		}

		exercise := exerciseIndex[exerciseID]
		exercise.Sets = append(exercise.Sets, set)
	}

	if err := rows.Err(); err != nil {
		return fmt.Errorf("iterate workout sets: %w", err)
	}

	return nil
}

func (s *WorkoutStore) listWorkoutExerciseContexts(ctx context.Context, workoutID int64) ([]ai.WorkoutExerciseContext, error) {
	rows, err := s.db.Query(ctx, `
		select
			we.id,
			we.sequence_number,
			ec.title,
			coalesce(we.notes, '')
		from workout_exercises we
		join exercise_catalog ec on ec.id = we.exercise_id
		where we.workout_id = $1
		order by we.sequence_number
	`, workoutID)
	if err != nil {
		return nil, fmt.Errorf("query workout exercises for explanation: %w", err)
	}
	defer rows.Close()

	exercises := make([]ai.WorkoutExerciseContext, 0)
	exerciseIDs := make([]int64, 0)
	exerciseIndex := make(map[int64]int)
	for rows.Next() {
		var (
			id       int64
			exercise ai.WorkoutExerciseContext
		)
		if err := rows.Scan(&id, &exercise.SequenceNumber, &exercise.Title, &exercise.Notes); err != nil {
			return nil, fmt.Errorf("scan workout exercise for explanation: %w", err)
		}
		exerciseIndex[id] = len(exercises)
		exerciseIDs = append(exerciseIDs, id)
		exercises = append(exercises, exercise)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("iterate workout exercises for explanation: %w", err)
	}
	if len(exerciseIDs) == 0 {
		return exercises, nil
	}

	setRows, err := s.db.Query(ctx, `
		select
			workout_exercise_id,
			sequence_number,
			coalesce(measurement_unit, ''),
			reps,
			distance_meters,
			load_value,
			coalesce(load_unit, ''),
			coalesce(raw_primary_value, ''),
			coalesce(raw_load_value, '')
		from workout_sets
		where workout_exercise_id = any($1)
		order by workout_exercise_id, sequence_number
	`, exerciseIDs)
	if err != nil {
		return nil, fmt.Errorf("query workout sets for explanation: %w", err)
	}
	defer setRows.Close()

	for setRows.Next() {
		var (
			exerciseID int64
			set        ai.WorkoutSetContext
		)
		if err := setRows.Scan(
			&exerciseID,
			&set.SequenceNumber,
			&set.MeasurementUnit,
			&set.Reps,
			&set.DistanceMeters,
			&set.LoadValue,
			&set.LoadUnit,
			&set.RawPrimaryValue,
			&set.RawLoadValue,
		); err != nil {
			return nil, fmt.Errorf("scan workout set for explanation: %w", err)
		}

		idx := exerciseIndex[exerciseID]
		exercises[idx].Sets = append(exercises[idx].Sets, set)
	}
	if err := setRows.Err(); err != nil {
		return nil, fmt.Errorf("iterate workout sets for explanation: %w", err)
	}

	return exercises, nil
}

func isNoRows(err error) bool {
	return err == pgx.ErrNoRows
}
