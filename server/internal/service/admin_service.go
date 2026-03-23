package service

import (
	"encoding/json"
	"errors"
	"time"

	"github.com/moment-server/moment-server/internal/model"
	"github.com/moment-server/moment-server/internal/repository"
	"github.com/moment-server/moment-server/pkg/jwt"
	"golang.org/x/crypto/bcrypt"
	"gorm.io/gorm"
)

// 错误定义（从 auth_service.go 引用）
var (
	ErrUserExists         = errors.New("user already exists")
	ErrUserDisabled       = errors.New("user is disabled")
	ErrInvalidCredentials = errors.New("invalid credentials")
	ErrRoleNotFound      = errors.New("role not found")
	ErrRoleExists        = errors.New("role already exists")
	ErrRoleHasUsers      = errors.New("role has assigned users")
)

// ==================== 用户管理 ====================

// AdminLoginRequest 管理员登录请求
type AdminLoginRequest struct {
	Username string `json:"username" binding:"required,min=3,max=50"`
	Password string `json:"password" binding:"required,min=6"`
}

// AdminLoginResponse 管理员登录响应
type AdminLoginResponse struct {
	Token     string        `json:"token"`
	User      *UserResponse `json:"user"`
	ExpiresAt int64         `json:"expires_at"`
}

// UserListResponse 用户列表响应
type UserListResponse struct {
	Total    int64          `json:"total"`
	Page     int            `json:"page"`
	PageSize int            `json:"page_size"`
	Users    []*UserResponse `json:"users"`
}

// CreateUserRequest 创建用户请求
type CreateUserRequest struct {
	Username string `json:"username" binding:"required,min=3,max=50"`
	Password string `json:"password" binding:"required,min=6"`
	Nickname string `json:"nickname" binding:"max=100"`
	Status   *int8  `json:"status"`
}

// UpdateUserByAdminRequest 管理员更新用户请求
type UpdateUserByAdminRequest struct {
	Username string `json:"username" binding:"min=3,max=50"`
	Nickname string `json:"nickname" binding:"max=100"`
	Password string `json:"password" binding:"omitempty,min=6"`
	Status   *int8  `json:"status"`
}

// AssignRolesRequest 分配角色请求
type AssignRolesRequest struct {
	RoleIDs []uint64 `json:"role_ids" binding:"required"`
}

// AdminLogin 管理员登录
func (s *UserService) AdminLogin(req *AdminLoginRequest) (*AdminLoginResponse, error) {
	user, err := s.userRepo.FindByUsername(req.Username)
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, ErrInvalidCredentials
		}
		return nil, err
	}

	// 检查密码
	if err := bcrypt.CompareHashAndPassword([]byte(user.Password), []byte(req.Password)); err != nil {
		return nil, ErrInvalidCredentials
	}

	// 检查状态
	if user.Status != 1 {
		return nil, ErrUserDisabled
	}

	// 检查是否是管理员角色
	isAdmin, err := s.userRepo.HasAdminRole(user.ID)
	if err != nil {
		return nil, err
	}
	if !isAdmin {
		return nil, ErrUserDisabled
	}

	// 生成Token
	token, _, err := jwt.GetManager().GenerateTokenPair(user.ID, user.Username, "admin")
	if err != nil {
		return nil, err
	}

	expiresAt := time.Now().Add(24 * time.Hour).Unix()

	return &AdminLoginResponse{
		Token:     token,
		User:      toUserResponse(user),
		ExpiresAt: expiresAt,
	}, nil
}

// ListUsers 获取用户列表
func (s *UserService) ListUsers(page, pageSize int, keyword string) (*UserListResponse, error) {
	users, total, err := s.userRepo.List(page, pageSize, keyword)
	if err != nil {
		return nil, err
	}

	userResponses := make([]*UserResponse, len(users))
	for i, user := range users {
		userResponses[i] = toUserResponse(user)
	}

	return &UserListResponse{
		Total:    total,
		Page:     page,
		PageSize: pageSize,
		Users:    userResponses,
	}, nil
}

// CreateUser 创建用户
func (s *UserService) CreateUser(req *CreateUserRequest) (*UserResponse, error) {
	// 检查用户名是否存在
	existing, err := s.userRepo.FindByUsername(req.Username)
	if err == nil && existing != nil {
		return nil, ErrUserExists
	}

	// 加密密码
	hashedPassword, err := bcrypt.GenerateFromPassword([]byte(req.Password), bcrypt.DefaultCost)
	if err != nil {
		return nil, err
	}

	status := int8(1)
	if req.Status != nil {
		status = *req.Status
	}

	user := &model.User{
		Username: req.Username,
		Password: string(hashedPassword),
		Nickname: req.Nickname,
		Status:   status,
	}

	if err := s.userRepo.Create(user); err != nil {
		return nil, err
	}

	return toUserResponse(user), nil
}

// UpdateUserByAdmin 管理员更新用户
func (s *UserService) UpdateUserByAdmin(userID uint64, req *UpdateUserByAdminRequest) (*UserResponse, error) {
	user, err := s.userRepo.FindByID(userID)
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, ErrUserNotFound
		}
		return nil, err
	}

	// 如果要更新用户名，检查是否已存在
	if req.Username != "" && req.Username != user.Username {
		existing, err := s.userRepo.FindByUsername(req.Username)
		if err == nil && existing != nil && existing.ID != userID {
			return nil, ErrUserExists
		}
		user.Username = req.Username
	}

	if req.Nickname != "" {
		user.Nickname = req.Nickname
	}

	if req.Password != "" {
		hashedPassword, err := bcrypt.GenerateFromPassword([]byte(req.Password), bcrypt.DefaultCost)
		if err != nil {
			return nil, err
		}
		user.Password = string(hashedPassword)
	}

	if req.Status != nil {
		user.Status = *req.Status
	}

	if err := s.userRepo.Update(user); err != nil {
		return nil, err
	}

	return toUserResponse(user), nil
}

// DeleteUser 删除用户
func (s *UserService) DeleteUser(userID uint64) error {
	user, err := s.userRepo.FindByID(userID)
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return ErrUserNotFound
		}
		return err
	}

	return s.userRepo.Delete(user.ID)
}

// ToggleUserStatus 切换用户状态
func (s *UserService) ToggleUserStatus(userID uint64) error {
	user, err := s.userRepo.FindByID(userID)
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return ErrUserNotFound
		}
		return err
	}

	if user.Status == 1 {
		user.Status = 0
	} else {
		user.Status = 1
	}

	return s.userRepo.Update(user)
}

// AssignRoles 分配用户角色
func (s *UserService) AssignRoles(userID uint64, roleIDs []uint64) error {
	user, err := s.userRepo.FindByID(userID)
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return ErrUserNotFound
		}
		return err
	}

	return s.userRepo.UpdateUserRoles(user.ID, roleIDs)
}

// GetUserByID 根据ID获取用户
func (s *UserService) GetUserByID(userID uint64) (*UserResponse, error) {
	user, err := s.userRepo.FindByID(userID)
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, ErrUserNotFound
		}
		return nil, err
	}

	return toUserResponse(user), nil
}

func toUserResponse(user *model.User) *UserResponse {
	return &UserResponse{
		ID:        user.ID,
		Username:  user.Username,
		Nickname:  user.Nickname,
		AvatarURL: user.AvatarURL,
		Status:    user.Status,
		CreatedAt: user.CreatedAt.Format("2006-01-02 15:04:05"),
	}
}

// ==================== 角色管理 ====================

// RoleService 角色服务
type RoleService struct {
	roleRepo *repository.RoleRepository
}

// NewRoleService 创建角色服务
func NewRoleService() *RoleService {
	return &RoleService{
		roleRepo: repository.NewRoleRepository(),
	}
}

// RoleResponse 角色响应
type RoleResponse struct {
	ID          uint64   `json:"id"`
	Name        string   `json:"name"`
	Code        string   `json:"code"`
	Description string   `json:"description"`
	Status      int8     `json:"status"`
	Permissions []uint64 `json:"permissions"`
	CreatedAt   string   `json:"created_at"`
}

// RoleListResponse 角色列表响应
type RoleListResponse struct {
	Roles []*RoleResponse `json:"roles"`
}

// CreateRoleRequest 创建角色请求
type CreateRoleRequest struct {
	Name         string   `json:"name" binding:"required,max=50"`
	Code         string   `json:"code" binding:"required,max=50"`
	Description  string   `json:"description" binding:"max=200"`
	PermissionIDs []uint64 `json:"permission_ids"`
}

// UpdateRoleRequest 更新角色请求
type UpdateRoleRequest struct {
	Name         string   `json:"name" binding:"max=50"`
	Code         string   `json:"code" binding:"max=50"`
	Description  string   `json:"description" binding:"max=200"`
	Status       *int8    `json:"status"`
	PermissionIDs []uint64 `json:"permission_ids"`
}

// AssignPermissionsRequest 分配权限请求
type AssignPermissionsRequest struct {
	PermissionIDs []uint64 `json:"permission_ids" binding:"required"`
}

// ListRoles 获取角色列表
func (s *RoleService) ListRoles() (*RoleListResponse, error) {
	roles, err := s.roleRepo.ListAll()
	if err != nil {
		return nil, err
	}

	roleResponses := make([]*RoleResponse, len(roles))
	for i, role := range roles {
		perms, _ := s.roleRepo.GetRolePermissions(role.ID)
		permIDs := make([]uint64, len(perms))
		for j, p := range perms {
			permIDs[j] = p.ID
		}

		roleResponses[i] = &RoleResponse{
			ID:          role.ID,
			Name:        role.Name,
			Code:        role.Code,
			Description: role.Description,
			Status:      role.Status,
			Permissions: permIDs,
			CreatedAt:   role.CreatedAt.Format("2006-01-02 15:04:05"),
		}
	}

	return &RoleListResponse{
		Roles: roleResponses,
	}, nil
}

// CreateRole 创建角色
func (s *RoleService) CreateRole(req *CreateRoleRequest) (*RoleResponse, error) {
	// 检查角色代码是否存在
	existing, err := s.roleRepo.FindByCode(req.Code)
	if err == nil && existing != nil {
		return nil, ErrRoleExists
	}

	role := &model.Role{
		Name:        req.Name,
		Code:        req.Code,
		Description: req.Description,
		Status:      1,
	}

	if err := s.roleRepo.Create(role); err != nil {
		return nil, err
	}

	// 分配权限
	if len(req.PermissionIDs) > 0 {
		if err := s.roleRepo.SetRolePermissions(role.ID, req.PermissionIDs); err != nil {
			return nil, err
		}
	}

	return &RoleResponse{
		ID:          role.ID,
		Name:        role.Name,
		Code:        role.Code,
		Description: role.Description,
		Status:      role.Status,
		Permissions: req.PermissionIDs,
		CreatedAt:   role.CreatedAt.Format("2006-01-02 15:04:05"),
	}, nil
}

// UpdateRole 更新角色
func (s *RoleService) UpdateRole(roleID uint64, req *UpdateRoleRequest) (*RoleResponse, error) {
	role, err := s.roleRepo.FindByID(roleID)
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, ErrRoleNotFound
		}
		return nil, err
	}

	// 如果要更新角色代码，检查是否已存在
	if req.Code != "" && req.Code != role.Code {
		existing, err := s.roleRepo.FindByCode(req.Code)
		if err == nil && existing != nil && existing.ID != roleID {
			return nil, ErrRoleExists
		}
		role.Code = req.Code
	}

	if req.Name != "" {
		role.Name = req.Name
	}
	if req.Description != "" {
		role.Description = req.Description
	}
	if req.Status != nil {
		role.Status = *req.Status
	}

	if err := s.roleRepo.Update(role); err != nil {
		return nil, err
	}

	// 更新权限
	if req.PermissionIDs != nil {
		if err := s.roleRepo.SetRolePermissions(role.ID, req.PermissionIDs); err != nil {
			return nil, err
		}
	}

	perms, _ := s.roleRepo.GetRolePermissions(role.ID)
	permIDs := make([]uint64, len(perms))
	for j, p := range perms {
		permIDs[j] = p.ID
	}

	return &RoleResponse{
		ID:          role.ID,
		Name:        role.Name,
		Code:        role.Code,
		Description: role.Description,
		Status:      role.Status,
		Permissions: permIDs,
		CreatedAt:   role.CreatedAt.Format("2006-01-02 15:04:05"),
	}, nil
}

// DeleteRole 删除角色
func (s *RoleService) DeleteRole(roleID uint64) error {
	role, err := s.roleRepo.FindByID(roleID)
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return ErrRoleNotFound
		}
		return err
	}

	// 检查是否有用户关联
	count, err := s.roleRepo.CountUsersByRole(roleID)
	if err != nil {
		return err
	}
	if count > 0 {
		return ErrRoleHasUsers
	}

	return s.roleRepo.Delete(role.ID)
}

// AssignPermissions 分配角色权限
func (s *RoleService) AssignPermissions(roleID uint64, permissionIDs []uint64) error {
	role, err := s.roleRepo.FindByID(roleID)
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return ErrRoleNotFound
		}
		return err
	}

	return s.roleRepo.SetRolePermissions(role.ID, permissionIDs)
}

// ==================== 权限管理 ====================

// PermissionService 权限服务
type PermissionService struct {
	permRepo *repository.PermissionRepository
}

// NewPermissionService 创建权限服务
func NewPermissionService() *PermissionService {
	return &PermissionService{
		permRepo: repository.NewPermissionRepository(),
	}
}

// PermissionResponse 权限响应
type PermissionResponse struct {
	ID       uint64                `json:"id"`
	Name     string                `json:"name"`
	Code     string                `json:"code"`
	Type     string                `json:"type"`
	ParentID uint64                `json:"parent_id"`
	Path     string                `json:"path"`
	Icon     string                `json:"icon"`
	Sort     int                   `json:"sort"`
	Status   int8                  `json:"status"`
	Children []*PermissionResponse `json:"children,omitempty"`
}

// PermissionListResponse 权限列表响应
type PermissionListResponse struct {
	Permissions []*PermissionResponse `json:"permissions"`
}

// ListPermissions 获取权限列表（树形）
func (s *PermissionService) ListPermissions() (*PermissionListResponse, error) {
	perms, err := s.permRepo.ListAll()
	if err != nil {
		return nil, err
	}

	// 构建树形结构
	permMap := make(map[uint64]*PermissionResponse)
	var rootPerms []*PermissionResponse

	// 先转换为响应结构
	for _, p := range perms {
		permMap[p.ID] = &PermissionResponse{
			ID:       p.ID,
			Name:     p.Name,
			Code:     p.Code,
			Type:     p.Type,
			ParentID: p.ParentID,
			Path:     p.Path,
			Icon:     p.Icon,
			Sort:     p.Sort,
			Status:   p.Status,
		}
	}

	// 构建树
	for _, p := range perms {
		if p.ParentID == 0 {
			rootPerms = append(rootPerms, permMap[p.ID])
		} else {
			if parent, ok := permMap[p.ParentID]; ok {
				parent.Children = append(parent.Children, permMap[p.ID])
			}
		}
	}

	return &PermissionListResponse{
		Permissions: rootPerms,
	}, nil
}

// ==================== 日志管理 ====================

// LogService 日志服务
type LogService struct {
	logRepo *repository.LogRepository
}

// NewLogService 创建日志服务
func NewLogService() *LogService {
	return &LogService{
		logRepo: repository.NewLogRepository(),
	}
}

// OperationLogResponse 操作日志响应
type OperationLogResponse struct {
	ID        uint64 `json:"id"`
	UserID    uint64 `json:"user_id"`
	Username  string `json:"username"`
	Module    string `json:"module"`
	Action    string `json:"action"`
	Method    string `json:"method"`
	Path      string `json:"path"`
	IP        string `json:"ip"`
	Location  string `json:"location"`
	Params    string `json:"params"`
	Status    int    `json:"status"`
	Duration  int    `json:"duration"`
	CreatedAt string `json:"created_at"`
}

// LogListResponse 日志列表响应
type LogListResponse struct {
	Total    int64                    `json:"total"`
	Page     int                      `json:"page"`
	PageSize int                      `json:"page_size"`
	Logs     []*OperationLogResponse `json:"logs"`
}

// ListLogsRequest 查询日志请求
type ListLogsRequest = repository.ListLogsRequest

// ListOperationLogs 获取操作日志列表
func (s *LogService) ListOperationLogs(req *ListLogsRequest) (*LogListResponse, error) {
	logs, total, err := s.logRepo.List(req)
	if err != nil {
		return nil, err
	}

	logResponses := make([]*OperationLogResponse, len(logs))
	for i, log := range logs {
		userID := uint64(0)
		if log.UserID != nil {
			userID = *log.UserID
		}
		paramsBytes, _ := json.Marshal(log.Params)
		logResponses[i] = &OperationLogResponse{
			ID:        log.ID,
			UserID:    userID,
			Username:  log.Username,
			Module:    log.Module,
			Action:    log.Action,
			Method:    log.Method,
			Path:      log.Path,
			IP:        log.IP,
			Location:  log.Location,
			Params:    string(paramsBytes),
			Status:    log.Status,
			Duration:  log.Duration,
			CreatedAt: log.CreatedAt.Format("2006-01-02 15:04:05"),
		}
	}

	return &LogListResponse{
		Total:    total,
		Page:     req.Page,
		PageSize: req.PageSize,
		Logs:     logResponses,
	}, nil
}
