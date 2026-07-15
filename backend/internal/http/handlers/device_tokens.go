package handlers

import (
	"context"
	"net/http"
	"strings"

	"github.com/gin-gonic/gin"
	"github.com/josefkarasek/ai-fitness-coach/backend/internal/auth"
	"github.com/josefkarasek/ai-fitness-coach/backend/internal/http/middleware"
)

type DeviceTokenStore interface {
	UpsertPushToken(ctx context.Context, user auth.User, token string, platform string) error
}

type DeviceTokensHandler struct {
	store DeviceTokenStore
}

func NewDeviceTokensHandler(store DeviceTokenStore) *DeviceTokensHandler {
	return &DeviceTokensHandler{store: store}
}

func (h *DeviceTokensHandler) Upsert(c *gin.Context) {
	user, ok := middleware.UserFromGinContext(c)
	if !ok {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "authenticated user missing from request context"})
		return
	}

	var requestBody struct {
		Token    string `json:"token"`
		Platform string `json:"platform"`
	}
	if err := c.ShouldBindJSON(&requestBody); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid request body"})
		return
	}

	token := strings.TrimSpace(requestBody.Token)
	if token == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "token is required"})
		return
	}

	if err := h.store.UpsertPushToken(c.Request.Context(), user, token, requestBody.Platform); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "store device token"})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"token":    token,
		"platform": strings.TrimSpace(requestBody.Platform),
	})
}
