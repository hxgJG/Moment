package handler

import (
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/gin-gonic/gin"
	"github.com/moment-server/moment-server/internal/service"
)

type adminAuthServiceStub struct {
	loginFn   func(req *service.AdminLoginRequest) (*service.AdminLoginResponse, error)
	refreshFn func(req *service.AdminRefreshRequest) (*service.AdminLoginResponse, error)
}

func (s adminAuthServiceStub) AdminLogin(req *service.AdminLoginRequest) (*service.AdminLoginResponse, error) {
	return s.loginFn(req)
}

func (s adminAuthServiceStub) AdminRefreshToken(req *service.AdminRefreshRequest) (*service.AdminLoginResponse, error) {
	return s.refreshFn(req)
}

func TestAdminLoginRejectsInvalidCredentials(t *testing.T) {
	gin.SetMode(gin.TestMode)

	router := gin.New()
	handler := &AdminHandler{
		authService: adminAuthServiceStub{
			loginFn: func(req *service.AdminLoginRequest) (*service.AdminLoginResponse, error) {
				return nil, service.ErrInvalidCredentials
			},
		},
	}
	router.POST("/admin/login", handler.Login)

	req := httptest.NewRequest(
		http.MethodPost,
		"/admin/login",
		strings.NewReader(`{"username":"admin","password":"wrong-password"}`),
	)
	req.Header.Set("Content-Type", "application/json")
	recorder := httptest.NewRecorder()

	router.ServeHTTP(recorder, req)

	assertHTTPJSON(t, recorder, http.StatusUnauthorized, 401, "用户名或密码错误")
}

func TestAdminLoginRejectsDisabledUser(t *testing.T) {
	gin.SetMode(gin.TestMode)

	router := gin.New()
	handler := &AdminHandler{
		authService: adminAuthServiceStub{
			loginFn: func(req *service.AdminLoginRequest) (*service.AdminLoginResponse, error) {
				return nil, service.ErrUserDisabled
			},
		},
	}
	router.POST("/admin/login", handler.Login)

	req := httptest.NewRequest(
		http.MethodPost,
		"/admin/login",
		strings.NewReader(`{"username":"admin","password":"admin123"}`),
	)
	req.Header.Set("Content-Type", "application/json")
	recorder := httptest.NewRecorder()

	router.ServeHTTP(recorder, req)

	assertHTTPJSON(t, recorder, http.StatusForbidden, 403, "账号已被禁用")
}

func TestAdminRefreshRejectsInvalidRefreshToken(t *testing.T) {
	gin.SetMode(gin.TestMode)

	router := gin.New()
	handler := &AdminHandler{
		authService: adminAuthServiceStub{
			refreshFn: func(req *service.AdminRefreshRequest) (*service.AdminLoginResponse, error) {
				return nil, service.ErrInvalidAdminRefresh
			},
		},
	}
	router.POST("/admin/refresh", handler.Refresh)

	req := httptest.NewRequest(
		http.MethodPost,
		"/admin/refresh",
		strings.NewReader(`{"refresh_token":"bad-token"}`),
	)
	req.Header.Set("Content-Type", "application/json")
	recorder := httptest.NewRecorder()

	router.ServeHTTP(recorder, req)

	assertHTTPJSON(t, recorder, http.StatusUnauthorized, 401, "invalid refresh token")
}
