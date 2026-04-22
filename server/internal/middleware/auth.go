package middleware

import (
	"strings"

	"github.com/gin-gonic/gin"
	"github.com/moment-server/moment-server/internal/repository"
	"github.com/moment-server/moment-server/pkg/jwt"
	"github.com/moment-server/moment-server/pkg/response"
)

const (
	// ContextKeyUserID 用户ID上下文键
	ContextKeyUserID = "user_id"
	// ContextKeyUsername 用户名上下文键
	ContextKeyUsername = "username"
	// ContextKeyRole 用户角色上下文键
	ContextKeyRole = "role"
	// ContextKeyPermissionCodes 权限码上下文键
	ContextKeyPermissionCodes = "permission_codes"
)

// Auth JWT认证中间件
func Auth() gin.HandlerFunc {
	return func(c *gin.Context) {
		// 从请求头获取 Token
		authHeader := c.GetHeader("Authorization")
		if authHeader == "" {
			response.Unauthorized(c, "missing authorization header")
			c.Abort()
			return
		}

		// 解析 Bearer token
		parts := strings.SplitN(authHeader, " ", 2)
		if len(parts) != 2 || strings.ToLower(parts[0]) != "bearer" {
			response.Unauthorized(c, "invalid authorization header format")
			c.Abort()
			return
		}

		tokenString := parts[1]

		// 解析和验证 Token
		claims, err := jwt.GetManager().ParseToken(tokenString)
		if err != nil {
			if err == jwt.ErrTokenExpired {
				response.Unauthorized(c, "token has expired")
			} else {
				response.Unauthorized(c, "invalid token")
			}
			c.Abort()
			return
		}

		// 将用户信息存入上下文
		c.Set(ContextKeyUserID, claims.UserID)
		c.Set(ContextKeyUsername, claims.Username)
		c.Set(ContextKeyRole, claims.Role)

		c.Next()
	}
}

// RequireAdmin 管理员鉴权中间件
func RequireAdmin() gin.HandlerFunc {
	return func(c *gin.Context) {
		userID := GetUserID(c)
		role := GetRole(c)
		if userID == 0 || role != "admin" {
			response.Forbidden(c, "admin access required")
			c.Abort()
			return
		}

		userRepo := repository.NewUserRepository()
		isAdmin, err := userRepo.HasAdminRole(userID)
		if err != nil {
			response.InternalServerError(c, "failed to verify admin role")
			c.Abort()
			return
		}
		if !isAdmin {
			response.Forbidden(c, "admin access required")
			c.Abort()
			return
		}

		codes, err := userRepo.GetUserPermissionCodes(userID)
		if err != nil {
			response.InternalServerError(c, "failed to load admin permissions")
			c.Abort()
			return
		}
		c.Set(ContextKeyPermissionCodes, codes)

		c.Next()
	}
}

// RequirePermission 权限码鉴权中间件
func RequirePermission(code string) gin.HandlerFunc {
	return func(c *gin.Context) {
		if code == "" {
			c.Next()
			return
		}

		for _, item := range GetPermissionCodes(c) {
			if item == code {
				c.Next()
				return
			}
		}

		response.Forbidden(c, "permission denied")
		c.Abort()
	}
}

// GetUserID 获取当前用户ID
func GetUserID(c *gin.Context) uint64 {
	userID, exists := c.Get(ContextKeyUserID)
	if !exists {
		return 0
	}
	return userID.(uint64)
}

// GetUsername 获取当前用户名
func GetUsername(c *gin.Context) string {
	username, exists := c.Get(ContextKeyUsername)
	if !exists {
		return ""
	}
	return username.(string)
}

// GetRole 获取当前用户角色
func GetRole(c *gin.Context) string {
	role, exists := c.Get(ContextKeyRole)
	if !exists {
		return ""
	}
	return role.(string)
}

// GetPermissionCodes 获取当前用户权限码
func GetPermissionCodes(c *gin.Context) []string {
	codes, exists := c.Get(ContextKeyPermissionCodes)
	if !exists {
		return nil
	}
	values, ok := codes.([]string)
	if !ok {
		return nil
	}
	return values
}

// OptionalAuth 可选认证中间件（不强制要求登录）
func OptionalAuth() gin.HandlerFunc {
	return func(c *gin.Context) {
		authHeader := c.GetHeader("Authorization")
		if authHeader == "" {
			c.Next()
			return
		}

		parts := strings.SplitN(authHeader, " ", 2)
		if len(parts) != 2 || strings.ToLower(parts[0]) != "bearer" {
			c.Next()
			return
		}

		tokenString := parts[1]
		claims, err := jwt.GetManager().ParseToken(tokenString)
		if err != nil {
			c.Next()
			return
		}

		c.Set(ContextKeyUserID, claims.UserID)
		c.Set(ContextKeyUsername, claims.Username)
		c.Set(ContextKeyRole, claims.Role)

		c.Next()
	}
}
