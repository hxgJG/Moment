package handler

import (
	"errors"

	"github.com/gin-gonic/gin"
	"github.com/moment-server/moment-server/internal/service"
	"github.com/moment-server/moment-server/pkg/response"
)

// AuthHandler 认证处理器
type AuthHandler struct {
	authService *service.AuthService
}

// NewAuthHandler 创建认证处理器
func NewAuthHandler() *AuthHandler {
	return &AuthHandler{
		authService: service.NewAuthService(),
	}
}

// Register 注册
// @Summary 用户注册
// @Tags auth
// @Accept json
// @Produce json
// @Param request body service.RegisterRequest true "注册信息"
// @Success 200 {object} response.Response{data=service.TokenResponse}
// @Router /v1/auth/register [post]
func (h *AuthHandler) Register(c *gin.Context) {
	var req service.RegisterRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, err.Error())
		return
	}

	result, err := h.authService.Register(&req)
	if err != nil {
		if errors.Is(err, service.ErrUserAlreadyExists) {
			response.Error(c, response.CodeBadRequest, "user already exists")
			return
		}
		response.InternalServerError(c, err.Error())
		return
	}

	response.Success(c, result)
}

// Login 登录
// @Summary 用户登录
// @Tags auth
// @Accept json
// @Produce json
// @Param request body service.LoginRequest true "登录信息"
// @Success 200 {object} response.Response{data=service.TokenResponse}
// @Router /v1/auth/login [post]
func (h *AuthHandler) Login(c *gin.Context) {
	var req service.LoginRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, err.Error())
		return
	}

	result, err := h.authService.Login(&req)
	if err != nil {
		if errors.Is(err, service.ErrUserNotFound) || errors.Is(err, service.ErrInvalidPassword) {
			response.Unauthorized(c, "invalid username or password")
			return
		}
		response.InternalServerError(c, err.Error())
		return
	}

	response.Success(c, result)
}

// RefreshToken 刷新Token
// @Summary 刷新Token
// @Tags auth
// @Accept json
// @Produce json
// @Param request body service.RefreshRequest true "刷新Token"
// @Success 200 {object} response.Response{data=service.TokenResponse}
// @Router /v1/auth/refresh [post]
func (h *AuthHandler) RefreshToken(c *gin.Context) {
	var req service.RefreshRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, err.Error())
		return
	}

	result, err := h.authService.RefreshToken(&req)
	if err != nil {
		if errors.Is(err, service.ErrInvalidRefreshToken) {
			response.Unauthorized(c, "invalid refresh token")
			return
		}
		response.InternalServerError(c, err.Error())
		return
	}

	response.Success(c, result)
}
