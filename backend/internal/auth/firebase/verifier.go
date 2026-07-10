package firebase

import (
	"context"
	"fmt"

	firebase "firebase.google.com/go/v4"
	firebaseauth "firebase.google.com/go/v4/auth"
	"github.com/josefkarasek/ai-fitness-coach/backend/internal/auth"
)

type Verifier struct {
	client *firebaseauth.Client
}

func NewVerifier(ctx context.Context, projectID string) (*Verifier, error) {
	if projectID == "" {
		return nil, fmt.Errorf("firebase project id is required")
	}

	app, err := firebase.NewApp(ctx, &firebase.Config{
		ProjectID: projectID,
	})
	if err != nil {
		return nil, fmt.Errorf("create firebase app: %w", err)
	}

	client, err := app.Auth(ctx)
	if err != nil {
		return nil, fmt.Errorf("create firebase auth client: %w", err)
	}

	return &Verifier{client: client}, nil
}

func (v *Verifier) VerifyToken(ctx context.Context, token string) (auth.Identity, error) {
	verified, err := v.client.VerifyIDToken(ctx, token)
	if err != nil {
		return auth.Identity{}, fmt.Errorf("verify firebase id token: %w", err)
	}

	identity := auth.Identity{
		FirebaseUID: verified.UID,
	}

	if email, ok := verified.Claims["email"].(string); ok {
		identity.Email = email
	}

	if name, ok := verified.Claims["name"].(string); ok {
		identity.DisplayName = name
	}

	return identity, nil
}
