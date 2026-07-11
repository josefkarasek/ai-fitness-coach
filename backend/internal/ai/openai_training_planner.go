package ai

import (
	"context"
	"encoding/json"
)

const (
	openAITrainingPlanPromptVersion = "training-plan-openai-v1"
	openAITrainingDayPromptVersion  = "training-day-openai-v1"
)

type OpenAITrainingPlanner struct {
	client *OpenAIClient
	model  string
}

func NewOpenAITrainingPlanner(client *OpenAIClient) *OpenAITrainingPlanner {
	return &OpenAITrainingPlanner{
		client: client,
		model:  client.model,
	}
}

func (p *OpenAITrainingPlanner) GenerateTrainingPlan(ctx context.Context, history TrainingHistorySummary, request TrainingPlanRequest) (GeneratedTrainingPlan, error) {
	var generated openAITrainingPlanResponse
	if err := p.client.GenerateJSON(ctx, openAITrainingPlanSystemPrompt, map[string]any{
		"history": history,
		"request": request,
	}, &generated); err != nil {
		return GeneratedTrainingPlan{}, err
	}

	result := generated.toGeneratedTrainingPlan()
	result.Provider = "openai"
	result.Model = p.model
	result.PromptVersion = openAITrainingPlanPromptVersion

	return result, nil
}

func (p *OpenAITrainingPlanner) GenerateWorkoutForDay(ctx context.Context, history TrainingHistorySummary, request TrainingDayRequest) (GeneratedPlannedWorkout, error) {
	var generated openAIWorkoutResponse
	if err := p.client.GenerateJSON(ctx, openAITrainingDaySystemPrompt, map[string]any{
		"history": history,
		"request": request,
	}, &generated); err != nil {
		return GeneratedPlannedWorkout{}, err
	}

	return generated.toGeneratedPlannedWorkout(), nil
}

const openAITrainingPlanSystemPrompt = `You are an experienced strength coach writing structured training plans for a mobile coaching app backend.

Return exactly one JSON object with this shape:
{
  "summary": string,
  "philosophy": string,
  "progression_strategy": string,
  "risks": string,
  "success_criteria": string,
  "weeks": [
    {
      "week_number": number,
      "theme": string,
      "workouts": [
        {
          "day_number": number,
          "title": string,
          "focus": string,
          "exercises": [
            {
              "title": string,
              "notes": string,
              "sets": [
                {
                  "reps": number|null,
                  "target_value": number|null,
                  "target_unit": string,
                  "load_value": number|null,
                  "load_unit": string
                }
              ]
            }
          ]
        }
      ]
    }
  ]
}

Rules:
- Use the user's measurement system natively. Metric plans should use practical kg increments. Imperial plans should use practical lb increments.
- Reps should be whole numbers represented as JSON numbers, not strings.
- For time, distance, bands, carries, planks, and non-weight prescriptions, use target_value + target_unit.
- Only use load_value + load_unit for external load that the athlete may actually load.
- Carries should usually be distance-based, for example 3 sets of 30 meters, optionally with load_value/load_unit.
- Keep the plan coherent across weeks and days.
- Keep exercise names conventional and easy to recognize in a gym.
- Do not include markdown, commentary, or extra keys.`

const openAITrainingDaySystemPrompt = `You are an experienced strength coach generating one additional workout day inside an existing training plan.

Return exactly one JSON object with this shape:
{
  "day_number": number,
  "title": string,
  "focus": string,
  "exercises": [
    {
      "title": string,
      "notes": string,
      "sets": [
        {
          "reps": number|null,
          "target_value": number|null,
          "target_unit": string,
          "load_value": number|null,
          "load_unit": string
        }
      ]
    }
  ]
}

Rules:
- Match the existing week theme and the rest of that week's already scheduled workouts.
- Respect the user's measurement system.
- Reps should be whole numbers represented as JSON numbers.
- Use target_value/target_unit for distance, time, bands, or unitless prescriptions.
- Use load_value/load_unit only for external load.
- Avoid duplicating the exact same day already present in the week.
- Do not include markdown, commentary, or extra keys.`

type openAITrainingPlanResponse struct {
	Summary             string                   `json:"summary"`
	Philosophy          string                   `json:"philosophy"`
	ProgressionStrategy string                   `json:"progression_strategy"`
	Risks               string                   `json:"risks"`
	SuccessCriteria     string                   `json:"success_criteria"`
	Weeks               []openAITrainingPlanWeek `json:"weeks"`
}

type openAITrainingPlanWeek struct {
	WeekNumber int                     `json:"week_number"`
	Theme      string                  `json:"theme"`
	Workouts   []openAIWorkoutResponse `json:"workouts"`
}

type openAIWorkoutResponse struct {
	DayNumber int                    `json:"day_number"`
	Title     string                 `json:"title"`
	Focus     string                 `json:"focus"`
	Exercises []openAIExerciseOutput `json:"exercises"`
}

type openAIExerciseOutput struct {
	Title string            `json:"title"`
	Notes string            `json:"notes"`
	Sets  []openAISetOutput `json:"sets"`
}

type openAISetOutput struct {
	Reps        *float64 `json:"reps"`
	TargetValue *float64 `json:"target_value"`
	TargetUnit  string   `json:"target_unit"`
	LoadValue   *float64 `json:"load_value"`
	LoadUnit    string   `json:"load_unit"`
}

func (r openAITrainingPlanResponse) toGeneratedTrainingPlan() GeneratedTrainingPlan {
	weeks := make([]GeneratedTrainingPlanWeek, 0, len(r.Weeks))
	for _, week := range r.Weeks {
		workouts := make([]GeneratedPlannedWorkout, 0, len(week.Workouts))
		for _, workout := range week.Workouts {
			workouts = append(workouts, workout.toGeneratedPlannedWorkout())
		}

		weeks = append(weeks, GeneratedTrainingPlanWeek{
			WeekNumber: week.WeekNumber,
			Theme:      week.Theme,
			Workouts:   workouts,
		})
	}

	return GeneratedTrainingPlan{
		Summary:             r.Summary,
		Philosophy:          r.Philosophy,
		ProgressionStrategy: r.ProgressionStrategy,
		Risks:               r.Risks,
		SuccessCriteria:     r.SuccessCriteria,
		Weeks:               weeks,
	}
}

func (r openAIWorkoutResponse) toGeneratedPlannedWorkout() GeneratedPlannedWorkout {
	exercises := make([]GeneratedPlannedExercise, 0, len(r.Exercises))
	for _, exercise := range r.Exercises {
		sets := make([]GeneratedPlannedSet, 0, len(exercise.Sets))
		for _, set := range exercise.Sets {
			sets = append(sets, GeneratedPlannedSet{
				Reps:        sanitizeWholeNumber(set.Reps),
				TargetValue: set.TargetValue,
				TargetUnit:  set.TargetUnit,
				LoadValue:   set.LoadValue,
				LoadUnit:    set.LoadUnit,
			})
		}

		exercises = append(exercises, GeneratedPlannedExercise{
			Title: exercise.Title,
			Notes: exercise.Notes,
			Sets:  sets,
		})
	}

	return GeneratedPlannedWorkout{
		DayNumber: r.DayNumber,
		Title:     r.Title,
		Focus:     r.Focus,
		Exercises: exercises,
	}
}

func sanitizeWholeNumber(value *float64) *float64 {
	if value == nil {
		return nil
	}

	rounded := float64(int(*value + 0.5))
	if *value < 0 {
		rounded = float64(int(*value - 0.5))
	}

	return &rounded
}

func (r openAITrainingPlanResponse) String() string {
	raw, _ := json.Marshal(r)
	return string(raw)
}
