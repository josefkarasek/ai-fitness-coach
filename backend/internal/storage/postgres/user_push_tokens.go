package postgres

import (
	"context"
	"fmt"
	"strings"

	"github.com/josefkarasek/ai-fitness-coach/backend/internal/auth"
)

func (s *UserStore) UpsertPushToken(ctx context.Context, user auth.User, token string, platform string) error {
	token = strings.TrimSpace(token)
	platform = strings.TrimSpace(platform)
	if token == "" {
		return fmt.Errorf("push token is required")
	}
	if platform == "" {
		platform = "unknown"
	}

	if _, err := s.db.Exec(ctx, `
		insert into user_push_tokens (token, user_id, platform)
		values ($1, $2::uuid, $3)
		on conflict (token)
		do update set
			user_id = excluded.user_id,
			platform = excluded.platform,
			updated_at = now(),
			last_seen_at = now()
	`, token, user.ID, platform); err != nil {
		return fmt.Errorf("upsert push token: %w", err)
	}

	return nil
}

func (s *UserStore) ListPushTokens(ctx context.Context, userID string) ([]string, error) {
	rows, err := s.db.Query(ctx, `
		select token
		from user_push_tokens
		where user_id = $1::uuid
		order by updated_at desc
	`, userID)
	if err != nil {
		return nil, fmt.Errorf("query push tokens: %w", err)
	}
	defer rows.Close()

	var tokens []string
	for rows.Next() {
		var token string
		if err := rows.Scan(&token); err != nil {
			return nil, fmt.Errorf("scan push token: %w", err)
		}
		tokens = append(tokens, token)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("iterate push tokens: %w", err)
	}

	return tokens, nil
}
