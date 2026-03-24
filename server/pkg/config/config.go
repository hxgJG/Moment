package config

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"sync"

	"github.com/spf13/viper"
)

var (
	cfg  *Config
	once sync.Once
)

// Config 应用配置
type Config struct {
	App      AppConfig      `mapstructure:"app"`
	Database DatabaseConfig `mapstructure:"database"`
	Redis    RedisConfig    `mapstructure:"redis"`
	JWT      JWTConfig      `mapstructure:"jwt"`
	Upload   UploadConfig   `mapstructure:"upload"`
	Log      LogConfig      `mapstructure:"log"`
}

// AppConfig 应用配置
type AppConfig struct {
	Name string `mapstructure:"name"`
	Host string `mapstructure:"host"`
	Port int    `mapstructure:"port"`
	Mode string `mapstructure:"mode"`
	Env  string `mapstructure:"env"`
}

// DatabaseConfig 数据库配置
type DatabaseConfig struct {
	Driver       string `mapstructure:"driver"`
	Host         string `mapstructure:"host"`
	Port         int    `mapstructure:"port"`
	Database     string `mapstructure:"database"`
	Username     string `mapstructure:"username"`
	Password     string `mapstructure:"password"`
	Charset      string `mapstructure:"charset"`
	MaxIdleConns int    `mapstructure:"max_idle_conns"`
	MaxOpenConns int    `mapstructure:"max_open_conns"`
	ConnMaxLifetime int `mapstructure:"conn_max_lifetime"`
}

// RedisConfig Redis配置
type RedisConfig struct {
	Host     string `mapstructure:"host"`
	Port     int    `mapstructure:"port"`
	Password string `mapstructure:"password"`
	DB       int    `mapstructure:"db"`
	PoolSize int    `mapstructure:"pool_size"`
}

// JWTConfig JWT配置
type JWTConfig struct {
	Secret             string `mapstructure:"secret"`
	AccessTokenExpire  int    `mapstructure:"access_token_expire"`
	RefreshTokenExpire int    `mapstructure:"refresh_token_expire"`
}

// UploadConfig 上传配置
type UploadConfig struct {
	Driver     string   `mapstructure:"driver"`
	LocalPath  string   `mapstructure:"local_path"`
	MaxSize    int64    `mapstructure:"max_size"`
	AllowedTypes []string `mapstructure:"allowed_types"`
}

// LogConfig 日志配置
type LogConfig struct {
	Level     string `mapstructure:"level"`
	Format    string `mapstructure:"format"`
	Output    string `mapstructure:"output"`
	FilePath  string `mapstructure:"file_path"`
	MaxSize   int    `mapstructure:"max_size"`
	MaxBackups int   `mapstructure:"max_backups"`
	MaxAge    int    `mapstructure:"max_age"`
}

// DSN 返回数据库连接字符串（强制 utf8mb4 + collation，避免中文按 latin1 误读导致乱码）
func (d *DatabaseConfig) DSN() string {
	cs := strings.TrimSpace(d.Charset)
	if cs == "" || strings.EqualFold(cs, "utf8") {
		cs = "utf8mb4"
	}
	return fmt.Sprintf("%s:%s@tcp(%s:%d)/%s?charset=%s&collation=utf8mb4_unicode_ci&parseTime=True&loc=Local",
		d.Username, d.Password, d.Host, d.Port, d.Database, cs)
}

// Addr 返回 Redis 地址
func (r *RedisConfig) Addr() string {
	return fmt.Sprintf("%s:%d", r.Host, r.Port)
}

// Load 加载配置
func Load(configPath string) (*Config, error) {
	var err error
	once.Do(func() {
		viper.SetConfigFile(configPath)
		viper.SetConfigType("yaml")

		// 设置默认值
		setDefaults()

		// 启用环境变量覆盖
		viper.SetEnvPrefix("APP")
		viper.SetEnvKeyReplacer(strings.NewReplacer(".", "_"))
		viper.AutomaticEnv()

		// 读取配置文件
		if err = viper.ReadInConfig(); err != nil {
			return
		}

		// 可选：config.local.yaml 覆盖同名键（本机 MySQL 密码等，勿提交仓库）
		localPath := filepath.Join(filepath.Dir(configPath), "config.local.yaml")
		if _, statErr := os.Stat(localPath); statErr == nil {
			viper.SetConfigFile(localPath)
			if err = viper.MergeInConfig(); err != nil {
				return
			}
		}

		// 绑定环境变量
		bindEnvVars()

		// 解析配置
		cfg = &Config{}
		if err = viper.Unmarshal(cfg); err != nil {
			return
		}
	})

	if err != nil {
		return nil, fmt.Errorf("failed to load config: %w", err)
	}

	return cfg, nil
}

// Get 获取配置实例
func Get() *Config {
	return cfg
}

func setDefaults() {
	// App defaults
	viper.SetDefault("app.host", "0.0.0.0")
	viper.SetDefault("app.port", 8080)
	viper.SetDefault("app.mode", "debug")
	viper.SetDefault("app.env", "development")

	// Database defaults
	viper.SetDefault("database.driver", "mysql")
	viper.SetDefault("database.charset", "utf8mb4")
	viper.SetDefault("database.max_idle_conns", 10)
	viper.SetDefault("database.max_open_conns", 100)
	viper.SetDefault("database.conn_max_lifetime", 3600)

	// Redis defaults
	viper.SetDefault("redis.port", 6379)
	viper.SetDefault("redis.db", 0)
	viper.SetDefault("redis.pool_size", 10)

	// JWT defaults
	viper.SetDefault("jwt.access_token_expire", 7200)
	viper.SetDefault("jwt.refresh_token_expire", 604800)

	// Upload defaults
	viper.SetDefault("upload.driver", "local")
	viper.SetDefault("upload.max_size", 104857600)

	// Log defaults
	viper.SetDefault("log.level", "debug")
	viper.SetDefault("log.format", "json")
	viper.SetDefault("log.output", "stdout")
}

// bindEnvVars 绑定环境变量到配置
func bindEnvVars() {
	// Database
	viper.BindEnv("database.host", "DATABASE_HOST")
	viper.BindEnv("database.port", "DATABASE_PORT")
	viper.BindEnv("database.username", "DATABASE_USER")
	viper.BindEnv("database.password", "DATABASE_PASSWORD")
	viper.BindEnv("database.database", "DATABASE_NAME")

	// Redis
	viper.BindEnv("redis.host", "REDIS_HOST")
	viper.BindEnv("redis.port", "REDIS_PORT")
	viper.BindEnv("redis.password", "REDIS_PASSWORD")

	// JWT
	viper.BindEnv("jwt.secret", "JWT_SECRET")

	// App
	viper.BindEnv("app.env", "APP_ENV")
}
