package service

import (
	"errors"
	"os"
	"path/filepath"
	"testing"

	"github.com/moment-server/moment-server/internal/model"
	"github.com/moment-server/moment-server/internal/repository"
	"github.com/moment-server/moment-server/pkg/config"
	"gorm.io/gorm"
)

type momentRepositoryStub struct {
	createFn                      func(moment *model.Moment) error
	findByUserIDAndClientIDFn     func(userID uint64, clientID string) (*model.Moment, error)
	findByIDFn                    func(id uint64) (*model.Moment, error)
	updateFn                      func(moment *model.Moment) error
	deleteFn                      func(id, userID uint64) error
	countOtherReferencesByMediaFn func(managedPath string, excludeMomentID uint64) (int64, error)
}

func (s momentRepositoryStub) FindAll(filter repository.MomentFilter, page, pageSize int) ([]*model.Moment, int64, error) {
	return nil, 0, nil
}

func (s momentRepositoryStub) FindForAdmin(filter repository.AdminMomentFilter, page, pageSize int) ([]*model.Moment, int64, error) {
	return nil, 0, nil
}

func (s momentRepositoryStub) Create(moment *model.Moment) error {
	if s.createFn != nil {
		return s.createFn(moment)
	}
	return nil
}

func (s momentRepositoryStub) FindByUserIDAndClientID(userID uint64, clientID string) (*model.Moment, error) {
	if s.findByUserIDAndClientIDFn != nil {
		return s.findByUserIDAndClientIDFn(userID, clientID)
	}
	return nil, gorm.ErrRecordNotFound
}

func (s momentRepositoryStub) FindByID(id uint64) (*model.Moment, error) {
	return s.findByIDFn(id)
}

func (s momentRepositoryStub) Update(moment *model.Moment) error {
	if s.updateFn != nil {
		return s.updateFn(moment)
	}
	return nil
}

func (s momentRepositoryStub) Delete(id, userID uint64) error {
	if s.deleteFn != nil {
		return s.deleteFn(id, userID)
	}
	return nil
}

func (s momentRepositoryStub) CountOtherReferencesByMediaPath(managedPath string, excludeMomentID uint64) (int64, error) {
	if s.countOtherReferencesByMediaFn != nil {
		return s.countOtherReferencesByMediaFn(managedPath, excludeMomentID)
	}
	return 0, nil
}

func TestMomentServiceCreateMomentReturnsExistingRecordForDuplicateClientID(t *testing.T) {
	var createCalls int
	service := newMomentServiceWithDeps(
		momentRepositoryStub{
			findByUserIDAndClientIDFn: func(userID uint64, clientID string) (*model.Moment, error) {
				if userID != 42 {
					t.Fatalf("userID = %d, want 42", userID)
				}
				if clientID != "local-uuid-1" {
					t.Fatalf("clientID = %q, want local-uuid-1", clientID)
				}
				return &model.Moment{
					ID:         1001,
					UserID:     42,
					Content:    "existing",
					MediaType:  model.MediaTypeMixed,
					MediaPaths: []string{"https://cdn.example.com/a.jpg"},
				}, nil
			},
			createFn: func(moment *model.Moment) error {
				createCalls++
				return nil
			},
		},
		nil,
	)

	resp, err := service.CreateMoment(42, &CreateMomentRequest{
		ClientID:  " local-uuid-1 ",
		Content:   "should-not-create",
		MediaType: model.MediaTypeText,
	})
	if err != nil {
		t.Fatalf("CreateMoment failed: %v", err)
	}
	if resp.ID != 1001 {
		t.Fatalf("id = %d, want 1001", resp.ID)
	}
	if resp.Content != "existing" {
		t.Fatalf("content = %q, want existing", resp.Content)
	}
	if createCalls != 0 {
		t.Fatalf("createCalls = %d, want 0", createCalls)
	}
}

func TestMomentServiceCreateMomentStoresClientIDForNewRecord(t *testing.T) {
	var created *model.Moment
	service := newMomentServiceWithDeps(
		momentRepositoryStub{
			findByUserIDAndClientIDFn: func(userID uint64, clientID string) (*model.Moment, error) {
				return nil, gorm.ErrRecordNotFound
			},
			createFn: func(moment *model.Moment) error {
				created = &model.Moment{
					ID:         2002,
					UserID:     moment.UserID,
					ClientID:   moment.ClientID,
					Content:    moment.Content,
					MediaType:  moment.MediaType,
					MediaPaths: moment.MediaPaths,
				}
				moment.ID = 2002
				return nil
			},
		},
		nil,
	)

	resp, err := service.CreateMoment(7, &CreateMomentRequest{
		ClientID:  "local-uuid-2",
		Content:   "new moment",
		MediaType: model.MediaTypeImage,
		MediaPaths: []string{
			"https://cdn.example.com/image.jpg",
		},
	})
	if err != nil {
		t.Fatalf("CreateMoment failed: %v", err)
	}
	if created == nil {
		t.Fatal("expected create to be called")
	}
	if created.ClientID == nil || *created.ClientID != "local-uuid-2" {
		t.Fatalf("clientID = %v, want local-uuid-2", created.ClientID)
	}
	if resp.ID != 2002 {
		t.Fatalf("id = %d, want 2002", resp.ID)
	}
}

func TestMomentServiceCreateMomentReturnsLookupError(t *testing.T) {
	service := newMomentServiceWithDeps(
		momentRepositoryStub{
			findByUserIDAndClientIDFn: func(userID uint64, clientID string) (*model.Moment, error) {
				return nil, errors.New("db lookup failed")
			},
		},
		nil,
	)

	_, err := service.CreateMoment(7, &CreateMomentRequest{
		ClientID:  "local-uuid-3",
		Content:   "new moment",
		MediaType: model.MediaTypeText,
	})
	if err == nil || err.Error() != "db lookup failed" {
		t.Fatalf("err = %v, want db lookup failed", err)
	}
}

func TestMomentServiceCreateMomentFallsBackToExistingAfterDuplicateCreate(t *testing.T) {
	var lookupCalls int
	service := newMomentServiceWithDeps(
		momentRepositoryStub{
			findByUserIDAndClientIDFn: func(userID uint64, clientID string) (*model.Moment, error) {
				lookupCalls++
				if lookupCalls == 1 {
					return nil, gorm.ErrRecordNotFound
				}
				return &model.Moment{
					ID:         3003,
					UserID:     userID,
					Content:    "already created",
					MediaType:  model.MediaTypeText,
					MediaPaths: []string{},
				}, nil
			},
			createFn: func(moment *model.Moment) error {
				return errors.New("duplicate key")
			},
		},
		nil,
	)

	resp, err := service.CreateMoment(8, &CreateMomentRequest{
		ClientID:  "local-uuid-4",
		Content:   "new moment",
		MediaType: model.MediaTypeText,
	})
	if err != nil {
		t.Fatalf("CreateMoment failed: %v", err)
	}
	if lookupCalls != 2 {
		t.Fatalf("lookupCalls = %d, want 2", lookupCalls)
	}
	if resp.ID != 3003 {
		t.Fatalf("id = %d, want 3003", resp.ID)
	}
}

func TestMomentServiceUpdateMomentDeletesUnusedManagedMedia(t *testing.T) {
	root := t.TempDir()
	target := filepath.Join(root, "image", "20260421", "a.jpg")
	if err := os.MkdirAll(filepath.Dir(target), 0o755); err != nil {
		t.Fatalf("mkdir failed: %v", err)
	}
	if err := os.WriteFile(target, []byte("data"), 0o644); err != nil {
		t.Fatalf("write failed: %v", err)
	}

	var gotManagedPath string
	service := newMomentServiceWithDeps(
		momentRepositoryStub{
			findByIDFn: func(id uint64) (*model.Moment, error) {
				return &model.Moment{
					ID:         10,
					UserID:     7,
					Content:    "old",
					MediaType:  model.MediaTypeImage,
					MediaPaths: []string{"https://files.example.com/uploads/image/20260421/a.jpg"},
				}, nil
			},
			updateFn: func(moment *model.Moment) error {
				if len(moment.MediaPaths) != 0 {
					t.Fatalf("expected media paths to be cleared, got %v", moment.MediaPaths)
				}
				return nil
			},
			countOtherReferencesByMediaFn: func(managedPath string, excludeMomentID uint64) (int64, error) {
				gotManagedPath = managedPath
				if excludeMomentID != 10 {
					t.Fatalf("excludeMomentID = %d, want 10", excludeMomentID)
				}
				return 0, nil
			},
		},
		NewUploadServiceWithConfig(&config.UploadConfig{LocalPath: root}),
	)

	resp, err := service.UpdateMoment(10, 7, &UpdateMomentRequest{
		Content:    "new",
		MediaType:  model.MediaTypeText,
		MediaPaths: []string{},
	})
	if err != nil {
		t.Fatalf("UpdateMoment failed: %v", err)
	}
	if resp.Content != "new" {
		t.Fatalf("content = %q, want new", resp.Content)
	}
	if gotManagedPath != "/uploads/image/20260421/a.jpg" {
		t.Fatalf("managed path = %q, want /uploads/image/20260421/a.jpg", gotManagedPath)
	}
	if _, err := os.Stat(target); !os.IsNotExist(err) {
		t.Fatalf("expected file deleted, stat err = %v", err)
	}
}

func TestMomentServiceDeleteMomentKeepsSharedManagedMedia(t *testing.T) {
	root := t.TempDir()
	target := filepath.Join(root, "video", "20260421", "clip.mp4")
	if err := os.MkdirAll(filepath.Dir(target), 0o755); err != nil {
		t.Fatalf("mkdir failed: %v", err)
	}
	if err := os.WriteFile(target, []byte("data"), 0o644); err != nil {
		t.Fatalf("write failed: %v", err)
	}

	service := newMomentServiceWithDeps(
		momentRepositoryStub{
			findByIDFn: func(id uint64) (*model.Moment, error) {
				return &model.Moment{
					ID:         20,
					UserID:     9,
					MediaType:  model.MediaTypeVideo,
					MediaPaths: []string{"/uploads/video/20260421/clip.mp4"},
				}, nil
			},
			deleteFn: func(id, userID uint64) error {
				return nil
			},
			countOtherReferencesByMediaFn: func(managedPath string, excludeMomentID uint64) (int64, error) {
				if managedPath != "/uploads/video/20260421/clip.mp4" {
					t.Fatalf("managed path = %q", managedPath)
				}
				return 1, nil
			},
		},
		NewUploadServiceWithConfig(&config.UploadConfig{LocalPath: root}),
	)

	if err := service.DeleteMoment(20, 9); err != nil {
		t.Fatalf("DeleteMoment failed: %v", err)
	}

	if _, err := os.Stat(target); err != nil {
		t.Fatalf("expected shared file to remain, stat err = %v", err)
	}
}
