package handler

import (
	"errors"
	"strconv"
	"strings"

	"github.com/gin-gonic/gin"
	"github.com/moment-server/moment-server/internal/middleware"
	"github.com/moment-server/moment-server/internal/model"
	"github.com/moment-server/moment-server/internal/service"
	"github.com/moment-server/moment-server/pkg/response"
)

// MomentHandler 时光记录处理器
type MomentHandler struct {
	momentService *service.MomentService
}

// NewMomentHandler 创建时光记录处理器
func NewMomentHandler() *MomentHandler {
	return &MomentHandler{
		momentService: service.NewMomentService(),
	}
}

// ListMoments 分页列表
// @Summary 获取时光记录列表
// @Tags moments
// @Produce json
// @Security BearerAuth
// @Param page query int false "页码" default(1)
// @Param page_size query int false "每页数量" default(10)
// @Success 200 {object} response.Response{data=response.PageData}
// @Router /v1/moments [get]
func (h *MomentHandler) ListMoments(c *gin.Context) {
	page, _ := strconv.Atoi(c.DefaultQuery("page", "1"))
	pageSize, _ := strconv.Atoi(c.DefaultQuery("page_size", "10"))
	if page < 1 {
		page = 1
	}
	if pageSize < 1 || pageSize > 100 {
		pageSize = 10
	}

	userID := middleware.GetUserID(c)

	list, total, err := h.momentService.ListMoments(userID, page, pageSize)
	if err != nil {
		response.InternalServerError(c, err.Error())
		return
	}

	response.SuccessPage(c, list, total, page, pageSize)
}

// CreateMoment 创建记录
// @Summary 创建时光记录
// @Tags moments
// @Accept json
// @Produce json
// @Security BearerAuth
// @Param request body service.CreateMomentRequest true "记录信息"
// @Success 200 {object} response.Response{data=service.MomentResponse}
// @Router /v1/moments [post]
func (h *MomentHandler) CreateMoment(c *gin.Context) {
	userID := middleware.GetUserID(c)
	if userID == 0 {
		response.Unauthorized(c, "unauthorized")
		return
	}

	var req service.CreateMomentRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, err.Error())
		return
	}

	// 设置默认 media_type
	if req.MediaType == "" {
		req.MediaType = model.MediaTypeText
	}

	if strings.TrimSpace(req.Content) == "" && len(req.MediaPaths) == 0 {
		response.BadRequest(c, "内容和媒体不能同时为空")
		return
	}

	result, err := h.momentService.CreateMoment(userID, &req)
	if err != nil {
		response.InternalServerError(c, err.Error())
		return
	}

	response.Success(c, result)
}

// GetMoment 获取详情
// @Summary 获取时光记录详情
// @Tags moments
// @Produce json
// @Security BearerAuth
// @Param id path int true "记录ID"
// @Success 200 {object} response.Response{data=service.MomentResponse}
// @Router /v1/moments/{id} [get]
func (h *MomentHandler) GetMoment(c *gin.Context) {
	id, err := strconv.ParseUint(c.Param("id"), 10, 64)
	if err != nil {
		response.BadRequest(c, "invalid id")
		return
	}

	result, err := h.momentService.GetMoment(id)
	if err != nil {
		if errors.Is(err, service.ErrMomentNotFound) {
			response.NotFound(c, "moment not found")
			return
		}
		response.InternalServerError(c, err.Error())
		return
	}

	response.Success(c, result)
}

// UpdateMoment 更新记录
// @Summary 更新时光记录
// @Tags moments
// @Accept json
// @Produce json
// @Security BearerAuth
// @Param id path int true "记录ID"
// @Param request body service.UpdateMomentRequest true "更新信息"
// @Success 200 {object} response.Response{data=service.MomentResponse}
// @Router /v1/moments/{id} [put]
func (h *MomentHandler) UpdateMoment(c *gin.Context) {
	userID := middleware.GetUserID(c)
	if userID == 0 {
		response.Unauthorized(c, "unauthorized")
		return
	}

	id, err := strconv.ParseUint(c.Param("id"), 10, 64)
	if err != nil {
		response.BadRequest(c, "invalid id")
		return
	}

	var req service.UpdateMomentRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, err.Error())
		return
	}

	result, err := h.momentService.UpdateMoment(id, userID, &req)
	if err != nil {
		if errors.Is(err, service.ErrMomentNotFound) {
			response.NotFound(c, "moment not found")
			return
		}
		if errors.Is(err, service.ErrForbidden) {
			response.Forbidden(c, "forbidden")
			return
		}
		response.InternalServerError(c, err.Error())
		return
	}

	response.Success(c, result)
}

// DeleteMoment 删除记录
// @Summary 删除时光记录
// @Tags moments
// @Produce json
// @Security BearerAuth
// @Param id path int true "记录ID"
// @Success 200 {object} response.Response
// @Router /v1/moments/{id} [delete]
func (h *MomentHandler) DeleteMoment(c *gin.Context) {
	userID := middleware.GetUserID(c)
	if userID == 0 {
		response.Unauthorized(c, "unauthorized")
		return
	}

	id, err := strconv.ParseUint(c.Param("id"), 10, 64)
	if err != nil {
		response.BadRequest(c, "invalid id")
		return
	}

	err = h.momentService.DeleteMoment(id, userID)
	if err != nil {
		if errors.Is(err, service.ErrMomentNotFound) {
			response.NotFound(c, "moment not found")
			return
		}
		if errors.Is(err, service.ErrForbidden) {
			response.Forbidden(c, "forbidden")
			return
		}
		response.InternalServerError(c, err.Error())
		return
	}

	response.SuccessWithMsg(c, "deleted successfully", nil)
}
