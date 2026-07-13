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
}
