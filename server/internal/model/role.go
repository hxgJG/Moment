package model

import (
	"time"
)

// Role 角色模型
type Role struct {
	ID          uint64     `gorm:"primaryKey;autoIncrement" json:"id"`
	Name        string     `gorm:"column:name;type:varchar(50);not null" json:"name"`
	Code        string     `gorm:"column:code;type:varchar(50);not null;uniqueIndex" json:"code"`
	Description string     `gorm:"column:description;type:varchar(200);default:''" json:"description"`
	Status      int8       `gorm:"column:status;type:tinyint;default:1" json:"status"`
	CreatedAt   time.Time  `gorm:"column:created_at;autoCreateTime" json:"created_at"`
	UpdatedAt   time.Time  `gorm:"column:updated_at;autoUpdateTime" json:"updated_at"`
	DeletedAt   *time.Time `gorm:"column:deleted_at;index" json:"deleted_at,omitempty"`
}

// TableName 指定表名
func (Role) TableName() string {
	return "roles"
}

// Permission 权限模型
type Permission struct {
	ID        uint64     `gorm:"primaryKey;autoIncrement" json:"id"`
	Name      string     `gorm:"column:name;type:varchar(100);not null" json:"name"`
	Code      string     `gorm:"column:code;type:varchar(100);not null;uniqueIndex" json:"code"`
	Type      string     `gorm:"column:type;type:varchar(20);default:'menu'" json:"type"` // menu, button, api
	ParentID  uint64     `gorm:"column:parent_id;default:0" json:"parent_id"`
	Path      string     `gorm:"column:path;type:varchar(200);default:''" json:"path"`
	Icon      string     `gorm:"column:icon;type:varchar(100);default:''" json:"icon"`
	Sort      int        `gorm:"column:sort;default:0" json:"sort"`
	Status    int8       `gorm:"column:status;type:tinyint;default:1" json:"status"`
	CreatedAt time.Time  `gorm:"column:created_at;autoCreateTime" json:"created_at"`
	UpdatedAt time.Time  `gorm:"column:updated_at;autoUpdateTime" json:"updated_at"`
	DeletedAt *time.Time `gorm:"column:deleted_at;index" json:"deleted_at,omitempty"`
}

// TableName 指定表名
func (Permission) TableName() string {
	return "permissions"
}

// RolePermission 角色权限关联
type RolePermission struct {
	ID           uint64    `gorm:"primaryKey;autoIncrement" json:"id"`
	RoleID       uint64    `gorm:"column:role_id;not null;uniqueIndex:uk_role_permission" json:"role_id"`
	PermissionID uint64    `gorm:"column:permission_id;not null;uniqueIndex:uk_role_permission" json:"permission_id"`
	CreatedAt    time.Time `gorm:"column:created_at;autoCreateTime" json:"created_at"`
}

// TableName 指定表名
func (RolePermission) TableName() string {
	return "role_permissions"
}
