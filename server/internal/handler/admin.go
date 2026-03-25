package handler

import (
	"errors"
	"strconv"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/moment-server/moment-server/internal/middleware"
	"github.com/moment-server/moment-server/internal/model"
	"github.com/moment-server/moment-server/internal/repository"
	"github.com/moment-server/moment-server/internal/service"
	"github.com/moment-server/moment-server/pkg/response"
)

// AdminHandler 管理端处理器
type AdminHandler struct {
	userService       *service.UserService
	roleService       *service.RoleService
	permissionService *service.PermissionService
	logService        *service.LogService
	momentService     *service.MomentService
}

// NewAdminHandler 创建管理端处理器
func NewAdminHandler() *AdminHandler {
	return &AdminHandler{
		userService:       service.NewUserService(),
		roleService:       service.NewRoleService(),
		permissionService: service.NewPermissionService(),
		logService:        service.NewLogService(),
		momentService:     service.NewMomentService(),
	}
}

// Login 管理员登录
// @Summary 管理员登录
// @Tags admin
// @Accept json
// @Produce json
// @Param request body service.AdminLoginRequest true "登录信息"
// @Success 200 {object} response.Response{data=service.AdminLoginResponse}
// @Router /v1/admin/login [post]
func (h *AdminHandler) Login(c *gin.Context) {
	var req service.AdminLoginRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, err.Error())
		return
	}

	result, err := h.userService.AdminLogin(&req)
	if err != nil {
		if errors.Is(err, service.ErrInvalidCredentials) {
			response.Unauthorized(c, "用户名或密码错误")
			return
		}
		if errors.Is(err, service.ErrUserDisabled) {
			response.Forbidden(c, "账号已被禁用")
			return
		}
		response.InternalServerError(c, err.Error())
		return
	}

	response.Success(c, result)
}

// Refresh 管理员刷新 Token
func (h *AdminHandler) Refresh(c *gin.Context) {
	var req service.AdminRefreshRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, err.Error())
		return
	}

	result, err := h.userService.AdminRefreshToken(&req)
	if err != nil {
		if errors.Is(err, service.ErrInvalidAdminRefresh) {
			response.Unauthorized(c, "invalid refresh token")
			return
		}
		response.InternalServerError(c, err.Error())
		return
	}

	response.Success(c, result)
}

// ListUsers 获取用户列表
// @Summary 获取用户列表
// @Tags admin
// @Produce json
// @Security BearerAuth
// @Param page query int false "页码"
// @Param page_size query int false "每页数量"
// @Param keyword query string false "搜索关键词"
// @Success 200 {object} response.Response{data=service.UserListResponse}
// @Router /v1/admin/users [get]
func (h *AdminHandler) ListUsers(c *gin.Context) {
	page, _ := strconv.Atoi(c.DefaultQuery("page", "1"))
	pageSize, _ := strconv.Atoi(c.DefaultQuery("page_size", "10"))
	keyword := c.Query("keyword")

	if page < 1 {
		page = 1
	}
	if pageSize < 1 || pageSize > 100 {
		pageSize = 10
	}

	result, err := h.userService.ListUsers(page, pageSize, keyword)
	if err != nil {
		response.InternalServerError(c, err.Error())
		return
	}

	response.Success(c, result)
}

// ListUserMoments 管理端查询指定用户的时光列表
// @Summary 管理端查询用户时光列表
// @Tags admin
// @Produce json
// @Security BearerAuth
// @Param user_id path int true "用户ID"
// @Param page query int false "页码"
// @Param page_size query int false "每页数量"
// @Param media_type query string false "媒体类型"
// @Param keyword query string false "内容关键词"
// @Param created_from query string false "开始时间 YYYY-MM-DD 或 RFC3339"
// @Param created_to query string false "结束日期 YYYY-MM-DD（含当日）或 RFC3339 截止时刻"
// @Param include_deleted query string false "1/true 包含已软删"
// @Success 200 {object} response.Response{data=service.AdminMomentListResponse}
// @Router /v1/admin/users/{user_id}/moments [get]
func (h *AdminHandler) ListUserMoments(c *gin.Context) {
	userID, err := strconv.ParseUint(c.Param("user_id"), 10, 64)
	if err != nil {
		response.BadRequest(c, "无效的用户ID")
		return
	}

	page, _ := strconv.Atoi(c.DefaultQuery("page", "1"))
	pageSize, _ := strconv.Atoi(c.DefaultQuery("page_size", "10"))
	if page < 1 {
		page = 1
	}
	if pageSize < 1 || pageSize > 100 {
		pageSize = 10
	}

	user, err := h.userService.GetUserByID(userID)
	if err != nil {
		if errors.Is(err, service.ErrUserNotFound) {
			response.NotFound(c, "用户不存在")
			return
		}
		response.InternalServerError(c, err.Error())
		return
	}

	mediaType := c.Query("media_type")
	if mediaType != "" {
		switch model.MediaType(mediaType) {
		case model.MediaTypeText, model.MediaTypeImage, model.MediaTypeAudio, model.MediaTypeVideo:
		default:
			response.BadRequest(c, "无效的 media_type")
			return
		}
	}

	filter := repository.AdminMomentFilter{
		UserID:    userID,
		MediaType: mediaType,
		Keyword:   c.Query("keyword"),
	}
	inc := c.Query("include_deleted")
	filter.IncludeDeleted = inc == "1" || inc == "true"

	if err := applyAdminMomentTimeQuery(c.Query("created_from"), c.Query("created_to"), &filter); err != nil {
		response.BadRequest(c, "无效的时间参数")
		return
	}

	result, err := h.momentService.ListMomentsForAdmin(filter, page, pageSize)
	if err != nil {
		response.InternalServerError(c, err.Error())
		return
	}
	result.User = user

	response.Success(c, result)
}

func applyAdminMomentTimeQuery(createdFrom, createdTo string, f *repository.AdminMomentFilter) error {
	if createdFrom != "" {
		t, err := time.ParseInLocation("2006-01-02", createdFrom, time.Local)
		if err != nil {
			t, err = time.Parse(time.RFC3339, createdFrom)
			if err != nil {
				return err
			}
		}
		f.CreatedFrom = &t
	}
	if createdTo != "" {
		if t, err := time.ParseInLocation("2006-01-02", createdTo, time.Local); err == nil {
			end := t.AddDate(0, 0, 1)
			f.CreatedToEnd = &end
		} else {
			t2, err2 := time.Parse(time.RFC3339, createdTo)
			if err2 != nil {
				return err2
			}
			f.CreatedToInclusive = &t2
		}
	}
	return nil
}

// CreateUser 创建用户
// @Summary 创建用户
// @Tags admin
// @Accept json
// @Produce json
// @Security BearerAuth
// @Param request body service.CreateUserRequest true "用户信息"
// @Success 200 {object} response.Response{data=service.UserResponse}
// @Router /v1/admin/users [post]
func (h *AdminHandler) CreateUser(c *gin.Context) {
	var req service.CreateUserRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, err.Error())
		return
	}

	result, err := h.userService.CreateUser(&req)
	if err != nil {
		if errors.Is(err, service.ErrUserExists) {
			response.Conflict(c, "用户名已存在")
			return
		}
		response.InternalServerError(c, err.Error())
		return
	}

	response.Success(c, result)
}

// UpdateUser 更新用户
// @Summary 更新用户
// @Tags admin
// @Accept json
// @Produce json
// @Security BearerAuth
// @Param id path int true "用户ID"
// @Param request body service.UpdateUserByAdminRequest true "用户信息"
// @Success 200 {object} response.Response{data=service.UserResponse}
// @Router /v1/admin/users/{id} [put]
func (h *AdminHandler) UpdateUser(c *gin.Context) {
	id, err := strconv.ParseUint(c.Param("id"), 10, 64)
	if err != nil {
		response.BadRequest(c, "无效的用户ID")
		return
	}

	var req service.UpdateUserByAdminRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, err.Error())
		return
	}

	result, err := h.userService.UpdateUserByAdmin(id, &req)
	if err != nil {
		if errors.Is(err, service.ErrUserNotFound) {
			response.NotFound(c, "用户不存在")
			return
		}
		if errors.Is(err, service.ErrUserExists) {
			response.Conflict(c, "用户名已存在")
			return
		}
		response.InternalServerError(c, err.Error())
		return
	}

	response.Success(c, result)
}

// DeleteUser 删除用户
// @Summary 删除用户
// @Tags admin
// @Produce json
// @Security BearerAuth
// @Param id path int true "用户ID"
// @Success 200 {object} response.Response
// @Router /v1/admin/users/{id} [delete]
func (h *AdminHandler) DeleteUser(c *gin.Context) {
	id, err := strconv.ParseUint(c.Param("id"), 10, 64)
	if err != nil {
		response.BadRequest(c, "无效的用户ID")
		return
	}

	if err := h.userService.DeleteUser(id); err != nil {
		if errors.Is(err, service.ErrUserNotFound) {
			response.NotFound(c, "用户不存在")
			return
		}
		response.InternalServerError(c, err.Error())
		return
	}

	response.Success(c, nil)
}

// ToggleUserStatus 切换用户状态
// @Summary 切换用户状态
// @Tags admin
// @Produce json
// @Security BearerAuth
// @Param id path int true "用户ID"
// @Success 200 {object} response.Response
// @Router /v1/admin/users/{id}/toggle-status [patch]
func (h *AdminHandler) ToggleUserStatus(c *gin.Context) {
	id, err := strconv.ParseUint(c.Param("id"), 10, 64)
	if err != nil {
		response.BadRequest(c, "无效的用户ID")
		return
	}

	if err := h.userService.ToggleUserStatus(id); err != nil {
		if errors.Is(err, service.ErrUserNotFound) {
			response.NotFound(c, "用户不存在")
			return
		}
		response.InternalServerError(c, err.Error())
		return
	}

	response.Success(c, nil)
}

// AssignRoles 分配用户角色
// @Summary 分配用户角色
// @Tags admin
// @Accept json
// @Produce json
// @Security BearerAuth
// @Param id path int true "用户ID"
// @Param request body service.AssignRolesRequest true "角色ID列表"
// @Success 200 {object} response.Response
// @Router /v1/admin/users/{id}/roles [put]
func (h *AdminHandler) AssignRoles(c *gin.Context) {
	id, err := strconv.ParseUint(c.Param("id"), 10, 64)
	if err != nil {
		response.BadRequest(c, "无效的用户ID")
		return
	}

	var req service.AssignRolesRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, err.Error())
		return
	}

	if err := h.userService.AssignRoles(id, req.RoleIDs); err != nil {
		if errors.Is(err, service.ErrUserNotFound) {
			response.NotFound(c, "用户不存在")
			return
		}
		response.InternalServerError(c, err.Error())
		return
	}

	response.Success(c, nil)
}

// ListRoles 获取角色列表
// @Summary 获取角色列表
// @Tags admin
// @Produce json
// @Security BearerAuth
// @Success 200 {object} response.Response{data=service.RoleListResponse}
// @Router /v1/admin/roles [get]
func (h *AdminHandler) ListRoles(c *gin.Context) {
	result, err := h.roleService.ListRoles()
	if err != nil {
		response.InternalServerError(c, err.Error())
		return
	}

	response.Success(c, result)
}

// CreateRole 创建角色
// @Summary 创建角色
// @Tags admin
// @Accept json
// @Produce json
// @Security BearerAuth
// @Param request body service.CreateRoleRequest true "角色信息"
// @Success 200 {object} response.Response{data=service.RoleResponse}
// @Router /v1/admin/roles [post]
func (h *AdminHandler) CreateRole(c *gin.Context) {
	var req service.CreateRoleRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, err.Error())
		return
	}

	result, err := h.roleService.CreateRole(&req)
	if err != nil {
		if errors.Is(err, service.ErrRoleExists) {
			response.Conflict(c, "角色代码已存在")
			return
		}
		response.InternalServerError(c, err.Error())
		return
	}

	response.Success(c, result)
}

// UpdateRole 更新角色
// @Summary 更新角色
// @Tags admin
// @Accept json
// @Produce json
// @Security BearerAuth
// @Param id path int true "角色ID"
// @Param request body service.UpdateRoleRequest true "角色信息"
// @Success 200 {object} response.Response{data=service.RoleResponse}
// @Router /v1/admin/roles/{id} [put]
func (h *AdminHandler) UpdateRole(c *gin.Context) {
	id, err := strconv.ParseUint(c.Param("id"), 10, 64)
	if err != nil {
		response.BadRequest(c, "无效的角色ID")
		return
	}

	var req service.UpdateRoleRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, err.Error())
		return
	}

	result, err := h.roleService.UpdateRole(id, &req)
	if err != nil {
		if errors.Is(err, service.ErrRoleNotFound) {
			response.NotFound(c, "角色不存在")
			return
		}
		if errors.Is(err, service.ErrRoleExists) {
			response.Conflict(c, "角色代码已存在")
			return
		}
		response.InternalServerError(c, err.Error())
		return
	}

	response.Success(c, result)
}

// DeleteRole 删除角色
// @Summary 删除角色
// @Tags admin
// @Produce json
// @Security BearerAuth
// @Param id path int true "角色ID"
// @Success 200 {object} response.Response
// @Router /v1/admin/roles/{id} [delete]
func (h *AdminHandler) DeleteRole(c *gin.Context) {
	id, err := strconv.ParseUint(c.Param("id"), 10, 64)
	if err != nil {
		response.BadRequest(c, "无效的角色ID")
		return
	}

	if err := h.roleService.DeleteRole(id); err != nil {
		if errors.Is(err, service.ErrRoleNotFound) {
			response.NotFound(c, "角色不存在")
			return
		}
		if errors.Is(err, service.ErrRoleHasUsers) {
			response.Conflict(c, "该角色下有用户，无法删除")
			return
		}
		response.InternalServerError(c, err.Error())
		return
	}

	response.Success(c, nil)
}

// AssignPermissions 分配角色权限
// @Summary 分配角色权限
// @Tags admin
// @Accept json
// @Produce json
// @Security BearerAuth
// @Param id path int true "角色ID"
// @Param request body service.AssignPermissionsRequest true "权限ID列表"
// @Success 200 {object} response.Response
// @Router /v1/admin/roles/{id}/permissions [put]
func (h *AdminHandler) AssignPermissions(c *gin.Context) {
	id, err := strconv.ParseUint(c.Param("id"), 10, 64)
	if err != nil {
		response.BadRequest(c, "无效的角色ID")
		return
	}

	var req service.AssignPermissionsRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, err.Error())
		return
	}

	if err := h.roleService.AssignPermissions(id, req.PermissionIDs); err != nil {
		if errors.Is(err, service.ErrRoleNotFound) {
			response.NotFound(c, "角色不存在")
			return
		}
		response.InternalServerError(c, err.Error())
		return
	}

	response.Success(c, nil)
}

// ListPermissions 获取权限列表
// @Summary 获取权限列表
// @Tags admin
// @Produce json
// @Security BearerAuth
// @Success 200 {object} response.Response{data=service.PermissionListResponse}
// @Router /v1/admin/permissions [get]
func (h *AdminHandler) ListPermissions(c *gin.Context) {
	result, err := h.permissionService.ListPermissions()
	if err != nil {
		response.InternalServerError(c, err.Error())
		return
	}

	response.Success(c, result)
}

// ListOperationLogs 获取操作日志
// @Summary 获取操作日志
// @Tags admin
// @Produce json
// @Security BearerAuth
// @Param page query int false "页码"
// @Param page_size query int false "每页数量"
// @Param module query string false "模块"
// @Param username query string false "用户名"
// @Param start_date query string false "开始日期"
// @Param end_date query string false "结束日期"
// @Success 200 {object} response.Response{data=service.LogListResponse}
// @Router /v1/admin/logs [get]
func (h *AdminHandler) ListOperationLogs(c *gin.Context) {
	page, _ := strconv.Atoi(c.DefaultQuery("page", "1"))
	pageSize, _ := strconv.Atoi(c.DefaultQuery("page_size", "10"))
	module := c.Query("module")
	username := c.Query("username")
	startDate := c.Query("start_date")
	endDate := c.Query("end_date")

	if page < 1 {
		page = 1
	}
	if pageSize < 1 || pageSize > 100 {
		pageSize = 10
	}

	req := &service.ListLogsRequest{
		Page:      page,
		PageSize:  pageSize,
		Module:    module,
		Username:  username,
		StartDate: startDate,
		EndDate:   endDate,
	}

	result, err := h.logService.ListOperationLogs(req)
	if err != nil {
		response.InternalServerError(c, err.Error())
		return
	}

	response.Success(c, result)
}

// GetCurrentAdmin 获取当前管理员信息
// @Summary 获取当前管理员信息
// @Tags admin
// @Produce json
// @Security BearerAuth
// @Success 200 {object} response.Response{data=service.UserResponse}
// @Router /v1/admin/me [get]
func (h *AdminHandler) GetCurrentAdmin(c *gin.Context) {
	userID := middleware.GetUserID(c)
	if userID == 0 {
		response.Unauthorized(c, "unauthorized")
		return
	}

	result, err := h.userService.GetUserByID(userID)
	if err != nil {
		if errors.Is(err, service.ErrUserNotFound) {
			response.NotFound(c, "用户不存在")
			return
		}
		response.InternalServerError(c, err.Error())
		return
	}

	response.Success(c, result)
}
