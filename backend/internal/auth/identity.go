package auth

import (
	"context"
	"errors"
)

type Identity struct {
	FirebaseUID string
	Email       string
	DisplayName string
}

type User struct {
	ID                 string   `json:"id"`
	FirebaseUID        string   `json:"firebase_uid"`
	Email              string   `json:"email,omitempty"`
	DisplayName        string   `json:"display_name,omitempty"`
	TrainingExperience string   `json:"training_experience,omitempty"`
	PrimaryGoal        string   `json:"primary_goal,omitempty"`
	PreferredDays      []string `json:"preferred_days,omitempty"`
	RedeemedPromoCode  string   `json:"redeemed_promo_code,omitempty"`
	AIAccessEnabled    bool     `json:"ai_access_enabled"`
}

var ErrPromoCodeNotFound = errors.New("promo code not found")

type Verifier interface {
	VerifyToken(ctx context.Context, token string) (Identity, error)
}

type contextKey string

const userContextKey contextKey = "auth_user"

func NewContextWithUser(ctx context.Context, user User) context.Context {
	return context.WithValue(ctx, userContextKey, user)
}

func UserFromContext(ctx context.Context) (User, bool) {
	user, ok := ctx.Value(userContextKey).(User)
	return user, ok
}
