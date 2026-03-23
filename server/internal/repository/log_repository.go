package repository

import (
	"github.com/moment-server/moment-server/internal/model"
	"gorm.io/gorm"
)

// ListLogsRequest 查询日志请求
type ListLogsRequest struct {
	Page      int
	PageSize  int
	Module    string
	Username  string
	StartDate string
	EndDate   string
}

// LogRepository 日志仓储
type LogRepository struct {
	db *gorm.DB
}

// NewLogRepository 创建日志仓储
func NewLogRepository() *LogRepository {
	return &LogRepository{db: GetDB()}
}

// List 分页查询日志
func (r *LogRepository) List(req *ListLogsRequest) ([]*model.OperationLog, int64, error) {
	var logs []*model.OperationLog
	var total int64

	query := r.db.Model(&model.OperationLog{})

	if req.Module != "" {
		query = query.Where("module = ?", req.Module)
	}
	if req.Username != "" {
		query = query.Where("username LIKE ?", "%"+req.Username+"%")
	}
	if req.StartDate != "" {
		query = query.Where("created_at >= ?", req.StartDate)
	}
	if req.EndDate != "" {
		query = query.Where("created_at <= ?", req.EndDate+" 23:59:59")
	}

	query.Count(&total)

	offset := (req.Page - 1) * req.PageSize
	err := query.Order("id DESC").Offset(offset).Limit(req.PageSize).Find(&logs).Error
	if err != nil {
		return nil, 0, err
	}

	return logs, total, nil
}

// Create 创建日志
func (r *LogRepository) Create(log *model.OperationLog) error {
	return r.db.Create(log).Error
}
