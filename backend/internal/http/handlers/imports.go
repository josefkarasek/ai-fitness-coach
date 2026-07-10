package handlers

import (
	"context"
	"fmt"
	"io"
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/josefkarasek/ai-fitness-coach/backend/internal/auth"
	"github.com/josefkarasek/ai-fitness-coach/backend/internal/http/middleware"
	"github.com/josefkarasek/ai-fitness-coach/backend/internal/traininghistory"
)

const (
	ImportTypeTrainHeroicCSV = "trainheroic_csv"
	maxImportArchiveSize     = 32 << 20
)

type TrainingImportStore interface {
	HasImportedArchiveForUser(ctx context.Context, user auth.User, source string, fileName string) (bool, error)
	ImportWorkoutsForUser(ctx context.Context, user auth.User, source string, sourceAthleteID string, workouts []traininghistory.WorkoutImport) error
	RecordImportedArchiveForUser(ctx context.Context, user auth.User, source string, fileName string) error
}

type importSummary struct {
	Workouts  int     `json:"workouts"`
	Exercises int     `json:"exercises"`
	Sets      int     `json:"sets"`
	DateRange *string `json:"date_range,omitempty"`
}

type ImportHandler struct {
	store TrainingImportStore
}

func NewImportHandler(store TrainingImportStore) *ImportHandler {
	return &ImportHandler{store: store}
}

func (h *ImportHandler) Create(c *gin.Context) {
	user, ok := middleware.UserFromGinContext(c)
	if !ok {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "authenticated user missing from request context",
		})
		return
	}

	importType := c.PostForm("import_type")
	if importType != ImportTypeTrainHeroicCSV {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": fmt.Sprintf("unsupported import_type %q", importType),
		})
		return
	}

	fileHeader, err := c.FormFile("file")
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "file is required",
		})
		return
	}

	alreadyImported, err := h.store.HasImportedArchiveForUser(c.Request.Context(), user, ImportTypeTrainHeroicCSV, fileHeader.Filename)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "check existing import",
		})
		return
	}
	if alreadyImported {
		c.JSON(http.StatusConflict, gin.H{
			"error":       "archive with this file name was already imported",
			"file_name":   fileHeader.Filename,
			"import_type": importType,
		})
		return
	}

	file, err := fileHeader.Open()
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "open uploaded file",
		})
		return
	}
	defer file.Close()

	archiveData, err := io.ReadAll(io.LimitReader(file, maxImportArchiveSize+1))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "read uploaded file",
		})
		return
	}

	if len(archiveData) > maxImportArchiveSize {
		c.JSON(http.StatusRequestEntityTooLarge, gin.H{
			"error": "uploaded archive exceeds 32 MiB limit",
		})
		return
	}

	workouts, err := traininghistory.ParseTrainHeroicExportZIP(archiveData)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": err.Error(),
		})
		return
	}

	if err := h.store.ImportWorkoutsForUser(c.Request.Context(), user, ImportTypeTrainHeroicCSV, "", workouts); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "store imported workouts",
		})
		return
	}

	if err := h.store.RecordImportedArchiveForUser(c.Request.Context(), user, ImportTypeTrainHeroicCSV, fileHeader.Filename); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "record imported archive",
		})
		return
	}

	summary := summarizeImport(workouts)

	c.JSON(http.StatusCreated, gin.H{
		"import_type":        importType,
		"file_name":          fileHeader.Filename,
		"archive_size_bytes": len(archiveData),
		"summary":            summary,
	})
}

func summarizeImport(workouts []traininghistory.WorkoutImport) importSummary {
	summary := importSummary{
		Workouts: len(workouts),
	}

	var minDate time.Time
	var maxDate time.Time

	for idx, workout := range workouts {
		if idx == 0 || workout.ScheduledDate.Before(minDate) {
			minDate = workout.ScheduledDate
		}
		if idx == 0 || workout.ScheduledDate.After(maxDate) {
			maxDate = workout.ScheduledDate
		}

		summary.Exercises += len(workout.Exercises)
		for _, exercise := range workout.Exercises {
			summary.Sets += len(exercise.Sets)
		}
	}

	if !minDate.IsZero() {
		dateRange := minDate.Format("2006-01-02")
		if !maxDate.Equal(minDate) {
			dateRange = fmt.Sprintf("%s to %s", dateRange, maxDate.Format("2006-01-02"))
		}
		summary.DateRange = &dateRange
	}

	return summary
}
