package postgres

import (
	"context"
	"fmt"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/josefkarasek/ai-fitness-coach/backend/internal/auth"
	"github.com/josefkarasek/ai-fitness-coach/backend/internal/traininghistory"
)

type TrainingHistoryStore struct {
	db *pgxpool.Pool
}

func NewTrainingHistoryStore(db *pgxpool.Pool) *TrainingHistoryStore {
	return &TrainingHistoryStore{db: db}
}

func (s *TrainingHistoryStore) UpsertAthlete(ctx context.Context, name string, source string, sourceAthleteID string) error {
	_, err := s.db.Exec(ctx, athleteUpsertSQL(sourceAthleteID), name, source, sourceAthleteID)
	if err != nil {
		return fmt.Errorf("upsert athlete: %w", err)
	}

	return nil
}

func (s *TrainingHistoryStore) HasImportedArchiveForUser(ctx context.Context, user auth.User, source string, fileName string) (bool, error) {
	var exists bool
	err := s.db.QueryRow(ctx, `
		select exists(
			select 1
			from imported_archives
			where user_id = $1::uuid
			  and import_type = $2
			  and file_name = $3
		)
	`, user.ID, source, fileName).Scan(&exists)
	if err != nil {
		return false, fmt.Errorf("check imported archive: %w", err)
	}

	return exists, nil
}

func (s *TrainingHistoryStore) ImportWorkouts(ctx context.Context, athleteName string, source string, sourceAthleteID string, workouts []traininghistory.WorkoutImport) error {
	tx, err := s.db.BeginTx(ctx, pgx.TxOptions{})
	if err != nil {
		return fmt.Errorf("begin tx: %w", err)
	}
	defer tx.Rollback(ctx)

	athleteID, err := upsertAthleteTx(ctx, tx, athleteName, source, sourceAthleteID)
	if err != nil {
		return err
	}

	for _, workout := range workouts {
		workoutID, err := upsertWorkoutTx(ctx, tx, athleteID, workout)
		if err != nil {
			return err
		}

		if _, err := tx.Exec(ctx, `delete from workout_exercises where workout_id = $1`, workoutID); err != nil {
			return fmt.Errorf("clear workout exercises: %w", err)
		}

		for idx, exercise := range workout.Exercises {
			exerciseID, err := upsertExerciseCatalogTx(ctx, tx, exercise.Title)
			if err != nil {
				return err
			}

			workoutExerciseID, err := insertWorkoutExerciseTx(ctx, tx, workoutID, exerciseID, idx+1, exercise)
			if err != nil {
				return err
			}

			for _, set := range exercise.Sets {
				if err := insertWorkoutSetTx(ctx, tx, workoutExerciseID, set); err != nil {
					return err
				}
			}
		}
	}

	if err := tx.Commit(ctx); err != nil {
		return fmt.Errorf("commit tx: %w", err)
	}

	return nil
}

func (s *TrainingHistoryStore) ImportWorkoutsForUser(ctx context.Context, user auth.User, source string, sourceAthleteID string, workouts []traininghistory.WorkoutImport) error {
	tx, err := s.db.BeginTx(ctx, pgx.TxOptions{})
	if err != nil {
		return fmt.Errorf("begin tx: %w", err)
	}
	defer tx.Rollback(ctx)

	athleteID, err := ensureAthleteForUserTx(ctx, tx, user)
	if err != nil {
		return err
	}

	for _, workout := range workouts {
		workoutID, err := upsertWorkoutTx(ctx, tx, athleteID, workout)
		if err != nil {
			return err
		}

		if _, err := tx.Exec(ctx, `delete from workout_exercises where workout_id = $1`, workoutID); err != nil {
			return fmt.Errorf("clear workout exercises: %w", err)
		}

		for idx, exercise := range workout.Exercises {
			exerciseID, err := upsertExerciseCatalogTx(ctx, tx, exercise.Title)
			if err != nil {
				return err
			}

			workoutExerciseID, err := insertWorkoutExerciseTx(ctx, tx, workoutID, exerciseID, idx+1, exercise)
			if err != nil {
				return err
			}

			for _, set := range exercise.Sets {
				if err := insertWorkoutSetTx(ctx, tx, workoutExerciseID, set); err != nil {
					return err
				}
			}
		}
	}

	if err := tx.Commit(ctx); err != nil {
		return fmt.Errorf("commit tx: %w", err)
	}

	return nil
}

func (s *TrainingHistoryStore) RecordImportedArchiveForUser(ctx context.Context, user auth.User, source string, fileName string) error {
	_, err := s.db.Exec(ctx, `
		insert into imported_archives (user_id, import_type, file_name)
		values ($1::uuid, $2, $3)
	`, user.ID, source, fileName)
	if err != nil {
		return fmt.Errorf("record imported archive: %w", err)
	}

	return nil
}

func upsertAthleteTx(ctx context.Context, tx pgx.Tx, name string, source string, sourceAthleteID string) (string, error) {
	var athleteID string
	err := tx.QueryRow(ctx, athleteUpsertSQL(sourceAthleteID)+" returning id::text", name, source, sourceAthleteID).Scan(&athleteID)
	if err != nil {
		return "", fmt.Errorf("upsert athlete: %w", err)
	}

	return athleteID, nil
}

func athleteUpsertSQL(sourceAthleteID string) string {
	if sourceAthleteID == "" {
		return `
			insert into athletes (name, source, source_athlete_id)
			values ($1, nullif($2, ''), nullif($3, ''))
			on conflict (name)
			do update set
				source = coalesce(athletes.source, excluded.source),
				source_athlete_id = coalesce(athletes.source_athlete_id, excluded.source_athlete_id),
				updated_at = now()
		`
	}

	return `
		insert into athletes (name, source, source_athlete_id)
		values ($1, nullif($2, ''), nullif($3, ''))
		on conflict (source, source_athlete_id)
		do update set
			name = excluded.name,
			updated_at = now()
	`
}

func upsertWorkoutTx(ctx context.Context, tx pgx.Tx, athleteID string, workout traininghistory.WorkoutImport) (int64, error) {
	var workoutID int64
	err := tx.QueryRow(ctx, `
		insert into workouts (
			athlete_id,
			source,
			source_workout_title,
			scheduled_date,
			rescheduled_date,
			workout_notes,
			block_value,
			block_units,
			block_instructions,
			block_notes
		)
		values ($1::uuid, $2, $3, $4, $5, nullif($6, ''), $7, nullif($8, ''), nullif($9, ''), nullif($10, ''))
		on conflict (athlete_id, source, source_workout_title, scheduled_date)
		do update set
			rescheduled_date = excluded.rescheduled_date,
			workout_notes = excluded.workout_notes,
			block_value = excluded.block_value,
			block_units = excluded.block_units,
			block_instructions = excluded.block_instructions,
			block_notes = excluded.block_notes,
			updated_at = now()
		returning id
	`,
		athleteID,
		workout.Source,
		workout.SourceWorkoutTitle,
		workout.ScheduledDate,
		workout.RescheduledDate,
		workout.WorkoutNotes,
		workout.BlockValue,
		workout.BlockUnits,
		workout.BlockInstructions,
		workout.BlockNotes,
	).Scan(&workoutID)
	if err != nil {
		return 0, fmt.Errorf("upsert workout %q: %w", workout.SourceWorkoutTitle, err)
	}

	return workoutID, nil
}

func upsertExerciseCatalogTx(ctx context.Context, tx pgx.Tx, title string) (int64, error) {
	var exerciseID int64
	err := tx.QueryRow(ctx, `
		insert into exercise_catalog (title)
		values ($1)
		on conflict (title)
		do update set title = excluded.title
		returning id
	`, title).Scan(&exerciseID)
	if err != nil {
		return 0, fmt.Errorf("upsert exercise %q: %w", title, err)
	}

	return exerciseID, nil
}

func insertWorkoutExerciseTx(ctx context.Context, tx pgx.Tx, workoutID int64, exerciseID int64, sequenceNumber int, exercise traininghistory.ExerciseImport) (int64, error) {
	var workoutExerciseID int64
	err := tx.QueryRow(ctx, `
		insert into workout_exercises (
			workout_id,
			exercise_id,
			sequence_number,
			notes,
			raw_exercise_data
		)
		values ($1, $2, $3, nullif($4, ''), nullif($5, ''))
		returning id
	`, workoutID, exerciseID, sequenceNumber, exercise.Notes, exercise.RawExerciseData).Scan(&workoutExerciseID)
	if err != nil {
		return 0, fmt.Errorf("insert workout exercise %q: %w", exercise.Title, err)
	}

	return workoutExerciseID, nil
}

func insertWorkoutSetTx(ctx context.Context, tx pgx.Tx, workoutExerciseID int64, set traininghistory.SetImport) error {
	_, err := tx.Exec(ctx, `
		insert into workout_sets (
			workout_exercise_id,
			sequence_number,
			measurement_unit,
			reps,
			distance_meters,
			load_value,
			load_unit,
			raw_primary_value,
			raw_load_value
		)
		values ($1, $2, nullif($3, ''), $4, $5, $6, nullif($7, ''), nullif($8, ''), nullif($9, ''))
	`, workoutExerciseID, set.SequenceNumber, set.MeasurementUnit, set.Reps, set.DistanceMeters, set.LoadValue, set.LoadUnit, set.RawPrimaryValue, set.RawLoadValue)
	if err != nil {
		return fmt.Errorf("insert workout set #%d: %w", set.SequenceNumber, err)
	}

	return nil
}

func ensureAthleteForUserTx(ctx context.Context, tx pgx.Tx, user auth.User) (string, error) {
	athleteName := user.DisplayName
	if athleteName == "" {
		athleteName = user.Email
	}
	if athleteName == "" {
		athleteName = user.FirebaseUID
	}

	var athleteID string
	err := tx.QueryRow(ctx, `
		insert into athletes (owner_user_id, name)
		values ($1::uuid, $2)
		on conflict (owner_user_id)
		where owner_user_id is not null
		do update set
			name = excluded.name,
			updated_at = now()
		returning id::text
	`, user.ID, athleteName).Scan(&athleteID)
	if err != nil {
		return "", fmt.Errorf("ensure athlete for user: %w", err)
	}

	return athleteID, nil
}
