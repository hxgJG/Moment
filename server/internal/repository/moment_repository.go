package repository

import (
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

// Create 创建记录
func (r *MomentRepository) Create(moment *model.Moment) error {
	return r.db.Create(moment).Error
}

// FindByID 按ID查询
func (r *MomentRepository) FindByID(id uint64) (*model.Moment, error) {
	var moment model.Moment
	err := r.db.Where("id = ?", id).First(&moment).Error
	if err != nil {
		return nil, err
	}
	return &moment, nil
}

// FindAll 分页查询
func (r *MomentRepository) FindAll(filter MomentFilter, page, pageSize int) ([]*model.Moment, int64, error) {
	var moments []*model.Moment
	var total int64

	query := r.db.Model(&model.Moment{})
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

// Update 更新记录
func (r *MomentRepository) Update(moment *model.Moment) error {
	return r.db.Save(moment).Error
}

// Delete 删除记录
func (r *MomentRepository) Delete(id, userID uint64) error {
	return r.db.Where("id = ? AND user_id = ?", id, userID).Delete(&model.Moment{}).Error
}

// CountByUserID 统计用户记录数
func (r *MomentRepository) CountByUserID(userID uint64) (int64, error) {
	var count int64
	err := r.db.Model(&model.Moment{}).Where("user_id = ?", userID).Count(&count).Error
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
		Where("user_id = ?", userID).
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
