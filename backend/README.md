# Backend

Initial backend stack:

- Go
- Gin
- Raw SQL with PostgreSQL
- Raw Tiltfile for local orchestration

## Local Development

1. Copy the repository root [.env.example](/home/jkarasek/go/src/github.com/josefkarasek/ai-fitness-coach/.env.example) values into your shell or local env file if you want local overrides.
2. Start Tilt from the repository root:

```bash
tilt up
```

This raw `Tiltfile` will start:

- PostgreSQL on `localhost:5432`
- Backend API on `localhost:8080`

It does not use Docker Compose.

## Authentication

The backend now supports a protected-route auth mode backed by Firebase Auth.

Relevant environment variables:

- `AUTH_MODE=disabled|firebase`
- `FIREBASE_PROJECT_ID=<your-firebase-project-id>`
- `GOOGLE_APPLICATION_CREDENTIALS=/absolute/path/to/firebase-admin.json`

With the repository `Tiltfile`, auth now defaults to `firebase` when both
`FIREBASE_PROJECT_ID` and `GOOGLE_APPLICATION_CREDENTIALS` are already set
in your shell. Otherwise it falls back to `disabled`.

When `AUTH_MODE=firebase`, the backend verifies Firebase ID tokens in middleware, upserts a backend `users` row, and exposes the authenticated backend user to handlers through request context.

The first protected endpoint is:

- `GET /api/v1/me`
- `POST /api/v1/imports`
- `GET /api/v1/workouts`
- `POST /api/v1/workouts/:id/explanation`
- `POST /api/v1/training-plans`
- `GET /api/v1/training-plans/latest`

Send a Firebase ID token as:

```bash
Authorization: Bearer <firebase-id-token>
```

## Health Endpoints

- `GET /api/v1/health/live`
- `GET /api/v1/health/ready`

## Training History Import

The backend now includes a first-pass training history schema plus two import paths for exported workout history:

- CLI import from `training_data.csv`
- Authenticated API import from a TrainHeroic export zip

Current persisted entities:

- `users`
- `athletes`
- `exercise_catalog`
- `workouts`
- `workout_exercises`
- `workout_sets`
- `imported_archives`
- `workout_explanations`
- `training_plans`
- `training_plan_weeks`
- `training_plan_workouts`

For the authenticated API flow, send a multipart request to `POST /api/v1/imports` with:

- `import_type=trainheroic_csv`
- `file=<trainheroic-export.zip>`

The backend will extract `training_data.csv` from the zip archive, parse the workouts, and store them under the logged-in user's athlete profile.

To import the sample workout history:

```bash
make import-training-data
```

You can also point the importer at another file:

```bash
go run ./cmd/import-training-data -csv /path/to/training_data.csv -athlete-name "Josef Karasek"
```

Note: while the schema is still evolving, local development uses `migrations/000001_initial_schema.sql` as the single source of truth.

## Workout Explanations

The first backend-controlled AI action is workout explanation generation.

The important boundary is:

- The Flutter client does not send arbitrary prompts.
- The backend decides when AI is called.
- Generated explanations are persisted and reused.
- A simple per-user daily limit protects against accidental token abuse.

Current environment variables:

- `AI_PROVIDER=mock|disabled`
- `AI_MODEL=<provider-specific-model-name>`
- `AI_DAILY_WORKOUT_EXPLANATIONS_LIMIT=<integer>`

For local development, `AI_PROVIDER=mock` uses an in-process explainer so the API flow can be built before wiring a real model vendor.

To generate or fetch an explanation for a workout:

```bash
curl -X POST \
  http://localhost:8080/api/v1/workouts/<workout-id>/explanation \
  -H "Authorization: Bearer <firebase-id-token>"
```

If an explanation already exists, the backend returns the cached record instead of regenerating it. This keeps the first version conservative about token usage.

## Training Plans

The next backend-controlled AI action is training-plan generation.

The current mocked flow:

- accepts a bounded JSON request for plan intent and constraints
- summarizes imported history from the database
- generates a mocked plan in the backend
- persists the plan and planned workouts
- lets the client reload the latest stored plan later

Relevant environment variables:

- `AI_DAILY_TRAINING_PLANS_LIMIT=<integer>`

For local development, keep this above `1` unless you explicitly want to
exercise the limit path. The default `.env.example` uses `3`.

Generate a plan:

```bash
curl -X POST \
  http://localhost:8080/api/v1/training-plans \
  -H "Authorization: Bearer <firebase-id-token>" \
  -H "Content-Type: application/json" \
  -d '{
    "objective": "Build a 12-week strength block",
    "duration_weeks": 12,
    "days_per_week": 4,
    "constraints": "Protect low back fatigue",
    "equipment": "Barbell, dumbbells, sled",
    "notes": "Bias squat and deadlift progress"
  }'
```

Load the latest stored plan:

```bash
curl \
  http://localhost:8080/api/v1/training-plans/latest \
  -H "Authorization: Bearer <firebase-id-token>"
```

## Next Backend Tasks

- Add a real model provider behind the AI interface
- Add statistics endpoints for prompt assembly
- Add richer coaching book and block APIs
- Add a proper migration runner
