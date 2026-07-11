package handlers

import (
	"log/slog"
	"net/http"

	"github.com/gin-gonic/gin"
	"github.com/josefkarasek/ai-fitness-coach/backend/internal/http/middleware"
)

type AuthHandler struct{}

func NewAuthHandler() *AuthHandler {
	return &AuthHandler{}
}

func (h *AuthHandler) Me(c *gin.Context) {
	user, ok := middleware.UserFromGinContext(c)
	if !ok {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "authenticated user missing from request context",
		})
		return
	}

	slog.Info("auth me response",
		"user_id", user.ID,
		"firebase_uid", user.FirebaseUID,
		"email", user.Email,
		"redeemed_promo_code", user.RedeemedPromoCode,
		"ai_access_enabled", user.AIAccessEnabled,
	)

	c.JSON(http.StatusOK, gin.H{
		"user": user,
	})
}
