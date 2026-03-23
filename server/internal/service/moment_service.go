package service

import (
	"errors"

	"github.com/moment-server/moment-server/internal/model"
	"github.com/moment-server/moment-server/internal/repository"
	"gorm.io/gorm"
)

var (
	ErrMomentNotFound = errors.New("moment not found")
	ErrForbidden      = errors.New("forbidden")
)

// MomentService 时光记录服务
type MomentService struct {
	momentRepo *repository.MomentRepository
}

// NewMomentService 创建时光记录服务
func NewMomentService() *MomentService {
	return &MomentService{
		momentRepo: repository.NewMomentRepository(),
	}
}

// CreateMomentRequest 创建记录请求
type CreateMomentRequest struct {
	Content   string          `json:"content" binding:"required,max=5000"`
	MediaType model.MediaType `json:"media_type" binding:"required,oneof=text image audio video"`
	MediaPaths []string       `json:"media_paths"`
}

// UpdateMomentRequest 更新记录请求
type UpdateMomentRequest struct {
	Content    string          `json:"content" binding:"max=5000"`
	MediaType  model.MediaType `json:"media_type" binding:"oneof=text image audio video"`
	MediaPaths []string        `json:"media_paths"`
}

// MomentResponse 记录响应
type MomentResponse struct {
	ID         uint64           `json:"id"`
	UserID     uint64           `json:"user_id"`
	Content    string           `json:"content"`
	MediaType  model.MediaType  `json:"media_type"`
	MediaPaths []string         `json:"media_paths"`
	CreatedAt  string           `json:"created_at"`
	UpdatedAt  string           `json:"updated_at"`
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

// CreateMoment 创建记录
func (s *MomentService) CreateMoment(userID uint64, req *CreateMomentRequest) (*MomentResponse, error) {
	moment := &model.Moment{
		UserID:     userID,
		Content:    req.Content,
		MediaType:  req.MediaType,
		MediaPaths: req.MediaPaths,
	}

	if err := s.momentRepo.Create(moment); err != nil {
		return nil, err
	}

	return toMomentResponse(moment), nil
}

// GetMoment 获取详情
func (s *MomentService) GetMoment(id uint64) (*MomentResponse, error) {
	moment, err := s.momentRepo.FindByID(id)
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, ErrMomentNotFound
		}
		return nil, err
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

	return s.momentRepo.Delete(id, userID)
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
