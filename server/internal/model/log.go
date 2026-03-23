package model

import (
	"encoding/json"
	"time"
)

// OperationLog 操作日志模型
type OperationLog struct {
	ID        uint64       `gorm:"primaryKey;autoIncrement" json:"id"`
	UserID    *uint64      `gorm:"column:user_id;index" json:"user_id,omitempty"`
	Username  string       `gorm:"column:username;type:varchar(50);default:''" json:"username"`
	Module    string       `gorm:"column:module;type:varchar(50);default:''" json:"module"`
	Action    string       `gorm:"column:action;type:varchar(50);default:''" json:"action"`
	Method    string       `gorm:"column:method;type:varchar(10);default:'GET'" json:"method"`
	Path      string       `gorm:"column:path;type:varchar(200);default:'';index" json:"path"`
	IP        string       `gorm:"column:ip;type:varchar(50);default:''" json:"ip"`
	Location  string       `gorm:"column:location;type:varchar(200);default:''" json:"location"`
	Params    StringSlice  `gorm:"column:params;type:json" json:"params"`
	Result    string       `gorm:"column:result;type:text" json:"result,omitempty"`
	Status    int          `gorm:"column:status;default:200" json:"status"`
	Duration  int          `gorm:"column:duration;default:0" json:"duration"`
	CreatedAt time.Time    `gorm:"column:created_at;autoCreateTime;index" json:"created_at"`
}

// TableName 指定表名
func (OperationLog) TableName() string {
	return "operation_logs"
}

// JSON 实现 json.Marshaler 接口
func (s OperationLog) MarshalJSON() ([]byte, error) {
	type Alias OperationLog
	return json.Marshal(&struct {
		Alias
		Params interface{} `json:"params"`
	}{
		Alias:  (Alias)(s),
		Params: s.Params,
	})
}

// Scan 实现 sql.Scanner 接口
func (s *StringSlice) ScanLog(value interface{}) error {
	return s.Scan(value)
}
