create extension if not exists pgcrypto;

create table if not exists schema_migrations (
    version text primary key,
    applied_at timestamptz not null default now()
);

create table if not exists users (
    id uuid primary key default gen_random_uuid(),
    firebase_uid text not null unique,
    email text,
    display_name text,
    training_experience text,
    primary_goal text,
    preferred_days text[],
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

create table if not exists athletes (
    id uuid primary key default gen_random_uuid(),
    owner_user_id uuid references users (id) on delete set null,
    name text not null,
    source text,
    source_athlete_id text,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

create unique index if not exists athletes_owner_user_id_idx
    on athletes (owner_user_id)
    where owner_user_id is not null;

create unique index if not exists athletes_name_idx
    on athletes (name);

create unique index if not exists athletes_source_source_athlete_id_idx
    on athletes (source, source_athlete_id);

create table if not exists exercise_catalog (
    id bigserial primary key,
    title text not null unique,
    created_at timestamptz not null default now()
);

create table if not exists workouts (
    id bigserial primary key,
    athlete_id uuid not null references athletes (id) on delete cascade,
    source text not null,
    source_workout_title text not null,
    scheduled_date date not null,
    rescheduled_date date,
    workout_notes text,
    block_value numeric(10, 2),
    block_units text,
    block_instructions text,
    block_notes text,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    unique (athlete_id, source, source_workout_title, scheduled_date)
);

create index if not exists workouts_athlete_id_scheduled_date_idx
    on workouts (athlete_id, scheduled_date desc);

create table if not exists workout_exercises (
    id bigserial primary key,
    workout_id bigint not null references workouts (id) on delete cascade,
    exercise_id bigint not null references exercise_catalog (id),
    sequence_number integer not null,
    notes text,
    raw_exercise_data text,
    created_at timestamptz not null default now(),
    unique (workout_id, sequence_number)
);

create index if not exists workout_exercises_workout_id_idx
    on workout_exercises (workout_id);

create table if not exists workout_sets (
    id bigserial primary key,
    workout_exercise_id bigint not null references workout_exercises (id) on delete cascade,
    sequence_number integer not null,
    measurement_unit text,
    reps numeric(10, 2),
    distance_meters numeric(10, 2),
    load_value numeric(10, 2),
    load_unit text,
    raw_primary_value text,
    raw_load_value text,
    created_at timestamptz not null default now(),
    unique (workout_exercise_id, sequence_number)
);

create index if not exists workout_sets_workout_exercise_id_idx
    on workout_sets (workout_exercise_id);

create table if not exists imported_archives (
    id bigserial primary key,
    user_id uuid not null references users (id) on delete cascade,
    import_type text not null,
    file_name text not null,
    created_at timestamptz not null default now(),
    unique (user_id, import_type, file_name)
);

create table if not exists workout_explanations (
    workout_id bigint primary key references workouts (id) on delete cascade,
    user_id uuid not null references users (id) on delete cascade,
    provider text not null,
    model text not null,
    prompt_version text not null,
    explanation text not null,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

create index if not exists workout_explanations_user_id_created_at_idx
    on workout_explanations (user_id, created_at desc);

create table if not exists training_plans (
    id bigserial primary key,
    user_id uuid not null references users (id) on delete cascade,
    objective text not null,
    duration_weeks integer not null,
    days_per_week integer not null,
    measurement_system text not null default 'Metric',
    constraints text,
    equipment text,
    notes text,
    provider text not null,
    model text not null,
    prompt_version text not null,
    summary text not null,
    philosophy text not null,
    progression_strategy text not null,
    risks text not null,
    success_criteria text not null,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

alter table if exists training_plans
    add column if not exists measurement_system text not null default 'Metric';

create index if not exists training_plans_user_id_created_at_idx
    on training_plans (user_id, created_at desc);

create table if not exists training_plan_weeks (
    id bigserial primary key,
    training_plan_id bigint not null references training_plans (id) on delete cascade,
    week_number integer not null,
    theme text not null,
    created_at timestamptz not null default now(),
    unique (training_plan_id, week_number)
);

create table if not exists training_plan_workouts (
    id bigserial primary key,
    training_plan_id bigint not null references training_plans (id) on delete cascade,
    week_number integer not null,
    day_number integer not null,
    title text not null,
    focus text,
    exercises_text text,
    exercises_json jsonb,
    created_at timestamptz not null default now(),
    unique (training_plan_id, week_number, day_number)
);

create table if not exists workout_logs (
    id bigserial primary key,
    user_id uuid not null references users (id) on delete cascade,
    training_plan_id bigint not null references training_plans (id) on delete cascade,
    week_number integer not null,
    day_number integer not null,
    title text not null,
    focus text,
    session_notes text,
    duration_minutes integer,
    performed_at timestamptz not null default now(),
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    unique (user_id, training_plan_id, week_number, day_number)
);

create index if not exists workout_logs_user_id_training_plan_id_idx
    on workout_logs (user_id, training_plan_id, performed_at desc);

create table if not exists workout_log_exercises (
    id bigserial primary key,
    workout_log_id bigint not null references workout_logs (id) on delete cascade,
    sequence_number integer not null,
    title text not null,
    notes text,
    created_at timestamptz not null default now(),
    unique (workout_log_id, sequence_number)
);

create index if not exists workout_log_exercises_workout_log_id_idx
    on workout_log_exercises (workout_log_id);

create table if not exists workout_log_sets (
    id bigserial primary key,
    workout_log_exercise_id bigint not null references workout_log_exercises (id) on delete cascade,
    sequence_number integer not null,
    reps numeric(10, 2),
    value numeric(10, 2),
    unit text,
    load_value numeric(10, 2),
    load_unit text,
    rpe numeric(4, 2),
    completed boolean not null default true,
    created_at timestamptz not null default now(),
    unique (workout_log_exercise_id, sequence_number)
);

create index if not exists workout_log_sets_workout_log_exercise_id_idx
    on workout_log_sets (workout_log_exercise_id);

create table if not exists workout_log_reviews (
    workout_log_id bigint primary key references workout_logs (id) on delete cascade,
    user_id uuid not null references users (id) on delete cascade,
    provider text not null,
    model text not null,
    prompt_version text not null,
    review text not null,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

create index if not exists workout_log_reviews_user_id_created_at_idx
    on workout_log_reviews (user_id, created_at desc);
