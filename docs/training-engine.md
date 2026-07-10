# Training Engine Design

## Purpose

The Training Engine is the deterministic core of the application.

It should be usable as:

- A Go library
- A REST service

This lets the product keep business logic in one place while allowing
multiple clients.

## Main Responsibilities

- Import historical training data
- Normalize training history into an internal model
- Store athlete, plan, and workout data in SQLite
- Compute training statistics
- Build structured inputs for AI workflows
- Validate and persist AI outputs

## Initial Modules

## Import

Responsibilities:

- Parse TrainHeroic exports
- Map raw exercise names to normalized movement patterns
- Convert historical sessions into internal workouts and workout logs
- Capture unknown or ambiguous mappings for review

Outputs:

- Athlete training history
- Exercise reference data
- Historical workout logs

## Persistence

Responsibilities:

- SQLite schema management
- Repositories for domain entities
- Versioning of generated blocks and coaching books
- Audit trail for imports and AI-generated artifacts

Key requirement:

- Generated plans and explanations must be storable as durable records,
  not transient AI responses

## Statistics

Responsibilities:

- Volume by week, block, movement pattern, and exercise
- Estimated 1RM calculations
- Adherence summaries
- Personal records
- Trend summaries for prompt generation

This module should be completely deterministic and heavily tested.

## Programming Models

Responsibilities:

- Movement pattern taxonomy
- Exercise selection constraints
- Progression models
- Weekly structure templates
- Deload logic

This is where training rules live in code.

## AI Prompt Generation

Responsibilities:

- Convert athlete history and current goals into structured AI inputs
- Summarize training history compactly
- Provide allowed movement patterns, constraints, and progression guardrails
- Request structured outputs for coaching books and block reviews
- Trigger only bounded backend-owned AI actions
- Cache generated outputs so repeat views do not re-spend tokens

The engine should shape the AI task rather than asking the AI to infer
everything from raw logs.

## API Layer

Responsibilities:

- Expose engine capabilities via REST
- Validate requests and responses
- Keep handlers thin
- Return structured data ready for Flutter rendering

Example API areas:

- Import
- Athlete profile
- Training blocks
- Coaching books
- Workouts
- Workout logs
- Statistics
- AI actions such as `POST /workouts/:id/explanation`

## Suggested Package Shape

An initial Go package layout could look like:

- `internal/domain`
- `internal/importer/trainheroic`
- `internal/persistence/sqlite`
- `internal/statistics`
- `internal/progression`
- `internal/prompting`
- `internal/ai`
- `internal/api`

If you want the engine reusable outside the service, the deterministic
core can later move into `pkg/engine` or a similar public package.

## SQLite Scope

Initial storage should cover:

- Athlete profile
- Goals and constraints
- Exercise catalog
- Movement pattern catalog
- Training history
- Training blocks
- Coaching books
- Workouts
- Workout logs
- Import jobs
- AI generation jobs
- AI-generated workout explanations

## Design Rules

- Deterministic calculations stay in Go code
- AI outputs must be persisted, not recomputed on every view
- Engine APIs should use explicit typed models
- The importer should preserve raw source data where useful for audits
- Flutter should not reimplement training logic

## MVP Deliverables

The first implementation pass should include:

1. TrainHeroic importer
2. SQLite schema
3. Core statistics
4. Prompt generation inputs for block creation
5. REST endpoints needed by a thin Flutter app
