package handlers

import (
	"embed"
	"net/http"

	"github.com/gin-gonic/gin"
)

//go:embed assets/landing.html assets/privacy.html assets/favicon.svg
var landingPageFS embed.FS

type LandingHandler struct {
	html        []byte
	privacyHTML []byte
	favicon     []byte
}

func NewLandingHandler() *LandingHandler {
	html, err := landingPageFS.ReadFile("assets/landing.html")
	if err != nil {
		panic("read embedded landing page: " + err.Error())
	}

	privacyHTML, err := landingPageFS.ReadFile("assets/privacy.html")
	if err != nil {
		panic("read embedded privacy page: " + err.Error())
	}

	favicon, err := landingPageFS.ReadFile("assets/favicon.svg")
	if err != nil {
		panic("read embedded favicon: " + err.Error())
	}

	return &LandingHandler{
		html:        html,
		privacyHTML: privacyHTML,
		favicon:     favicon,
	}
}

func (h *LandingHandler) Home(c *gin.Context) {
	c.Data(http.StatusOK, "text/html; charset=utf-8", h.html)
}

func (h *LandingHandler) Privacy(c *gin.Context) {
	c.Data(http.StatusOK, "text/html; charset=utf-8", h.privacyHTML)
}

func (h *LandingHandler) Favicon(c *gin.Context) {
	c.Data(http.StatusOK, "image/svg+xml; charset=utf-8", h.favicon)
}
