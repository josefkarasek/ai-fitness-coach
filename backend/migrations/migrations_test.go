package migrations

import "testing"

func TestLoad(t *testing.T) {
	t.Parallel()

	migrations, err := load()
	if err != nil {
		t.Fatalf("load() returned error: %v", err)
	}

	if len(migrations) == 0 {
		t.Fatal("expected at least one embedded migration")
	}

	if migrations[0].version != "000001_initial_schema" {
		t.Fatalf("expected first migration version %q, got %q", "000001_initial_schema", migrations[0].version)
	}

	if migrations[0].sql == "" {
		t.Fatal("expected embedded SQL contents to be non-empty")
	}

	if len(migrations) < 2 {
		t.Fatal("expected versioned follow-up migrations after the initial schema")
	}

	if migrations[1].version != "000002_training_plan_jobs_and_push_tokens" {
		t.Fatalf(
			"expected second migration version %q, got %q",
			"000002_training_plan_jobs_and_push_tokens",
			migrations[1].version,
		)
	}
}
