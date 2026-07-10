# Architecture

## Overview

The system has three layers:

1. Mobile UI
2. Training Engine
3. AI Coach

The key architectural rule is that the Training Engine is not AI.

## Layer 1: Mobile UI

Responsibilities:

- Display plans, workouts, explanations, and summaries
- Capture workout logs quickly during training
- Cache data locally for offline use
- Sync with the Go service when available

The mobile app should stay thin. It is primarily a renderer and input
surface, not the place where coaching or training rules live.

Recommended client stack:

- Flutter
- Local SQLite cache
- REST client for Go service

Client-side storage should be split into three buckets:

- Device only: UI and device preferences such as theme, measurement
  system, onboarding completion, and the last signed-in user
- Device cache plus sync queue: Drift-backed local cache for user
  profile snapshots, generated training plans, workout logs, and
  pending offline writes that need to be replayed later
- Backend source of truth: the Go service remains authoritative for
  persisted athlete data, imported history, training blocks, and synced
  workout logs

## Layer 2: Training Engine

Responsibilities:

- Domain model for athlete, block, workout, exercise, and logs
- TrainHeroic import and normalization
- Persist performed workout logs separately from imported historical workouts
- Movement patterns and exercise catalog
- Progression models
- Volume calculations
- e1RM calculations
- Weekly summaries
- Statistics
- Import/export
- Prompt assembly for the AI Coach
- Persistence in SQLite
- REST API for the mobile app

The Training Engine is the deterministic core of the product. It owns
training logic that must be testable, repeatable, and explainable in
code.

This layer should be implemented in Go as a standalone library plus a
service wrapper.

## Layer 3: AI Coach

Responsibilities:

- Generate 12-week coaching books
- Generate training blocks from structured inputs
- Explain exercise choices and completed workouts
- Review completed blocks
- Suggest adjustments for the next block

The AI Coach should operate on structured inputs prepared by the
Training Engine and produce structured outputs that can be stored,
reviewed, and rendered later.

The mobile client should not expose an open-ended chat box that can
directly consume model tokens. Instead, the backend should own bounded
AI actions such as:

- Generate a new coaching book
- Explain a logged workout
- Review a completed block

## Boundaries

The AI Coach is responsible for coaching judgment.

The Training Engine is responsible for deterministic calculations.

The Mobile UI is responsible for presentation and input.

Business rules should not be embedded in Flutter widgets.
Prompt construction, model selection, token limits, and caching should
also stay in the backend.

## Offline-first

The product should remain usable when offline:

- Previously generated plans must remain available locally
- Workout logging must work without network access
- Local statistics and history browsing should still work
- AI generation can be deferred until connectivity is available

## Deployment Shape

For development and architecture, think in this order:

1. Go training engine as a library
2. Go REST API exposing engine capabilities
3. Flutter mobile client consuming the API

This keeps the core reusable for future desktop, web, CLI, or batch
tools.
