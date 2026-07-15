create table if not exists training_plan_generation_jobs (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references users (id) on delete cascade,
    request_json jsonb not null,
    status text not null,
    training_plan_id bigint references training_plans (id) on delete set null,
    error_message text,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    started_at timestamptz,
    completed_at timestamptz
);

create unique index if not exists training_plan_generation_jobs_active_user_idx
    on training_plan_generation_jobs (user_id)
    where status in ('queued', 'running');

create index if not exists training_plan_generation_jobs_user_id_created_at_idx
    on training_plan_generation_jobs (user_id, created_at desc);

create table if not exists user_push_tokens (
    token text primary key,
    user_id uuid not null references users (id) on delete cascade,
    platform text not null,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    last_seen_at timestamptz not null default now()
);

create index if not exists user_push_tokens_user_id_idx
    on user_push_tokens (user_id, updated_at desc);
