package service

import (
	"errors"
	"strings"

	"github.com/moment-server/moment-server/internal/middleware"
	"github.com/moment-server/moment-server/internal/model"
	"github.com/moment-server/moment-server/internal/repository"
	"go.uber.org/zap"
	"gorm.io/gorm"
)

var (
	ErrMomentNotFound = errors.New("moment not found")
	ErrForbidden      = errors.New("forbidden")
)

// MomentService 时光记录服务
type MomentService struct {
	momentRepo    momentRepository
	uploadService momentMediaCleaner
}

type momentRepository interface {
	FindAll(filter repository.MomentFilter, page, pageSize int) ([]*model.Moment, int64, error)
	FindForAdmin(filter repository.AdminMomentFilter, page, pageSize int) ([]*model.Moment, int64, error)
	Create(moment *model.Moment) error
	FindByUserIDAndClientID(userID uint64, clientID string) (*model.Moment, error)
	FindByID(id uint64) (*model.Moment, error)
	Update(moment *model.Moment) error
	Delete(id, userID uint64) error
	CountOtherReferencesByMediaPath(managedPath string, excludeMomentID uint64) (int64, error)
}

type momentMediaCleaner interface {
	ResolveManagedFile(raw string) (string, string, bool)
	DeleteManagedFile(raw string) error
}

// NewMomentService 创建时光记录服务
func NewMomentService() *MomentService {
	return &MomentService{
		momentRepo:    repository.NewMomentRepository(),
		uploadService: NewUploadService(),
	}
}

func newMomentServiceWithDeps(repo momentRepository, uploadService momentMediaCleaner) *MomentService {
	return &MomentService{
		momentRepo:    repo,
		uploadService: uploadService,
	}
}

// CreateMomentRequest 创建记录请求（正文可与媒体二选一，与 App 端一致）
type CreateMomentRequest struct {
	ClientID   string          `json:"client_id" binding:"omitempty,max=64"`
	Content    string          `json:"content" binding:"max=5000"`
	MediaType  model.MediaType `json:"media_type" binding:"required,oneof=text image audio video mixed"`
	MediaPaths []string        `json:"media_paths"`
}

// UpdateMomentRequest 更新记录请求
type UpdateMomentRequest struct {
	Content    string          `json:"content" binding:"max=5000"`
	MediaType  model.MediaType `json:"media_type" binding:"oneof=text image audio video mixed"`
	MediaPaths []string        `json:"media_paths"`
}

// MomentResponse 记录响应
type MomentResponse struct {
	ID         uint64          `json:"id"`
	UserID     uint64          `json:"user_id"`
	Content    string          `json:"content"`
	MediaType  model.MediaType `json:"media_type"`
	MediaPaths []string        `json:"media_paths"`
	CreatedAt  string          `json:"created_at"`
	UpdatedAt  string          `json:"updated_at"`
}

// AdminMomentItem 管理端时光列表项（含软删时间）
type AdminMomentItem struct {
	ID         uint64          `json:"id"`
	UserID     uint64          `json:"user_id"`
	Content    string          `json:"content"`
	MediaType  model.MediaType `json:"media_type"`
	MediaPaths []string        `json:"media_paths"`
	CreatedAt  string          `json:"created_at"`
	UpdatedAt  string          `json:"updated_at"`
	DeletedAt  *string         `json:"deleted_at,omitempty"`
}

// AdminMomentListResponse 管理端用户时光分页
type AdminMomentListResponse struct {
	Total    int64              `json:"total"`
	Page     int                `json:"page"`
	PageSize int                `json:"page_size"`
	User     *UserResponse      `json:"user"`
	Moments  []*AdminMomentItem `json:"moments"`
}

// ListMoments 分页查询
func (s *MomentService) ListMoments(userID uint64, page, pageSize int) ([]*MomentResponse, int64, error) {
	filter := repository.MomentFilter{UserID: userID}
	moments, total, err := s.momentRepo.FindAll(filter, page, pageSize)
	if err != nil {
		return nil, 0, err
	}

	responses := make([]*MomentResponse, len(moments))
	for i, m := range moments {
		responses[i] = toMomentResponse(m)
	}

	return responses, total, nil
}

// ListMomentsForAdmin 管理端按用户分页查询时光
func (s *MomentService) ListMomentsForAdmin(filter repository.AdminMomentFilter, page, pageSize int) (*AdminMomentListResponse, error) {
	moments, total, err := s.momentRepo.FindForAdmin(filter, page, pageSize)
	if err != nil {
		return nil, err
	}

	items := make([]*AdminMomentItem, len(moments))
	for i, m := range moments {
		items[i] = toAdminMomentItem(m)
	}

	return &AdminMomentListResponse{
		Total:    total,
		Page:     page,
		PageSize: pageSize,
		Moments:  items,
	}, nil
}

// CreateMoment 创建记录
func (s *MomentService) CreateMoment(userID uint64, req *CreateMomentRequest) (*MomentResponse, error) {
	clientID := strings.TrimSpace(req.ClientID)
	if clientID != "" {
		existing, err := s.momentRepo.FindByUserIDAndClientID(userID, clientID)
		if err == nil {
			return toMomentResponse(existing), nil
		}
		if !errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, err
		}
	}

	moment := &model.Moment{
		UserID:     userID,
		ClientID:   nil,
		Content:    req.Content,
		MediaType:  req.MediaType,
		MediaPaths: req.MediaPaths,
	}
	if clientID != "" {
		moment.ClientID = &clientID
	}

	if err := s.momentRepo.Create(moment); err != nil {
		if clientID != "" {
			existing, lookupErr := s.momentRepo.FindByUserIDAndClientID(userID, clientID)
			if lookupErr == nil {
				return toMomentResponse(existing), nil
			}
		}
		return nil, err
	}

	return toMomentResponse(moment), nil
}

// GetMoment 获取详情
func (s *MomentService) GetMoment(id, userID uint64) (*MomentResponse, error) {
	moment, err := s.momentRepo.FindByID(id)
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, ErrMomentNotFound
		}
		return nil, err
	}
	if moment.UserID != userID {
		return nil, ErrForbidden
	}

	return toMomentResponse(moment), nil
}

// UpdateMoment 更新记录
func (s *MomentService) UpdateMoment(id, userID uint64, req *UpdateMomentRequest) (*MomentResponse, error) {
	moment, err := s.momentRepo.FindByID(id)
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, ErrMomentNotFound
		}
		return nil, err
	}

	// 校验归属
	if moment.UserID != userID {
		return nil, ErrForbidden
	}

	originalMediaPaths := cloneMediaPaths(moment.MediaPaths)

	// 更新字段
	if req.Content != "" {
		moment.Content = req.Content
	}
	if req.MediaType != "" {
		moment.MediaType = req.MediaType
	}
	if req.MediaPaths != nil {
		moment.MediaPaths = req.MediaPaths
	}

	if err := s.momentRepo.Update(moment); err != nil {
		return nil, err
	}

	if req.MediaPaths != nil {
		s.cleanupUnusedManagedMedia(diffRemovedPaths(originalMediaPaths, moment.MediaPaths), moment.ID)
	}

	return toMomentResponse(moment), nil
}

// DeleteMoment 删除记录
func (s *MomentService) DeleteMoment(id, userID uint64) error {
	moment, err := s.momentRepo.FindByID(id)
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return ErrMomentNotFound
		}
		return err
	}

	// 校验归属
	if moment.UserID != userID {
		return ErrForbidden
	}

	mediaPaths := cloneMediaPaths(moment.MediaPaths)
	if err := s.momentRepo.Delete(id, userID); err != nil {
		return err
	}

	s.cleanupUnusedManagedMedia(mediaPaths, moment.ID)
	return nil
}

func toMomentResponse(m *model.Moment) *MomentResponse {
	return &MomentResponse{
		ID:         m.ID,
		UserID:     m.UserID,
		Content:    m.Content,
		MediaType:  m.MediaType,
		MediaPaths: m.MediaPaths,
		CreatedAt:  m.CreatedAt.Format("2006-01-02 15:04:05"),
		UpdatedAt:  m.UpdatedAt.Format("2006-01-02 15:04:05"),
	}
}

func toAdminMomentItem(m *model.Moment) *AdminMomentItem {
	item := &AdminMomentItem{
		ID:         m.ID,
		UserID:     m.UserID,
		Content:    m.Content,
		MediaType:  m.MediaType,
		MediaPaths: m.MediaPaths,
		CreatedAt:  m.CreatedAt.Format("2006-01-02 15:04:05"),
		UpdatedAt:  m.UpdatedAt.Format("2006-01-02 15:04:05"),
	}
	if m.DeletedAt != nil {
		s := m.DeletedAt.Format("2006-01-02 15:04:05")
		item.DeletedAt = &s
	}
	return item
}

func (s *MomentService) cleanupUnusedManagedMedia(paths []string, excludeMomentID uint64) {
	if s.uploadService == nil || len(paths) == 0 {
		return
	}

	seen := make(map[string]struct{}, len(paths))
	for _, rawPath := range paths {
		managedPath, _, ok := s.uploadService.ResolveManagedFile(rawPath)
		if !ok {
			continue
		}
		if _, exists := seen[managedPath]; exists {
			continue
		}
		seen[managedPath] = struct{}{}

		refCount, err := s.momentRepo.CountOtherReferencesByMediaPath(managedPath, excludeMomentID)
		if err != nil {
			logCleanupError("count media references failed", err, managedPath, excludeMomentID)
			continue
		}
		if refCount > 0 {
			continue
		}

		if err := s.uploadService.DeleteManagedFile(managedPath); err != nil {
			logCleanupError("delete managed media failed", err, managedPath, excludeMomentID)
		}
	}
}

func cloneMediaPaths(paths []string) []string {
	if paths == nil {
		return nil
	}
	cloned := make([]string, len(paths))
	copy(cloned, paths)
	return cloned
}

func diffRemovedPaths(before, after []string) []string {
	if len(before) == 0 {
		return nil
	}

	kept := make(map[string]struct{}, len(after))
	for _, item := range after {
		kept[item] = struct{}{}
	}

	removed := make([]string, 0, len(before))
	seen := make(map[string]struct{}, len(before))
	for _, item := range before {
		if _, exists := kept[item]; exists {
			continue
		}
		if _, duplicated := seen[item]; duplicated {
			continue
		}
		seen[item] = struct{}{}
		removed = append(removed, item)
	}
	return removed
}

func logCleanupError(message string, err error, managedPath string, excludeMomentID uint64) {
	logger := middleware.GetLogger()
	if logger == nil {
		return
	}
	logger.Warn(message,
		zap.Error(err),
		zap.String("media_path", managedPath),
		zap.Uint64("exclude_moment_id", excludeMomentID),
	)
}
