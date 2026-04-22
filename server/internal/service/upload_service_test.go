package service

import (
	"os"
	"path/filepath"
	"testing"

	"github.com/moment-server/moment-server/pkg/config"
)

func TestUploadServiceResolveManagedFile(t *testing.T) {
	root := t.TempDir()
	service := NewUploadServiceWithConfig(&config.UploadConfig{LocalPath: root})

	tests := []struct {
		name        string
		raw         string
		wantPath    string
		wantFile    string
		wantManaged bool
	}{
		{
			name:        "relative public path",
			raw:         "/uploads/image/20260421/a.jpg",
			wantPath:    "/uploads/image/20260421/a.jpg",
			wantFile:    filepath.Join(root, "image", "20260421", "a.jpg"),
			wantManaged: true,
		},
		{
			name:        "absolute url with query",
			raw:         "https://example.com/uploads/video/20260421/a.mp4?token=1",
			wantPath:    "/uploads/video/20260421/a.mp4",
			wantFile:    filepath.Join(root, "video", "20260421", "a.mp4"),
			wantManaged: true,
		},
		{
			name:        "external path outside uploads",
			raw:         "https://example.com/assets/a.jpg",
			wantManaged: false,
		},
		{
			name:        "path traversal",
			raw:         "/uploads/../secret.txt",
			wantManaged: false,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			gotPath, gotFile, gotManaged := service.ResolveManagedFile(tc.raw)
			if gotManaged != tc.wantManaged {
				t.Fatalf("managed = %v, want %v", gotManaged, tc.wantManaged)
			}
			if gotPath != tc.wantPath {
				t.Fatalf("path = %q, want %q", gotPath, tc.wantPath)
			}
			if gotFile != tc.wantFile {
				t.Fatalf("file = %q, want %q", gotFile, tc.wantFile)
			}
		})
	}
}

func TestUploadServiceDeleteManagedFile(t *testing.T) {
	root := t.TempDir()
	target := filepath.Join(root, "image", "20260421", "a.jpg")
	if err := os.MkdirAll(filepath.Dir(target), 0o755); err != nil {
		t.Fatalf("mkdir failed: %v", err)
	}
	if err := os.WriteFile(target, []byte("data"), 0o644); err != nil {
		t.Fatalf("write failed: %v", err)
	}

	service := NewUploadServiceWithConfig(&config.UploadConfig{LocalPath: root})
	if err := service.DeleteManagedFile("/uploads/image/20260421/a.jpg"); err != nil {
		t.Fatalf("delete failed: %v", err)
	}

	if _, err := os.Stat(target); !os.IsNotExist(err) {
		t.Fatalf("expected file to be deleted, stat err = %v", err)
	}

	if err := service.DeleteManagedFile("https://example.com/assets/a.jpg"); err != nil {
		t.Fatalf("unexpected error for unmanaged path: %v", err)
	}
}
