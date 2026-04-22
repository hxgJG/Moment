package main

import (
	"context"
	"database/sql"
	"fmt"
	"os"
	"path/filepath"
	"time"

	_ "github.com/go-sql-driver/mysql"
	"github.com/moment-server/moment-server/internal/migration"
	"github.com/moment-server/moment-server/pkg/config"
)

func main() {
	cfg, err := config.Load("configs/config.yaml")
	if err != nil {
		fmt.Fprintf(os.Stderr, "load config failed: %v\n", err)
		os.Exit(1)
	}

	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Minute)
	defer cancel()

	adminDB, err := sql.Open("mysql", cfg.Database.DSNWithoutDatabase())
	if err != nil {
		fmt.Fprintf(os.Stderr, "open admin db failed: %v\n", err)
		os.Exit(1)
	}
	defer adminDB.Close()

	if err := migration.EnsureDatabase(ctx, adminDB, cfg.Database.Database, cfg.Database.Charset); err != nil {
		fmt.Fprintf(os.Stderr, "ensure database failed: %v\n", err)
		os.Exit(1)
	}

	targetDB, err := sql.Open("mysql", cfg.Database.DSN())
	if err != nil {
		fmt.Fprintf(os.Stderr, "open target db failed: %v\n", err)
		os.Exit(1)
	}
	defer targetDB.Close()

	if err := migration.EnsureSchemaMigrationsTable(ctx, targetDB); err != nil {
		fmt.Fprintf(os.Stderr, "ensure schema_migrations failed: %v\n", err)
		os.Exit(1)
	}

	migrationsDir := filepath.Join("migrations")
	files, err := migration.DiscoverFiles(migrationsDir)
	if err != nil {
		fmt.Fprintf(os.Stderr, "discover migrations failed: %v\n", err)
		os.Exit(1)
	}

	summary, err := migration.ApplyPending(ctx, targetDB, files)
	if err != nil {
		fmt.Fprintf(os.Stderr, "apply migrations failed: %v\n", err)
		os.Exit(1)
	}

	fmt.Printf("Applied %d migration(s)\n", len(summary.Applied))
	for _, name := range summary.Applied {
		fmt.Printf("  + %s\n", name)
	}
	fmt.Printf("Skipped %d migration(s)\n", len(summary.Skipped))
	for _, name := range summary.Skipped {
		fmt.Printf("  = %s\n", name)
	}
}
