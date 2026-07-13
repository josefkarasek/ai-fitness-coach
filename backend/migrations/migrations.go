package migrations

import (
	"context"
	"embed"
	"fmt"
	"io/fs"
	"path/filepath"
	"sort"
	"strings"

	"github.com/jackc/pgx/v5/pgxpool"
)

//go:embed *.sql
var migrationFiles embed.FS

const advisoryLockKey int64 = 4_263_019_001

type migration struct {
	version string
	sql     string
}

func Apply(ctx context.Context, db *pgxpool.Pool) error {
	migrations, err := load()
	if err != nil {
		return err
	}

	tx, err := db.Begin(ctx)
	if err != nil {
		return fmt.Errorf("begin migration transaction: %w", err)
	}
	defer tx.Rollback(ctx)

	var locked bool
	if err := tx.QueryRow(ctx, "select pg_try_advisory_xact_lock($1)", advisoryLockKey).Scan(&locked); err != nil {
		return fmt.Errorf("acquire migration advisory lock: %w", err)
	}
	if !locked {
		return fmt.Errorf("acquire migration advisory lock: lock unavailable")
	}

	if _, err := tx.Exec(ctx, `
		create table if not exists schema_migrations (
			version text primary key,
			applied_at timestamptz not null default now()
		)
	`); err != nil {
		return fmt.Errorf("ensure schema_migrations table: %w", err)
	}

	for _, migration := range migrations {
		var applied bool
		if err := tx.QueryRow(ctx, `
			select exists (
				select 1
				from schema_migrations
				where version = $1
			)
		`, migration.version).Scan(&applied); err != nil {
			return fmt.Errorf("check migration %s: %w", migration.version, err)
		}

		if applied {
			continue
		}

		if _, err := tx.Exec(ctx, migration.sql); err != nil {
			return fmt.Errorf("apply migration %s: %w", migration.version, err)
		}

		if _, err := tx.Exec(ctx, `
			insert into schema_migrations (version)
			values ($1)
		`, migration.version); err != nil {
			return fmt.Errorf("record migration %s: %w", migration.version, err)
		}
	}

	if err := tx.Commit(ctx); err != nil {
		return fmt.Errorf("commit migrations: %w", err)
	}

	return nil
}

func load() ([]migration, error) {
	entries, err := fs.Glob(migrationFiles, "*.sql")
	if err != nil {
		return nil, fmt.Errorf("glob migration files: %w", err)
	}

	sort.Strings(entries)

	migrations := make([]migration, 0, len(entries))
	for _, entry := range entries {
		contents, err := migrationFiles.ReadFile(entry)
		if err != nil {
			return nil, fmt.Errorf("read migration %s: %w", entry, err)
		}

		migrations = append(migrations, migration{
			version: strings.TrimSuffix(filepath.Base(entry), filepath.Ext(entry)),
			sql:     string(contents),
		})
	}

	return migrations, nil
}
