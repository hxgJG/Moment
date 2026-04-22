package repository

import (
	"strings"
	"time"

	"github.com/moment-server/moment-server/internal/model"
	"gorm.io/gorm"
)

// MomentRepository 时光记录仓储
type MomentRepository struct {
	db *gorm.DB
}

// NewMomentRepository 创建时光记录仓储
func NewMomentRepository() *MomentRepository {
	return &MomentRepository{db: GetDB()}
}

// MomentFilter 查询过滤器
type MomentFilter struct {
	UserID uint64
}

// AdminMomentFilter 管理端按用户查询时光
type AdminMomentFilter struct {
	UserID             uint64
	MediaType          string // 空表示不限
	CreatedFrom        *time.Time
	CreatedToEnd       *time.Time // 上界（不含），用于按自然日区间
	CreatedToInclusive *time.Time // 若设置：created_at <= 该时刻（用于 RFC3339）
	Keyword            string
	IncludeDeleted     bool
}

// Create 创建记录
func (r *MomentRepository) Create(moment *model.Moment) error {
	return r.db.Create(moment).Error
}

// FindByUserIDAndClientID 按用户和客户端记录 ID 查询
func (r *MomentRepository) FindByUserIDAndClientID(userID uint64, clientID string) (*model.Moment, error) {
	var moment model.Moment
	err := r.db.
		Where("user_id = ? AND client_id = ? AND deleted_at IS NULL", userID, clientID).
		First(&moment).
		Error
	if err != nil {
		return nil, err
	}
	return &moment, nil
}

// FindByID 按ID查询
func (r *MomentRepository) FindByID(id uint64) (*model.Moment, error) {
	var moment model.Moment
	err := r.db.Where("id = ? AND deleted_at IS NULL", id).First(&moment).Error
	if err != nil {
		return nil, err
	}
	return &moment, nil
}

// FindAll 分页查询
func (r *MomentRepository) FindAll(filter MomentFilter, page, pageSize int) ([]*model.Moment, int64, error) {
	var moments []*model.Moment
	var total int64

	query := r.db.Model(&model.Moment{}).Where("deleted_at IS NULL")
	if filter.UserID > 0 {
		query = query.Where("user_id = ?", filter.UserID)
	}

	// 统计总数
	if err := query.Count(&total).Error; err != nil {
		return nil, 0, err
	}

	// 分页查询
	offset := (page - 1) * pageSize
	if err := query.Offset(offset).Limit(pageSize).Order("created_at DESC").Find(&moments).Error; err != nil {
		return nil, 0, err
	}

	return moments, total, nil
}

// FindForAdmin 管理端分页查询某用户时光（显式处理 deleted_at，与 ORM 软删字段类型无关）
func (r *MomentRepository) FindForAdmin(f AdminMomentFilter, page, pageSize int) ([]*model.Moment, int64, error) {
	var moments []*model.Moment
	var total int64

	query := r.db.Model(&model.Moment{}).Where("user_id = ?", f.UserID)
	if !f.IncludeDeleted {
		query = query.Where("deleted_at IS NULL")
	}
	if f.MediaType != "" {
		query = query.Where("media_type = ?", f.MediaType)
	}
	if f.CreatedFrom != nil {
		query = query.Where("created_at >= ?", *f.CreatedFrom)
	}
	if f.CreatedToEnd != nil {
		query = query.Where("created_at < ?", *f.CreatedToEnd)
	}
	if f.CreatedToInclusive != nil {
		query = query.Where("created_at <= ?", *f.CreatedToInclusive)
	}
	if f.Keyword != "" {
		like := "%" + f.Keyword + "%"
		query = query.Where("content LIKE ?", like)
	}

	if err := query.Count(&total).Error; err != nil {
		return nil, 0, err
	}

	offset := (page - 1) * pageSize
	if err := query.Order("created_at DESC").Offset(offset).Limit(pageSize).Find(&moments).Error; err != nil {
		return nil, 0, err
	}

	return moments, total, nil
}

// Update 更新记录
func (r *MomentRepository) Update(moment *model.Moment) error {
	return r.db.Save(moment).Error
}

// Delete 删除记录
func (r *MomentRepository) Delete(id, userID uint64) error {
	return r.db.Where("id = ? AND user_id = ?", id, userID).Delete(&model.Moment{}).Error
}

// CountOtherReferencesByMediaPath 统计其他未删除记录是否仍引用同一媒体路径
// managedPath 必须是标准化后的 /uploads/... 公共路径。
func (r *MomentRepository) CountOtherReferencesByMediaPath(managedPath string, excludeMomentID uint64) (int64, error) {
	var count int64
	pattern := "%" + escapeLike(managedPath) + "%"

	err := r.db.Model(&model.Moment{}).
		Where("deleted_at IS NULL").
		Where("id <> ?", excludeMomentID).
		Where(
			"(JSON_SEARCH(media_paths, 'one', ?) IS NOT NULL OR CAST(media_paths AS CHAR) LIKE ? ESCAPE '\\\\')",
			managedPath,
			pattern,
		).
		Count(&count).Error

	return count, err
}

// CountByUserID 统计用户记录数
func (r *MomentRepository) CountByUserID(userID uint64) (int64, error) {
	var count int64
	err := r.db.Model(&model.Moment{}).Where("user_id = ? AND deleted_at IS NULL", userID).Count(&count).Error
	return count, err
}

// CountByMediaType 按类型统计
func (r *MomentRepository) CountByMediaType(userID uint64) (map[model.MediaType]int64, error) {
	type Result struct {
		MediaType model.MediaType
		Count     int64
	}

	var results []Result
	err := r.db.Model(&model.Moment{}).
		Select("media_type, COUNT(*) as count").
		Where("user_id = ? AND deleted_at IS NULL", userID).
		Group("media_type").
		Find(&results).Error

	if err != nil {
		return nil, err
	}

	counts := make(map[model.MediaType]int64)
	for _, r := range results {
		counts[r.MediaType] = r.Count
	}

	return counts, nil
}

func escapeLike(value string) string {
	replacer := strings.NewReplacer(
		"\\", "\\\\",
		"%", "\\%",
		"_", "\\_",
	)
	return replacer.Replace(value)
}
