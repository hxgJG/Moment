package response

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/gin-gonic/gin"
)

func TestErrorUsesHTTPStatusForKnownCode(t *testing.T) {
	gin.SetMode(gin.TestMode)

	tests := []struct {
		name       string
		code       int
		wantStatus int
	}{
		{name: "bad request", code: CodeBadRequest, wantStatus: http.StatusBadRequest},
		{name: "unauthorized", code: CodeUnauthorized, wantStatus: http.StatusUnauthorized},
		{name: "forbidden", code: CodeForbidden, wantStatus: http.StatusForbidden},
		{name: "not found", code: CodeNotFound, wantStatus: http.StatusNotFound},
		{name: "conflict", code: CodeConflict, wantStatus: http.StatusConflict},
		{name: "internal", code: CodeInternalError, wantStatus: http.StatusInternalServerError},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			recorder := httptest.NewRecorder()
			context, _ := gin.CreateTestContext(recorder)

			Error(context, tt.code, "test message")

			if recorder.Code != tt.wantStatus {
				t.Fatalf("unexpected status code: got %d want %d", recorder.Code, tt.wantStatus)
			}

			var body Response
			if err := json.Unmarshal(recorder.Body.Bytes(), &body); err != nil {
				t.Fatalf("failed to decode body: %v", err)
			}
			if body.Code != tt.code {
				t.Fatalf("unexpected body code: got %d want %d", body.Code, tt.code)
			}
			if body.Msg != "test message" {
				t.Fatalf("unexpected message: got %q want %q", body.Msg, "test message")
			}
		})
	}
}

func TestErrorFallsBackToBadRequestForUnknownCode(t *testing.T) {
	gin.SetMode(gin.TestMode)

	recorder := httptest.NewRecorder()
	context, _ := gin.CreateTestContext(recorder)

	Error(context, 4999, "unknown")

	if recorder.Code != http.StatusBadRequest {
		t.Fatalf("unexpected status code: got %d want %d", recorder.Code, http.StatusBadRequest)
	}
}
