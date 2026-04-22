package migration

import (
	"bufio"
	"context"
	"database/sql"
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"sort"
	"strings"
	"time"
)

var migrationFilenamePattern = regexp.MustCompile(`^(\d+)_.*\.sql$`)

// File 表示单个迁移文件。
type File struct {
	Version string
	Name    string
	Path    string
}

// Summary 表示一次迁移执行结果。
type Summary struct {
	Applied []string
	Skipped []string
}

// DiscoverFiles 按版本号升序发现迁移文件。
func DiscoverFiles(dir string) ([]File, error) {
	entries, err := os.ReadDir(dir)
	if err != nil {
		return nil, fmt.Errorf("read migrations dir: %w", err)
	}

	files := make([]File, 0, len(entries))
	for _, entry := range entries {
		if entry.IsDir() {
			continue
		}
		name := entry.Name()
		match := migrationFilenamePattern.FindStringSubmatch(name)
		if match == nil {
			continue
		}
		files = append(files, File{
			Version: match[1],
			Name:    name,
			Path:    filepath.Join(dir, name),
		})
	}

	sort.Slice(files, func(i, j int) bool {
		if files[i].Version == files[j].Version {
			return files[i].Name < files[j].Name
		}
		return files[i].Version < files[j].Version
	})

	return files, nil
}

// EnsureDatabase 创建数据库（若不存在）。
func EnsureDatabase(ctx context.Context, db *sql.DB, databaseName string, charset string) error {
	if strings.TrimSpace(databaseName) == "" {
		return fmt.Errorf("database name is required")
	}
	if strings.TrimSpace(charset) == "" {
		charset = "utf8mb4"
	}

	stmt := fmt.Sprintf(
		"CREATE DATABASE IF NOT EXISTS `%s` DEFAULT CHARACTER SET %s COLLATE utf8mb4_unicode_ci",
		strings.ReplaceAll(databaseName, "`", "``"),
		charset,
	)
	if _, err := db.ExecContext(ctx, stmt); err != nil {
		return fmt.Errorf("create database: %w", err)
	}
	return nil
}

// EnsureSchemaMigrationsTable 创建迁移记录表（若不存在）。
func EnsureSchemaMigrationsTable(ctx context.Context, db *sql.DB) error {
	const stmt = `
CREATE TABLE IF NOT EXISTS schema_migrations (
  version VARCHAR(32) NOT NULL PRIMARY KEY,
  name VARCHAR(255) NOT NULL,
  applied_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci`
	if _, err := db.ExecContext(ctx, stmt); err != nil {
		return fmt.Errorf("create schema_migrations: %w", err)
	}
	return nil
}

// AppliedVersions 查询已执行版本。
func AppliedVersions(ctx context.Context, db *sql.DB) (map[string]string, error) {
	rows, err := db.QueryContext(ctx, `SELECT version, name FROM schema_migrations`)
	if err != nil {
		return nil, fmt.Errorf("query schema_migrations: %w", err)
	}
	defer rows.Close()

	versions := make(map[string]string)
	for rows.Next() {
		var version string
		var name string
		if err := rows.Scan(&version, &name); err != nil {
			return nil, fmt.Errorf("scan schema_migrations: %w", err)
		}
		versions[version] = name
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("iterate schema_migrations: %w", err)
	}
	return versions, nil
}

// ApplyPending 执行所有未执行的迁移。
func ApplyPending(ctx context.Context, db *sql.DB, files []File) (*Summary, error) {
	appliedVersions, err := AppliedVersions(ctx, db)
	if err != nil {
		return nil, err
	}

	summary := &Summary{
		Applied: make([]string, 0),
		Skipped: make([]string, 0),
	}
	for _, file := range files {
		if _, ok := appliedVersions[file.Version]; ok {
			summary.Skipped = append(summary.Skipped, file.Name)
			continue
		}
		if err := ApplyFile(ctx, db, file); err != nil {
			return summary, err
		}
		summary.Applied = append(summary.Applied, file.Name)
	}
	return summary, nil
}

// ApplyFile 执行单个迁移文件，并记录版本。
func ApplyFile(ctx context.Context, db *sql.DB, file File) error {
	content, err := os.ReadFile(file.Path)
	if err != nil {
		return fmt.Errorf("read migration %s: %w", file.Name, err)
	}

	statements := SplitStatements(string(content))
	for _, stmt := range statements {
		if _, err := db.ExecContext(ctx, stmt); err != nil {
			return fmt.Errorf("execute %s: %w", file.Name, err)
		}
	}

	if _, err := db.ExecContext(
		ctx,
		`INSERT INTO schema_migrations (version, name, applied_at) VALUES (?, ?, ?)`,
		file.Version,
		file.Name,
		time.Now(),
	); err != nil {
		return fmt.Errorf("record %s: %w", file.Name, err)
	}
	return nil
}

// SplitStatements 将 SQL 文件拆成可顺序执行的语句。
func SplitStatements(sqlText string) []string {
	var statements []string
	var current strings.Builder
	var inSingleQuote bool
	var inDoubleQuote bool
	var inBacktick bool
	var escapeNext bool

	scanner := bufio.NewScanner(strings.NewReader(sqlText))
	for scanner.Scan() {
		line := scanner.Text()
		trimmed := strings.TrimSpace(line)
		if !inSingleQuote && !inDoubleQuote && !inBacktick {
			if trimmed == "" || strings.HasPrefix(trimmed, "--") || strings.HasPrefix(trimmed, "#") {
				continue
			}
		}

		for _, r := range line {
			switch {
			case escapeNext:
				escapeNext = false
			case r == '\\' && (inSingleQuote || inDoubleQuote):
				escapeNext = true
			case r == '\'' && !inDoubleQuote && !inBacktick:
				inSingleQuote = !inSingleQuote
			case r == '"' && !inSingleQuote && !inBacktick:
				inDoubleQuote = !inDoubleQuote
			case r == '`' && !inSingleQuote && !inDoubleQuote:
				inBacktick = !inBacktick
			case r == ';' && !inSingleQuote && !inDoubleQuote && !inBacktick:
				statement := strings.TrimSpace(current.String())
				if statement != "" {
					statements = append(statements, statement)
				}
				current.Reset()
				continue
			}
			current.WriteRune(r)
		}
		current.WriteByte('\n')
	}

	last := strings.TrimSpace(current.String())
	if last != "" {
		statements = append(statements, last)
	}
	return statements
}
