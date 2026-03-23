package repository

import (
	"github.com/moment-server/moment-server/internal/model"
	"gorm.io/gorm"
)

// PermissionRepository 权限仓储
type PermissionRepository struct {
	db *gorm.DB
}

// NewPermissionRepository 创建权限仓储
func NewPermissionRepository() *PermissionRepository {
	return &PermissionRepository{db: GetDB()}
}

// ListAll 获取所有权限
func (r *PermissionRepository) ListAll() ([]*model.Permission, error) {
	var permissions []*model.Permission
	err := r.db.Where("status = ?", 1).Order("sort ASC, id ASC").Find(&permissions).Error
	if err != nil {
		return nil, err
	}
	return permissions, nil
}

// FindByID 按ID查询
func (r *PermissionRepository) FindByID(id uint64) (*model.Permission, error) {
	var perm model.Permission
	err := r.db.Where("id = ?", id).First(&perm).Error
	if err != nil {
		return nil, err
	}
	return &perm, nil
}
