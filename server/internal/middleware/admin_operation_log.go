package middleware

import (
	"bytes"
	"encoding/json"
	"io"
	"net/http"
	"sort"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/moment-server/moment-server/internal/model"
	"github.com/moment-server/moment-server/internal/repository"
	"go.uber.org/zap"
)

type operationLogCreator interface {
	Create(log *model.OperationLog) error
}

// AdminOperationLogger 记录管理端操作日志。
func AdminOperationLogger() gin.HandlerFunc {
	return adminOperationLoggerWithRepo(repository.NewLogRepository())
}

func adminOperationLoggerWithRepo(logRepo operationLogCreator) gin.HandlerFunc {
	return func(c *gin.Context) {
		if logRepo == nil {
			c.Next()
			return
		}

		start := time.Now()
		bodyBytes := snapshotRequestBody(c)

		c.Next()

		userID := GetUserID(c)
		if userID == 0 {
			return
		}

		username := GetUsername(c)
		params := collectOperationParams(c, bodyBytes)
		logEntry := &model.OperationLog{
			UserID:   &userID,
			Username: username,
			Module:   adminLogModule(c.FullPath(), c.Request.URL.Path),
			Action:   adminLogAction(c.Request.Method, c.FullPath(), c.Request.URL.Path),
			Method:   c.Request.Method,
			Path:     fallbackString(c.FullPath(), c.Request.URL.Path),
			IP:       c.ClientIP(),
			Params:   params,
			Status:   c.Writer.Status(),
			Duration: int(time.Since(start).Milliseconds()),
		}

		if err := logRepo.Create(logEntry); err != nil {
			logger := GetLogger()
			if logger != nil {
				logger.Warn("failed to persist admin operation log",
					zap.Error(err),
					zap.String("path", logEntry.Path),
					zap.String("method", logEntry.Method),
				)
			}
		}
	}
}

func snapshotRequestBody(c *gin.Context) []byte {
	if c.Request == nil || c.Request.Body == nil {
		return nil
	}
	if c.Request.Method == http.MethodGet || c.Request.Method == http.MethodHead {
		return nil
	}

	contentType := strings.ToLower(c.GetHeader("Content-Type"))
	if !strings.Contains(contentType, "application/json") {
		return nil
	}

	bodyBytes, err := io.ReadAll(c.Request.Body)
	if err != nil {
		return nil
	}
	c.Request.Body = io.NopCloser(bytes.NewBuffer(bodyBytes))
	return bodyBytes
}

func collectOperationParams(c *gin.Context, bodyBytes []byte) model.StringSlice {
	values := make([]string, 0, len(c.Params)+len(c.Request.URL.Query())+4)

	if len(c.Params) > 0 {
		for _, param := range c.Params {
			values = append(values, "path."+param.Key+"="+truncateLogValue(param.Value))
		}
	}

	queryKeys := make([]string, 0, len(c.Request.URL.Query()))
	for key := range c.Request.URL.Query() {
		queryKeys = append(queryKeys, key)
	}
	sort.Strings(queryKeys)
	for _, key := range queryKeys {
		for _, value := range c.Request.URL.Query()[key] {
			values = append(values, "query."+key+"="+truncateLogValue(value))
		}
	}

	bodyParams := parseJSONBodyForLog(bodyBytes)
	values = append(values, bodyParams...)

	if len(values) == 0 {
		return nil
	}
	return model.StringSlice(values)
}

func parseJSONBodyForLog(bodyBytes []byte) []string {
	if len(bytes.TrimSpace(bodyBytes)) == 0 {
		return nil
	}

	var body map[string]any
	if err := json.Unmarshal(bodyBytes, &body); err != nil {
		return []string{"body=<invalid-json>"}
	}

	keys := make([]string, 0, len(body))
	for key := range body {
		keys = append(keys, key)
	}
	sort.Strings(keys)

	result := make([]string, 0, len(keys))
	for _, key := range keys {
		result = append(result, "body."+key+"="+truncateLogValue(sanitizeLogFieldValue(key, body[key])))
	}
	return result
}

func sanitizeLogFieldValue(key string, value any) string {
	lowerKey := strings.ToLower(key)
	switch lowerKey {
	case "password", "token", "refresh_token", "access_token":
		return "<redacted>"
	}

	switch typed := value.(type) {
	case string:
		return typed
	default:
		bytes, err := json.Marshal(typed)
		if err != nil {
			return "<unserializable>"
		}
		return string(bytes)
	}
}

func truncateLogValue(value string) string {
	const maxLen = 200
	if len(value) <= maxLen {
		return value
	}
	return value[:maxLen] + "..."
}

func adminLogModule(fullPath, requestPath string) string {
	path := normalizeAdminLogPath(fullPath, requestPath)
	switch {
	case strings.HasPrefix(path, "/users/") && strings.HasSuffix(path, "/moments"):
		return "moment"
	case strings.HasPrefix(path, "/users"):
		return "user"
	case strings.HasPrefix(path, "/roles"):
		return "role"
	case strings.HasPrefix(path, "/permissions"):
		return "permission"
	case strings.HasPrefix(path, "/logs"):
		return "system"
	default:
		return "system"
	}
}

func adminLogAction(method, fullPath, requestPath string) string {
	path := normalizeAdminLogPath(fullPath, requestPath)
	switch {
	case path == "/me":
		return "profile"
	case strings.HasSuffix(path, "/toggle-status"):
		return "toggle-status"
	case strings.HasSuffix(path, "/roles"):
		return "assign-roles"
	case strings.HasSuffix(path, "/permissions"):
		return "assign-permissions"
	}

	switch method {
	case http.MethodGet:
		return "list"
	case http.MethodPost:
		return "create"
	case http.MethodPut:
		return "update"
	case http.MethodPatch:
		return "patch"
	case http.MethodDelete:
		return "delete"
	default:
		return strings.ToLower(method)
	}
}

func normalizeAdminLogPath(fullPath, requestPath string) string {
	path := fallbackString(fullPath, requestPath)
	path = strings.TrimPrefix(path, "/v1/admin")
	if path == "" {
		return "/"
	}
	return path
}

func fallbackString(primary, fallback string) string {
	if primary != "" {
		return primary
	}
	return fallback
}
