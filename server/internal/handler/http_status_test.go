package handler

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/gin-gonic/gin"
	"github.com/moment-server/moment-server/internal/middleware"
)

func TestMomentCreateRejectsUnauthorized(t *testing.T) {
	gin.SetMode(gin.TestMode)

	router := gin.New()
	handler := &MomentHandler{}
	router.POST("/moments", handler.CreateMoment)

	req := httptest.NewRequest(http.MethodPost, "/moments", strings.NewReader(`{"content":"hello"}`))
	req.Header.Set("Content-Type", "application/json")
	recorder := httptest.NewRecorder()

	router.ServeHTTP(recorder, req)

	assertHTTPJSON(t, recorder, http.StatusUnauthorized, 401, "unauthorized")
}

func TestMomentCreateRejectsEmptyContentAndMedia(t *testing.T) {
	gin.SetMode(gin.TestMode)

	router := gin.New()
	router.Use(func(c *gin.Context) {
		c.Set(middleware.ContextKeyUserID, uint64(1))
		c.Next()
	})
	handler := &MomentHandler{}
	router.POST("/moments", handler.CreateMoment)

	req := httptest.NewRequest(
		http.MethodPost,
		"/moments",
		strings.NewReader(`{"content":"   ","media_type":"text","media_paths":[]}`),
	)
	req.Header.Set("Content-Type", "application/json")
	recorder := httptest.NewRecorder()

	router.ServeHTTP(recorder, req)

	assertHTTPJSON(t, recorder, http.StatusBadRequest, 400, "内容和媒体不能同时为空")
}

func TestMomentGetRejectsInvalidID(t *testing.T) {
	gin.SetMode(gin.TestMode)

	router := gin.New()
	router.Use(func(c *gin.Context) {
		c.Set(middleware.ContextKeyUserID, uint64(1))
		c.Next()
	})
	handler := &MomentHandler{}
	router.GET("/moments/:id", handler.GetMoment)

	req := httptest.NewRequest(http.MethodGet, "/moments/not-a-number", nil)
	recorder := httptest.NewRecorder()

	router.ServeHTTP(recorder, req)

	assertHTTPJSON(t, recorder, http.StatusBadRequest, 400, "invalid id")
}

func TestUploadRejectsUnauthorized(t *testing.T) {
	gin.SetMode(gin.TestMode)

	router := gin.New()
	handler := &UploadHandler{}
	router.POST("/upload", handler.Upload)

	req := httptest.NewRequest(http.MethodPost, "/upload", nil)
	recorder := httptest.NewRecorder()

	router.ServeHTTP(recorder, req)

	assertHTTPJSON(t, recorder, http.StatusUnauthorized, 401, "unauthorized")
}

func TestUploadRequiresFile(t *testing.T) {
	gin.SetMode(gin.TestMode)

	router := gin.New()
	router.Use(func(c *gin.Context) {
		c.Set(middleware.ContextKeyUserID, uint64(1))
		c.Next()
	})
	handler := &UploadHandler{}
	router.POST("/upload", handler.Upload)

	req := httptest.NewRequest(
		http.MethodPost,
		"/upload",
		strings.NewReader("--boundary--\r\n"),
	)
	req.Header.Set("Content-Type", "multipart/form-data; boundary=boundary")
	recorder := httptest.NewRecorder()

	router.ServeHTTP(recorder, req)

	assertHTTPJSON(t, recorder, http.StatusBadRequest, 400, "file is required")
}

func assertHTTPJSON(t *testing.T, recorder *httptest.ResponseRecorder, wantHTTP, wantCode int, wantMsg string) {
	t.Helper()

	if recorder.Code != wantHTTP {
		t.Fatalf("unexpected http status: got %d want %d", recorder.Code, wantHTTP)
	}

	var body map[string]any
	if err := json.Unmarshal(recorder.Body.Bytes(), &body); err != nil {
		t.Fatalf("failed to decode body: %v", err)
	}

	if int(body["code"].(float64)) != wantCode {
		t.Fatalf("unexpected body code: got %v want %d", body["code"], wantCode)
	}
	if body["msg"] != wantMsg {
		t.Fatalf("unexpected body msg: got %v want %s", body["msg"], wantMsg)
	}
}
