package postgres

import (
	"context"
	"fmt"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/josefkarasek/ai-fitness-coach/backend/internal/auth"
)

type UserStore struct {
	db *pgxpool.Pool
}

func NewUserStore(db *pgxpool.Pool) *UserStore {
	return &UserStore{db: db}
}

func (s *UserStore) UpsertByFirebaseIdentity(ctx context.Context, identity auth.Identity) (auth.User, error) {
	var user auth.User
	err := s.db.QueryRow(ctx, `
		insert into users (firebase_uid, email, display_name)
		values ($1, nullif($2, ''), nullif($3, ''))
		on conflict (firebase_uid)
		do update set
			email = excluded.email,
			display_name = coalesce(excluded.display_name, users.display_name),
			updated_at = now()
		returning
			id::text,
			firebase_uid,
			coalesce(email, ''),
			coalesce(display_name, ''),
			coalesce(training_experience, ''),
			coalesce(primary_goal, ''),
			coalesce(preferred_days, '{}')
	`, identity.FirebaseUID, identity.Email, identity.DisplayName).Scan(
		&user.ID,
		&user.FirebaseUID,
		&user.Email,
		&user.DisplayName,
		&user.TrainingExperience,
		&user.PrimaryGoal,
		&user.PreferredDays,
	)
	if err != nil {
		return auth.User{}, fmt.Errorf("upsert user by firebase identity: %w", err)
	}

	return user, nil
}
