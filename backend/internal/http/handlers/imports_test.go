package handlers

import (
	"archive/zip"
	"bytes"
	"context"
	"encoding/json"
	"mime/multipart"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/gin-gonic/gin"
	"github.com/josefkarasek/ai-fitness-coach/backend/internal/auth"
	"github.com/josefkarasek/ai-fitness-coach/backend/internal/traininghistory"
)

type fakeTrainingImportStore struct {
	user             auth.User
	workoutsImported int
	importedFiles    map[string]bool
}

func (f *fakeTrainingImportStore) HasImportedArchiveForUser(_ context.Context, _ auth.User, _ string, fileName string) (bool, error) {
	return f.importedFiles[fileName], nil
}

func (f *fakeTrainingImportStore) ImportWorkoutsForUser(_ context.Context, user auth.User, _ string, _ string, workouts []traininghistory.WorkoutImport) error {
	f.user = user
	f.workoutsImported = len(workouts)
	return nil
}

func (f *fakeTrainingImportStore) RecordImportedArchiveForUser(_ context.Context, _ auth.User, _ string, fileName string) error {
	if f.importedFiles == nil {
		f.importedFiles = make(map[string]bool)
	}
	f.importedFiles[fileName] = true
	return nil
}

func TestImportHandlerCreate(t *testing.T) {
	t.Parallel()

	gin.SetMode(gin.TestMode)

	var archive bytes.Buffer
	zipWriter := zip.NewWriter(&archive)
	fileWriter, err := zipWriter.Create("training_data.csv")
	if err != nil {
		t.Fatalf("Create returned error: %v", err)
	}

	_, err = fileWriter.Write([]byte(`WorkoutTitle,ScheduledDate,RescheduledDate,WorkoutNotes,BlockValue,BlockUnits,BlockInstructions,BlockNotes,ExerciseTitle,ExerciseData,ExerciseNotes
W1T1,2022-11-15,,Felt good,0.00,,,,Trap bar deadlift,"8, 8 rep x 100, 120 kilogram",
`))
	if err != nil {
		t.Fatalf("Write returned error: %v", err)
	}

	if err := zipWriter.Close(); err != nil {
		t.Fatalf("Close returned error: %v", err)
	}

	var body bytes.Buffer
	writer := multipart.NewWriter(&body)
	if err := writer.WriteField("import_type", ImportTypeTrainHeroicCSV); err != nil {
		t.Fatalf("WriteField returned error: %v", err)
	}

	part, err := writer.CreateFormFile("file", "export.zip")
	if err != nil {
		t.Fatalf("CreateFormFile returned error: %v", err)
	}

	if _, err := part.Write(archive.Bytes()); err != nil {
		t.Fatalf("part.Write returned error: %v", err)
	}

	if err := writer.Close(); err != nil {
		t.Fatalf("writer.Close returned error: %v", err)
	}

	store := &fakeTrainingImportStore{
		importedFiles: make(map[string]bool),
	}
	handler := NewImportHandler(store)

	recorder := httptest.NewRecorder()
	c, _ := gin.CreateTestContext(recorder)
	req := httptest.NewRequest(http.MethodPost, "/api/v1/imports", &body)
	req.Header.Set("Content-Type", writer.FormDataContentType())
	c.Request = req
	c.Set("auth_user", auth.User{
		ID:          "user-1",
		FirebaseUID: "firebase-user-1",
		Email:       "jk@example.com",
		DisplayName: "Josef",
	})

	handler.Create(c)

	if recorder.Code != http.StatusCreated {
		t.Fatalf("expected status %d, got %d with body %s", http.StatusCreated, recorder.Code, recorder.Body.String())
	}

	if store.user.ID != "user-1" {
		t.Fatalf("expected user id user-1, got %q", store.user.ID)
	}

	if store.workoutsImported != 1 {
		t.Fatalf("expected 1 workout imported, got %d", store.workoutsImported)
	}

	var response map[string]any
	if err := json.Unmarshal(recorder.Body.Bytes(), &response); err != nil {
		t.Fatalf("json.Unmarshal returned error: %v", err)
	}

	if response["import_type"] != ImportTypeTrainHeroicCSV {
		t.Fatalf("expected import_type %q, got %#v", ImportTypeTrainHeroicCSV, response["import_type"])
	}

	if response["file_name"] != "export.zip" {
		t.Fatalf("expected file_name export.zip, got %#v", response["file_name"])
	}

	summary, ok := response["summary"].(map[string]any)
	if !ok {
		t.Fatalf("expected summary object, got %#v", response["summary"])
	}

	if summary["workouts"] != float64(1) {
		t.Fatalf("expected 1 workout, got %#v", summary["workouts"])
	}

	if summary["exercises"] != float64(1) {
		t.Fatalf("expected 1 exercise, got %#v", summary["exercises"])
	}

	if summary["sets"] != float64(2) {
		t.Fatalf("expected 2 sets, got %#v", summary["sets"])
	}

	if summary["date_range"] != "2022-11-15" {
		t.Fatalf("expected date_range 2022-11-15, got %#v", summary["date_range"])
	}
}

func TestImportHandlerCreateRejectsDuplicateFileName(t *testing.T) {
	t.Parallel()

	gin.SetMode(gin.TestMode)

	var archive bytes.Buffer
	zipWriter := zip.NewWriter(&archive)
	fileWriter, err := zipWriter.Create("training_data.csv")
	if err != nil {
		t.Fatalf("Create returned error: %v", err)
	}

	_, err = fileWriter.Write([]byte(`WorkoutTitle,ScheduledDate,RescheduledDate,WorkoutNotes,BlockValue,BlockUnits,BlockInstructions,BlockNotes,ExerciseTitle,ExerciseData,ExerciseNotes
W1T1,2022-11-15,,Felt good,0.00,,,,Trap bar deadlift,"8, 8 rep x 100, 120 kilogram",
`))
	if err != nil {
		t.Fatalf("Write returned error: %v", err)
	}

	if err := zipWriter.Close(); err != nil {
		t.Fatalf("Close returned error: %v", err)
	}

	var body bytes.Buffer
	writer := multipart.NewWriter(&body)
	if err := writer.WriteField("import_type", ImportTypeTrainHeroicCSV); err != nil {
		t.Fatalf("WriteField returned error: %v", err)
	}

	part, err := writer.CreateFormFile("file", "export.zip")
	if err != nil {
		t.Fatalf("CreateFormFile returned error: %v", err)
	}

	if _, err := part.Write(archive.Bytes()); err != nil {
		t.Fatalf("part.Write returned error: %v", err)
	}

	if err := writer.Close(); err != nil {
		t.Fatalf("writer.Close returned error: %v", err)
	}

	store := &fakeTrainingImportStore{
		importedFiles: map[string]bool{
			"export.zip": true,
		},
	}
	handler := NewImportHandler(store)

	recorder := httptest.NewRecorder()
	c, _ := gin.CreateTestContext(recorder)
	req := httptest.NewRequest(http.MethodPost, "/api/v1/imports", &body)
	req.Header.Set("Content-Type", writer.FormDataContentType())
	c.Request = req
	c.Set("auth_user", auth.User{
		ID:          "user-1",
		FirebaseUID: "firebase-user-1",
		Email:       "jk@example.com",
		DisplayName: "Josef",
	})

	handler.Create(c)

	if recorder.Code != http.StatusConflict {
		t.Fatalf("expected status %d, got %d with body %s", http.StatusConflict, recorder.Code, recorder.Body.String())
	}

	if store.workoutsImported != 0 {
		t.Fatalf("expected no workouts imported, got %d", store.workoutsImported)
	}
}
