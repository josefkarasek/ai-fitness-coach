package coaching

import (
	"context"

	"github.com/josefkarasek/ai-fitness-coach/backend/internal/auth"
)

type AIAccessStore interface {
	HasPaidAIAccessForUser(ctx context.Context, user auth.User) (bool, error)
}
