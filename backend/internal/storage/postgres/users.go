package postgres

import (
	"context"
	"fmt"
	"strings"

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
			coalesce(preferred_days, '{}'),
			coalesce(redeemed_promo_code, ''),
			exists(
				select 1
				from promo_codes pc
				where pc.code = users.redeemed_promo_code
				  and pc.active = true
			)
	`, identity.FirebaseUID, identity.Email, identity.DisplayName).Scan(
		&user.ID,
		&user.FirebaseUID,
		&user.Email,
		&user.DisplayName,
		&user.TrainingExperience,
		&user.PrimaryGoal,
		&user.PreferredDays,
		&user.RedeemedPromoCode,
		&user.AIAccessEnabled,
	)
	if err != nil {
		return auth.User{}, fmt.Errorf("upsert user by firebase identity: %w", err)
	}

	return user, nil
}

func (s *UserStore) RedeemPromoCodeForUser(ctx context.Context, user auth.User, rawCode string) (auth.User, error) {
	code := normalizePromoCode(rawCode)
	if code == "" {
		return auth.User{}, auth.ErrPromoCodeNotFound
	}

	var exists bool
	if err := s.db.QueryRow(ctx, `
		select exists(
			select 1
			from promo_codes
			where code = $1 and active = true
		)
	`, code).Scan(&exists); err != nil {
		return auth.User{}, fmt.Errorf("check promo code: %w", err)
	}
	if !exists {
		return auth.User{}, auth.ErrPromoCodeNotFound
	}

	var updated auth.User
	err := s.db.QueryRow(ctx, `
		update users
		set redeemed_promo_code = $2,
		    updated_at = now()
		where id = $1::uuid
		returning
			id::text,
			firebase_uid,
			coalesce(email, ''),
			coalesce(display_name, ''),
			coalesce(training_experience, ''),
			coalesce(primary_goal, ''),
			coalesce(preferred_days, '{}'),
			coalesce(redeemed_promo_code, ''),
			exists(
				select 1
				from promo_codes pc
				where pc.code = users.redeemed_promo_code
				  and pc.active = true
			)
	`, user.ID, code).Scan(
		&updated.ID,
		&updated.FirebaseUID,
		&updated.Email,
		&updated.DisplayName,
		&updated.TrainingExperience,
		&updated.PrimaryGoal,
		&updated.PreferredDays,
		&updated.RedeemedPromoCode,
		&updated.AIAccessEnabled,
	)
	if err != nil {
		return auth.User{}, fmt.Errorf("redeem promo code for user: %w", err)
	}

	return updated, nil
}

func (s *UserStore) HasPaidAIAccessForUser(ctx context.Context, user auth.User) (bool, error) {
	var enabled bool
	err := s.db.QueryRow(ctx, `
		select exists(
			select 1
			from users u
			join promo_codes pc on pc.code = u.redeemed_promo_code
			where u.id = $1::uuid
			  and pc.active = true
		)
	`, user.ID).Scan(&enabled)
	if err != nil {
		return false, fmt.Errorf("check paid ai access for user: %w", err)
	}

	return enabled, nil
}

func normalizePromoCode(code string) string {
	return strings.ToUpper(strings.TrimSpace(code))
}
