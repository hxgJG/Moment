package repository

import (
	"github.com/moment-server/moment-server/internal/model"
	"gorm.io/gorm"
)

// RoleRepository 角色仓储
type RoleRepository struct {
	db *gorm.DB
}

// NewRoleRepository 创建角色仓储
func NewRoleRepository() *RoleRepository {
	return &RoleRepository{db: GetDB()}
}

// Create 创建角色
func (r *RoleRepository) Create(role *model.Role) error {
	return r.db.Create(role).Error
}

// FindByID 按ID查询
func (r *RoleRepository) FindByID(id uint64) (*model.Role, error) {
	var role model.Role
	err := r.db.Where("id = ?", id).First(&role).Error
	if err != nil {
		return nil, err
	}
	return &role, nil
}

// FindByCode 按代码查询
func (r *RoleRepository) FindByCode(code string) (*model.Role, error) {
	var role model.Role
	err := r.db.Where("code = ?", code).First(&role).Error
	if err != nil {
		return nil, err
	}
	return &role, nil
}

// Update 更新角色
func (r *RoleRepository) Update(role *model.Role) error {
	return r.db.Save(role).Error
}

// Delete 删除角色（软删除）
func (r *RoleRepository) Delete(id uint64) error {
	return r.db.Delete(&model.Role{}, id).Error
}

// ListAll 获取所有角色
func (r *RoleRepository) ListAll() ([]*model.Role, error) {
	var roles []*model.Role
	err := r.db.Where("status = ?", 1).Order("id ASC").Find(&roles).Error
	if err != nil {
		return nil, err
	}
	return roles, nil
}

// CountUsersByRole 统计角色关联的用户数
func (r *RoleRepository) CountUsersByRole(roleID uint64) (int64, error) {
	var count int64
	err := r.db.Model(&model.UserRole{}).Where("role_id = ?", roleID).Count(&count).Error
	return count, err
}

// GetRolePermissions 获取角色权限
func (r *RoleRepository) GetRolePermissions(roleID uint64) ([]*model.Permission, error) {
	var permissions []*model.Permission
	err := r.db.Model(&model.Permission{}).
		Joins("JOIN role_permissions ON permissions.id = role_permissions.permission_id").
		Where("role_permissions.role_id = ?", roleID).
		Find(&permissions).Error
	if err != nil {
		return nil, err
	}
	return permissions, nil
}

// SetRolePermissions 设置角色权限
func (r *RoleRepository) SetRolePermissions(roleID uint64, permissionIDs []uint64) error {
	// 开启事务
	return r.db.Transaction(func(tx *gorm.DB) error {
		// 删除现有权限关联
		if err := tx.Where("role_id = ?", roleID).Delete(&model.RolePermission{}).Error; err != nil {
			return err
		}

		// 添加新权限关联
		for _, permID := range permissionIDs {
			rolePerm := &model.RolePermission{
				RoleID:       roleID,
				PermissionID: permID,
			}
			if err := tx.Create(rolePerm).Error; err != nil {
				return err
			}
		}

		return nil
	})
}
