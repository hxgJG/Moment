package migration

import (
	"path/filepath"
	"testing"
)

func TestSplitStatements(t *testing.T) {
	sqlText := `
-- comment
CREATE TABLE foo (
  id INT PRIMARY KEY,
  name VARCHAR(20) NOT NULL DEFAULT 'a;b'
);

# comment
INSERT INTO foo (id, name) VALUES (1, "x;y");
USE moment;
`

	got := SplitStatements(sqlText)
	if len(got) != 3 {
		t.Fatalf("len = %d, want 3; got=%v", len(got), got)
	}
	if got[0][:16] != "CREATE TABLE foo" {
		t.Fatalf("unexpected first statement: %q", got[0])
	}
	if got[1] != `INSERT INTO foo (id, name) VALUES (1, "x;y")` {
		t.Fatalf("unexpected second statement: %q", got[1])
	}
	if got[2] != "USE moment" {
		t.Fatalf("unexpected third statement: %q", got[2])
	}
}

func TestDiscoverFilesOrdersByVersion(t *testing.T) {
	dir := t.TempDir()
	paths := []string{
		filepath.Join(dir, "010_last.sql"),
		filepath.Join(dir, "002_second.sql"),
		filepath.Join(dir, "001_init.sql"),
		filepath.Join(dir, "README.md"),
	}
	for _, path := range paths {
		if err := osWriteFile(path, []byte("SELECT 1;")); err != nil {
			t.Fatalf("write %s: %v", path, err)
		}
	}

	files, err := DiscoverFiles(dir)
	if err != nil {
		t.Fatalf("DiscoverFiles failed: %v", err)
	}
	if len(files) != 3 {
		t.Fatalf("len = %d, want 3", len(files))
	}
	if files[0].Name != "001_init.sql" || files[1].Name != "002_second.sql" || files[2].Name != "010_last.sql" {
		t.Fatalf("unexpected order: %#v", files)
	}
}

func osWriteFile(path string, data []byte) error {
	return os.WriteFile(path, data, 0o644)
}
