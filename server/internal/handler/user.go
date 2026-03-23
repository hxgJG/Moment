package handler

import (
	"errors"

	"github.com/gin-gonic/gin"
	"github.com/moment-server/moment-server/internal/middleware"
	"github.com/moment-server/moment-server/internal/service"
	"github.com/moment-server/moment-server/pkg/response"
)

// UserHandler 用户处理器
type UserHandler struct {
	userService *service.UserService
}

// NewUserHandler 创建用户处理器
func NewUserHandler() *UserHandler {
	return &UserHandler{
		userService: service.NewUserService(),
	}
}

// GetCurrentUser 获取当前用户
// @Summary 获取当前用户信息
// @Tags users
// @Produce json
// @Security BearerAuth
// @Success 200 {object} response.Response{data=service.UserResponse}
// @Router /v1/users/me [get]
func (h *UserHandler) GetCurrentUser(c *gin.Context) {
	userID := middleware.GetUserID(c)
	if userID == 0 {
		response.Unauthorized(c, "unauthorized")
		return
	}

	result, err := h.userService.GetCurrentUser(userID)
	if err != nil {
		if errors.Is(err, service.ErrUserNotFound) {
			response.NotFound(c, "user not found")
			return
		}
		response.InternalServerError(c, err.Error())
		return
	}

	response.Success(c, result)
}

// UpdateCurrentUser 更新当前用户
// @Summary 更新当前用户信息
// @Tags users
// @Accept json
// @Produce json
// @Security BearerAuth
// @Param request body service.UpdateUserRequest true "更新信息"
// @Success 200 {object} response.Response{data=service.UserResponse}
// @Router /v1/users/me [put]
func (h *UserHandler) UpdateCurrentUser(c *gin.Context) {
	userID := middleware.GetUserID(c)
	if userID == 0 {
		response.Unauthorized(c, "unauthorized")
		return
	}

	var req service.UpdateUserRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, err.Error())
		return
	}

	result, err := h.userService.UpdateUser(userID, &req)
	if err != nil {
		if errors.Is(err, service.ErrUserNotFound) {
			response.NotFound(c, "user not found")
			return
		}
		response.InternalServerError(c, err.Error())
		return
	}

	response.Success(c, result)
}

// GetStats 获取用户统计
// @Summary 获取用户统计
// @Tags stats
// @Produce json
// @Security BearerAuth
// @Success 200 {object} response.Response{data=service.StatsResponse}
// @Router /v1/stats [get]
func (h *UserHandler) GetStats(c *gin.Context) {
	userID := middleware.GetUserID(c)
	if userID == 0 {
		response.Unauthorized(c, "unauthorized")
		return
	}

	result, err := h.userService.GetStats(userID)
	if err != nil {
		response.InternalServerError(c, err.Error())
		return
	}

	response.Success(c, result)
}
