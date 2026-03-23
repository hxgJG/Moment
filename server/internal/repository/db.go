package repository

import (
	"fmt"
	"time"

	"github.com/moment-server/moment-server/internal/model"
	"github.com/moment-server/moment-server/pkg/config"
	"gorm.io/driver/mysql"
	"gorm.io/gorm"
	"gorm.io/gorm/logger"
)

var db *gorm.DB

// InitDB 初始化数据库连接
func InitDB(cfg *config.DatabaseConfig) error {
	var err error

	// 配置 GORM 日志
	gormLogger := logger.Default.LogMode(logger.Info)

	// 连接数据库
	db, err = gorm.Open(mysql.Open(cfg.DSN()), &gorm.Config{
		Logger: gormLogger,
	})
	if err != nil {
		return fmt.Errorf("failed to connect database: %w", err)
	}

	// 获取原生 sql.DB
	sqlDB, err := db.DB()
	if err != nil {
		return fmt.Errorf("failed to get database instance: %w", err)
	}

	// 配置连接池
	sqlDB.SetMaxIdleConns(cfg.MaxIdleConns)
	sqlDB.SetMaxOpenConns(cfg.MaxOpenConns)
	sqlDB.SetConnMaxLifetime(time.Duration(cfg.ConnMaxLifetime) * time.Second)

	// 自动迁移表结构（仅在开发环境使用）
	// 注意：生产环境应使用 migrate 工具
	// autoMigrate()

	return nil
}

// GetDB 获取数据库实例
func GetDB() *gorm.DB {
	return db
}

// CloseDB 关闭数据库连接
func CloseDB() error {
	if db != nil {
		sqlDB, err := db.DB()
		if err != nil {
			return err
		}
		return sqlDB.Close()
	}
	return nil
}

// autoMigrate 自动迁移表结构
func autoMigrate() {
	err := db.AutoMigrate(
		&model.User{},
		&model.Moment{},
		&model.Role{},
		&model.Permission{},
		&model.UserRole{},
		&model.RolePermission{},
		&model.OperationLog{},
	)
	if err != nil {
		panic(fmt.Sprintf("failed to auto migrate: %v", err))
	}
}

// Transaction 事务执行
func Transaction(fn func(tx *gorm.DB) error) error {
	return db.Transaction(fn)
}
