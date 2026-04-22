package handler

import (
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/gin-gonic/gin"
	"github.com/moment-server/moment-server/internal/service"
)

type authServiceStub struct {
	loginFn   func(req *service.LoginRequest) (*service.TokenResponse, error)
	refreshFn func(req *service.RefreshRequest) (*service.TokenResponse, error)
}

func (s authServiceStub) Register(req *service.RegisterRequest) (*service.TokenResponse, error) {
	return nil, nil
}

func (s authServiceStub) Login(req *service.LoginRequest) (*service.TokenResponse, error) {
	return s.loginFn(req)
}

func (s authServiceStub) RefreshToken(req *service.RefreshRequest) (*service.TokenResponse, error) {
	return s.refreshFn(req)
}

func TestAuthLoginRejectsInvalidCredentials(t *testing.T) {
	gin.SetMode(gin.TestMode)

	router := gin.New()
	handler := &AuthHandler{
		authService: authServiceStub{
			loginFn: func(req *service.LoginRequest) (*service.TokenResponse, error) {
				return nil, service.ErrInvalidPassword
			},
		},
	}
	router.POST("/auth/login", handler.Login)

	req := httptest.NewRequest(
		http.MethodPost,
		"/auth/login",
		strings.NewReader(`{"username":"alice","password":"wrong-password"}`),
	)
	req.Header.Set("Content-Type", "application/json")
	recorder := httptest.NewRecorder()

	router.ServeHTTP(recorder, req)

	assertHTTPJSON(t, recorder, http.StatusUnauthorized, 401, "invalid username or password")
}

func TestAuthRefreshRejectsInvalidRefreshToken(t *testing.T) {
	gin.SetMode(gin.TestMode)

	router := gin.New()
	handler := &AuthHandler{
		authService: authServiceStub{
			refreshFn: func(req *service.RefreshRequest) (*service.TokenResponse, error) {
				return nil, service.ErrInvalidRefreshToken
			},
		},
	}
	router.POST("/auth/refresh", handler.RefreshToken)

	req := httptest.NewRequest(
		http.MethodPost,
		"/auth/refresh",
		strings.NewReader(`{"refresh_token":"bad-token"}`),
	)
	req.Header.Set("Content-Type", "application/json")
	recorder := httptest.NewRecorder()

	router.ServeHTTP(recorder, req)

	assertHTTPJSON(t, recorder, http.StatusUnauthorized, 401, "invalid refresh token")
}
