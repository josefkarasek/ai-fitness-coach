package handlers

import (
	"embed"
	"net/http"

	"github.com/gin-gonic/gin"
)

//go:embed assets/landing.html assets/favicon.svg
var landingPageFS embed.FS

type LandingHandler struct {
	html    []byte
	favicon []byte
}

func NewLandingHandler() *LandingHandler {
	html, err := landingPageFS.ReadFile("assets/landing.html")
	if err != nil {
		panic("read embedded landing page: " + err.Error())
	}

	favicon, err := landingPageFS.ReadFile("assets/favicon.svg")
	if err != nil {
		panic("read embedded favicon: " + err.Error())
	}

	return &LandingHandler{
		html:    html,
		favicon: favicon,
	}
}

func (h *LandingHandler) Home(c *gin.Context) {
	c.Data(http.StatusOK, "text/html; charset=utf-8", h.html)
}

func (h *LandingHandler) Favicon(c *gin.Context) {
	c.Data(http.StatusOK, "image/svg+xml; charset=utf-8", h.favicon)
}
