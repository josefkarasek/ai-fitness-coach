package traininghistory

import (
	"fmt"
	"strconv"
	"strings"
)

func ParseExerciseData(raw string) ([]SetImport, error) {
	raw = strings.TrimSpace(raw)
	if raw == "" {
		return nil, nil
	}

	left, right, ok := cutExerciseData(raw)
	if !ok {
		return nil, fmt.Errorf("expected exercise data in '<values> unit x <values> unit' format")
	}

	primaryValuesPart, measurementUnit, err := splitValueAndUnit(left)
	if err != nil {
		return nil, fmt.Errorf("parse primary side: %w", err)
	}

	loadValuesPart, loadUnit, err := splitValueAndUnit(right)
	if err != nil {
		return nil, fmt.Errorf("parse load side: %w", err)
	}

	primaryValues := parseValueList(primaryValuesPart)
	loadValues := parseValueList(loadValuesPart)
	setCount := max(len(primaryValues), len(loadValues))
	if setCount == 0 {
		return nil, nil
	}

	sets := make([]SetImport, 0, setCount)
	for idx := range setCount {
		set := SetImport{
			SequenceNumber:  idx + 1,
			MeasurementUnit: measurementUnit,
			LoadUnit:        loadUnit,
			RawPrimaryValue: valueAt(primaryValues, idx),
			RawLoadValue:    valueAt(loadValues, idx),
		}

		switch measurementUnit {
		case "rep":
			if set.RawPrimaryValue != "" {
				value, ok, err := parseOptionalNumber(set.RawPrimaryValue)
				if err != nil {
					return nil, fmt.Errorf("parse reps for set %d: %w", idx+1, err)
				}
				if ok {
					set.Reps = &value
				}
			}
		case "meter":
			if set.RawPrimaryValue != "" {
				value, ok, err := parseOptionalNumber(set.RawPrimaryValue)
				if err != nil {
					return nil, fmt.Errorf("parse distance for set %d: %w", idx+1, err)
				}
				if ok {
					set.DistanceMeters = &value
				}
			}
		}

		if set.RawLoadValue != "" {
			value, ok, err := parseOptionalNumber(set.RawLoadValue)
			if err != nil {
				return nil, fmt.Errorf("parse load for set %d: %w", idx+1, err)
			}
			if ok {
				set.LoadValue = &value
			}
		}

		sets = append(sets, set)
	}

	return sets, nil
}

func splitValueAndUnit(part string) (string, string, error) {
	part = strings.TrimSpace(part)
	if part == "" {
		return "", "", nil
	}

	lastSpace := strings.LastIndex(part, " ")
	if lastSpace == -1 {
		if _, err := strconv.ParseFloat(part, 64); err == nil {
			return "", "", fmt.Errorf("missing unit")
		}
		return "", part, nil
	}

	values := strings.TrimSpace(part[:lastSpace])
	unit := strings.TrimSpace(part[lastSpace+1:])
	return values, unit, nil
}

func cutExerciseData(raw string) (string, string, bool) {
	if left, right, ok := strings.Cut(raw, " x "); ok {
		return left, right, true
	}

	if left, right, ok := strings.Cut(raw, " x"); ok {
		return left, right, true
	}

	return "", "", false
}

func parseValueList(part string) []string {
	if strings.TrimSpace(part) == "" {
		return nil
	}

	pieces := strings.Split(part, ",")
	values := make([]string, 0, len(pieces))
	for _, piece := range pieces {
		trimmed := strings.TrimSpace(piece)
		if trimmed == "" {
			continue
		}
		values = append(values, trimmed)
	}

	return values
}

func parseOptionalNumber(raw string) (float64, bool, error) {
	raw = strings.TrimSpace(raw)
	if raw == "" {
		return 0, false, nil
	}

	value, err := strconv.ParseFloat(raw, 64)
	if err == nil {
		return value, true, nil
	}

	// Real exports contain placeholders like "MAX" that still carry useful raw text.
	if isNonNumericPlaceholder(raw) {
		return 0, false, nil
	}

	return 0, false, err
}

func isNonNumericPlaceholder(raw string) bool {
	switch strings.ToUpper(strings.TrimSpace(raw)) {
	case "MAX":
		return true
	default:
		return false
	}
}

func valueAt(values []string, idx int) string {
	if idx >= len(values) {
		return ""
	}

	return values[idx]
}

func max(a, b int) int {
	if a > b {
		return a
	}
	return b
}
