package traininghistory

import (
	"encoding/csv"
	"fmt"
	"io"
	"strconv"
	"strings"
	"time"
)

const (
	sourceTrainHeroicCSV = "trainheroic_csv"
	dateLayoutISO        = "2006-01-02"
)

type WorkoutImport struct {
	Source             string
	SourceWorkoutTitle string
	ScheduledDate      time.Time
	RescheduledDate    *time.Time
	WorkoutNotes       string
	BlockValue         *float64
	BlockUnits         string
	BlockInstructions  string
	BlockNotes         string
	Exercises          []ExerciseImport
}

type ExerciseImport struct {
	Title           string
	Notes           string
	RawExerciseData string
	Sets            []SetImport
}

type SetImport struct {
	SequenceNumber  int
	MeasurementUnit string
	Reps            *float64
	DistanceMeters  *float64
	LoadValue       *float64
	LoadUnit        string
	RawPrimaryValue string
	RawLoadValue    string
}

type csvRow struct {
	WorkoutTitle      string
	ScheduledDate     string
	RescheduledDate   string
	WorkoutNotes      string
	BlockValue        string
	BlockUnits        string
	BlockInstructions string
	BlockNotes        string
	ExerciseTitle     string
	ExerciseData      string
	ExerciseNotes     string
}

func ParseTrainingDataCSV(r io.Reader) ([]WorkoutImport, error) {
	reader := csv.NewReader(r)

	records, err := reader.ReadAll()
	if err != nil {
		return nil, fmt.Errorf("read csv: %w", err)
	}

	if len(records) == 0 {
		return nil, nil
	}

	workoutsByKey := make(map[string]*WorkoutImport)
	workoutOrder := make([]string, 0)

	for rowIdx, record := range records[1:] {
		row, err := parseCSVRow(record)
		if err != nil {
			return nil, fmt.Errorf("parse row %d: %w", rowIdx+2, err)
		}

		scheduledDate, err := time.Parse(dateLayoutISO, row.ScheduledDate)
		if err != nil {
			return nil, fmt.Errorf("parse row %d scheduled date: %w", rowIdx+2, err)
		}

		var rescheduledDate *time.Time
		if row.RescheduledDate != "" {
			parsed, err := time.Parse(dateLayoutISO, row.RescheduledDate)
			if err != nil {
				return nil, fmt.Errorf("parse row %d rescheduled date: %w", rowIdx+2, err)
			}
			rescheduledDate = &parsed
		}

		workoutKey := strings.Join([]string{
			row.WorkoutTitle,
			scheduledDate.Format(dateLayoutISO),
		}, "|")

		workout, ok := workoutsByKey[workoutKey]
		if !ok {
			blockValue, err := parseOptionalFloat(row.BlockValue)
			if err != nil {
				return nil, fmt.Errorf("parse row %d block value: %w", rowIdx+2, err)
			}

			workout = &WorkoutImport{
				Source:             sourceTrainHeroicCSV,
				SourceWorkoutTitle: row.WorkoutTitle,
				ScheduledDate:      scheduledDate,
				RescheduledDate:    rescheduledDate,
				WorkoutNotes:       row.WorkoutNotes,
				BlockValue:         blockValue,
				BlockUnits:         row.BlockUnits,
				BlockInstructions:  row.BlockInstructions,
				BlockNotes:         row.BlockNotes,
			}
			workoutsByKey[workoutKey] = workout
			workoutOrder = append(workoutOrder, workoutKey)
		}

		sets, err := ParseExerciseData(row.ExerciseData)
		if err != nil {
			return nil, fmt.Errorf("parse row %d exercise data: %w", rowIdx+2, err)
		}

		workout.Exercises = append(workout.Exercises, ExerciseImport{
			Title:           row.ExerciseTitle,
			Notes:           row.ExerciseNotes,
			RawExerciseData: row.ExerciseData,
			Sets:            sets,
		})
	}

	workouts := make([]WorkoutImport, 0, len(workoutOrder))
	for _, key := range workoutOrder {
		workouts = append(workouts, *workoutsByKey[key])
	}

	return workouts, nil
}

func parseCSVRow(record []string) (csvRow, error) {
	if len(record) != 11 {
		return csvRow{}, fmt.Errorf("expected 11 columns, got %d", len(record))
	}

	return csvRow{
		WorkoutTitle:      strings.TrimSpace(record[0]),
		ScheduledDate:     strings.TrimSpace(record[1]),
		RescheduledDate:   strings.TrimSpace(record[2]),
		WorkoutNotes:      strings.TrimSpace(record[3]),
		BlockValue:        strings.TrimSpace(record[4]),
		BlockUnits:        strings.TrimSpace(record[5]),
		BlockInstructions: strings.TrimSpace(record[6]),
		BlockNotes:        strings.TrimSpace(record[7]),
		ExerciseTitle:     strings.TrimSpace(record[8]),
		ExerciseData:      strings.TrimSpace(record[9]),
		ExerciseNotes:     strings.TrimSpace(record[10]),
	}, nil
}

func parseOptionalFloat(value string) (*float64, error) {
	if value == "" {
		return nil, nil
	}

	parsed, err := strconv.ParseFloat(value, 64)
	if err != nil {
		return nil, err
	}

	return &parsed, nil
}
