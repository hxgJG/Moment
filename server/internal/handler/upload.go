package handler

import (
	"github.com/gin-gonic/gin"
	"github.com/moment-server/moment-server/internal/middleware"
	"github.com/moment-server/moment-server/internal/service"
	"github.com/moment-server/moment-server/pkg/response"
)

// UploadHandler 上传处理器
type UploadHandler struct {
	uploadService *service.UploadService
}

// NewUploadHandler 创建上传处理器
func NewUploadHandler() *UploadHandler {
	return &UploadHandler{
		uploadService: service.NewUploadService(),
	}
}

// Upload 上传文件
// @Summary 上传文件
// @Tags upload
// @Accept multipart/form-data
// @Produce json
// @Security BearerAuth
// @Param file formData file true "文件"
// @Param media_type formData string true "媒体类型" Enums(text, image, audio, video)
// @Success 200 {object} response.Response{data=service.UploadResponse}
// @Router /v1/upload [post]
func (h *UploadHandler) Upload(c *gin.Context) {
	userID := middleware.GetUserID(c)
	if userID == 0 {
		response.Unauthorized(c, "unauthorized")
		return
	}

	file, err := c.FormFile("file")
	if err != nil {
		response.BadRequest(c, "file is required")
		return
	}

	mediaType := c.PostForm("media_type")
	if mediaType == "" {
		mediaType = "image"
	}

	result, err := h.uploadService.UploadFile(file, mediaType)
	if err != nil {
		response.BadRequest(c, err.Error())
		return
	}

	response.Success(c, result)
}
