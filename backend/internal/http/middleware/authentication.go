package middleware

import (
	"context"
	"errors"
	"net/http"
	"strings"

	"github.com/gin-gonic/gin"
	"github.com/josefkarasek/ai-fitness-coach/backend/internal/auth"
)

const ginUserContextKey = "auth_user"

type UserResolver interface {
	UpsertByFirebaseIdentity(ctx context.Context, identity auth.Identity) (auth.User, error)
}

type Authentication struct {
	verifier Verifier
	users    UserResolver
}

type Verifier interface {
	VerifyToken(ctx context.Context, token string) (auth.Identity, error)
}

func NewAuthentication(verifier Verifier, users UserResolver) *Authentication {
	return &Authentication{
		verifier: verifier,
		users:    users,
	}
}

func (a *Authentication) RequireAuth() gin.HandlerFunc {
	return func(c *gin.Context) {
		token, err := bearerTokenFromHeader(c.GetHeader("Authorization"))
		if err != nil {
			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{
				"error": "missing or invalid authorization header",
			})
			return
		}

		identity, err := a.verifier.VerifyToken(c.Request.Context(), token)
		if err != nil {
			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{
				"error": "invalid auth token",
			})
			return
		}

		user, err := a.users.UpsertByFirebaseIdentity(c.Request.Context(), identity)
		if err != nil {
			c.AbortWithStatusJSON(http.StatusInternalServerError, gin.H{
				"error": "resolve authenticated user",
			})
			return
		}

		requestCtx := auth.NewContextWithUser(c.Request.Context(), user)
		c.Request = c.Request.WithContext(requestCtx)
		c.Set(ginUserContextKey, user)
		c.Next()
	}
}

func UserFromGinContext(c *gin.Context) (auth.User, bool) {
	user, ok := c.Get(ginUserContextKey)
	if !ok {
		return auth.User{}, false
	}

	authUser, ok := user.(auth.User)
	return authUser, ok
}

func bearerTokenFromHeader(header string) (string, error) {
	header = strings.TrimSpace(header)
	if header == "" {
		return "", errors.New("empty authorization header")
	}

	parts := strings.SplitN(header, " ", 2)
	if len(parts) != 2 || !strings.EqualFold(parts[0], "bearer") {
		return "", errors.New("malformed bearer token")
	}

	token := strings.TrimSpace(parts[1])
	if token == "" {
		return "", errors.New("empty bearer token")
	}

	return token, nil
}
