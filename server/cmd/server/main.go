package main

import (
	"fmt"
	"net/http"
	"os"
	"os/signal"
	"strconv"
	"syscall"

	"github.com/gin-gonic/gin"
	"github.com/moment-server/moment-server/internal/handler"
	"github.com/moment-server/moment-server/internal/middleware"
	"github.com/moment-server/moment-server/internal/repository"
	"github.com/moment-server/moment-server/pkg/config"
	"github.com/moment-server/moment-server/pkg/jwt"
	"go.uber.org/zap"
)

func main() {
	// 加载配置
	cfg, err := config.Load("configs/config.yaml")
	if err != nil {
		fmt.Printf("Failed to load config: %v\n", err)
		os.Exit(1)
	}

	// 初始化日志
	if err := middleware.InitLogger(
		cfg.Log.Level,
		cfg.Log.Format,
		cfg.Log.Output,
		cfg.Log.FilePath,
		cfg.Log.MaxSize,
		cfg.Log.MaxBackups,
		cfg.Log.MaxAge,
	); err != nil {
		fmt.Printf("Failed to init logger: %v\n", err)
		os.Exit(1)
	}
	defer middleware.GetLogger().Sync()

	// 初始化数据库
	if err := repository.InitDB(&cfg.Database); err != nil {
		middleware.GetLogger().Error("Failed to init database", zap.Error(err))
		os.Exit(1)
	}
	defer repository.CloseDB()
	middleware.GetLogger().Info("Database connected successfully")

	// 初始化 JWT
	jwt.Init(&cfg.JWT)

	// 设置 Gin 模式
	gin.SetMode(cfg.App.Mode)

	// 创建 Gin 引擎
	router := gin.New()

	// 注册中间件
	router.Use(middleware.Recovery())
	router.Use(middleware.Logger())
	router.Use(middleware.CORS())

	// 注册路由
	registerRoutes(router)

	// 启动服务器
	addr := fmt.Sprintf("%s:%d", cfg.App.Host, cfg.App.Port)
	middleware.GetLogger().Info("Starting server", zap.String("addr", addr))

	// 优雅关闭
	go func() {
		if err := router.Run(addr); err != nil && err != http.ErrServerClosed {
			middleware.GetLogger().Error("Server failed", zap.Error(err))
			os.Exit(1)
		}
	}()

	// 等待中断信号
	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit

	middleware.GetLogger().Info("Shutting down server...")
}

// registerRoutes 注册路由
func registerRoutes(router *gin.Engine) {
	// 健康检查
	router.GET("/health", healthCheck)

	// 创建处理器
	authHandler := handler.NewAuthHandler()
	userHandler := handler.NewUserHandler()
	momentHandler := handler.NewMomentHandler()
	uploadHandler := handler.NewUploadHandler()
	adminHandler := handler.NewAdminHandler()

	// API v1 路由组
	v1 := router.Group("/v1")
	{
		// 认证路由
		auth := v1.Group("/auth")
		{
			auth.POST("/register", authHandler.Register)
			auth.POST("/login", authHandler.Login)
			auth.POST("/refresh", authHandler.RefreshToken)
		}

		// 用户路由
		users := v1.Group("/users")
		users.Use(middleware.Auth())
		{
			users.GET("/me", userHandler.GetCurrentUser)
			users.PUT("/me", userHandler.UpdateCurrentUser)
		}

		// 时光路由
		moments := v1.Group("/moments")
		{
			moments.GET("", momentHandler.ListMoments)
			moments.GET("/:id", momentHandler.GetMoment)
			moments.POST("", middleware.Auth(), momentHandler.CreateMoment)
			moments.PUT("/:id", middleware.Auth(), momentHandler.UpdateMoment)
			moments.DELETE("/:id", middleware.Auth(), momentHandler.DeleteMoment)
		}

		// 上传路由
		upload := v1.Group("/upload")
		{
			upload.POST("", middleware.Auth(), uploadHandler.Upload)
		}

		// 统计路由
		stats := v1.Group("/stats")
		stats.Use(middleware.Auth())
		{
			stats.GET("", userHandler.GetStats)
		}

		// 管理端路由
		admin := v1.Group("/admin")
		{
			// 管理员登录（不需要认证）
			admin.POST("/login", adminHandler.Login)

			// 需要管理员权限的路由
			adminProtected := admin.Group("")
			adminProtected.Use(middleware.Auth())
			{
				// 管理员信息
				adminProtected.GET("/me", adminHandler.GetCurrentAdmin)

				// 用户管理
				adminProtected.GET("/users", adminHandler.ListUsers)
				adminProtected.POST("/users", adminHandler.CreateUser)
				adminProtected.PUT("/users/:id", adminHandler.UpdateUser)
				adminProtected.DELETE("/users/:id", adminHandler.DeleteUser)
				adminProtected.PATCH("/users/:id/toggle-status", adminHandler.ToggleUserStatus)
				adminProtected.PUT("/users/:id/roles", adminHandler.AssignRoles)

				// 角色管理
				adminProtected.GET("/roles", adminHandler.ListRoles)
				adminProtected.POST("/roles", adminHandler.CreateRole)
				adminProtected.PUT("/roles/:id", adminHandler.UpdateRole)
				adminProtected.DELETE("/roles/:id", adminHandler.DeleteRole)
				adminProtected.PUT("/roles/:id/permissions", adminHandler.AssignPermissions)

				// 权限管理
				adminProtected.GET("/permissions", adminHandler.ListPermissions)

				// 日志管理
				adminProtected.GET("/logs", adminHandler.ListOperationLogs)
			}
		}
	}
}

// healthCheck 健康检查
func healthCheck(c *gin.Context) {
	c.JSON(http.StatusOK, gin.H{
		"status":  "healthy",
		"service": "moment-server",
		"version": "1.0.0",
	})
}

// getPageParam 获取分页参数
func getPageParam(c *gin.Context, defaultPage, defaultPageSize int) (page, pageSize int) {
	page, _ = strconv.Atoi(c.DefaultQuery("page", fmt.Sprintf("%d", defaultPage)))
	pageSize, _ = strconv.Atoi(c.DefaultQuery("page_size", fmt.Sprintf("%d", defaultPageSize)))

	if page < 1 {
		page = 1
	}
	if pageSize < 1 || pageSize > 100 {
		pageSize = defaultPageSize
	}

	return page, pageSize
}
