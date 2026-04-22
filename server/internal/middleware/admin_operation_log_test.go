package middleware

import (
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/gin-gonic/gin"
	"github.com/moment-server/moment-server/internal/model"
)

type operationLogRepoStub struct {
	createFn func(log *model.OperationLog) error
}

func (s operationLogRepoStub) Create(log *model.OperationLog) error {
	return s.createFn(log)
}

func TestAdminOperationLoggerPersistsRedactedBody(t *testing.T) {
	gin.SetMode(gin.TestMode)

	var saved *model.OperationLog
	router := gin.New()
	router.POST("/v1/admin/users", func(c *gin.Context) {
		c.Set(ContextKeyUserID, uint64(9))
		c.Set(ContextKeyUsername, "admin")
		c.Next()
	}, adminOperationLoggerWithRepo(operationLogRepoStub{
		createFn: func(log *model.OperationLog) error {
			saved = log
			return nil
		},
	}), func(c *gin.Context) {
		c.Status(http.StatusOK)
	})

	req := httptest.NewRequest(http.MethodPost, "/v1/admin/users", strings.NewReader(`{"username":"alice","password":"secret123"}`))
	req.Header.Set("Content-Type", "application/json")
	recorder := httptest.NewRecorder()
	router.ServeHTTP(recorder, req)

	if recorder.Code != http.StatusOK {
		t.Fatalf("unexpected status: got %d want %d", recorder.Code, http.StatusOK)
	}
	if saved == nil {
		t.Fatal("expected log entry to be saved")
	}
	if saved.Module != "user" {
		t.Fatalf("module = %q, want user", saved.Module)
	}
	if saved.Action != "create" {
		t.Fatalf("action = %q, want create", saved.Action)
	}
	if saved.Status != http.StatusOK {
		t.Fatalf("status = %d, want %d", saved.Status, http.StatusOK)
	}
	if !containsLogParam(saved.Params, "body.username=alice") {
		t.Fatalf("expected username in params, got %v", saved.Params)
	}
	if !containsLogParam(saved.Params, "body.password=<redacted>") {
		t.Fatalf("expected redacted password in params, got %v", saved.Params)
	}
}

func TestAdminOperationLoggerRecordsDeniedMomentQuery(t *testing.T) {
	gin.SetMode(gin.TestMode)

	var saved *model.OperationLog
	router := gin.New()
	router.GET("/v1/admin/users/:user_id/moments", func(c *gin.Context) {
		c.Set(ContextKeyUserID, uint64(3))
		c.Set(ContextKeyUsername, "auditor")
		c.Next()
	}, adminOperationLoggerWithRepo(operationLogRepoStub{
		createFn: func(log *model.OperationLog) error {
			saved = log
			return nil
		},
	}), func(c *gin.Context) {
		c.AbortWithStatus(http.StatusForbidden)
	})

	req := httptest.NewRequest(http.MethodGet, "/v1/admin/users/12/moments?keyword=foo", nil)
	recorder := httptest.NewRecorder()
	router.ServeHTTP(recorder, req)

	if recorder.Code != http.StatusForbidden {
		t.Fatalf("unexpected status: got %d want %d", recorder.Code, http.StatusForbidden)
	}
	if saved == nil {
		t.Fatal("expected log entry to be saved")
	}
	if saved.Module != "moment" {
		t.Fatalf("module = %q, want moment", saved.Module)
	}
	if saved.Action != "list" {
		t.Fatalf("action = %q, want list", saved.Action)
	}
	if saved.Status != http.StatusForbidden {
		t.Fatalf("status = %d, want %d", saved.Status, http.StatusForbidden)
	}
	if !containsLogParam(saved.Params, "path.user_id=12") {
		t.Fatalf("expected path user_id in params, got %v", saved.Params)
	}
	if !containsLogParam(saved.Params, "query.keyword=foo") {
		t.Fatalf("expected query keyword in params, got %v", saved.Params)
	}
}

func containsLogParam(params []string, expected string) bool {
	for _, item := range params {
		if item == expected {
			return true
		}
	}
	return false
}
