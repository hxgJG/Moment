package model

import (
	"database/sql/driver"
	"encoding/json"
	"errors"
	"time"
)

// MediaType 媒体类型
type MediaType string

const (
	MediaTypeText   MediaType = "text"
	MediaTypeImage  MediaType = "image"
	MediaTypeAudio  MediaType = "audio"
	MediaTypeVideo  MediaType = "video"
)

// StringSlice JSON序列化的字符串数组
type StringSlice []string

// Scan 实现 sql.Scanner 接口
func (s *StringSlice) Scan(value interface{}) error {
	if value == nil {
		*s = nil
		return nil
	}

	bytes, ok := value.([]byte)
	if !ok {
		return errors.New("failed to scan StringSlice")
	}

	return json.Unmarshal(bytes, s)
}

// Value 实现 driver.Valuer 接口
func (s StringSlice) Value() (driver.Value, error) {
	if s == nil {
		return nil, nil
	}
	return json.Marshal(s)
}

// Moment 时光记录模型
type Moment struct {
	ID         uint64     `gorm:"primaryKey;autoIncrement" json:"id"`
	UserID     uint64     `gorm:"column:user_id;not null;index" json:"user_id"`
	Content    string     `gorm:"column:content;type:text;not null" json:"content"`
	MediaType  MediaType  `gorm:"column:media_type;type:varchar(20);default:'text'" json:"media_type"`
	MediaPaths StringSlice `gorm:"column:media_paths;type:json" json:"media_paths"`
	CreatedAt  time.Time  `gorm:"column:created_at;autoCreateTime" json:"created_at"`
	UpdatedAt  time.Time  `gorm:"column:updated_at;autoUpdateTime" json:"updated_at"`
	DeletedAt  *time.Time `gorm:"column:deleted_at;index" json:"deleted_at,omitempty"`
}

// TableName 指定表名
func (Moment) TableName() string {
	return "moments"
}

// MomentStats 记录统计
type MomentStats struct {
	Total      int64            `json:"total"`
	ByType     map[MediaType]int64 `json:"by_type"`
}
