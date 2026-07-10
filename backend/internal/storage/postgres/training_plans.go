package postgres

import (
	"context"
	"encoding/json"
	"fmt"
	"sort"
	"strings"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/josefkarasek/ai-fitness-coach/backend/internal/ai"
	"github.com/josefkarasek/ai-fitness-coach/backend/internal/auth"
	"github.com/josefkarasek/ai-fitness-coach/backend/internal/coaching"
)

type TrainingPlanStore struct {
	db *pgxpool.Pool
}

func NewTrainingPlanStore(db *pgxpool.Pool) *TrainingPlanStore {
	return &TrainingPlanStore{db: db}
}

func (s *TrainingPlanStore) SummarizeTrainingHistoryForUser(ctx context.Context, user auth.User) (ai.TrainingHistorySummary, error) {
	var summary ai.TrainingHistorySummary
	err := s.db.QueryRow(ctx, `
		select count(*)
		from workouts w
		join athletes a on a.id = w.athlete_id
		where a.owner_user_id = $1::uuid
	`, user.ID).Scan(&summary.WorkoutCount)
	if err != nil {
		return ai.TrainingHistorySummary{}, fmt.Errorf("count workouts: %w", err)
	}

	recentRows, err := s.db.Query(ctx, `
		select w.source_workout_title
		from workouts w
		join athletes a on a.id = w.athlete_id
		where a.owner_user_id = $1::uuid
		order by w.scheduled_date desc, w.id desc
		limit 5
	`, user.ID)
	if err != nil {
		return ai.TrainingHistorySummary{}, fmt.Errorf("query recent workouts: %w", err)
	}
	defer recentRows.Close()

	for recentRows.Next() {
		var title string
		if err := recentRows.Scan(&title); err != nil {
			return ai.TrainingHistorySummary{}, fmt.Errorf("scan recent workout: %w", err)
		}
		summary.RecentWorkoutTitles = append(summary.RecentWorkoutTitles, title)
	}
	if err := recentRows.Err(); err != nil {
		return ai.TrainingHistorySummary{}, fmt.Errorf("iterate recent workouts: %w", err)
	}

	exerciseRows, err := s.db.Query(ctx, `
		select ec.title, count(*) as usage_count
		from workout_exercises we
		join workouts w on w.id = we.workout_id
		join athletes a on a.id = w.athlete_id
		join exercise_catalog ec on ec.id = we.exercise_id
		where a.owner_user_id = $1::uuid
		group by ec.title
		order by usage_count desc, ec.title asc
		limit 5
	`, user.ID)
	if err != nil {
		return ai.TrainingHistorySummary{}, fmt.Errorf("query top exercises: %w", err)
	}
	defer exerciseRows.Close()

	for exerciseRows.Next() {
		var title string
		var usageCount int
		if err := exerciseRows.Scan(&title, &usageCount); err != nil {
			return ai.TrainingHistorySummary{}, fmt.Errorf("scan top exercise: %w", err)
		}
		summary.TopExercises = append(summary.TopExercises, title)
	}
	if err := exerciseRows.Err(); err != nil {
		return ai.TrainingHistorySummary{}, fmt.Errorf("iterate top exercises: %w", err)
	}

	return summary, nil
}

func (s *TrainingPlanStore) SaveTrainingPlanForUser(ctx context.Context, user auth.User, request ai.TrainingPlanRequest, generated ai.GeneratedTrainingPlan) (coaching.StoredTrainingPlan, error) {
	tx, err := s.db.BeginTx(ctx, pgx.TxOptions{})
	if err != nil {
		return coaching.StoredTrainingPlan{}, fmt.Errorf("begin tx: %w", err)
	}
	defer tx.Rollback(ctx)

	if _, err := tx.Exec(ctx, `
		update users
		set
			display_name = coalesce(nullif($2, ''), display_name),
			training_experience = nullif($3, ''),
			primary_goal = nullif($4, ''),
			preferred_days = $5,
			updated_at = now()
		where id = $1::uuid
	`,
		user.ID,
		request.Profile.DisplayName,
		request.Profile.TrainingExperience,
		request.Profile.PrimaryGoal,
		request.Profile.PreferredDays,
	); err != nil {
		return coaching.StoredTrainingPlan{}, fmt.Errorf("update user coaching profile: %w", err)
	}

	var stored coaching.StoredTrainingPlan
	err = tx.QueryRow(ctx, `
		insert into training_plans (
			user_id,
			objective,
			duration_weeks,
			days_per_week,
			measurement_system,
			constraints,
			equipment,
			notes,
			provider,
			model,
			prompt_version,
			summary,
			philosophy,
			progression_strategy,
			risks,
			success_criteria
		)
		values (
			$1::uuid, $2, $3, $4, $5, nullif($6, ''), nullif($7, ''), nullif($8, ''),
			$9, $10, $11, $12, $13, $14, $15, $16
		)
		returning id, objective, duration_weeks, days_per_week, measurement_system,
			coalesce(constraints, ''), coalesce(equipment, ''), coalesce(notes, ''),
			provider, model, prompt_version, summary, philosophy, progression_strategy,
			risks, success_criteria, created_at, updated_at
	`,
		user.ID,
		request.Objective,
		request.DurationWeeks,
		request.DaysPerWeek,
		request.MeasurementSystem,
		request.Constraints,
		request.Equipment,
		request.Notes,
		generated.Provider,
		generated.Model,
		generated.PromptVersion,
		generated.Summary,
		generated.Philosophy,
		generated.ProgressionStrategy,
		generated.Risks,
		generated.SuccessCriteria,
	).Scan(
		&stored.ID,
		&stored.Objective,
		&stored.DurationWeeks,
		&stored.DaysPerWeek,
		&stored.MeasurementSystem,
		&stored.Constraints,
		&stored.Equipment,
		&stored.Notes,
		&stored.Provider,
		&stored.Model,
		&stored.PromptVersion,
		&stored.Summary,
		&stored.Philosophy,
		&stored.ProgressionStrategy,
		&stored.Risks,
		&stored.SuccessCriteria,
		&stored.CreatedAt,
		&stored.UpdatedAt,
	)
	if err != nil {
		return coaching.StoredTrainingPlan{}, fmt.Errorf("insert training plan: %w", err)
	}

	for _, week := range generated.Weeks {
		if _, err := tx.Exec(ctx, `
			insert into training_plan_weeks (training_plan_id, week_number, theme)
			values ($1, $2, $3)
		`, stored.ID, week.WeekNumber, week.Theme); err != nil {
			return coaching.StoredTrainingPlan{}, fmt.Errorf("insert training plan week: %w", err)
		}

		storedWeek := coaching.StoredTrainingPlanWeek{
			WeekNumber: week.WeekNumber,
			Theme:      week.Theme,
			Workouts:   make([]coaching.StoredPlannedWorkout, 0, len(week.Workouts)),
		}

		for _, workout := range week.Workouts {
			exerciseTitles := make([]string, 0, len(workout.Exercises))
			for _, exercise := range workout.Exercises {
				exerciseTitles = append(exerciseTitles, exercise.Title)
			}
			exercisesText := strings.Join(exerciseTitles, "\n")
			exercisesJSON, err := json.Marshal(workout.Exercises)
			if err != nil {
				return coaching.StoredTrainingPlan{}, fmt.Errorf("marshal training plan exercises: %w", err)
			}
			if _, err := tx.Exec(ctx, `
				insert into training_plan_workouts (
					training_plan_id,
					week_number,
					day_number,
					title,
					focus,
					exercises_text,
					exercises_json
				)
				values ($1, $2, $3, $4, $5, nullif($6, ''), $7::jsonb)
			`, stored.ID, week.WeekNumber, workout.DayNumber, workout.Title, workout.Focus, exercisesText, string(exercisesJSON)); err != nil {
				return coaching.StoredTrainingPlan{}, fmt.Errorf("insert training plan workout: %w", err)
			}

			storedWeek.Workouts = append(storedWeek.Workouts, coaching.StoredPlannedWorkout{
				DayNumber: workout.DayNumber,
				Title:     workout.Title,
				Focus:     workout.Focus,
				Exercises: buildStoredPlannedExercises(workout.Exercises),
			})
		}

		stored.Weeks = append(stored.Weeks, storedWeek)
	}

	if err := tx.Commit(ctx); err != nil {
		return coaching.StoredTrainingPlan{}, fmt.Errorf("commit tx: %w", err)
	}

	return stored, nil
}

func buildStoredPlannedExercises(exercises []ai.GeneratedPlannedExercise) []coaching.StoredPlannedExercise {
	stored := make([]coaching.StoredPlannedExercise, 0, len(exercises))
	for _, exercise := range exercises {
		sets := make([]coaching.StoredPlannedSet, 0, len(exercise.Sets))
		for _, set := range exercise.Sets {
			sets = append(sets, coaching.StoredPlannedSet{
				Reps:        set.Reps,
				TargetValue: set.TargetValue,
				TargetUnit:  set.TargetUnit,
				LoadValue:   set.LoadValue,
				LoadUnit:    set.LoadUnit,
			})
		}

		stored = append(stored, coaching.StoredPlannedExercise{
			Title: exercise.Title,
			Notes: exercise.Notes,
			Sets:  sets,
		})
	}

	return stored
}

func (s *TrainingPlanStore) GetLatestTrainingPlanForUser(ctx context.Context, user auth.User) (coaching.StoredTrainingPlan, bool, error) {
	return s.getTrainingPlan(ctx, user, `
		select
			id,
			objective,
			duration_weeks,
			days_per_week,
			measurement_system,
			coalesce(constraints, ''),
			coalesce(equipment, ''),
			coalesce(notes, ''),
			provider,
			model,
			prompt_version,
			summary,
			philosophy,
			progression_strategy,
			risks,
			success_criteria,
			created_at,
			updated_at
		from training_plans
		where user_id = $1::uuid
		order by created_at desc, id desc
		limit 1
	`, user.ID)
}

func (s *TrainingPlanStore) GetTrainingPlanForUser(ctx context.Context, user auth.User, trainingPlanID int64) (coaching.StoredTrainingPlan, bool, error) {
	return s.getTrainingPlan(ctx, user, `
		select
			id,
			objective,
			duration_weeks,
			days_per_week,
			measurement_system,
			coalesce(constraints, ''),
			coalesce(equipment, ''),
			coalesce(notes, ''),
			provider,
			model,
			prompt_version,
			summary,
			philosophy,
			progression_strategy,
			risks,
			success_criteria,
			created_at,
			updated_at
		from training_plans
		where user_id = $1::uuid
		  and id = $2
		limit 1
	`, user.ID, trainingPlanID)
}

func (s *TrainingPlanStore) getTrainingPlan(ctx context.Context, user auth.User, sql string, args ...any) (coaching.StoredTrainingPlan, bool, error) {
	var stored coaching.StoredTrainingPlan
	err := s.db.QueryRow(ctx, sql, args...).Scan(
		&stored.ID,
		&stored.Objective,
		&stored.DurationWeeks,
		&stored.DaysPerWeek,
		&stored.MeasurementSystem,
		&stored.Constraints,
		&stored.Equipment,
		&stored.Notes,
		&stored.Provider,
		&stored.Model,
		&stored.PromptVersion,
		&stored.Summary,
		&stored.Philosophy,
		&stored.ProgressionStrategy,
		&stored.Risks,
		&stored.SuccessCriteria,
		&stored.CreatedAt,
		&stored.UpdatedAt,
	)
	if err != nil {
		if err == pgx.ErrNoRows {
			return coaching.StoredTrainingPlan{}, false, nil
		}
		return coaching.StoredTrainingPlan{}, false, fmt.Errorf("query latest training plan: %w", err)
	}

	weekIndexesByNumber := make(map[int]int)
	weekRows, err := s.db.Query(ctx, `
		select week_number, theme
		from training_plan_weeks
		where training_plan_id = $1
		order by week_number
	`, stored.ID)
	if err != nil {
		return coaching.StoredTrainingPlan{}, false, fmt.Errorf("query training plan weeks: %w", err)
	}
	defer weekRows.Close()

	for weekRows.Next() {
		var week coaching.StoredTrainingPlanWeek
		if err := weekRows.Scan(&week.WeekNumber, &week.Theme); err != nil {
			return coaching.StoredTrainingPlan{}, false, fmt.Errorf("scan training plan week: %w", err)
		}
		stored.Weeks = append(stored.Weeks, week)
		weekIndexesByNumber[week.WeekNumber] = len(stored.Weeks) - 1
	}
	if err := weekRows.Err(); err != nil {
		return coaching.StoredTrainingPlan{}, false, fmt.Errorf("iterate training plan weeks: %w", err)
	}

	workoutRows, err := s.db.Query(ctx, `
		select week_number, day_number, title, coalesce(focus, ''), coalesce(exercises_text, ''), exercises_json
		from training_plan_workouts
		where training_plan_id = $1
		order by week_number, day_number
	`, stored.ID)
	if err != nil {
		return coaching.StoredTrainingPlan{}, false, fmt.Errorf("query training plan workouts: %w", err)
	}
	defer workoutRows.Close()

	for workoutRows.Next() {
		var (
			weekNumber    int
			workout       coaching.StoredPlannedWorkout
			exercisesText string
			exercisesJSON []byte
		)
		if err := workoutRows.Scan(&weekNumber, &workout.DayNumber, &workout.Title, &workout.Focus, &exercisesText, &exercisesJSON); err != nil {
			return coaching.StoredTrainingPlan{}, false, fmt.Errorf("scan training plan workout: %w", err)
		}
		if len(exercisesJSON) > 0 {
			if err := json.Unmarshal(exercisesJSON, &workout.Exercises); err != nil {
				return coaching.StoredTrainingPlan{}, false, fmt.Errorf("unmarshal training plan exercises: %w", err)
			}
		} else if exercisesText != "" {
			for _, title := range strings.Split(exercisesText, "\n") {
				workout.Exercises = append(workout.Exercises, coaching.StoredPlannedExercise{Title: title})
			}
		}

		weekIndex, ok := weekIndexesByNumber[weekNumber]
		if !ok {
			continue
		}
		stored.Weeks[weekIndex].Workouts = append(stored.Weeks[weekIndex].Workouts, workout)
	}
	if err := workoutRows.Err(); err != nil {
		return coaching.StoredTrainingPlan{}, false, fmt.Errorf("iterate training plan workouts: %w", err)
	}

	sort.Slice(stored.Weeks, func(i, j int) bool {
		return stored.Weeks[i].WeekNumber < stored.Weeks[j].WeekNumber
	})

	return stored, true, nil
}

func (s *TrainingPlanStore) SaveTrainingPlanWorkoutForUser(ctx context.Context, user auth.User, trainingPlanID int64, weekNumber int, workout coaching.StoredPlannedWorkout) error {
	exercisesText, exercisesJSON, err := serializeWorkoutExercises(workout.Exercises)
	if err != nil {
		return err
	}

	tag, err := s.db.Exec(ctx, `
		insert into training_plan_workouts (
			training_plan_id,
			week_number,
			day_number,
			title,
			focus,
			exercises_text,
			exercises_json
		)
		select
			tp.id,
			$3,
			$4,
			$5,
			nullif($6, ''),
			nullif($7, ''),
			$8::jsonb
		from training_plans tp
		where tp.user_id = $1::uuid
		  and tp.id = $2
		on conflict (training_plan_id, week_number, day_number)
		do update set
			title = excluded.title,
			focus = excluded.focus,
			exercises_text = excluded.exercises_text,
			exercises_json = excluded.exercises_json
	`, user.ID, trainingPlanID, weekNumber, workout.DayNumber, workout.Title, workout.Focus, exercisesText, string(exercisesJSON))
	if err != nil {
		return fmt.Errorf("upsert training plan workout: %w", err)
	}
	if tag.RowsAffected() == 0 {
		return fmt.Errorf("training plan %d does not belong to user", trainingPlanID)
	}

	if _, err := s.db.Exec(ctx, `
		update training_plans
		set updated_at = now()
		where id = $1 and user_id = $2::uuid
	`, trainingPlanID, user.ID); err != nil {
		return fmt.Errorf("touch training plan after workout upsert: %w", err)
	}

	return nil
}

func (s *TrainingPlanStore) DeleteTrainingPlanWorkoutForUser(ctx context.Context, user auth.User, trainingPlanID int64, weekNumber int, dayNumber int) error {
	tag, err := s.db.Exec(ctx, `
		delete from training_plan_workouts tpw
		using training_plans tp
		where tpw.training_plan_id = tp.id
		  and tp.user_id = $1::uuid
		  and tpw.training_plan_id = $2
		  and tpw.week_number = $3
		  and tpw.day_number = $4
	`, user.ID, trainingPlanID, weekNumber, dayNumber)
	if err != nil {
		return fmt.Errorf("delete training plan workout: %w", err)
	}
	if tag.RowsAffected() == 0 {
		return fmt.Errorf("training plan workout not found")
	}

	if _, err := s.db.Exec(ctx, `
		update training_plans
		set updated_at = now()
		where id = $1 and user_id = $2::uuid
	`, trainingPlanID, user.ID); err != nil {
		return fmt.Errorf("touch training plan after workout delete: %w", err)
	}

	return nil
}

func serializeWorkoutExercises(exercises []coaching.StoredPlannedExercise) (string, []byte, error) {
	exerciseTitles := make([]string, 0, len(exercises))
	for _, exercise := range exercises {
		exerciseTitles = append(exerciseTitles, exercise.Title)
	}
	exercisesText := strings.Join(exerciseTitles, "\n")
	exercisesJSON, err := json.Marshal(exercises)
	if err != nil {
		return "", nil, fmt.Errorf("marshal training plan exercises: %w", err)
	}

	return exercisesText, exercisesJSON, nil
}

func (s *TrainingPlanStore) CountTrainingPlansGeneratedSince(ctx context.Context, user auth.User, since time.Time) (int, error) {
	var count int
	err := s.db.QueryRow(ctx, `
		select count(*)
		from training_plans
		where user_id = $1::uuid
		  and created_at >= $2
	`, user.ID, since).Scan(&count)
	if err != nil {
		return 0, fmt.Errorf("count training plans: %w", err)
	}

	return count, nil
}
