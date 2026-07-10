package handlers

import (
	"context"
	"errors"
	"net/http"

	"github.com/gin-gonic/gin"
	"github.com/josefkarasek/ai-fitness-coach/backend/internal/auth"
	"github.com/josefkarasek/ai-fitness-coach/backend/internal/http/middleware"
)

type PromoCodeStore interface {
	RedeemPromoCodeForUser(ctx context.Context, user auth.User, code string) (auth.User, error)
}

type PromoCodeHandler struct {
	store PromoCodeStore
}

func NewPromoCodeHandler(store PromoCodeStore) *PromoCodeHandler {
	return &PromoCodeHandler{store: store}
}

func (h *PromoCodeHandler) Redeem(c *gin.Context) {
	user, ok := middleware.UserFromGinContext(c)
	if !ok {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "authenticated user missing from request context"})
		return
	}

	var body struct {
		Code string `json:"code"`
	}
	if err := c.ShouldBindJSON(&body); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid request body"})
		return
	}

	updatedUser, err := h.store.RedeemPromoCodeForUser(c.Request.Context(), user, body.Code)
	if err != nil {
		switch {
		case errors.Is(err, auth.ErrPromoCodeNotFound):
			c.JSON(http.StatusNotFound, gin.H{"error": "promo code not found"})
		default:
			c.JSON(http.StatusInternalServerError, gin.H{"error": "redeem promo code"})
		}
		return
	}

	c.JSON(http.StatusOK, gin.H{"user": updatedUser})
}
