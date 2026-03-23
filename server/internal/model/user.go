package model

import (
	"time"
)

// User 用户模型
type User struct {
	ID        uint64     `gorm:"primaryKey;autoIncrement" json:"id"`
	Username  string     `gorm:"column:username;type:varchar(50);not null;uniqueIndex" json:"username"`
	Password  string     `gorm:"column:password;type:varchar(255);not null" json:"-"`
	Nickname  string     `gorm:"column:nickname;type:varchar(100);default:''" json:"nickname"`
	AvatarURL string     `gorm:"column:avatar_url;type:varchar(500);default:''" json:"avatar_url"`
	Status    int8       `gorm:"column:status;type:tinyint;default:1" json:"status"`
	CreatedAt time.Time  `gorm:"column:created_at;autoCreateTime" json:"created_at"`
	UpdatedAt time.Time  `gorm:"column:updated_at;autoUpdateTime" json:"updated_at"`
	DeletedAt *time.Time `gorm:"column:deleted_at;index" json:"deleted_at,omitempty"`
}

// TableName 指定表名
func (User) TableName() string {
	return "users"
}

// UserStatus 用户状态
type UserStatus int8

const (
	UserStatusDisabled UserStatus = 0
	UserStatusEnabled  UserStatus = 1
)

// IsValid 检查用户是否有效
func (u *User) IsEnabled() bool {
	return u.Status == int8(UserStatusEnabled)
}

// UserRole 用户角色关联
type UserRole struct {
	ID        uint64    `gorm:"primaryKey;autoIncrement" json:"id"`
	UserID    uint64    `gorm:"column:user_id;not null;uniqueIndex:uk_user_role" json:"user_id"`
	RoleID    uint64    `gorm:"column:role_id;not null;uniqueIndex:uk_user_role" json:"role_id"`
	CreatedAt time.Time `gorm:"column:created_at;autoCreateTime" json:"created_at"`
}

// TableName 指定表名
func (UserRole) TableName() string {
	return "user_roles"
}
