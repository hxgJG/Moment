package service

import (
	"errors"

	"github.com/moment-server/moment-server/internal/repository"
	"gorm.io/gorm"
)

// UserService 用户服务
type UserService struct {
	userRepo   *repository.UserRepository
	momentRepo *repository.MomentRepository
}

// NewUserService 创建用户服务
func NewUserService() *UserService {
	return &UserService{
		userRepo:   repository.NewUserRepository(),
		momentRepo: repository.NewMomentRepository(),
	}
}

// UserResponse 用户响应
type UserResponse struct {
	ID              uint64   `json:"id"`
	Username        string   `json:"username"`
	Nickname        string   `json:"nickname"`
	AvatarURL       string   `json:"avatar_url"`
	Status          int8     `json:"status"`
	CreatedAt       string   `json:"created_at"`
	Roles           []string `json:"roles,omitempty"`
	PermissionCodes []string `json:"permission_codes,omitempty"`
}

// UpdateUserRequest 更新用户请求
type UpdateUserRequest struct {
	Nickname  string `json:"nickname" binding:"max=100"`
	AvatarURL string `json:"avatar_url" binding:"max=500"`
}

// StatsResponse 统计响应
type StatsResponse struct {
	Total  int64            `json:"total"`
	ByType map[string]int64 `json:"by_type"`
}

// GetCurrentUser 获取当前用户
func (s *UserService) GetCurrentUser(userID uint64) (*UserResponse, error) {
	user, err := s.userRepo.FindByID(userID)
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, ErrUserNotFound
		}
		return nil, err
	}

	return &UserResponse{
		ID:        user.ID,
		Username:  user.Username,
		Nickname:  user.Nickname,
		AvatarURL: user.AvatarURL,
		Status:    user.Status,
		CreatedAt: user.CreatedAt.Format("2006-01-02 15:04:05"),
	}, nil
}

// UpdateUser 更新用户
func (s *UserService) UpdateUser(userID uint64, req *UpdateUserRequest) (*UserResponse, error) {
	user, err := s.userRepo.FindByID(userID)
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, ErrUserNotFound
		}
		return nil, err
	}

	// 更新字段
	if req.Nickname != "" {
		user.Nickname = req.Nickname
	}
	if req.AvatarURL != "" {
		user.AvatarURL = req.AvatarURL
	}

	if err := s.userRepo.Update(user); err != nil {
		return nil, err
	}

	return &UserResponse{
		ID:        user.ID,
		Username:  user.Username,
		Nickname:  user.Nickname,
		AvatarURL: user.AvatarURL,
		Status:    user.Status,
		CreatedAt: user.CreatedAt.Format("2006-01-02 15:04:05"),
	}, nil
}

// GetStats 获取用户统计
func (s *UserService) GetStats(userID uint64) (*StatsResponse, error) {
	// 统计总数
	total, err := s.momentRepo.CountByUserID(userID)
	if err != nil {
		return nil, err
	}

	// 按类型统计
	byType, err := s.momentRepo.CountByMediaType(userID)
	if err != nil {
		return nil, err
	}

	// 转换key为字符串
	byTypeStr := make(map[string]int64)
	for k, v := range byType {
		byTypeStr[string(k)] = v
	}

	return &StatsResponse{
		Total:  total,
		ByType: byTypeStr,
	}, nil
}

// GetAdminProfile 获取管理员资料（含角色和权限码）
func (s *UserService) GetAdminProfile(userID uint64) (*UserResponse, error) {
	user, err := s.userRepo.FindByID(userID)
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, ErrUserNotFound
		}
		return nil, err
	}

	resp := &UserResponse{
		ID:        user.ID,
		Username:  user.Username,
		Nickname:  user.Nickname,
		AvatarURL: user.AvatarURL,
		Status:    user.Status,
		CreatedAt: user.CreatedAt.Format("2006-01-02 15:04:05"),
	}

	roles, err := s.userRepo.GetUserRoles(userID)
	if err != nil {
		return nil, err
	}
	if len(roles) > 0 {
		resp.Roles = make([]string, 0, len(roles))
		for _, role := range roles {
			resp.Roles = append(resp.Roles, role.Code)
		}
	}

	codes, err := s.userRepo.GetUserPermissionCodes(userID)
	if err != nil {
		return nil, err
	}
	resp.PermissionCodes = codes

	return resp, nil
}
