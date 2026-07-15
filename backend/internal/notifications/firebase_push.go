package notifications

import (
	"context"
	"fmt"
	"log/slog"
	"strings"

	firebase "firebase.google.com/go/v4"
	"firebase.google.com/go/v4/messaging"
	"github.com/josefkarasek/ai-fitness-coach/backend/internal/coaching"
)

type PushTokenReader interface {
	ListPushTokens(ctx context.Context, userID string) ([]string, error)
}

type FirebasePushNotifier struct {
	client *messaging.Client
	tokens PushTokenReader
}

func NewFirebasePushNotifier(ctx context.Context, projectID string, tokens PushTokenReader) (*FirebasePushNotifier, error) {
	if strings.TrimSpace(projectID) == "" {
		return nil, fmt.Errorf("firebase project id is required")
	}

	app, err := firebase.NewApp(ctx, &firebase.Config{
		ProjectID: projectID,
	})
	if err != nil {
		return nil, fmt.Errorf("create firebase app: %w", err)
	}

	client, err := app.Messaging(ctx)
	if err != nil {
		return nil, fmt.Errorf("create firebase messaging client: %w", err)
	}

	return &FirebasePushNotifier{
		client: client,
		tokens: tokens,
	}, nil
}

func (n *FirebasePushNotifier) NotifyTrainingPlanReady(ctx context.Context, userID string, job coaching.TrainingPlanJob) error {
	if job.TrainingPlanID == nil {
		return fmt.Errorf("training plan id missing for completed job")
	}

	return n.send(ctx, userID, map[string]string{
		"type":             "training_plan_ready",
		"job_id":           job.ID,
		"training_plan_id": fmt.Sprintf("%d", *job.TrainingPlanID),
		"status":           job.Status,
	})
}

func (n *FirebasePushNotifier) NotifyTrainingPlanFailed(ctx context.Context, userID string, job coaching.TrainingPlanJob) error {
	return n.send(ctx, userID, map[string]string{
		"type":          "training_plan_failed",
		"job_id":        job.ID,
		"status":        job.Status,
		"error_message": job.ErrorMessage,
	})
}

func (n *FirebasePushNotifier) send(ctx context.Context, userID string, data map[string]string) error {
	tokens, err := n.tokens.ListPushTokens(ctx, userID)
	if err != nil {
		return fmt.Errorf("load push tokens: %w", err)
	}
	if len(tokens) == 0 {
		slog.Info("skip push send because no device tokens were registered", "user_id", userID, "payload_type", data["type"])
		return nil
	}

	for _, token := range tokens {
		message := &messaging.Message{
			Token: token,
			Data:  data,
			Android: &messaging.AndroidConfig{
				Priority: "high",
			},
		}

		messageID, err := n.client.Send(ctx, message)
		if err != nil {
			slog.Warn("send firebase push failed", "user_id", userID, "token", token, "payload_type", data["type"], "error", err)
			continue
		}

		slog.Info("firebase push sent", "user_id", userID, "token", token, "payload_type", data["type"], "message_id", messageID)
	}

	return nil
}
