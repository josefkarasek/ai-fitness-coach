package handlers

import (
	"embed"
	"net/http"

	"github.com/gin-gonic/gin"
)

//go:embed assets/landing.html
var landingPageFS embed.FS

type LandingHandler struct {
	html []byte
}

func NewLandingHandler() *LandingHandler {
	html, err := landingPageFS.ReadFile("assets/landing.html")
	if err != nil {
		panic("read embedded landing page: " + err.Error())
	}

	return &LandingHandler{html: html}
}

func (h *LandingHandler) Home(c *gin.Context) {
	c.Data(http.StatusOK, "text/html; charset=utf-8", h.html)
}
