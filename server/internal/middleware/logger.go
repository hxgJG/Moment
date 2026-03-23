package middleware

import (
	"bytes"
	"io"
	"time"

	"github.com/gin-gonic/gin"
	"go.uber.org/zap"
	"go.uber.org/zap/zapcore"
)

var zapLogger *zap.Logger

// InitLogger 初始化日志记录器
func InitLogger(level, format, output, filePath string, maxSize, maxBackups, maxAge int) error {
	var err error

	// 配置 zap 日志
	config := zap.NewProductionConfig()
	if format == "console" {
		config = zap.NewDevelopmentConfig()
	}
	config.Level = zap.NewAtomicLevelAt(parseLevel(level))
	config.Encoding = format

	if output == "file" {
		config.OutputPaths = []string{filePath}
		config.ErrorOutputPaths = []string{filePath}
	} else {
		config.OutputPaths = []string{"stdout"}
		config.ErrorOutputPaths = []string{"stderr"}
	}

	zapLogger, err = config.Build()
	if err != nil {
		return err
	}

	return nil
}

// Logger 请求日志中间件
func Logger() gin.HandlerFunc {
	return func(c *gin.Context) {
		start := time.Now()

		// 读取请求体（用于日志记录）
		var requestBody []byte
		if c.Request.Body != nil {
			requestBody, _ = io.ReadAll(c.Request.Body)
			c.Request.Body = io.NopCloser(bytes.NewBuffer(requestBody))
		}

		// 处理请求
		c.Next()

		// 计算耗时
		duration := time.Since(start)

		// 获取响应状态
		status := c.Writer.Status()

		// 构建日志字段
		fields := []zap.Field{
			zap.Int("status", status),
			zap.String("method", c.Request.Method),
			zap.String("path", c.Request.URL.Path),
			zap.String("query", c.Request.URL.RawQuery),
			zap.String("ip", c.ClientIP()),
			zap.Duration("duration", duration),
			zap.String("user_agent", c.Request.UserAgent()),
		}

		// 如果有用户信息则记录
		if userID := GetUserID(c); userID > 0 {
			fields = append(fields, zap.Uint64("user_id", userID))
		}

		// 记录错误信息
		if len(c.Errors) > 0 {
			for _, e := range c.Errors {
				fields = append(fields, zap.String("error", e.Error()))
			}
		}

		// 根据状态码选择日志级别
		if status >= 500 {
			zapLogger.Error("request completed with server error", fields...)
		} else if status >= 400 {
			zapLogger.Warn("request completed with client error", fields...)
		} else {
			zapLogger.Info("request completed", fields...)
		}
	}
}

// GetLogger 获取日志记录器
func GetLogger() *zap.Logger {
	return zapLogger
}

func parseLevel(level string) zapcore.Level {
	switch level {
	case "debug":
		return zapcore.DebugLevel
	case "info":
		return zapcore.InfoLevel
	case "warn":
		return zapcore.WarnLevel
	case "error":
		return zapcore.ErrorLevel
	case "dpanic":
		return zapcore.DPanicLevel
	case "panic":
		return zapcore.PanicLevel
	case "fatal":
		return zapcore.FatalLevel
	default:
		return zapcore.InfoLevel
	}
}
