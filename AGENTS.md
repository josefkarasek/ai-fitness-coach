# AGENTS.md

## Project

AI Fitness Coach

## Mission

Build an AI coaching application, not a workout tracker.

The AI generates long-term coaching books (typically 12 weeks), explains
every coaching decision, and learns from the athlete's history.

## Core Principles

-   AI is a coach, not a calculator.
-   Deterministic calculations stay in code.
-   Offline-first.
-   Training blocks are generated infrequently.
-   Every important decision should be explainable.

## Domain

Main entities: - Athlete - TrainingHistory - TrainingBlock -
CoachingBook - Workout - Exercise - WorkoutLog

When implementing features, preserve this architecture and avoid
embedding business rules directly in UI code.
