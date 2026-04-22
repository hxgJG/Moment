package middleware

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/gin-gonic/gin"
	"github.com/moment-server/moment-server/pkg/config"
	"github.com/moment-server/moment-server/pkg/jwt"
)

func initTestJWT() {
	jwt.Init(&config.JWTConfig{
		Secret:             "test-secret",
		AccessTokenExpire:  3600,
		RefreshTokenExpire: 7200,
	})
}

func TestAuthRejectsMissingToken(t *testing.T) {
	gin.SetMode(gin.TestMode)
	initTestJWT()

	router := gin.New()
	router.GET("/moments", Auth(), func(c *gin.Context) {
		c.Status(http.StatusOK)
	})

	req := httptest.NewRequest(http.MethodGet, "/moments", nil)
	recorder := httptest.NewRecorder()

	router.ServeHTTP(recorder, req)

	if recorder.Code != http.StatusUnauthorized {
		t.Fatalf("unexpected status code: got %d want %d", recorder.Code, http.StatusUnauthorized)
	}

	assertJSONBody(t, recorder.Body.String(), map[string]any{
		"code": float64(401),
		"msg":  "missing authorization header",
	})
}

func TestRequireAdminRejectsUserToken(t *testing.T) {
	gin.SetMode(gin.TestMode)
	initTestJWT()

	token, err := jwt.GetManager().GenerateAccessToken(1, "alice", "user")
	if err != nil {
		t.Fatalf("GenerateAccessToken() error = %v", err)
	}

	router := gin.New()
	router.GET("/admin/ping", Auth(), RequireAdmin(), func(c *gin.Context) {
		c.Status(http.StatusOK)
	})

	req := httptest.NewRequest(http.MethodGet, "/admin/ping", nil)
	req.Header.Set("Authorization", "Bearer "+token)
	recorder := httptest.NewRecorder()

	router.ServeHTTP(recorder, req)

	if recorder.Code != http.StatusForbidden {
		t.Fatalf("unexpected status code: got %d want %d", recorder.Code, http.StatusForbidden)
	}

	assertJSONBody(t, recorder.Body.String(), map[string]any{
		"code": float64(403),
		"msg":  "admin access required",
	})
}

func TestRequirePermissionRejectsMissingPermission(t *testing.T) {
	gin.SetMode(gin.TestMode)

	router := gin.New()
	router.GET("/admin/users", func(c *gin.Context) {
		c.Set(ContextKeyPermissionCodes, []string{"moment:list"})
		c.Next()
	}, RequirePermission("system:user"), func(c *gin.Context) {
		c.Status(http.StatusOK)
	})

	req := httptest.NewRequest(http.MethodGet, "/admin/users", nil)
	recorder := httptest.NewRecorder()

	router.ServeHTTP(recorder, req)

	if recorder.Code != http.StatusForbidden {
		t.Fatalf("unexpected status code: got %d want %d", recorder.Code, http.StatusForbidden)
	}

	assertJSONBody(t, recorder.Body.String(), map[string]any{
		"code": float64(403),
		"msg":  "permission denied",
	})
}

func TestRequirePermissionAllowsGrantedPermission(t *testing.T) {
	gin.SetMode(gin.TestMode)

	router := gin.New()
	router.GET("/admin/users", func(c *gin.Context) {
		c.Set(ContextKeyPermissionCodes, []string{"system:user", "moment:list"})
		c.Next()
	}, RequirePermission("system:user"), func(c *gin.Context) {
		c.Status(http.StatusOK)
	})

	req := httptest.NewRequest(http.MethodGet, "/admin/users", nil)
	recorder := httptest.NewRecorder()

	router.ServeHTTP(recorder, req)

	if recorder.Code != http.StatusOK {
		t.Fatalf("unexpected status code: got %d want %d", recorder.Code, http.StatusOK)
	}
}

func assertJSONBody(t *testing.T, body string, want map[string]any) {
	t.Helper()

	var got map[string]any
	if err := json.Unmarshal([]byte(body), &got); err != nil {
		t.Fatalf("invalid json body %q: %v", body, err)
	}
	for key, expected := range want {
		if got[key] != expected {
			t.Fatalf("unexpected %s: got %v want %v", key, got[key], expected)
		}
	}
}
