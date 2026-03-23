package service

import (
	"fmt"
	"io"
	"mime/multipart"
	"os"
	"path/filepath"
	"strings"
	"time"

	"github.com/moment-server/moment-server/pkg/config"
)

// UploadService 上传服务
type UploadService struct {
	cfg *config.UploadConfig
}

// NewUploadService 创建上传服务
func NewUploadService() *UploadService {
	return &UploadService{
		cfg: &config.Get().Upload,
	}
}

// UploadResponse 上传响应
type UploadResponse struct {
	URL      string `json:"url"`
	Filename string `json:"filename"`
	Size     int64  `json:"size"`
}

// UploadFile 上传文件
func (s *UploadService) UploadFile(file *multipart.FileHeader, mediaType string) (*UploadResponse, error) {
	// 验证文件大小
	if file.Size > s.cfg.MaxSize {
		return nil, fmt.Errorf("file size exceeds limit: %d bytes", s.cfg.MaxSize)
	}

	// 验证文件类型
	if !s.isAllowedType(file.Header.Get("Content-Type")) {
		return nil, fmt.Errorf("file type not allowed")
	}

	// 生成存储路径
	ext := filepath.Ext(file.Filename)
	filename := fmt.Sprintf("%d_%s%s", time.Now().UnixNano(), randomString(8), ext)
	relativePath := fmt.Sprintf("/%s/%s/%s", mediaType, time.Now().Format("20060102"), filename)

	// 确保目录存在
	dir := filepath.Dir(s.cfg.LocalPath + relativePath)
	if err := os.MkdirAll(dir, 0755); err != nil {
		return nil, fmt.Errorf("failed to create directory: %w", err)
	}

	// 保存文件
	src, err := file.Open()
	if err != nil {
		return nil, fmt.Errorf("failed to open file: %w", err)
	}
	defer src.Close()

	dst, err := os.Create(s.cfg.LocalPath + relativePath)
	if err != nil {
		return nil, fmt.Errorf("failed to create file: %w", err)
	}
	defer dst.Close()

	if _, err := io.Copy(dst, src); err != nil {
		return nil, fmt.Errorf("failed to copy file: %w", err)
	}

	return &UploadResponse{
		URL:      relativePath,
		Filename: filename,
		Size:     file.Size,
	}, nil
}

func (s *UploadService) isAllowedType(contentType string) bool {
	for _, allowed := range s.cfg.AllowedTypes {
		if strings.EqualFold(contentType, allowed) {
			return true
		}
	}
	return false
}

func randomString(length int) string {
	const charset = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
	b := make([]byte, length)
	for i := range b {
		b[i] = charset[time.Now().UnixNano()%int64(len(charset))]
	}
	return string(b)
}
