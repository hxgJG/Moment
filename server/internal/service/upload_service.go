package service

import (
	"errors"
	"fmt"
	"io"
	"mime/multipart"
	"net/url"
	"os"
	"path"
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

// NewUploadServiceWithConfig 使用指定配置创建上传服务，主要用于测试。
func NewUploadServiceWithConfig(cfg *config.UploadConfig) *UploadService {
	return &UploadService{cfg: cfg}
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
	if !s.isAllowedType(file, mediaType) {
		return nil, fmt.Errorf("file type not allowed")
	}

	// 生成存储路径
	ext := filepath.Ext(file.Filename)
	filename := fmt.Sprintf("%d_%s%s", time.Now().UnixNano(), randomString(8), ext)
	storageRelativePath := filepath.Join(mediaType, time.Now().Format("20060102"), filename)
	publicPath := "/" + filepath.ToSlash(filepath.Join("uploads", storageRelativePath))

	// 确保目录存在
	targetPath := filepath.Join(s.cfg.LocalPath, storageRelativePath)
	dir := filepath.Dir(targetPath)
	if err := os.MkdirAll(dir, 0755); err != nil {
		return nil, fmt.Errorf("failed to create directory: %w", err)
	}

	// 保存文件
	src, err := file.Open()
	if err != nil {
		return nil, fmt.Errorf("failed to open file: %w", err)
	}
	defer src.Close()

	dst, err := os.Create(targetPath)
	if err != nil {
		return nil, fmt.Errorf("failed to create file: %w", err)
	}
	defer dst.Close()

	if _, err := io.Copy(dst, src); err != nil {
		return nil, fmt.Errorf("failed to copy file: %w", err)
	}

	return &UploadResponse{
		URL:      publicPath,
		Filename: filename,
		Size:     file.Size,
	}, nil
}

func (s *UploadService) isAllowedType(file *multipart.FileHeader, mediaType string) bool {
	contentType := strings.ToLower(file.Header.Get("Content-Type"))
	for _, allowed := range s.cfg.AllowedTypes {
		if contentType != "" && strings.EqualFold(contentType, allowed) {
			return true
		}
	}

	ext := strings.ToLower(filepath.Ext(file.Filename))
	switch strings.ToLower(mediaType) {
	case "image":
		return ext == ".jpg" || ext == ".jpeg" || ext == ".png" || ext == ".gif" || ext == ".webp" || ext == ".bmp"
	case "audio":
		return ext == ".mp3" || ext == ".wav" || ext == ".m4a" || ext == ".aac"
	case "video":
		return ext == ".mp4" || ext == ".mov" || ext == ".avi" || ext == ".webm" || ext == ".mkv"
	default:
		return false
	}
}

func randomString(length int) string {
	const charset = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
	b := make([]byte, length)
	for i := range b {
		b[i] = charset[time.Now().UnixNano()%int64(len(charset))]
	}
	return string(b)
}

// ResolveManagedFile 将媒体地址解析为受管的公共路径和本地文件路径。
func (s *UploadService) ResolveManagedFile(raw string) (string, string, bool) {
	candidate := strings.TrimSpace(raw)
	if candidate == "" || s.cfg == nil || strings.TrimSpace(s.cfg.LocalPath) == "" {
		return "", "", false
	}

	if strings.HasPrefix(candidate, "http://") || strings.HasPrefix(candidate, "https://") {
		parsed, err := url.Parse(candidate)
		if err != nil {
			return "", "", false
		}
		candidate = parsed.Path
	}

	cleanPublicPath := path.Clean(candidate)
	if !strings.HasPrefix(cleanPublicPath, "/uploads/") {
		return "", "", false
	}

	relativePath := strings.TrimPrefix(cleanPublicPath, "/uploads/")
	parts := strings.Split(relativePath, "/")
	if len(parts) < 3 {
		return "", "", false
	}
	switch parts[0] {
	case "image", "audio", "video":
	default:
		return "", "", false
	}

	root := filepath.Clean(s.cfg.LocalPath)
	target := filepath.Clean(filepath.Join(root, filepath.FromSlash(relativePath)))
	if target != root && !strings.HasPrefix(target, root+string(filepath.Separator)) {
		return "", "", false
	}

	return cleanPublicPath, target, true
}

// DeleteManagedFile 删除受管上传文件。非受管路径和不存在文件会被忽略。
func (s *UploadService) DeleteManagedFile(raw string) error {
	_, targetPath, ok := s.ResolveManagedFile(raw)
	if !ok {
		return nil
	}

	if err := os.Remove(targetPath); err != nil && !errors.Is(err, os.ErrNotExist) {
		return err
	}
	return nil
}
