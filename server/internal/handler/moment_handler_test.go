package handler

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/gin-gonic/gin"
	"github.com/moment-server/moment-server/internal/middleware"
	"github.com/moment-server/moment-server/internal/model"
	"github.com/moment-server/moment-server/internal/service"
)

type momentServiceStub struct {
	createFn func(userID uint64, req *service.CreateMomentRequest) (*service.MomentResponse, error)
	getFn    func(id, userID uint64) (*service.MomentResponse, error)
	deleteFn func(id, userID uint64) error
}

func (s momentServiceStub) ListMoments(userID uint64, page, pageSize int) ([]*service.MomentResponse, int64, error) {
	return nil, 0, nil
}

func (s momentServiceStub) CreateMoment(userID uint64, req *service.CreateMomentRequest) (*service.MomentResponse, error) {
	if s.createFn != nil {
		return s.createFn(userID, req)
	}
	return nil, nil
}

func (s momentServiceStub) GetMoment(id, userID uint64) (*service.MomentResponse, error) {
	return s.getFn(id, userID)
}

func (s momentServiceStub) UpdateMoment(id, userID uint64, req *service.UpdateMomentRequest) (*service.MomentResponse, error) {
	return nil, nil
}

func (s momentServiceStub) DeleteMoment(id, userID uint64) error {
	return s.deleteFn(id, userID)
}

func TestMomentGetReturnsNotFound(t *testing.T) {
	gin.SetMode(gin.TestMode)

	router := gin.New()
	router.Use(func(c *gin.Context) {
		c.Set(middleware.ContextKeyUserID, uint64(1))
		c.Next()
	})
	handler := &MomentHandler{
		momentService: momentServiceStub{
			getFn: func(id, userID uint64) (*service.MomentResponse, error) {
				return nil, service.ErrMomentNotFound
			},
		},
	}
	router.GET("/moments/:id", handler.GetMoment)

	req := httptest.NewRequest(http.MethodGet, "/moments/123", nil)
	recorder := httptest.NewRecorder()
	router.ServeHTTP(recorder, req)

	assertHTTPJSON(t, recorder, http.StatusNotFound, 404, "moment not found")
}

func TestMomentCreatePassesClientIDAndMixedMediaType(t *testing.T) {
	gin.SetMode(gin.TestMode)

	router := gin.New()
	router.Use(func(c *gin.Context) {
		c.Set(middleware.ContextKeyUserID, uint64(9))
		c.Next()
	})

	handler := &MomentHandler{
		momentService: momentServiceStub{
			createFn: func(userID uint64, req *service.CreateMomentRequest) (*service.MomentResponse, error) {
				if userID != 9 {
					t.Fatalf("userID = %d, want 9", userID)
				}
				if req.ClientID != "local-uuid-9" {
					t.Fatalf("client_id = %q, want local-uuid-9", req.ClientID)
				}
				if req.MediaType != model.MediaTypeMixed {
					t.Fatalf("media_type = %q, want mixed", req.MediaType)
				}
				if len(req.MediaPaths) != 2 {
					t.Fatalf("media_paths length = %d, want 2", len(req.MediaPaths))
				}
				return &service.MomentResponse{
					ID:         501,
					UserID:     userID,
					Content:    req.Content,
					MediaType:  req.MediaType,
					MediaPaths: req.MediaPaths,
					CreatedAt:  "2026-04-21 10:00:00",
					UpdatedAt:  "2026-04-21 10:00:00",
				}, nil
			},
		},
	}
	router.POST("/moments", handler.CreateMoment)

	req := httptest.NewRequest(
		http.MethodPost,
		"/moments",
		strings.NewReader(`{"client_id":"local-uuid-9","content":"hello","media_type":"mixed","media_paths":["https://cdn.example.com/a.jpg","https://cdn.example.com/b.mp4"]}`),
	)
	req.Header.Set("Content-Type", "application/json")
	recorder := httptest.NewRecorder()

	router.ServeHTTP(recorder, req)

	if recorder.Code != http.StatusOK {
		t.Fatalf("unexpected http status: got %d want %d", recorder.Code, http.StatusOK)
	}

	var body map[string]any
	if err := json.Unmarshal(recorder.Body.Bytes(), &body); err != nil {
		t.Fatalf("failed to decode body: %v", err)
	}
	if int(body["code"].(float64)) != 200 {
		t.Fatalf("unexpected body code: got %v want 200", body["code"])
	}
	data, ok := body["data"].(map[string]any)
	if !ok {
		t.Fatalf("unexpected data payload: %#v", body["data"])
	}
	if int(data["id"].(float64)) != 501 {
		t.Fatalf("id = %v, want 501", data["id"])
	}
	if data["media_type"] != string(model.MediaTypeMixed) {
		t.Fatalf("media_type = %v, want mixed", data["media_type"])
	}
}

func TestMomentCreateRejectsTooLongClientID(t *testing.T) {
	gin.SetMode(gin.TestMode)

	router := gin.New()
	router.Use(func(c *gin.Context) {
		c.Set(middleware.ContextKeyUserID, uint64(1))
		c.Next()
	})

	handler := &MomentHandler{
		momentService: momentServiceStub{
			createFn: func(userID uint64, req *service.CreateMomentRequest) (*service.MomentResponse, error) {
				t.Fatal("create service should not be called for invalid payload")
				return nil, nil
			},
		},
	}
	router.POST("/moments", handler.CreateMoment)

	req := httptest.NewRequest(
		http.MethodPost,
		"/moments",
		strings.NewReader(`{"client_id":"`+strings.Repeat("x", 65)+`","content":"hello","media_type":"text"}`),
	)
	req.Header.Set("Content-Type", "application/json")
	recorder := httptest.NewRecorder()

	router.ServeHTTP(recorder, req)

	if recorder.Code != http.StatusBadRequest {
		t.Fatalf("unexpected http status: got %d want %d", recorder.Code, http.StatusBadRequest)
	}
}

func TestMomentGetReturnsForbidden(t *testing.T) {
	gin.SetMode(gin.TestMode)

	router := gin.New()
	router.Use(func(c *gin.Context) {
		c.Set(middleware.ContextKeyUserID, uint64(1))
		c.Next()
	})
	handler := &MomentHandler{
		momentService: momentServiceStub{
			getFn: func(id, userID uint64) (*service.MomentResponse, error) {
				return nil, service.ErrForbidden
			},
		},
	}
	router.GET("/moments/:id", handler.GetMoment)

	req := httptest.NewRequest(http.MethodGet, "/moments/123", nil)
	recorder := httptest.NewRecorder()
	router.ServeHTTP(recorder, req)

	assertHTTPJSON(t, recorder, http.StatusForbidden, 403, "forbidden")
}

func TestMomentDeleteReturnsNotFound(t *testing.T) {
	gin.SetMode(gin.TestMode)

	router := gin.New()
	router.Use(func(c *gin.Context) {
		c.Set(middleware.ContextKeyUserID, uint64(1))
		c.Next()
	})
	handler := &MomentHandler{
		momentService: momentServiceStub{
			deleteFn: func(id, userID uint64) error {
				return service.ErrMomentNotFound
			},
		},
	}
	router.DELETE("/moments/:id", handler.DeleteMoment)

	req := httptest.NewRequest(http.MethodDelete, "/moments/123", nil)
	recorder := httptest.NewRecorder()
	router.ServeHTTP(recorder, req)

	assertHTTPJSON(t, recorder, http.StatusNotFound, 404, "moment not found")
}

func TestMomentDeleteReturnsForbidden(t *testing.T) {
	gin.SetMode(gin.TestMode)

	router := gin.New()
	router.Use(func(c *gin.Context) {
		c.Set(middleware.ContextKeyUserID, uint64(1))
		c.Next()
	})
	handler := &MomentHandler{
		momentService: momentServiceStub{
			deleteFn: func(id, userID uint64) error {
				return service.ErrForbidden
			},
		},
	}
	router.DELETE("/moments/:id", handler.DeleteMoment)

	req := httptest.NewRequest(http.MethodDelete, "/moments/123", nil)
	recorder := httptest.NewRecorder()
	router.ServeHTTP(recorder, req)

	assertHTTPJSON(t, recorder, http.StatusForbidden, 403, "forbidden")
}
