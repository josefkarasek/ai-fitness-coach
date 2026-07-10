package traininghistory

import (
	"archive/zip"
	"bytes"
	"fmt"
	"path/filepath"
	"strings"
)

const trainHeroicTrainingDataFileName = "training_data.csv"

func ParseTrainHeroicExportZIP(data []byte) ([]WorkoutImport, error) {
	reader, err := zip.NewReader(bytes.NewReader(data), int64(len(data)))
	if err != nil {
		return nil, fmt.Errorf("open zip: %w", err)
	}

	for _, file := range reader.File {
		if !strings.EqualFold(filepath.Base(file.Name), trainHeroicTrainingDataFileName) {
			continue
		}

		rc, err := file.Open()
		if err != nil {
			return nil, fmt.Errorf("open %s from zip: %w", file.Name, err)
		}
		defer rc.Close()

		workouts, err := ParseTrainingDataCSV(rc)
		if err != nil {
			return nil, fmt.Errorf("parse %s: %w", file.Name, err)
		}

		return workouts, nil
	}

	return nil, fmt.Errorf("%s not found in zip archive", trainHeroicTrainingDataFileName)
}
