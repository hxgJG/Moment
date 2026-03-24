-- Moment 项目数据库初始化
-- 版本：001_init.sql
-- 创建时间：2026-03-19

-- 创建数据库（如果不存在）
CREATE DATABASE IF NOT EXISTS moment DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

USE moment;

-- ============================================
-- 用户表
-- ============================================
CREATE TABLE IF NOT EXISTS `users` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '用户ID',
    `username` VARCHAR(50) NOT NULL COMMENT '用户名',
    `password` VARCHAR(255) NOT NULL COMMENT '密码（bcrypt加密）',
    `nickname` VARCHAR(100) NOT NULL DEFAULT '' COMMENT '昵称',
    `avatar_url` VARCHAR(500) NOT NULL DEFAULT '' COMMENT '头像URL',
    `status` TINYINT NOT NULL DEFAULT 1 COMMENT '状态：0-禁用，1-正常',
    `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    `deleted_at` DATETIME DEFAULT NULL COMMENT '删除时间（软删除）',
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_username` (`username`),
    KEY `idx_status` (`status`),
    KEY `idx_deleted_at` (`deleted_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='用户表';

-- ============================================
-- 时光记录表
-- ============================================
CREATE TABLE IF NOT EXISTS `moments` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '记录ID',
    `user_id` BIGINT UNSIGNED NOT NULL COMMENT '用户ID',
    `content` TEXT NOT NULL COMMENT '记录内容',
    `media_type` VARCHAR(20) NOT NULL DEFAULT 'text' COMMENT '媒体类型：text/image/audio/video',
    `media_paths` JSON DEFAULT NULL COMMENT '媒体文件路径（JSON数组）',
    `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    `deleted_at` DATETIME DEFAULT NULL COMMENT '删除时间（软删除）',
    PRIMARY KEY (`id`),
    KEY `idx_user_id` (`user_id`),
    KEY `idx_created_at` (`created_at`),
    KEY `idx_deleted_at` (`deleted_at`),
    CONSTRAINT `fk_moments_user_id` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='时光记录表';

-- ============================================
-- 角色表
-- ============================================
CREATE TABLE IF NOT EXISTS `roles` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '角色ID',
    `name` VARCHAR(50) NOT NULL COMMENT '角色名称',
    `code` VARCHAR(50) NOT NULL COMMENT '角色代码',
    `description` VARCHAR(200) DEFAULT '' COMMENT '角色描述',
    `status` TINYINT NOT NULL DEFAULT 1 COMMENT '状态：0-禁用，1-正常',
    `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    `deleted_at` DATETIME DEFAULT NULL COMMENT '删除时间（软删除）',
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_code` (`code`),
    KEY `idx_deleted_at` (`deleted_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='角色表';

-- ============================================
-- 权限表
-- ============================================
CREATE TABLE IF NOT EXISTS `permissions` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '权限ID',
    `name` VARCHAR(100) NOT NULL COMMENT '权限名称',
    `code` VARCHAR(100) NOT NULL COMMENT '权限代码',
    `type` VARCHAR(20) NOT NULL DEFAULT 'menu' COMMENT '权限类型：menu/button/api',
    `parent_id` BIGINT UNSIGNED DEFAULT 0 COMMENT '父权限ID',
    `path` VARCHAR(200) DEFAULT '' COMMENT '路由路径',
    `icon` VARCHAR(100) DEFAULT '' COMMENT '图标',
    `sort` INT NOT NULL DEFAULT 0 COMMENT '排序',
    `status` TINYINT NOT NULL DEFAULT 1 COMMENT '状态：0-禁用，1-正常',
    `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    `deleted_at` DATETIME DEFAULT NULL COMMENT '删除时间（软删除）',
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_code` (`code`),
    KEY `idx_parent_id` (`parent_id`),
    KEY `idx_deleted_at` (`deleted_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='权限表';

-- ============================================
-- 用户角色关联表
-- ============================================
CREATE TABLE IF NOT EXISTS `user_roles` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'ID',
    `user_id` BIGINT UNSIGNED NOT NULL COMMENT '用户ID',
    `role_id` BIGINT UNSIGNED NOT NULL COMMENT '角色ID',
    `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_user_role` (`user_id`, `role_id`),
    KEY `idx_role_id` (`role_id`),
    CONSTRAINT `fk_user_roles_user_id` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE,
    CONSTRAINT `fk_user_roles_role_id` FOREIGN KEY (`role_id`) REFERENCES `roles` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='用户角色关联表';

-- ============================================
-- 角色权限关联表
-- ============================================
CREATE TABLE IF NOT EXISTS `role_permissions` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'ID',
    `role_id` BIGINT UNSIGNED NOT NULL COMMENT '角色ID',
    `permission_id` BIGINT UNSIGNED NOT NULL COMMENT '权限ID',
    `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_role_permission` (`role_id`, `permission_id`),
    KEY `idx_permission_id` (`permission_id`),
    CONSTRAINT `fk_role_permissions_role_id` FOREIGN KEY (`role_id`) REFERENCES `roles` (`id`) ON DELETE CASCADE,
    CONSTRAINT `fk_role_permissions_permission_id` FOREIGN KEY (`permission_id`) REFERENCES `permissions` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='角色权限关联表';

-- ============================================
-- 操作日志表
-- ============================================
CREATE TABLE IF NOT EXISTS `operation_logs` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '日志ID',
    `user_id` BIGINT UNSIGNED DEFAULT NULL COMMENT '操作用户ID',
    `username` VARCHAR(50) DEFAULT '' COMMENT '操作用户名',
    `module` VARCHAR(50) NOT NULL DEFAULT '' COMMENT '模块',
    `action` VARCHAR(50) NOT NULL DEFAULT '' COMMENT '动作',
    `method` VARCHAR(10) NOT NULL DEFAULT 'GET' COMMENT '请求方法',
    `path` VARCHAR(200) NOT NULL DEFAULT '' COMMENT '请求路径',
    `ip` VARCHAR(50) NOT NULL DEFAULT '' COMMENT 'IP地址',
    `location` VARCHAR(200) DEFAULT '' COMMENT '地理位置',
    `params` JSON DEFAULT NULL COMMENT '请求参数',
    `result` TEXT COMMENT '返回结果',
    `status` INT NOT NULL DEFAULT 200 COMMENT '响应状态码',
    `duration` INT DEFAULT 0 COMMENT '请求耗时（毫秒）',
    `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '操作时间',
    PRIMARY KEY (`id`),
    KEY `idx_user_id` (`user_id`),
    KEY `idx_module` (`module`),
    KEY `idx_created_at` (`created_at`),
    KEY `idx_path` (`path`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='操作日志表';

-- ============================================
-- 初始化默认数据
-- ============================================

-- 插入超级管理员角色
INSERT INTO `roles` (`name`, `code`, `description`, `status`) VALUES
('超级管理员', 'super_admin', '拥有系统所有权限', 1),
('普通用户', 'user', '普通用户角色', 1),
('管理员', 'admin', '后台管理员角色', 1);

-- 插入超级管理员用户（密码：admin123，bcrypt加密）
INSERT INTO `users` (`username`, `password`, `nickname`, `status`) VALUES
('admin', '$2a$10$uKzWOxUe901YJhGwe540l.7O3vRneTmgaaHMmRVagd8PMrrbaxIzi', '超级管理员', 1);

-- 关联超级管理员和角色
INSERT INTO `user_roles` (`user_id`, `role_id`) VALUES (1, 1);

-- 插入基础权限
INSERT INTO `permissions` (`name`, `code`, `type`, `parent_id`, `path`, `sort`, `status`) VALUES
('系统管理', 'system', 'menu', 0, '/system', 100, 1),
('用户管理', 'system:user', 'menu', 1, '/system/users', 1, 1),
('角色管理', 'system:role', 'menu', 1, '/system/roles', 2, 1),
('权限管理', 'system:permission', 'menu', 1, '/system/permissions', 3, 1),
('日志管理', 'system:log', 'menu', 1, '/system/logs', 4, 1),
('时光管理', 'moment', 'menu', 0, '/moments', 50, 1),
('查看时光', 'moment:list', 'button', 6, '', 1, 1),
('添加时光', 'moment:add', 'button', 6, '', 2, 1),
('编辑时光', 'moment:edit', 'button', 6, '', 3, 1),
('删除时光', 'moment:delete', 'button', 6, '', 4, 1);

-- 关联超级管理员角色和所有权限
INSERT INTO `role_permissions` (`role_id`, `permission_id`)
SELECT 1, `id` FROM `permissions` WHERE `status` = 1;

-- ============================================
-- 创建索引优化（可选，根据实际查询需求）
-- ============================================

-- 为操作日志创建分区（可选，生产环境建议）
-- ALTER TABLE operation_logs PARTITION BY RANGE (YEAR(created_at)) (
--     PARTITION p2024 VALUES LESS THAN (2025),
--     PARTITION p2025 VALUES LESS THAN (2026),
--     PARTITION p2026 VALUES LESS THAN (2027),
--     PARTITION pmax VALUES LESS THAN MAXVALUE
-- );

-- ============================================
-- 验证表结构
-- ============================================
SHOW TABLES;
